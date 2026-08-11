# Alternative Azure Deployment Guide (Education Subscription Workaround)

## Overview
Since standard Azure services are blocked by subscription policies, we'll use **Azure App Service with built-in container support** and deploy directly from GitHub Actions.

## What We're Doing
- Using **Azure App Service (Web Apps)** - often available even when other services are restricted
- Deploying from Git directly (no need for ACR)
- Using Azure PostgreSQL Flexible Server (if available, otherwise use external database)
- Free SSL/HTTPS with managed certificates
- Custom domain binding

## Prerequisites
1. Azure CLI logged in: `az login`
2. GitHub repository with secrets configured
3. Custom domain (optional, can use *.azurewebsites.net initially)

## Step 1: Create Azure App Service (No Container Registry Needed)

```powershell
$rg = "my-iitd-rg"
$app = "iitd-merch-app"
$plan = "$app-plan"
$location = "eastus2"

# Create Resource Group (if not exists)
az group create -n $rg -l $location

# Create App Service Plan (Linux, PHP to start - we'll override)
az appservice plan create -n $plan -g $rg --sku B1 --is-linux

# Create Web App with built-in Node.js runtime
az webapp create -g $rg -n $app -p $plan --runtime "node|20-lts" --runtime-version 20-lts

# Enable Git deployment
az webapp deployment user set --user-name gitdeploy --user-password "ChooseSecurePassword123!"

# Create local Git deployment endpoint
az webapp deployment source config-local-git -n $app -g $rg
```

## Step 2: Add Database Connection String

### Option A: Use Managed PostgreSQL (if allowed)
```powershell
$dbName = "iitd-postgres"
$adminUser = "iitd_admin"
$adminPass = "YourSecurePassword123!"

az postgres flexible-server create `
  -g $rg -n $dbName `
  -l $location `
  --admin-user $adminUser `
  --admin-password $adminPass `
  --sku-name Standard_B1ms `
  --storage-size 32

# Build connection string
$dbHost = "$dbName.postgres.database.azure.com"
$dbUrl = "postgresql://${adminUser}:${adminPass}@${dbHost}:5432/postgres?sslmode=require"
```

### Option B: Use External Database
Use any PostgreSQL host (AWS RDS, external provider, local machine)
```powershell
$dbUrl = "postgresql://user:password@hostname:5432/database?sslmode=require"
```

## Step 3: Add Application Settings

```powershell
$dbUrl = "postgresql://..."  # From step 2
$sessionSecret = node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
$otpSecret = node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
$adminHash = node scripts/hash-password.mjs "admin@123"

az webapp config appsettings set -n $app -g $rg --settings `
  DATABASE_URL=$dbUrl `
  SESSION_SECRET=$sessionSecret `
  OTP_SECRET=$otpSecret `
  ADMIN_PASSWORD_HASH=$adminHash `
  NODE_ENV=production `
  SCM_DO_BUILD_DURING_DEPLOYMENT=true
```

## Step 4: Deploy from Git

```powershell
# Get Git clone URL from Azure
$gitUrl = az webapp deployment source config-local-git -n $app -g $rg --query url -o tsv

# Add Git remote to your local repo
git remote add azure $gitUrl

# Push to Azure (this triggers automatic build and deployment)
git push azure detroner-migrate-to-postgresql:master

# Watch deployment logs
az webapp log tail -n $app -g $rg
```

## Step 5: Configure Custom Domain

### Step 5a: Purchase Domain (if not already owned)
Options:
- **Azure App Service Domains** (integrated)
- **GoDaddy**, **Namecheap**, **Route53**, etc.

### Step 5b: Add Domain to App Service

```powershell
# Create App Service Domain (if using Azure)
az appservice domain create -n yourdomain.com -g $rg --admin-contact-name "Your Name" --admin-email "your@email.com"

# OR Bind existing domain
az webapp config hostname add -n $app -g $rg --hostname yourdomain.com

# Create managed certificate for HTTPS
az webapp config ssl bind -n $app -g $rg --certificate-thumbprint <thumbprint> --ssl-type SNI

# If using external domain registrar:
# 1. Get App Service default domain: iitd-merch-app.azurewebsites.net
# 2. Create CNAME record: yourdomain.com CNAME iitd-merch-app.azurewebsites.net
# 3. Wait 5-10 minutes for DNS propagation
# 4. Run the bind command above
```

## Step 6: Configure Continuous Deployment (GitHub Actions)

### Already Configured!
The CI/CD pipeline at `.github/workflows/ci.yml` needs one update:

Update `.github/workflows/ci.yml` to deploy to App Service:

```yaml
- name: Deploy to Azure Web App
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: |
    az webapp up \
      --name ${{ secrets.AZURE_WEBAPP_NAME }} \
      --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} \
      --runtime "node|20-lts"
```

Add these GitHub Secrets:
```powershell
gh secret set AZURE_WEBAPP_NAME --body "iitd-merch-app"
gh secret set AZURE_RESOURCE_GROUP --body "my-iitd-rg"
gh secret set AZURE_CREDENTIALS --body $credentials_json
```

## Step 7: Monitor Application

```powershell
# Tail live logs
az webapp log tail -n iitd-merch-app -g my-iitd-rg --provider github

# Check app health endpoint
curl https://iitd-merch-app.azurewebsites.net/api/health

# View current app settings
az webapp config appsettings list -n iitd-merch-app -g my-iitd-rg

# Restart if needed
az webapp restart -n iitd-merch-app -g my-iitd-rg
```

## Cost Estimation (Education Credits)

| Service | SKU | Est. Monthly Cost |
|---------|-----|------------------|
| App Service Plan | B1 (Basic) | $15-20 |
| PostgreSQL | B1ms Standard | $45-60 |
| Data Transfer | 50GB/mo | $0-5 |
| **Total** | | **$60-85/month** |

**Your $100 credit covers ~1-2 months** ✓

## Troubleshooting

### App fails to start
```powershell
# Check logs
az webapp log tail -n iitd-merch-app -g my-iitd-rg

# Common issue: DATABASE_URL not set
az webapp config appsettings list -n iitd-merch-app -g my-iitd-rg | grep DATABASE_URL

# Verify with SSH
az webapp create-remote-connection -n iitd-merch-app -g my-iitd-rg
```

### Domain not resolving
```powershell
# Check domain binding
az webapp config hostname list -n iitd-merch-app -g my-iitd-rg

# If using custom domain, verify DNS is resolving
nslookup yourdomain.com
```

### Deployments failing
```powershell
# View deployment history
az webapp deployment list -n iitd-merch-app -g my-iitd-rg

# Get deployment logs
az webapp log download -n iitd-merch-app -g my-iitd-rg
```

## Next: Request Policy Exception (Still Recommended)

While this workaround works, you should still request a policy exception for:
- **Container Registry** (for production multi-stage builds)
- **Key Vault** (for centralized secret management)
- **Application Insights** (for monitoring)

This takes 2-4 hours and gives you enterprise-grade deployment capabilities.

---

**Status**: Ready to deploy once DNS/domain is configured
**Deployment Time**: ~5-10 minutes
**Testing**: Verify at `https://yourdomain.com/api/health`
