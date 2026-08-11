# MerchStore Azure Deployment - Complete Manual Guide

## STATUS: Policy Restriction - Support Ticket Required

**Current Blocker**: Your Azure Education subscription has a policy that blocks:
- All App Service Plans
- Container Registries  
- PostgreSQL Servers
- Key Vaults
- And other enterprise services

This requires a **Microsoft Support ticket** to resolve.

---

## IMMEDIATE ACTION REQUIRED

### Step 1: Create Azure Support Request

1. Go to: https://portal.azure.com/
2. Click **Help + support** → **New support request**
3. Fill out:
   - **Issue type**: Service and subscription limits (quotas)
   - **Subscription**: Azure for Students
   - **Service**: General
   - **Problem summary**: "Policy restrictions blocking resource creation for MerchStore app deployment"
   - **Description**: 
     ```
     Hello,
     
     I'm using an Azure Education subscription ($100 credits) to deploy a production Node.js/PostgreSQL application 
     called MerchStore. I need to deploy:
     
     - 1x App Service Plan (B1 tier, Linux)
     - 1x Web App for Containers
     - 1x Azure Container Registry (Basic)
     - 1x PostgreSQL Flexible Server (B1ms)
     - 1x Key Vault (Standard)
     
     I'm receiving "RequestDisallowedByAzure" errors for all resource types in all regions. 
     
     Could you please approve these resource types for my subscription? 
     Resource Group: my-iitd-rg
     Subscription ID: [from your account]
     
     Thank you!
     ```
4. Click **Next: Solutions** → **Next: Details** → **Create**

**Expected response time: 2-4 hours**

---

## Once Policy Exception is Approved:

Run this complete deployment script:

```powershell
# Set these variables
$subscriptionId = "92e0da8a-a2bd-4791-8b9b-412bf60101b1"
$resourceGroup = "my-iitd-rg"
$location = "eastus2"
$appName = "iitd-merch-app"
$acrName = "myacrregistry"
$postgresName = "iitd-postgres"
$keyVaultName = "iitd-keyvault"
$githubRepo = "Detroner/MerchStoreIITD"

# Login to Azure
az login
az account set --subscription $subscriptionId

# Run onboarding
cd C:\path\to\MerchStore\repository
.\azure\onboard-full.ps1
```

---

## Manual Step-by-Step Deployment (If Automation Fails)

### Phase 1: Infrastructure Setup (15 mins)

```powershell
$rg = "my-iitd-rg"
$loc = "eastus2"
$sub = "92e0da8a-a2bd-4791-8b9b-412bf60101b1"

# 1. Create Resource Group
az group create -n $rg -l $loc

# 2. Create Container Registry
az acr create -g $rg -n myacrregistry --sku Basic --admin-enabled true

# 3. Create PostgreSQL
$dbAdmin = "iitd_admin"
$dbPass = "YourSecurePassword@123"

az postgres flexible-server create `
  -g $rg -n iitd-postgres `
  -l $loc `
  --admin-user $dbAdmin `
  --admin-password $dbPass `
  --sku-name Standard_B1ms `
  --storage-size 32 `
  --tier Burstable `
  --public-access 0.0.0.0

# 4. Create App Service Plan
az appservice plan create -g $rg -n "$appName-plan" --sku B1 --is-linux

# 5. Create Web App
az webapp create -g $rg -n $appName -p "$appName-plan" `
  --deployment-container-image-name "nginx:latest"

# 6. Enable Managed Identity
az webapp identity assign -g $rg -n $appName

# 7. Create Key Vault
az keyvault create -g $rg -n $keyVaultName -l $loc
```

### Phase 2: Secrets Management (5 mins)

```powershell
$kvName = "iitd-keyvault"
$dbHost = "iitd-postgres.postgres.database.azure.com"
$dbUrl = "postgresql://$dbAdmin`:$dbPass@$dbHost:5432/postgres?sslmode=require"
$sessionSecret = node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
$otpSecret = node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
$adminHash = node scripts/hash-password.mjs "admin@123"

# Store in Key Vault
az keyvault secret set -n "DATABASE-URL" --vault-name $kvName --value $dbUrl
az keyvault secret set -n "SESSION-SECRET" --vault-name $kvName --value $sessionSecret
az keyvault secret set -n "OTP-SECRET" --vault-name $kvName --value $otpSecret
az keyvault secret set -n "ADMIN-PASSWORD-HASH" --vault-name $kvName --value $adminHash

# Grant Web App access
$principalId = az webapp identity show -g $rg -n $appName --query principalId -o tsv
az keyvault set-policy -n $kvName --object-id $principalId --secret-permissions get list
```

### Phase 3: Container Setup (10 mins)

```powershell
$acrLoginServer = az acr show -n myacrregistry -g $rg --query loginServer -o tsv

# Login to ACR
az acr login -n myacrregistry

# Build and push image
docker build -t "$acrLoginServer/iitd-merch-app:latest" .
docker push "$acrLoginServer/iitd-merch-app:latest"

