# The IIT Delhi Drop

A creative, mobile-first merchandise storefront and operations Studio built with React, Anime.js, Node.js, Express.js and PostgreSQL.

## What is included

- Responsive storefront with a stable embedded catalogue, size filters, sorting, four-card phone batches and graceful empty/error states.
- Full product pages with exact size × colour variants, stock, customization preview and production-time disclosure; personalization is included in the product price.
- Persistent cart with server-authoritative quote validation, non-charging demo checkout and optional Razorpay Standard Checkout when configured.
- Phone OTP registration and login, affiliation-aware profiles, optional hostel details, durable sessions and a customer loyalty wallet.
- Per-product wallet reward percentages controlled from Studio; rewards and redemptions are recorded in an auditable PostgreSQL ledger.
- Product customization placements are controlled per product from Studio; customers see only the enabled Front, Back or Side choices.
- Verified-purchase reviews from My Orders, a 400-word limit, up to three image descriptors and Studio moderation. Placeholder ratings and seeded review counts are not shown.
- PostgreSQL schema for catalogue, variants, inventory, customers, addresses, orders, customization snapshots, coupons, reviews and idempotent payment events.
- Studio controls for products and photos, themes, motion, coupons, reviews, customers, product/size demand, wallet adjustments, customization placements and the complete Our Story page. Product management includes structured features, multiple photos, explicit thumbnail selection, archiving and safe draft deletion.
- Argon2 administrator credentials, HttpOnly cookies, CSRF proofs, throttling, security headers and audit records.
- Razorpay Standard Checkout and MSG91 OTP adapters with demo fallbacks; external providers remain disabled until credentials and merchant onboarding are configured.

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

## Content and merchandising controls

The storefront has a dedicated `/our-story` page. Studio → **Our Story** edits its eyebrow, hero title, lead paragraph, motto label, motto, closing line, CTA label and image URL. Studio → **Products** controls each customizable product’s allowed placements; only the selected placements are presented to the customer and the server rejects any placement not enabled for that product.

Ratings are calculated only from approved reviews. Products with no approved reviews do not show a score, star row, review count, or “be the first to review” placeholder. Studio moderation recalculates the product aggregate whenever a review changes state.

## Azure deployment and CI/CD

The live deployment uses the Linux App Service `merchstore-iitd-demo` and Azure Database for PostgreSQL Flexible Server in resource group `my-iitd-rg`. Production secrets are stored in Key Vault `merchstore-iitd-kv-2026`; App Service retrieves them through its managed identity. GitHub Actions authenticates to Azure through OIDC, opens a runner-only PostgreSQL firewall rule, runs `npm run db:migrate`, removes the rule even when a migration fails, deploys the ZIP package, restarts App Service and checks `/api/health`.

For the exact manual commands, read `azure-manual-deployment-guide.md`. To inspect the PostgreSQL administrator password without printing it in application settings, use `az keyvault secret show --vault-name merchstore-iitd-kv-2026 --name POSTGRES-ADMIN-PASSWORD --query value -o tsv`. If the secret is unavailable, reset the PostgreSQL administrator password and update the Key Vault `DATABASE-URL` secret rather than committing a password.

## Payment and messaging configuration

The application is safe to run without purchasing either service. With the default `RAZORPAY_MODE=demo` and `SMS_PROVIDER=demo`, checkout remains non-charging and OTP verification uses the configured demo code. The provider adapters activate only when their credentials are present.

For Razorpay, first use test credentials: set `RAZORPAY_MODE=test`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET`. The server creates the Razorpay order, the browser opens Standard Checkout, the server verifies the `razorpay_order_id|razorpay_payment_id` signature, and the webhook endpoint deduplicates events before settling the order. Switch to `RAZORPAY_MODE=live` only after merchant onboarding, test payments, failed/duplicate callback tests, reconciliation and a controlled live penny test. Never mark an order paid from a browser redirect alone.

For MSG91, create an OTP template and set `SMS_PROVIDER=msg91`, `MSG91_AUTHKEY`, and `MSG91_TEMPLATE_ID`. The server calls MSG91 to send and verify the OTP; no local OTP is exposed in the response when MSG91 is active. If these values are absent, the app refuses to claim MSG91 is active and stays in demo mode.

Store these values as Azure Key Vault secrets and reference them from App Service settings. Do not commit them to `.env`, the repository, client-side code or browser-visible responses.

## External adapters still required

- MSG91 account, OTP template and auth key for real SMS delivery
- Razorpay merchant onboarding, test/live credentials and webhook secret for real payments
- S3-compatible object storage and CDN for product/review images
- Transactional email provider
- Shipping aggregator or courier workflow
- Hosted observability and alerting

MotionSites.ai informed the creative direction; Anime.js provides the local runtime motion. The concept artwork does not use an institutional seal. Obtain IIT Delhi branding and merchandise approvals before launch.

The full implementation and launch sequence is in `outputs/postgresql-commerce-evolution-pipeline.md`.
