# Full onboarding for Azure deployment (PowerShell version)
# Sets up ACR, Postgres, Web App, Key Vault, Service Principal, and GitHub secrets

param(
  [string]$Repo = $env:REPO,
  [string]$RG = $env:RESOURCE_GROUP,
  [string]$Loc = $env:LOCATION,
  [string]$ACR = $env:ACR_NAME,
  [string]$Postgres = $env:POSTGRES_NAME,
  [string]$App = $env:APP_NAME,
  [string]$KV = $env:KEYVAULT_NAME,
  [string]$Sub = $env:AZ_SUBSCRIPTION_ID
)

if (-not $Sub) { $Sub = (az account show --query id -o tsv) }
if (-not $Loc) { $Loc = "eastus2" }
if (-not $RG) { $RG = "my-iitd-rg" }
if (-not $ACR) { $ACR = "myacrregistry" }
if (-not $Postgres) { $Postgres = "iitd-postgres" }
if (-not $App) { $App = "iitd-merch-app" }
if (-not $KV) { $KV = "iitd-keyvault" }

Write-Host "[INFO] Starting Azure onboarding..." -ForegroundColor Green
Write-Host "Subscription: $Sub, RG: $RG, ACR: $ACR, Postgres: $Postgres, App: $App, KV: $KV"

# 1) Create Resource Group
Write-Host "[INFO] Creating resource group..." -ForegroundColor Green
az group create -n $RG -l $Loc --subscription $Sub

# 2) Create ACR
Write-Host "[INFO] Creating Azure Container Registry..." -ForegroundColor Green
az acr create -g $RG -n $ACR --sku Basic --admin-enabled true --subscription $Sub

# 3) Create Postgres Flexible Server
Write-Host "[INFO] Creating Azure Database for PostgreSQL..." -ForegroundColor Green
$AdminUser = "iitd_admin"
if (-not $env:DB_ADMIN_PASSWORD) {
  $env:DB_ADMIN_PASSWORD = "DbPass@$(Get-Random -Minimum 1000 -Maximum 9999)"
  Write-Host "[INFO] Generated admin password: $($env:DB_ADMIN_PASSWORD)" -ForegroundColor Green
}
$AdminPass = $env:DB_ADMIN_PASSWORD

az postgres flexible-server create `
  -g $RG -n $Postgres `
  -l $Loc `
  --admin-user $AdminUser `
  --admin-password $AdminPass `
  --sku-name Standard_B1ms `
  --storage-size 32 `
  --tier Burstable `
  --public-access 0.0.0.0 `
  --subscription $Sub

# 4) Create App Service Plan
Write-Host "[INFO] Creating App Service Plan..." -ForegroundColor Green
az appservice plan create -g $RG -n "$App-plan" --sku B1 --is-linux --subscription $Sub

# 5) Create Web App for Containers
Write-Host "[INFO] Creating Web App for Containers..." -ForegroundColor Green
az webapp create -g $RG -n $App -p "$App-plan" --deployment-container-image-name "nginx:latest" --subscription $Sub

# 6) Get ACR credentials
Write-Host "[INFO] Getting ACR login server..." -ForegroundColor Green
$AcrLoginServer = az acr show -n $ACR -g $RG --query loginServer -o tsv
Write-Host "ACR Login Server: $AcrLoginServer" -ForegroundColor Cyan

# 7) Enable Web App managed identity
Write-Host "[INFO] Enabling managed identity on Web App..." -ForegroundColor Green
az webapp identity assign -g $RG -n $App --subscription $Sub

# 8) Assign AcrPull role to Web App
Write-Host "[INFO] Granting Web App AcrPull access..." -ForegroundColor Green
$PrincipalId = az webapp identity show -g $RG -n $App --query principalId -o tsv
$AcrId = az acr show -n $ACR -g $RG --query id -o tsv
az role assignment create --assignee $PrincipalId --role AcrPull --scope $AcrId --subscription $Sub

# 9) Build and push Docker image (optional - can be skipped if Docker not available)
Write-Host "[INFO] Building Docker image..." -ForegroundColor Green
$ImageTag = "$AcrLoginServer/$App`:latest"
$SkipDocker = $false

if (Test-Path "Dockerfile") {
  try {
    az acr login -n $ACR --subscription $Sub
    docker build -t $ImageTag . 2>&1 | Write-Host
    if ($LASTEXITCODE -eq 0) {
      docker push $ImageTag
      Write-Host "[OK] Image pushed to ACR" -ForegroundColor Green
    } else {
      Write-Host "[WARN] Docker build failed; will use placeholder image" -ForegroundColor Yellow
      $SkipDocker = $true
    }
  } catch {
    Write-Host "[WARN] Docker not available or error occurred; skipping image build" -ForegroundColor Yellow
    $SkipDocker = $true
  }
} else {
  Write-Host "[WARN] Dockerfile not found; will use placeholder image" -ForegroundColor Yellow
  $SkipDocker = $true
}

