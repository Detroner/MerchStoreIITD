# MerchStoreIITD production go-live runbook

**Last reviewed:** 25 August 2026

## Executive status

The Azure-hosted site is currently ready to operate as a **public catalogue and showcase**. The homepage, product experience, The Dogra Drip catalogue item, media carousel, cart quoting, health endpoint, and production browser shell are live. The application is **not yet a live e-commerce launch**: customer authentication, no-charge demo checkout, and the Studio console are intentionally fail-closed until the real provider and identity controls are configured.

> **Do not accept real orders or payments yet.** Razorpay and MSG91 credentials have deliberately not been added. The current posture is the safe one for showing the catalogue to others while those services are being purchased and onboarded.

## Release evidence

| Check | Result |
|---|---|
| Git commit | `7b2690e` — Harden production launch gates and deployment |
| GitHub Actions | Run `32831357492` completed successfully |
| Production URL | `https://theiitdelhidrop.azurewebsites.net` |
| Local application checks | `npm run check` passed; Node syntax and source contracts passed |
| JSX/rendering checks | Full Babel parser and rendering regression harness passed |
| Preview checks | Python syntax, preview self-test, and preview API self-test passed with generated one-run fixture credentials |
| Production dependency audit | `npm audit --omit=dev --audit-level=high` found zero vulnerabilities |
| Production routes | Homepage, cart, account, login, Studio, product, health, store, catalogue, JSX, and CSS probes returned HTTP 200 |
| Production headers | HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, Referrer Policy, Permissions Policy, COOP, and CORP were present |
| Production guard checks | OTP request, demo checkout, and admin login returned HTTP 503 without touching a live order or payment |
| Browser verification | Homepage, The Dogra Drip, cart, login, and Studio rendered; console checks reported no JavaScript errors |

The deployment workflow now uses Node 22, declares the Node 22 engine in `package.json`, audits production dependencies, validates every non-empty SQL migration dynamically, and excludes dotenv, audit, fixture, and work artifacts from the deployment ZIP. The tracked preview adapter no longer contains a live-looking administrator identity or password; preview credentials must be injected for one local run.

## What is intentionally disabled

| Surface | Current production behavior | Reason |
|---|---|---|
| Customer phone sign-in | `503`: secure sign-in is unavailable until MSG91 is configured | Prevents browser-visible demo OTPs from becoming an authentication method |
| Demo checkout | `503`: no-charge orders are disabled in production before customer-session lookup | Prevents stock, wallet, coupon, and order mutations without a real payment |
| Razorpay checkout | Not configured; no provider order is created | No Razorpay account or credentials have been supplied |
| Studio login and admin APIs | `503` while `ADMIN_CONSOLE_ENABLED` is not explicitly true in production | Protects the shared-password/HMAC console until the administrator identity is rotated and strengthened |
| Product browsing and cart quoting | Available | Catalogue can be demonstrated without pretending that ordering is live |

## Exact operator checklist before live money

### 1. Remediate the administrator identity first

Treat the previously used shared administrator credential as compromised. Rotate the administrator password hash in Key Vault, invalidate any existing administrator sessions, and do not enable the console until a separate administrator identity with MFA and a revocation path is in place. After that work is complete, set the App Service setting `ADMIN_CONSOLE_ENABLED=true`. The application will otherwise continue to return the deliberate 503 response for Studio login and admin APIs.

The current server still uses a shared password plus an HMAC proof cookie rather than a full identity provider. That is acceptable for the paused catalogue-only posture, but it is not the target control for a production operations console.

### 2. Configure and test MSG91 in test-safe fashion

Create and approve the MSG91 OTP template, then store the auth key and template ID in Key Vault. The application uses MSG91’s v5 send endpoint with `mobile`, `authkey`, and `template_id` parameters; confirm those values and the approved template in the MSG91 dashboard before testing [4]. Configure `SMS_PROVIDER=msg91`, `MSG91_AUTHKEY`, and `MSG91_TEMPLATE_ID` as App Service settings whose values are Key Vault references, not plaintext secrets.

Use a real test phone owned by the operator to verify the complete flow: send, wrong-code rejection, expiry, resend throttling, successful verification, new-account creation, returning-user session creation, logout, and rate-limit behavior. Confirm that the HTTP response never contains an OTP. Do not use a fixed demo code and do not put a phone number or provider credential into the repository.

### 3. Configure Razorpay in test mode

