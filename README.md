# The IIT Delhi Drop

A creative, mobile-first merchandise storefront and operations Studio built with React, Anime.js, Node.js, Express.js and PostgreSQL.

## What is included

- Responsive storefront with a stable embedded catalogue, category/type/size filters, sorting, four-card phone batches and graceful empty/error states.
- Full product pages with exact size × colour variants, stock, customization preview, surcharge and production-time disclosure.
- Persistent cart with server-authoritative quote validation and demo checkout.
- Phone OTP registration and login, affiliation-aware profiles, optional hostel details, durable sessions and a customer loyalty wallet.
- Per-product wallet reward percentages controlled from Studio; rewards and redemptions are recorded in an auditable PostgreSQL ledger.
- Customization is fixed to the Front placement for consistent production; style and text colour remain selectable.
- Verified-purchase reviews from My Orders, a 400-word limit, up to three image descriptors and Studio moderation.
- PostgreSQL schema for catalogue, variants, inventory, customers, addresses, orders, customization snapshots, coupons, reviews and idempotent payment events.
- Studio controls for products, catalogue structure, themes, motion, coupons, reviews, customers, product/size demand and wallet adjustments.
- Argon2 administrator credentials, HttpOnly cookies, CSRF proofs, throttling, security headers and audit records.
- Razorpay-ready boundaries with live charging intentionally disabled until credentials, signed webhooks and reconciliation checks are complete.

## Quick visual review (no database required)

The local review adapter is non-persistent and never uses SQLite.

```powershell
python work/preview_server.py
```

Then open:

- Storefront: `http://localhost:4173/`
- Product: `http://localhost:4173/products/core-memory-hoodie`
- Cart: `http://localhost:4173/cart`
- Customer account: `http://localhost:4173/login`
- Studio: `http://localhost:4173/studio`

Local review credentials:

- Customer OTP: `202626`
- Studio email: `admin@iitdmerch.local`
- Studio password: set `ADMIN_PREVIEW_PASSWORD` in the shell before starting `work/preview_server.py`.

The preview adapter no longer contains a hardcoded administrator password. These local values must never be used in a shared environment.

## Production setup with PostgreSQL

1. Install Node.js 20+ and PostgreSQL 16+.
2. Copy `.env.example` to `.env` and replace every secret.
3. Install packages with `npm install` (this creates a fresh lockfile for your platform).
4. Create the database, then run `npm run db:migrate`.
5. Generate an Argon2id admin password hash and assign it to `ADMIN_PASSWORD_HASH`.
6. Run `npm start`.

Docker can provide PostgreSQL locally:

```powershell
docker compose up -d postgres
npm run db:migrate
npm start
```

The production server refuses to boot without `DATABASE_URL`, `SESSION_SECRET` and `OTP_SECRET`. PostgreSQL is the only production data store.

Automated setup scripts

Two helper scripts are provided to automate developer setup:

- Windows: `scripts/setup-windows.ps1` — attempts to install Node.js and Docker via `winget` (when available), runs `npm ci`, generates `ADMIN_PASSWORD_HASH`, starts Postgres via `docker compose`, runs migrations and boots the server.

- Linux / macOS: `scripts/setup-unix.sh` — installs Node.js (NodeSource/homebrew) and Docker (get.docker.com / Homebrew Cask) when possible, runs `npm ci`, generates `ADMIN_PASSWORD_HASH`, starts Postgres via `docker compose`, runs migrations and boots the server.

Key Vault helper

A helper script is provided to create an Azure Key Vault and store secrets. Use it after you provision an Azure resource group and are logged in with the Azure CLI:

```
# example
export AZ_SUBSCRIPTION_ID="<your-subscription-id>"
export AZ_RESOURCE_GROUP="my-iitd-rg"
export AZURE_REGION="eastus"
./azure/create-keyvault-and-secrets.sh my-iitd-keyvault
```

The script will prompt for any missing secret values: DATABASE_URL, SESSION_SECRET, OTP_SECRET, ADMIN_PASSWORD_HASH. The deployed App Service should use managed identity and Key Vault references rather than plaintext app settings.

Usage (example):

- Windows (PowerShell as Administrator):

  .\scripts\setup-windows.ps1

- Linux / macOS:

  sudo ./scripts/setup-unix.sh

If automatic installers are unavailable on your machine, follow the manual instructions above to install Node.js and Docker, then re-run the scripts. If you run into permission or PATH issues, open a fresh shell after installer finishes.

## Azure deployment and CI/CD

The live deployment uses the Linux App Service `merchstore-iitd-demo` and Azure Database for PostgreSQL Flexible Server in resource group `my-iitd-rg`. Production secrets are stored in Key Vault `merchstore-iitd-kv-2026`; App Service retrieves them through its managed identity. GitHub Actions authenticates to Azure through OIDC, opens a runner-only PostgreSQL firewall rule, runs `npm run db:migrate`, removes the rule even when a migration fails, deploys the ZIP package, restarts App Service and checks `/api/health`.

For the exact manual commands, read `azure-manual-deployment-guide.md`. To inspect the PostgreSQL administrator password without printing it in application settings, use `az keyvault secret show --vault-name merchstore-iitd-kv-2026 --name POSTGRES-ADMIN-PASSWORD --query value -o tsv`. If the secret is unavailable, reset the PostgreSQL administrator password and update the Key Vault `DATABASE-URL` secret rather than committing a password.

## Payment status

Razorpay is adapter-ready but remains in demo mode. Before accepting money, complete merchant onboarding, provide test credentials through managed secrets, create server-owned orders, verify webhook signatures, deduplicate webhook events, test failed/duplicate callbacks, reconcile settlements and refunds, and complete a controlled live penny test. Never mark an order paid from a browser redirect alone.

## External adapters still required

- SMS provider for OTP delivery
- S3-compatible object storage and CDN for product/review images
- Razorpay test/live credentials and webhook secret
- Transactional email provider
- Shipping aggregator or courier workflow
- Hosted observability and alerting

MotionSites.ai informed the creative direction; Anime.js provides the local runtime motion. The concept artwork does not use an official institutional seal. Obtain IIT Delhi branding and merchandise approvals before launch.

The full implementation and launch sequence is in `outputs/postgresql-commerce-evolution-pipeline.md`.