# 10) Collect secrets
Write-Host "[INFO] Collecting secrets..." -ForegroundColor Green

if (-not $env:DATABASE_URL) {
  $env:DATABASE_URL = "postgresql://$AdminUser`:$AdminPass@$Postgres.postgres.database.azure.com:5432/postgres?sslmode=require"
  Write-Host "[INFO] Generated DATABASE_URL" -ForegroundColor Green
}

if (-not $env:SESSION_SECRET) {
  $env:SESSION_SECRET = node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
  Write-Host "Generated SESSION_SECRET" -ForegroundColor Green
}

if (-not $env:OTP_SECRET) {
  $env:OTP_SECRET = node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
  Write-Host "Generated OTP_SECRET" -ForegroundColor Green
}

if (-not $env:ADMIN_PASSWORD_HASH) {
  $adminPassIn = "admin@123"
  if (Test-Path "scripts/hash-password.mjs") {
    $env:ADMIN_PASSWORD_HASH = node scripts/hash-password.mjs $adminPassIn
    Write-Host "Generated ADMIN_PASSWORD_HASH" -ForegroundColor Green
  } else {
    Write-Host "[WARN] hash-password.mjs not found" -ForegroundColor Yellow
  }
}

# 11) Create Key Vault
Write-Host "[INFO] Creating Key Vault..." -ForegroundColor Green
az keyvault create -g $RG -n $KV -l $Loc --subscription $Sub

# 12) Store secrets in Key Vault
Write-Host "[INFO] Storing secrets in Key Vault..." -ForegroundColor Green
az keyvault secret set -n "DATABASE-URL" --vault-name $KV --value $env:DATABASE_URL --subscription $Sub
az keyvault secret set -n "SESSION-SECRET" --vault-name $KV --value $env:SESSION_SECRET --subscription $Sub
az keyvault secret set -n "OTP-SECRET" --vault-name $KV --value $env:OTP_SECRET --subscription $Sub
az keyvault secret set -n "ADMIN-PASSWORD-HASH" --vault-name $KV --value $env:ADMIN_PASSWORD_HASH --subscription $Sub
Write-Host "[OK] Secrets stored in Key Vault" -ForegroundColor Green

# 13) Grant Web App Key Vault access
Write-Host "[INFO] Granting Web App Key Vault permissions..." -ForegroundColor Green
az keyvault set-policy -n $KV --object-id $PrincipalId --secret-permissions get list --subscription $Sub

# 14) Create Key Vault references in App Settings
Write-Host "[INFO] Configuring App Settings with Key Vault references..." -ForegroundColor Green
$dbRef = "@Microsoft.KeyVault(SecretUri=https://$KV.vault.azure.net/secrets/DATABASE-URL)"
$sessRef = "@Microsoft.KeyVault(SecretUri=https://$KV.vault.azure.net/secrets/SESSION-SECRET)"
$otpRef = "@Microsoft.KeyVault(SecretUri=https://$KV.vault.azure.net/secrets/OTP-SECRET)"
$adminRef = "@Microsoft.KeyVault(SecretUri=https://$KV.vault.azure.net/secrets/ADMIN-PASSWORD-HASH)"

$settings = @(
  "DATABASE_URL=$dbRef",
  "SESSION_SECRET=$sessRef",
  "OTP_SECRET=$otpRef",
  "ADMIN_PASSWORD_HASH=$adminRef"
)

az webapp config appsettings set -g $RG -n $App --settings $settings --subscription $Sub

# 15) Configure registry for Web App (only if image was built)
if (-not $SkipDocker) {
  Write-Host "[INFO] Updating Web App container configuration..." -ForegroundColor Green
  $AcrUser = az acr credential show -n $ACR -g $RG --query username -o tsv
  $AcrPass = az acr credential show -n $ACR -g $RG --query "passwords[0].value" -o tsv

  az webapp config container set -g $RG -n $App `
    --docker-custom-image-name $ImageTag `
    --docker-registry-server-url "https://$AcrLoginServer" `
    --docker-registry-server-user $AcrUser `
    --docker-registry-server-password $AcrPass `
    --subscription $Sub
} else {
  Write-Host "[INFO] Skipping container configuration (Docker image not built)" -ForegroundColor Yellow
}

# 16) Restart Web App
Write-Host "[INFO] Restarting Web App..." -ForegroundColor Green
az webapp restart -g $RG -n $App --subscription $Sub

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Onboarding Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $RG" -ForegroundColor Yellow
Write-Host "Container Registry: $AcrLoginServer" -ForegroundColor Yellow
Write-Host "Web App: https://$App.azurewebsites.net" -ForegroundColor Yellow
Write-Host "Key Vault: $KV" -ForegroundColor Yellow
Write-Host ""
