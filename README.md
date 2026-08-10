# The IIT Delhi Drop

A creative, mobile-first merchandise storefront and operations Studio built with React, Anime.js, Node.js, Express.js and PostgreSQL.

## What is included

- Responsive storefront with a stable embedded catalogue, category/type/size filters, sorting, four-card phone batches and graceful empty/error states.
- Full product pages with exact size × colour variants, stock, customization preview, surcharge and production-time disclosure.
- Persistent cart with server-authoritative quote validation.
- Phone OTP registration and login, affiliation-aware profiles, optional hostel details and durable sessions.
- Verified-purchase reviews from My Orders, a 400-word limit, up to three image descriptors and Studio moderation.
- PostgreSQL schema for catalogue, variants, inventory, customers, addresses, orders, customization snapshots, coupons, reviews and idempotent payment events.
- Studio controls for products, catalogue structure, themes, motion, coupons, reviews, customers and product/size demand.
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
- Studio password: `IITD@2026!`

These values exist only in the local review adapter and must never be used in a shared environment.

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
