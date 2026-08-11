#!/usr/bin/env bash
set -euo pipefail

# Create an Azure Key Vault and populate it with required secrets for the app.
# Usage:
#   AZ_SUBSCRIPTION_ID=... AZ_RESOURCE_GROUP=... ./azure/create-keyvault-and-secrets.sh myKeyVault
# Or pass as env vars: KV_NAME, AZURE_REGION, DATABASE_URL, SESSION_SECRET, OTP_SECRET, ADMIN_PASSWORD_HASH

KV_NAME=${1:-${KV_NAME:-}}
RG=${AZ_RESOURCE_GROUP:-${RG:-my-iitd-rg}}
LOC=${AZURE_REGION:-${LOC:-eastus}}

if [ -z "$KV_NAME" ]; then
  echo "Usage: $0 <keyvault-name>" >&2
  exit 2
fi

echo "Creating Key Vault '$KV_NAME' in resource group '$RG' (location: $LOC)"

if [ -n "${AZ_SUBSCRIPTION_ID:-}" ]; then
  az account set --subscription "$AZ_SUBSCRIPTION_ID"
fi

az group create --name "$RG" --location "$LOC"

az keyvault create --name "$KV_NAME" --resource-group "$RG" --location "$LOC" --sku standard

# Helper to read secret from env or prompt
read_secret(){
  local name=$1
  local envval=$(printenv "$2" || true)
  if [ -n "$envval" ]; then
    echo "$envval"
    return
  fi
  read -s -p "Enter value for $name: " val
  echo
  echo "$val"
}

# DATABASE_URL
DATABASE_URL=${DATABASE_URL:-}
if [ -z "$DATABASE_URL" ]; then
  DATABASE_URL=$(read_secret "DATABASE_URL" DATABASE_URL)
fi
az keyvault secret set --vault-name "$KV_NAME" --name "DATABASE-URL" --value "$DATABASE_URL"

# SESSION_SECRET
SESSION_SECRET=${SESSION_SECRET:-}
if [ -z "$SESSION_SECRET" ]; then
  SESSION_SECRET=$(read_secret "SESSION_SECRET" SESSION_SECRET)
fi
az keyvault secret set --vault-name "$KV_NAME" --name "SESSION-SECRET" --value "$SESSION_SECRET"

# OTP_SECRET
OTP_SECRET=${OTP_SECRET:-}
if [ -z "$OTP_SECRET" ]; then
  OTP_SECRET=$(read_secret "OTP_SECRET" OTP_SECRET)
fi
az keyvault secret set --vault-name "$KV_NAME" --name "OTP-SECRET" --value "$OTP_SECRET"

# ADMIN_PASSWORD_HASH
ADMIN_PASSWORD_HASH=${ADMIN_PASSWORD_HASH:-}
if [ -z "$ADMIN_PASSWORD_HASH" ]; then
  ADMIN_PASSWORD_HASH=$(read_secret "ADMIN_PASSWORD_HASH" ADMIN_PASSWORD_HASH)
fi
az keyvault secret set --vault-name "$KV_NAME" --name "ADMIN-PASSWORD-HASH" --value "$ADMIN_PASSWORD_HASH"

echo "Secrets written to Key Vault: $KV_NAME"

echo "Notes:
 - Use az keyvault secret show --vault-name $KV_NAME --name <NAME> to read a secret
 - In App Service, set app settings to reference Key Vault secrets via Managed Identity or pull them at deployment time
"
