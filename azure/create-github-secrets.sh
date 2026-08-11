#!/usr/bin/env bash
set -euo pipefail

# Create a service principal scoped to a resource group and push required GitHub secrets.
# Usage:
#   AZ_SUBSCRIPTION_ID=<sub> ./azure/create-github-secrets.sh owner/repo my-rg myacrname my-app-name
# Requires: az (logged in with a user that can create SPs), gh (authenticated), jq (optional but helpful)

REPO=${1:-}
RG=${2:-}
ACR=${3:-}
APP=${4:-}

if [ -z "$REPO" ] || [ -z "$RG" ] || [ -z "$ACR" ] || [ -z "$APP" ]; then
  echo "Usage: $0 owner/repo resource-group acr-name app-name" >&2
  exit 2
fi

if [ -z "${AZ_SUBSCRIPTION_ID:-}" ]; then
  echo "Please set AZ_SUBSCRIPTION_ID in the environment to the target subscription id." >&2
  exit 2
fi

set -x

# Ensure resource group exists
az group show -n "$RG" >/dev/null 2>&1 || az group create -n "$RG" --subscription "$AZ_SUBSCRIPTION_ID"

# Create service principal scoped to the resource group
SP_NAME="github-actions-$(date +%s)"
SP_JSON=$(az ad sp create-for-rbac --name "$SP_NAME" --role Contributor --scopes "/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$RG" --sdk-auth -o json)

# Write AZURE_CREDENTIALS to GitHub secret
echo "Setting AZURE_CREDENTIALS in repo $REPO"
gh secret set AZURE_CREDENTIALS --repo "$REPO" --body "$SP_JSON"

# ACR registry
ACR_LOGIN_SERVER=$(az acr show -n "$ACR" -g "$RG" --query loginServer -o tsv)
if [ -z "$ACR_LOGIN_SERVER" ]; then
  echo "Failed to read ACR login server. Ensure ACR '$ACR' exists in resource group '$RG'." >&2
else
  echo "Setting ACR_REGISTRY=$ACR_LOGIN_SERVER in repo $REPO"
  gh secret set ACR_REGISTRY --repo "$REPO" --body "$ACR_LOGIN_SERVER"

  # Try to fetch admin credentials (may be disabled)
  if az acr credential show -n "$ACR" -g "$RG" >/dev/null 2>&1; then
    ACR_USERNAME=$(az acr credential show -n "$ACR" -g "$RG" --query username -o tsv)
    ACR_PASSWORD=$(az acr credential show -n "$ACR" -g "$RG" --query passwords[0].value -o tsv)
    gh secret set ACR_USERNAME --repo "$REPO" --body "$ACR_USERNAME"
    gh secret set ACR_PASSWORD --repo "$REPO" --body "$ACR_PASSWORD"
  else
    echo "ACR admin credentials not available (admin-enabled may be false). Consider granting a service principal 'AcrPush' role to allow pushing images." >&2
  fi
fi

# App names and resource group
gh secret set AZURE_WEBAPP_NAME --repo "$REPO" --body "$APP"
gh secret set AZURE_RESOURCE_GROUP --repo "$REPO" --body "$RG"

# Guidance output
cat <<EOF
Created service principal with name: $SP_NAME
AZURE_CREDENTIALS secret was written to repo: $REPO
If you want CI to run migrations in GitHub Actions, set DATABASE_URL as a secret too (or prefer Key Vault & Managed Identity).

Next recommended steps:
 1. If ACR admin is disabled, assign AcrPush to the service principal for the ACR resource:
    ACR_ID=$(az acr show -n "$ACR" -g "$RG" --query id -o tsv)
    az role assignment create --assignee-object-id $(echo "$SP_JSON" | jq -r '.clientId') --role AcrPush --scope "$ACR_ID"

 2. Optionally set DATABASE_URL secret:
    gh secret set DATABASE_URL --repo "$REPO" --body "<your-database-url>"

 3. Push to main to trigger CI or build/push locally:
    docker build -t ${ACR_LOGIN_SERVER}/${APP}:latest .
    docker push ${ACR_LOGIN_SERVER}/${APP}:latest
EOF

set +x
