# Manual Azure Deployment Guide for MerchStoreIITD

This guide explains how to reproduce the MerchStoreIITD deployment manually from Azure Cloud Shell, Azure CLI, or a local terminal with Azure CLI installed. The deployed architecture uses **Azure App Service** for the Node.js web application and **Azure Database for PostgreSQL Flexible Server** for persistent data.

## 1. Deployment architecture

The final deployment contains three main Azure resources in the `my-iitd-rg` resource group:

| Resource | Name | Purpose |
|---|---|---|
| App Service plan | `merchstore-plan` | Provides Linux compute for the Node.js application |
| Web App | `theiitdelhidrop` | Public HTTPS storefront and admin studio |
| PostgreSQL Flexible Server | `merchstore-pg-central` | Persistent application database |

The public URL is `https://theiitdelhidrop.azurewebsites.net`. Azure provides the HTTPS certificate and the public DNS name automatically.

The App Service plan is **B1** rather than the Free F1 tier because the Free tier reached a quota-disabled state during deployment. The PostgreSQL server uses the **Standard_B1ms Burstable** tier. Both are paid Azure resources and therefore consume Azure credits while running.

> The central deployment lesson is to separate the web process from the database. App Service handles HTTP traffic and process hosting, while PostgreSQL Flexible Server stores products, users, orders, settings, and migrations persistently.

## 2. Prerequisites

Install Azure CLI, Node.js, npm, and Git. Confirm that the commands are available:

```bash
az version
git --version
node --version
npm --version
```

Authenticate to Azure:

```bash
az login
```

If you are using Azure Cloud Shell, Azure CLI is already installed and `az login` is normally handled by the Cloud Shell session. Select the correct subscription and verify it:

```bash
az account list --output table
az account set --subscription "92e0da8a-a2bd-4791-8b9b-412bf60101b1"
az account show --query "{name:name,id:id,tenantId:tenantId}" --output table
```

For another project, replace the subscription ID with your own subscription ID. Never paste passwords, connection strings, or access tokens into GitHub or into a public document.

## 3. Get the source code and inspect it

Clone the repository and enter the project directory:

```bash
git clone https://github.com/Detroner/MerchStoreIITD.git
cd MerchStoreIITD
```

Before deploying, inspect the application contract:

```bash
cat package.json
cat Dockerfile
cat docker-compose.yml
find migrations -maxdepth 1 -type f -print
```

The important facts for this project are:

| Requirement | Project value |
|---|---|
| Node entrypoint | `server.mjs` |
| Database migration command | `npm run db:migrate` |
| Database driver | `pg` |
| Runtime database variable | `DATABASE_URL` |
| Runtime SSL variable | `DATABASE_SSL=true` |
| Application port | `4173` |

Run the application locally before involving Azure:

```bash
npm install
npm run db:migrate
npm start
```

Then open `http://localhost:4173`. This catches application errors before cloud deployment.

## 4. Select a deployment region and register providers

Azure for Students subscriptions can restrict regions or resource providers. Check the current subscription and register the providers used by this architecture:

```bash
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.DBforPostgreSQL

az provider show --namespace Microsoft.Web \
  --query registrationState --output tsv

az provider show --namespace Microsoft.DBforPostgreSQL \
  --query registrationState --output tsv
```

Wait until both providers report `Registered`.

For this deployment, `centralindia` was an allowed region. In a different subscription, choose a region permitted by the subscription policy and with available capacity.

## 5. Create or reuse a resource group

A resource group is a logical container for the application resources:

```bash
az group create \
  --name my-iitd-rg \
  --location centralindia
```

If the group already exists, this command is harmless and returns the existing group.

## 6. Create the PostgreSQL Flexible Server

Generate a strong database administrator password locally and keep it outside Git:

```bash
export PG_ADMIN_PASSWORD="$(openssl rand -hex 24)"
```

Create the server:

```bash
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

In this command, `--public-access 0.0.0.0` creates the Azure-services access rule in the Flexible Server workflow used here. It does **not** mean that you should expose PostgreSQL broadly to the internet. For a production system, use private networking or narrowly scoped firewall rules.

Create the application database:

```bash
az postgres flexible-server db create \
  --resource-group my-iitd-rg \
  --server-name merchstore-pg-central \
  --name iitd_drop
```

Build the connection string. The `sslmode=require` parameter is important for Azure PostgreSQL:

```bash
export DATABASE_URL="postgresql://iitdadmin:${PG_ADMIN_PASSWORD}@merchstore-pg-central.postgres.database.azure.com:5432/iitd_drop?sslmode=require"
```

Do not commit this value to Git.

## 7. Run database migrations securely

The application migrations create the schema and seed the catalogue. Azure PostgreSQL does not allow every PostgreSQL extension. The original migration attempted to run:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Azure rejected that statement because `pgcrypto` was not allow-listed. The statement was removed. PostgreSQL 16 on Azure provides the UUID functionality needed by this schema without that explicit extension command.

To run migrations from your local machine, temporarily allow only your current public IP. Find the IP:

```bash
export CLIENT_IP="$(curl -sS https://api.ipify.org)"
```

Create a temporary firewall rule:

```bash
az postgres flexible-server firewall-rule create \
  --resource-group my-iitd-rg \
  --server-name merchstore-pg-central \
  --name temporary-migration-client \
  --start-ip-address "$CLIENT_IP" \
  --end-ip-address "$CLIENT_IP"
```

Run the migration:

```bash
DATABASE_URL="$DATABASE_URL" \
DATABASE_SSL=true \
npm run db:migrate
```

Delete the temporary rule immediately afterward:

```bash
az postgres flexible-server firewall-rule delete \
  --resource-group my-iitd-rg \
  --server-name merchstore-pg-central \
  --name temporary-migration-client \
  --yes
```

Verify the firewall rules:

```bash
az postgres flexible-server firewall-rule list \
  --resource-group my-iitd-rg \
  --server-name merchstore-pg-central \
  --output table
```

A robust deployment pipeline would run migrations from a controlled release job rather than from every web process startup. The web process should normally start with `node server.mjs` after the migration step has completed successfully.

## 8. Create the App Service plan and Web App

Create a Linux App Service plan. The B1 tier is inexpensive relative to larger plans and is sufficient for a demonstration storefront:

```bash
az appservice plan create \
  --resource-group my-iitd-rg \
  --name merchstore-plan \
  --location centralindia \
  --is-linux \
  --sku B1
```

Create the Node.js Web App:

```bash
az webapp create \
  --resource-group my-iitd-rg \
  --plan merchstore-plan \
  --name theiitdelhidrop \
  --runtime "NODE:22-lts" \
  --https-only true
```

The name must be globally unique because it becomes part of the hostname. If `theiitdelhidrop` is already taken in another subscription, choose another name.

## 9. Configure Web App settings

Azure App Service settings become environment variables inside the Node.js process. Set production configuration using the CLI rather than adding a `.env` file to the repository:

```bash
az webapp config appsettings set \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --settings \
    NODE_ENV=production \
    PORT=4173 \
    WEBSITE_NODE_DEFAULT_VERSION=22-lts \
    SCM_DO_BUILD_DURING_DEPLOYMENT=true \
    DATABASE_URL="$DATABASE_URL" \
    DATABASE_SSL=true \
    DB_POOL_SIZE=10 \
    SESSION_SECRET="replace-with-a-long-random-secret" \
    OTP_SECRET="replace-with-a-separate-long-random-secret" \
    ADMIN_EMAIL="admin@your-domain.example" \
    ADMIN_PASSWORD_HASH="argon2-hash-generated-by-the-project-script" \
    RAZORPAY_MODE=demo \
    SMS_PROVIDER=demo
```

Generate secrets instead of using the placeholder values:

```bash
openssl rand -hex 32
```

The project includes a password-hashing script. Generate an Argon2 password hash locally and set the resulting hash as `ADMIN_PASSWORD_HASH`; never store the plain administrator password in the repository.

Set the startup command to run only the already-completed application process:

```bash
az webapp config set \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --startup-file "node server.mjs"
```

The application logs should show a message similar to `The IIT Delhi Drop is ready at http://localhost:4173`. App Service routes the public HTTPS hostname to this process.

