# Azure Deployment Guide for MerchStore on Education Subscription

## Current Situation

Your Azure Education subscription has **policy restrictions** preventing deployment of:
- Azure Container Registry (ACR)
- Azure Database for PostgreSQL
- App Service Plans
- Key Vault

**Error Message**: "This policy maintains a set of best available regions where your subscription can deploy resources."

## Solution Options

### Option 1: Request Policy Exception (Recommended)
Contact Azure support to request approval for:
- Container Registries
- Database for PostgreSQL
- App Service Plans
- Key Vault

**Steps**:
1. Go to https://portal.azure.com/
2. Click "Help + support" → "New support request"
3. Issue type: "Service and subscription limits (quotas)"
4. Service: "General"
5. Request: "I need to use ACR, PostgreSQL, App Service, and Key Vault for my education project"

### Option 2: Use Alternative Services (No approval needed)
Deploy using services that may be available:

#### Alternative: Azure App Service (Web Apps) without Container Support
Use Node.js runtime directly instead of containers:
- No ACR needed
- Deploy via Git or zip
- Same App Service Plan required (may have restrictions)

#### Alternative: Azure Container Instances (ACI)
Simpler container deployment without ACR:
```bash
az container create -g my-iitd-rg -n merch-store \
  --image myregistry.azurecr.io/merch-app:latest \
  --cpu 1 --memory 1
```

#### Alternative: Local Deployment + Managed Database
- Deploy locally or on VM
- Use Azure Database for PostgreSQL (if allowed separately)
- SSH into VM to run the app

### Option 3: Check Specific Resource Restrictions

Run these commands to see which regions/SKUs are actually allowed:

```powershell
# Check which resources are explicitly blocked
az policy assignment list --output json | ConvertFrom-Json

# Try creating in different SKU/tier combinations
az storage account create -n teststorage123 -g my-iitd-rg -l eastus2 --sku Standard_LRS

# Try creating an Azure VM (often available)
az vm create -g my-iitd-rg -n test-vm --image UbuntuLTS --size Standard_B1s
```

## Current State

**Resource Group Created**: my-iitd-rg (eastus2)
**Status**: Ready for deployment once policies are resolved

## Recommended Next Steps

1. **Immediate**: Contact Azure support for policy exception (2-4 hours typical)
2. **Meanwhile**: 
   - Verify dependencies and configuration locally
   - Test migrations locally
   - Prepare Docker image (can push to ACR later)
   - Write comprehensive deployment documentation

3. **Once approved**: Re-run the provisioning script:
   ```powershell
   .\azure\onboard-full.ps1
   ```

## Using Alternative: Deploy to Azure VM Instead

If ACR/App Service remains blocked, use a Linux VM:

```powershell
# Create VM (if allowed)
az vm create -g my-iitd-rg -n merch-store-vm `
  --image UbuntuLTS `
  --size Standard_B1s `
  --admin-username azureuser `
  --generate-ssh-keys

# SSH into VM and run:
# 1. Install Node.js, PostgreSQL client
# 2. Clone repository
# 3. npm install && npm start
```

## Key Vault Alternative: Environment Variables
If Key Vault is blocked, use App Service application settings with environment variables:

```powershell
az webapp config appsettings set -g my-iitd-rg -n app-name `
  --settings DATABASE_URL="postgresql://..." SESSION_SECRET="..."
```

## Support Resources

- **Azure Education Support**: https://docs.microsoft.com/en-us/azure/education-hub/
- **Policy Exceptions**: Contact your Azure subscription administrator
- **Pricing**: https://azure.microsoft.com/en-us/pricing/ (many services have free tiers on education)

## Next Actions

1. Try running this command to test if ANY new resources can be created:
   ```powershell
   az storage account create -n mystoragetest123 -g my-iitd-rg -l eastus2 --sku Standard_LRS
   ```

2. Contact Azure support if storage account is also blocked

3. Once policies are resolved, the full deployment will complete with:
   - ACR for container images
   - PostgreSQL Flexible Server
   - App Service for hosting
   - Key Vault for secrets
   - GitHub Actions CI/CD pipeline

---

**Last Updated**: $(date)
**Status**: Awaiting subscription policy resolution
