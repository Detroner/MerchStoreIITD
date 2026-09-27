# Azure Deployment Guide for MerchStoreIITD

This guide explains how to deploy MerchStoreIITD manually or understand the Azure architecture used by GitHub Actions CI/CD. The deployment uses **Azure App Service** (Linux / Node.js) and **Azure Database for PostgreSQL Flexible Server** for persistent data storage.

---

## 1. Deployment Architecture

The primary Azure resources inside the `my-iitd-rg` resource group are:

| Resource | Resource Name | Purpose |
|---|---|---|
| App Service Plan | `merchstore-plan` | Provides Linux compute for the Node.js application (B1 tier) |
| Web App | `theiitdelhidrop` | Public HTTPS storefront and administration studio |
| PostgreSQL Flexible Server | `merchstore-pg-central` | Persistent application database (`iitd_drop`) |
| Key Vault | `merchstore-iitd-kv-2026` | Secure secret storage for database credentials, session secret, admin credentials |

- **Public URL**: `https://theiitdelhidrop.azurewebsites.net`
- **Studio URL**: `https://theiitdelhidrop.azurewebsites.net/studio`

---

## 2. Prerequisites

Ensure the following tools are installed:
- Azure CLI (`az`)
- Node.js (v22 recommended) and npm
- Git

Authenticate with Azure:
```bash
az login
```

Verify your active subscription:
```bash
az account show --output table
```

---

## 3. Resource Group & PostgreSQL Setup

1. **Create the Resource Group:**
   ```bash
   az group create --name my-iitd-rg --location centralindia
   ```

2. **Create PostgreSQL Flexible Server:**
   ```bash
   export PG_ADMIN_PASSWORD="$(openssl rand -hex 24)"

   az postgres flexible-server create \
     --resource-group my-iitd-rg \
     --name merchstore-pg-central \
     --location centralindia \
     --admin-user iitdadmin \
     --admin-password "$PG_ADMIN_PASSWORD" \
     --sku-name Standard_B1ms \
     --tier Burstable \
     --storage-size 32 \
     --version 16 \
     --public-access 0.0.0.0
   ```

3. **Create Database:**
   ```bash
   az postgres flexible-server db create \
     --resource-group my-iitd-rg \
     --server-name merchstore-pg-central \
     --database-name iitd_drop
   ```

4. **Construct Database Connection String:**
   ```bash
   export DATABASE_URL="postgres://iitdadmin:${PG_ADMIN_PASSWORD}@merchstore-pg-central.postgres.database.azure.com:5432/iitd_drop?sslmode=require"
   ```

---

## 4. Run Database Migrations

Run database migrations locally or via CI runner before deploying the application:
```bash
DATABASE_URL="$DATABASE_URL" npm run db:migrate
```

---

## 5. App Service Plan & Web App Setup

1. **Create App Service Plan:**
   ```bash
   az appservice plan create \
     --name merchstore-plan \
     --resource-group my-iitd-rg \
     --sku B1 \
     --is-linux \
     --location centralindia
   ```

2. **Create Web App:**
   ```bash
   az webapp create \
     --resource-group my-iitd-rg \
     --plan merchstore-plan \
     --name theiitdelhidrop \
     --runtime "NODE:22-lts"
   ```

3. **Configure Application Settings:**
   ```bash
   export SESSION_SECRET="$(openssl rand -hex 32)"
   export ADMIN_PASSWORD="$(openssl rand -hex 16)"

   az webapp config appsettings set \
     --resource-group my-iitd-rg \
     --name theiitdelhidrop \
     --settings \
       NODE_ENV="production" \
       PORT="8080" \
       WEBSITES_PORT="8080" \
       DATABASE_URL="$DATABASE_URL" \
       SESSION_SECRET="$SESSION_SECRET" \
       ADMIN_PASSWORD="$ADMIN_PASSWORD" \
       RAZORPAY_MODE="demo" \
       SMS_PROVIDER="demo"
   ```

4. **Set Startup Command:**
   ```bash
   az webapp config set \
     --resource-group my-iitd-rg \
     --name theiitdelhidrop \
     --startup-file "node server.mjs"
   ```

---

## 6. Deploy Code Package (ZIP Deployment)

1. **Create deployment archive (excluding `.git`, `node_modules`, etc.):**
   ```bash
   git archive --format=zip HEAD -o ../merchstore-webapp.zip
   ```

2. **Deploy archive to Azure Web App:**
   ```bash
   az webapp deploy \
     --resource-group my-iitd-rg \
     --name theiitdelhidrop \
     --src-path ../merchstore-webapp.zip \
     --type zip \
     --restart true
   ```

3. **Verify Deployment:**
   ```bash
   curl -I https://theiitdelhidrop.azurewebsites.net/api/health
   ```

---

## 7. Troubleshooting

| Symptom | Diagnosis Command | Common Cause |
|---|---|---|
| Site returns 503 / Application Error | `az webapp log tail -g my-iitd-rg -n theiitdelhidrop` | Wrong port, missing environment variable, database connection error |
| Database connection refused | `az postgres flexible-server show -g my-iitd-rg -n merchstore-pg-central` | Firewall rule missing or SSL mode missing in connection string |
| Deploy command hangs | Use fallback deployment | `az webapp deployment source config-zip -g my-iitd-rg -n theiitdelhidrop --src ../merchstore-webapp.zip` |
| View active application settings | `az webapp config appsettings list -g my-iitd-rg -n theiitdelhidrop` | Verify environment variables and Key Vault references |