# Grant Web App pull access
$acrId = az acr show -n myacrregistry -g $rg --query id -o tsv
$principalId = az webapp identity show -g $rg -n $appName --query principalId -o tsv
az role assignment create --assignee $principalId --role AcrPull --scope $acrId
```

### Phase 4: App Configuration (5 mins)

```powershell
$dbRef = "@Microsoft.KeyVault(SecretUri=https://$kvName.vault.azure.net/secrets/DATABASE-URL)"
$sessRef = "@Microsoft.KeyVault(SecretUri=https://$kvName.vault.azure.net/secrets/SESSION-SECRET)"
$otpRef = "@Microsoft.KeyVault(SecretUri=https://$kvName.vault.azure.net/secrets/OTP-SECRET)"
$adminRef = "@Microsoft.KeyVault(SecretUri=https://$kvName.vault.azure.net/secrets/ADMIN-PASSWORD-HASH)"

# Set app settings
az webapp config appsettings set -g $rg -n $appName --settings `
  DATABASE_URL=$dbRef `
  SESSION_SECRET=$sessRef `
  OTP_SECRET=$otpRef `
  ADMIN_PASSWORD_HASH=$adminRef `
  NODE_ENV=production

# Configure container
$acrUser = az acr credential show -n myacrregistry -g $rg --query username -o tsv
$acrPass = az acr credential show -n myacrregistry -g $rg --query "passwords[0].value" -o tsv

az webapp config container set -g $rg -n $appName `
  --docker-custom-image-name "$acrLoginServer/iitd-merch-app:latest" `
  --docker-registry-server-url "https://$acrLoginServer" `
  --docker-registry-server-user $acrUser `
  --docker-registry-server-password $acrPass

# Restart app
az webapp restart -g $rg -n $appName
```

### Phase 5: Custom Domain & DNS (15 mins)

```powershell
# Option A: Using Azure Domain (Premium, easier)
az appservice domain create -n yourdomain.com -g $rg `
  --admin-contact-name "Your Name" --admin-email "your@email.com"

# Option B: Using External Registrar (GoDaddy, Namecheap, Route53)
# 1. Go to domain registrar
# 2. Create CNAME record:
#    Host: www
#    Points to: iitd-merch-app.azurewebsites.net
#    TTL: 3600

# Bind domain to app
az webapp config hostname add -n $appName -g $rg --hostname yourdomain.com

# Create managed SSL certificate
# (Automatic with App Service - wait 10-15 mins)

# Verify
curl https://yourdomain.com/api/health
```

### Phase 6: CI/CD Pipeline

```powershell
# Create GitHub secrets
gh secret set AZURE_WEBAPP_NAME --body "iitd-merch-app"
gh secret set AZURE_RESOURCE_GROUP --body "my-iitd-rg"
gh secret set AZURE_SUBSCRIPTION_ID --body "92e0da8a-a2bd-4791-8b9b-412bf60101b1"

# The CI workflow will now auto-deploy on push to main
# Verify at: https://github.com/Detroner/MerchStoreIITD/actions
```

---

## Verification Checklist

After deployment, verify everything works:

```powershell
# Check app is running
curl https://iitd-merch-app.azurewebsites.net/api/health

# Tail logs
az webapp log tail -n iitd-merch-app -g my-iitd-rg

# Check secrets are accessible
az keyvault secret list --vault-name iitd-keyvault

# Test database connection (via SSH into app)
az webapp create-remote-connection -n iitd-merch-app -g my-iitd-rg

# Inside remote terminal:
# psql $DATABASE_URL
# SELECT COUNT(*) FROM users;
```

---

## Monitoring & Alerts

```powershell
# Enable Application Insights
az monitor app-insights component create \
  -g my-iitd-rg -n merch-store-insights \
  --app iitd-merch-app \
  --application-type web

# Add to app settings
az webapp config appsettings set -g my-iitd-rg -n iitd-merch-app \
  --settings "APPINSIGHTS_INSTRUMENTATIONKEY=<key>"

# View metrics
az monitor metrics list -n iitd-merch-app -g my-iitd-rg --start-time 2026-08-11T00:00 --end-time 2026-08-12T00:00
```

---

## Cost & Budget

| Resource | Tier | Est./Month | Your Budget |
|----------|------|-----------|------------|
| App Service Plan | B1 | $15-20 | ✓ |
| PostgreSQL | Standard B1ms | $45-60 | ✓ |
| Container Registry | Basic | $5-10 | ✓ |
| Data Transfer | 50GB | $0-5 | ✓ |
| Key Vault | Standard | ~$1 | ✓ |
| **TOTAL** | | **~$70-100/month** | **✓ Covered by $100 credit** |

---

## Support Resources

- **Azure Support**: https://portal.azure.com/
- **App Service Docs**: https://learn.microsoft.com/en-us/azure/app-service/
- **PostgreSQL Docs**: https://learn.microsoft.com/en-us/azure/postgresql/
- **Key Vault Docs**: https://learn.microsoft.com/en-us/azure/key-vault/

---

## What We Have Ready

✅ Application code (PostgreSQL configured)
✅ Automated provisioning scripts
✅ Docker image (node:22-alpine)
✅ Database migrations (3 files)
✅ CI/CD pipeline (GitHub Actions)
✅ Environment templates (.env.example)
✅ Secrets management (Key Vault ready)
✅ Deployment guides

## Next Step: Support Ticket

**Request policy exception NOW** → Deployment completes in ~1 hour → Your app is live!

---

**Last Updated**: August 11, 2026
**Status**: Awaiting subscription policy approval
**Estimated Time to Live**: 4-6 hours (2-4 for support + 1-2 for deployment)
