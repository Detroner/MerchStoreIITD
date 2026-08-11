#!/usr/bin/env bash
set -euo pipefail

# Provision Azure resources for the app. Requires 'az' CLI logged in and subscription set.
# Usage: ./azure/provision-azure.sh <resource-group> <location> <acr-name> <postgres-name> <app-name>

RG=${1:-my-iitd-rg}
LOC=${2:-eastus}
ACR=${3:-myiitragistry}
POSTGRES=${4:-iitd-postgres}
APP=${5:-iitd-merch-app}

echo "Resource group: $RG"

az group create --name "$RG" --location "$LOC"

# Create Azure Container Registry
az acr create --resource-group "$RG" --name "$ACR" --sku Standard --admin-enabled true
ACR_LOGIN_SERVER=$(az acr show -n "$ACR" -g "$RG" --query loginServer -o tsv)

# Create Azure Database for PostgreSQL Flexible Server
az postgres flexible-server create --resource-group "$RG" --name "$POSTGRES" --location "$LOC" --sku-name Standard_B1ms --storage-size 32 --admin-user iitd_admin --admin-password "P@ssw0rdChangeMe!" --version 15

# Configure firewall to allow Azure services (adjust for security)
az postgres flexible-server firewall-rule create -g "$RG" -s "$POSTGRES" -n AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create App Service plan (Linux)
az appservice plan create --name "${APP}-plan" --resource-group "$RG" --is-linux --sku B1 --location "$LOC"

# Create Web App for Container
az webapp create --resource-group "$RG" --plan "${APP}-plan" --name "$APP" --deployment-container-image-name "${ACR_LOGIN_SERVER}/${APP}:latest"

# Assign ACR pull role to webapp's managed identity
PRINCIPAL_ID=$(az webapp identity assign -g "$RG" -n "$APP" --query principalId -o tsv)
AZURE_ACR_RESOURCE_ID=$(az acr show -n "$ACR" -g "$RG" --query id -o tsv)
az role assignment create --assignee "$PRINCIPAL_ID" --role "AcrPull" --scope "$AZURE_ACR_RESOURCE_ID"

# Output values to set as secrets
echo
echo "=== ACTIONS SECRETS / APP SETTINGS ==="
echo "ACR_REGISTRY=$ACR_LOGIN_SERVER"
echo "AZURE_WEBAPP_NAME=$APP"
echo "AZURE_RESOURCE_GROUP=$RG"

echo
echo "Attach the following connection string to your GitHub secrets and App Service configuration:"
echo "DATABASE_URL=postgresql://iitd_admin:P@ssw0rdChangeMe!@${POSTGRES}.postgres.database.azure.com:5432/postgres?sslmode=require"

echo "Provisioning complete. Push Docker images to $ACR_LOGIN_SERVER and update web app container settings or enable CI via GitHub Actions."
