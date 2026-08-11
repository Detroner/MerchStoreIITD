#!/usr/bin/env bash
set -euo pipefail

# Full onboarding helper for Azure. Interactive but can be driven with env vars.
# Usage example:
# AZ_SUBSCRIPTION_ID=<sub> RESOURCE_GROUP=my-iitd-rg LOCATION=eastus ACR_NAME=myacr POSTGRES_NAME=iitd-postgres APP_NAME=iitd-merch-app KEYVAULT_NAME=my-iitd-kv REPO=owner/repo ./azure/onboard-full.sh

REPO=${REPO:-}
RG=${RESOURCE_GROUP:-my-iitd-rg}
LOC=${LOCATION:-eastus}
ACR=${ACR_NAME:-myacr}
POSTGRES=${POSTGRES_NAME:-iitd-postgres}
APP=${APP_NAME:-iitd-merch-app}
KV=${KEYVAULT_NAME:-my-iitd-keyvault}
SUB=${AZ_SUBSCRIPTION_ID:-}

if [ -z "$SUB" ]; then
  echo "Please set AZ_SUBSCRIPTION_ID in the environment and re-run. Example: export AZ_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
  exit 2
fi

echo "Subscription: $SUB"
echo "Resource group: $RG, location: $LOC, ACR: $ACR, Postgres: $POSTGRES, App: $APP, KeyVault: $KV, Repo: $REPO"

# 1) Provision Azure resources
echo "==> Provisioning ACR, Postgres Flexible Server, Web App (this will create the resource group if missing)"
# Pass ADMIN_PASSWORD in env if you want to set a specific admin password
ADMIN_PASSWORD_ENV="${ADMIN_PASSWORD:-}"
if [ -n "$ADMIN_PASSWORD_ENV" ]; then
  ./azure/provision-azure.sh "$RG" "$LOC" "$ACR" "$POSTGRES" "$APP" "$ADMIN_PASSWORD_ENV"
else
  ./azure/provision-azure.sh "$RG" "$LOC" "$ACR" "$POSTGRES" "$APP"
fi

# Read ACR login server
ACR_LOGIN_SERVER=$(az acr show -n "$ACR" -g "$RG" --subscription "$SUB" --query loginServer -o tsv)
if [ -z "$ACR_LOGIN_SERVER" ]; then
  echo "Failed to determine ACR login server. Check ACR name and resource group." >&2
  exit 1
fi

# 2) Build and push image
echo "==> Building Docker image and pushing to ACR: $ACR_LOGIN_SERVER"
# Ensure we can login to ACR
az acr login -n "$ACR" --subscription "$SUB"
IMAGE_TAG="$ACR_LOGIN_SERVER/$APP:latest"
docker build -t "$IMAGE_TAG" .
docker push "$IMAGE_TAG"

# 3) Create Key Vault and populate secrets (interactive prompts if env not set)
export AZ_SUBSCRIPTION_ID="$SUB"
export AZ_RESOURCE_GROUP="$RG"
export AZURE_REGION="$LOC"

# Prompt or expect DATABASE_URL and secrets in env
if [ -z "${DATABASE_URL:-}" ]; then
  echo "Please enter the DATABASE_URL for the Postgres server (example: postgresql://iitd_admin:<PASSWORD>@${POSTGRES}.postgres.database.azure.com:5432/postgres?sslmode=require)" >&2
  read -r -p "DATABASE_URL: " DATABASE_URL
fi

if [ -z "${SESSION_SECRET:-}" ]; then
  SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))")
  echo "Generated SESSION_SECRET"
fi
if [ -z "${OTP_SECRET:-}" ]; then
  OTP_SECRET=$(node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))")
  echo "Generated OTP_SECRET"
fi
if [ -z "${ADMIN_PASSWORD_HASH:-}" ]; then
  echo "Provide admin password to hash or press Enter to generate a temporary password (you should set a real one)."
  read -s -p "Admin password (leave empty to auto-generate): " ADMIN_PASS
  echo
  if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 16 || echo "ChangeMe2026!")
    echo "Generated temporary admin password: (not printed)"
  fi
  ADMIN_PASSWORD_HASH=$(node scripts/hash-password.mjs "$ADMIN_PASS")
fi

# Call helper to create keyvault and store secrets
DATABASE_URL="$DATABASE_URL" SESSION_SECRET="$SESSION_SECRET" OTP_SECRET="$OTP_SECRET" ADMIN_PASSWORD_HASH="$ADMIN_PASSWORD_HASH" ./azure/create-keyvault-and-secrets.sh "$KV"

# 4) Create service principal and push GitHub secrets (requires gh authenticated)
if [ -z "$REPO" ]; then
  echo "REPO is empty; skipping GitHub secrets creation. To enable, re-run with REPO=owner/repo in env." 
else
  echo "==> Creating service principal and writing GitHub secrets"
  export AZ_SUBSCRIPTION_ID="$SUB"
  ./azure/create-github-secrets.sh "$REPO" "$RG" "$ACR" "$APP"
fi

# 5) Grant Web App managed identity access to Key Vault and set Key Vault references as App Settings
echo "==> Assigning Key Vault access policy to Web App managed identity and configuring App Settings"
PRINCIPAL_ID=$(az webapp identity show -g "$RG" -n "$APP" --query principalId -o tsv)
if [ -z "$PRINCIPAL_ID" ]; then
  echo "Web App managed identity not available; ensure the web app exists and has identity assigned." >&2
else
  az keyvault set-policy -n "$KV" --object-id "$PRINCIPAL_ID" --secret-permissions get list --subscription "$SUB"
  az webapp config appsettings set -g "$RG" -n "$APP" --settings \
    DATABASE_URL="@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/DATABASE-URL)" \
    SESSION_SECRET="@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/SESSION-SECRET)" \
    OTP_SECRET="@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/OTP-SECRET)" \
    ADMIN_PASSWORD_HASH="@Microsoft.KeyVault(SecretUri=https://${KV}.vault.azure.net/secrets/ADMIN-PASSWORD-HASH)"
fi

# 6) Update Web App container to use the pushed image
echo "==> Updating Web App container image to $IMAGE_TAG"
az webapp config container set --name "$APP" --resource-group "$RG" --docker-custom-image-name "$IMAGE_TAG" --docker-registry-server-url "https://$ACR_LOGIN_SERVER"

# 7) Final notes & verification
cat <<EOF
Onboarding complete (scripts ran). Verify the deployment:
  az webapp log tail -g $RG -n $APP
  curl -s https://$APP.azurewebsites.net/api/health
If the app fails to start due to migrations, check container logs and ensure the DATABASE_URL secret is accessible.
EOF
