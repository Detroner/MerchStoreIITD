Quick Azure onboarding (use your $100 Education credits)

1) Prerequisites (local):
   - Azure CLI logged in: az login
   - Docker installed and logged in: docker login <ACR_LOGIN_SERVER> (after ACR created)
   - GitHub repo with the updated CI workflow (.github/workflows/ci.yml)

2) Provision resources (quick):
   - Run the provided script (adjust names):
     ./azure/provision-azure.sh my-iitd-rg eastus myiitragistry iitd-postgres iitd-merch-app
   - Note: change admin password and resource names; the script prints ACR registry and DATABASE_URL.

3) Build & push image locally (alternative to Actions):
   - docker build -t <ACR_LOGIN>/${IMAGE_NAME}:latest .
   - docker push <ACR_LOGIN>/${IMAGE_NAME}:latest

4) GitHub Actions (recommended):
   - Add repo secrets:
     - ACR_REGISTRY (e.g., myregistry.azurecr.io)
     - ACR_USERNAME / ACR_PASSWORD (or use azure/login with AZURE_CREDENTIALS)
     - AZURE_CREDENTIALS (service principal JSON)
     - AZURE_WEBAPP_NAME
     - AZURE_RESOURCE_GROUP
     - DATABASE_URL (postgres connection string)
   - Push to main to trigger CI: it builds image and deploys to Web App for Containers.

5) App configuration in Azure:
   - In App Service > Configuration, add app settings:
     - DATABASE_URL, SESSION_SECRET, OTP_SECRET, ADMIN_EMAIL, ADMIN_PASSWORD_HASH (set from scripts/hash-password.mjs output)
   - Enable HTTPS only and configure startup health checks.

6) Post-deploy verification:
   - Visit https://<AZURE_WEBAPP_NAME>.azurewebsites.net/api/health — should return {ok:true,database:'postgresql'}
   - Check logs: az webapp log tail -n <app> -g <rg>

7) Cost & scaling notes:
   - Use small SKUs during development (ACR Standard, App Service B1, Postgres Basic). Scale up for production.
   - Monitor spend in portal and use budget alerts.

Detailed GitHub Actions and Service Principal setup

If you want CI to push images and deploy automatically, create a service principal with contributor rights to the resource group (or a scoped role that can deploy and update the Web App). Run locally and keep the JSON safe:

```bash
# Create a service principal scoped to the resource group (run after creating the resource group)
az ad sp create-for-rbac --name "github-actions-iitd" \
  --role Contributor \
  --scopes /subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$RG \
  --sdk-auth
```

The output is a JSON blob suitable for the AZURE_CREDENTIALS secret in GitHub. Copy it and add a repository secret named `AZURE_CREDENTIALS` with the JSON value (exact text). Also add these secrets:

- ACR_REGISTRY -> the ACR login server printed by the provisioning script (e.g. myacr.azurecr.io)
- ACR_USERNAME -> the ACR admin username (if using admin credentials)
- ACR_PASSWORD -> the ACR admin password (if using admin credentials)
- AZURE_WEBAPP_NAME -> name of the Web App created
- AZURE_RESOURCE_GROUP -> the resource group name
- DATABASE_URL -> full postgres connection string for migrations (if you want CI to run migrations)

If you prefer using Managed Identity and Key Vault referencing instead of storing DATABASE_URL in GitHub, follow these steps after provisioning:

1. Create a Key Vault and write secrets (or run the helper):
   ./azure/create-keyvault-and-secrets.sh my-iitd-keyvault

2. Assign the Web App's system-assigned identity access to Key Vault secrets:
   PRINCIPAL_ID=$(az webapp identity show -g $RG -n $APP --query principalId -o tsv)
   az keyvault set-policy -n my-iitd-keyvault --object-id $PRINCIPAL_ID --secret-permissions get list

3. Configure App Settings with Key Vault references (App Service resolves them automatically):
   az webapp config appsettings set -g $RG -n $APP --settings \
     DATABASE_URL="@Microsoft.KeyVault(SecretUri=https://my-iitd-keyvault.vault.azure.net/secrets/DATABASE-URL)" \
     SESSION_SECRET="@Microsoft.KeyVault(SecretUri=https://my-iitd-keyvault.vault.azure.net/secrets/SESSION-SECRET)" \
     OTP_SECRET="@Microsoft.KeyVault(SecretUri=https://my-iitd-keyvault.vault.azure.net/secrets/OTP-SECRET)"

This keeps secrets out of GitHub and uses the Web App's managed identity to fetch secrets at runtime.

If you'd like, I can prepare the exact one-line commands to run locally (provision, create SP, and push secrets) and a checklist to paste into your terminal. I'll continue implementing those scripts and CI guidance now.