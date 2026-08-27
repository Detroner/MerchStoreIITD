# IIT Delhi Drop

A campus merchandise storefront and Studio admin console. It supports product and media management, personalisation, loyalty wallet rewards, addresses, time-bound coupons, reviews, and demo/test/live payment modes.

## Local setup

Use Node.js 22 and PostgreSQL. Copy `.env.example` to `.env`, set secure secrets, then run:

```bash
npm install
npm run db:migrate
npm run dev
```

The application runs at `http://localhost:3000`. To start a local database in containers, run `docker compose up -d db` before migrations.

## Required configuration

Set `DATABASE_URL`, `SESSION_SECRET`, `OTP_SECRET`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD_HASH`. Razorpay, MSG91, and Google Maps are optional; the exact variable names and safe local defaults are in `.env.example`. Keep payments and SMS in demo mode for local development, and never deploy a demo OTP.

## Everyday commands

| Command | Purpose |
|---|---|
| `npm run dev` | Start local development. |
| `npm run db:migrate` | Apply PostgreSQL migrations. |
| `npm run check` | Run source checks before a change. |
| `python work/preview_server.py` | Run the non-persistent visual preview on port 4173. |

Studio is available at `/studio` with the configured administrator account. Use it to manage products, images, coupons, loyalty adjustments, storefront settings, and the Story page.