## 10. Package and deploy the application

Create a ZIP package from the repository. Exclude Git metadata, local dependencies, generated output, and secrets:

```bash
zip -qr ../merchstore-webapp.zip . \
  -x '.git/*' \
     'node_modules/*' \
     '.env' \
     'outputs/*'
```

Deploy the ZIP:

```bash
az webapp deploy \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --src-path ../merchstore-webapp.zip \
  --type zip \
  --restart true
```

If the asynchronous Kudu polling hangs, the older but useful fallback is:

```bash
az webapp deployment source config-zip \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --src ../merchstore-webapp.zip
```

The deployment output should report a successful build and a started site.

## 11. Verify the deployment

Check the Azure resource state:

```bash
az webapp show \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --query "{state:state,availability:availabilityState,hostNames:hostNames}" \
  --output json
```

Check the application health endpoint:

```bash
curl -i https://theiitdelhidrop.azurewebsites.net/api/health
```

Expected response:

```json
{"ok":true,"database":"postgresql"}
```

Check the seeded catalogue:

```bash
curl -i 'https://theiitdelhidrop.azurewebsites.net/api/catalog?limit=3'
```

Open the storefront in a browser:

```text
https://theiitdelhidrop.azurewebsites.net
```

Open the administration studio at:

```text
https://theiitdelhidrop.azurewebsites.net/studio
```

## 12. Troubleshooting commands

| Problem | Useful command | What to look for |
|---|---|---|
| Site is disabled | `az webapp show -g my-iitd-rg -n theiitdelhidrop --query state` | `QuotaExceeded` usually means the Free plan quota was reached |
| Site returns 503 | `az webapp log tail -g my-iitd-rg -n theiitdelhidrop` | Node startup errors, wrong port, missing module, or failed migration |
| Deployment status | `az webapp log deployment list -g my-iitd-rg -n theiitdelhidrop` | Latest deployment status and timestamp |
| Download logs | `az webapp log download -g my-iitd-rg -n theiitdelhidrop --log-file webapp_logs.zip` | Startup and Kudu deployment logs |
| Database cannot connect | `az postgres flexible-server firewall-rule list -g my-iitd-rg -s merchstore-pg-central` | Confirm the App Service/Azure rule or temporary client rule exists |
| Provider failure | `az provider show -n Microsoft.Web --query registrationState` | Provider should report `Registered` |
| Region/SKU unavailable | `az vm list-skus --location centralindia --resource-type virtualMachines` | Capacity restrictions may require another region or SKU |

During this deployment, VM sizes `Standard_B1s` and `Standard_B2s` were unavailable in multiple approved regions because of Azure capacity restrictions. App Service was selected because it provisioned successfully in Central India and was a better fit for a public demo.

## 13. Cost control

Stop the Web App when you are not presenting:

```bash
az webapp stop \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop
```

Start it again before a presentation:

```bash
az webapp start \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop
```

Stop the PostgreSQL server when it is not needed:

```bash
az postgres flexible-server stop \
  --resource-group my-iitd-rg \
  --name merchstore-pg-central
```

Start it again when needed:

```bash
az postgres flexible-server start \
  --resource-group my-iitd-rg \
  --name merchstore-pg-central
```

For a disposable deployment, delete the entire resource group after the demonstration. This permanently deletes the resources and database:

```bash
az group delete --name my-iitd-rg --yes --no-wait
```

Use deletion only when you are certain that the database contents are no longer needed.

## 14. Recommended production improvements

For a real production deployment, move secrets into Azure Key Vault, use a private endpoint or tightly scoped network rules for PostgreSQL, use a custom domain, enable Application Insights, add a CI/CD workflow through GitHub Actions, and run migrations as a controlled release step. The current deployment is appropriate for a public demonstration, not for processing real payments or storing production customer data without further security hardening.