First configure `RAZORPAY_MODE=test`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET` through Key Vault references. Configure the Razorpay webhook URL as:

```text
https://theiitdelhidrop.azurewebsites.net/api/payments/razorpay/webhook
```

Test successful payment, failed payment, user dismissal, a stale or mismatched order, a mismatched amount or currency, a duplicate webhook, and a delayed or out-of-order webhook. Verify that the server only settles a captured INR payment matched to the internal order and that inventory, wallet redemption, wallet reward, payment attempts, and audit records are each changed exactly once. Razorpay documents raw-body HMAC-SHA256 signature validation, duplicate event handling through the event ID, and the fact that webhook order is not guaranteed [3].

Before switching to live mode, reconcile test orders against the Razorpay dashboard, confirm refund and cancellation handling, document customer support and fulfilment procedures, complete merchant onboarding, and perform a controlled low-value live test. Change to `RAZORPAY_MODE=live` only after those checks pass. Never mark an order paid from a browser redirect alone.

### 4. Configure secrets without placing values in chat or Git

Azure App Service Key Vault references allow the application to read a secret as an app setting through its managed identity, keeping the secret outside the repository and application source [1]. Use the Azure CLI or portal while signed in to the correct subscription. The following pattern shows the intended flow without containing any secret value:

```bash
# Enter each value privately when prompted; do not paste it into Git or chat.
read -r -s MSG91_AUTHKEY
read -r MSG91_TEMPLATE_ID
az keyvault secret set --vault-name merchstore-iitd-kv-2026 --name MSG91-AUTHKEY --value "$MSG91_AUTHKEY" -o none
az keyvault secret set --vault-name merchstore-iitd-kv-2026 --name MSG91-TEMPLATE-ID --value "$MSG91_TEMPLATE_ID" -o none

az webapp config appsettings set \
  --resource-group my-iitd-rg \
  --name theiitdelhidrop \
  --settings \
    SMS_PROVIDER='msg91' \
    MSG91_AUTHKEY='@Microsoft.KeyVault(VaultName=merchstore-iitd-kv-2026;SecretName=MSG91-AUTHKEY)' \
    MSG91_TEMPLATE_ID='@Microsoft.KeyVault(VaultName=merchstore-iitd-kv-2026;SecretName=MSG91-TEMPLATE-ID)' \
  -o none
```

Use the same pattern for the three Razorpay secrets, using Key Vault secret names `RAZORPAY-KEY-ID`, `RAZORPAY-KEY-SECRET`, and `RAZORPAY-WEBHOOK-SECRET`, and App Service settings `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET`. Set `RAZORPAY_MODE=test` first. Restart the App Service after configuration changes, then inspect `/api/store` only for boolean readiness fields and the selected mode; never print the setting values. Key Vault reference values can be cached by App Service, so a configuration change or the documented refresh mechanism may be needed after rotation [1].

### 5. Complete customer-facing and business readiness

Before accepting orders, attach a custom domain with a certificate, publish a real privacy notice and terms, define shipping, returns, cancellations, refunds, taxes, customer support, and delivery expectations, and replace the placeholder footer links with working documents. Confirm IIT Delhi branding and merchandise approvals. Add a fulfilment workflow, payment reconciliation, refund handling, inventory reservation policy, and incident contact.

### 6. Close the Azure and GitHub control-plane gaps

The current audit found that PostgreSQL and Key Vault use public network access, PostgreSQL has a broad Azure-services firewall rule, Key Vault purge protection is not enabled, and the Key Vault uses access-policy mode. Move toward private endpoints or tightly restricted network paths, least-privilege database credentials, a validated PostgreSQL CA chain, Key Vault RBAC with purge protection, backup-restore testing, and monitored alerts before a live-money launch.

Protect the `main` branch, require the production environment to have an approving reviewer and selected deployment branches, and narrow the GitHub OIDC identity from resource-group-wide Contributor to only the resources and actions required by this deployment. GitHub environment protection rules can hold a job until its rules pass and can restrict deployment branches [2]. Continue to verify that the temporary migration firewall rule is removed on success and failure.

Enable Application Insights or an equivalent service with alerts for health failures, provider errors, webhook signature failures, repeated 5xx responses, database connection exhaustion, and unusual order/payment status changes. Test restoration rather than relying only on the configured backup retention.

### 7. Replace the raw browser compilation architecture

The current page intentionally uses raw JSX compiled in the browser from CDN scripts, and it was retained to preserve the existing visual experience. It is not yet a strict supply-chain posture: a production build should bundle and pin dependencies, add integrity metadata where appropriate, remove development compilation, and then enforce a tested Content Security Policy. Complete this migration and run the full desktop/mobile browser regression suite before treating the storefront as fully hardened.

## Safe verification sequence after provider configuration

After each configuration change, first confirm that the public catalogue still loads. Then inspect only redacted readiness fields from `/api/store`, check `/api/health`, and review App Service logs and provider dashboards without copying secrets into tickets or chat. Run MSG91 tests before enabling sign-in, run Razorpay test-mode scenarios before enabling checkout, and preserve the catalogue-only posture if any provider or webhook check fails.

The final cutover should be a deliberate operator action: verify all P0 items in this document, create a rollback plan, announce the customer-facing policies, enable the provider mode, and monitor the first controlled transactions. Until that point, the correct public message is that the catalogue is live and ordering will open soon.

## References

[1]: https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references "Microsoft Learn — Use Key Vault references as app settings in Azure App Service"

[2]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment "GitHub Docs — Managing environments for deployment"

[3]: https://razorpay.com/docs/webhooks/validate-test/?preferred-country=US "Razorpay Docs — Validate and Test Webhooks"

[4]: https://docs.msg91.com/otp/sendotp "MSG91 Docs — SendOTP"
