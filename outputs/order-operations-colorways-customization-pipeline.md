# The IIT Delhi Drop — Order Operations, Vendor Handoff, Customization, and Colorway Pipeline

**Repository:** `Detroner/MerchStoreIITD`  
**Status:** Implementation-ready proposal  
**Primary users:** Studio administrators, fulfilment operators, production vendors, and customers  
**Recommended delivery:** Four staged releases behind Studio feature flags

---

## 1. Outcomes

This work should deliver four connected outcomes:

1. Turn Studio Orders into a structured operations workspace with reliable server-side filtering, grouping, sorting, pagination, order details, and status actions.
2. Generate a repeatable vendor handoff that clearly separates newly submitted work from older pending work and summarizes exact product, color, size, quantity, and customization requirements.
3. Expose customization configuration and purchased customization details throughout Studio instead of showing only a Boolean `customized` flag.
4. Display every active colorway as its own visual catalogue card on the homepage and merchandise section while retaining one canonical product and product detail page.

The implementation must preserve PostgreSQL as the system of record, use the existing Express/React architecture, avoid loading all orders into the browser, and keep historical order data immutable.

---

## 2. Current-state findings

The repository already has useful foundations:

- `orders`, `order_items`, `product_variants`, `order_item_customizations`, inventory movements, and payment records exist in PostgreSQL.
- Each order item already snapshots product name, SKU, size, color, price, image, and quantity.
- Product-level customization rules and order-item customization snapshots already exist.
- The customer catalogue already receives active variants and customization configuration.
- Studio already has an Orders tab, product and size selectors, a demand grid, and a basic order ledger.
- Product variants already distinguish size and color.

The operational gaps are:

- `/api/admin/data` returns at most 100 orders and makes the browser perform most refinement.
- The demand query groups only by product and size; color, SKU, status, payment, customization, and production state are absent.
- Studio order rows show only order number, customer, total, and fulfilment status.
- Studio receives only `customized: true/false`; it does not receive the custom text, placement, style, text color, surcharge, moderation state, or production state.
- The product editor can toggle customization but cannot configure its rules.
- There is no auditable concept of a vendor batch, last-sent cutoff, vendor acknowledgement, or generated export.
- The catalogue renders one card per product using one primary image, so additional colors do not receive their own visual card.
- Color is currently a string repeated across size variants rather than a first-class visual colorway.

---

## 3. Product decisions

### 3.1 One product, multiple catalogue colorway cards

Do not create duplicate product records for black and white versions of the same T-shirt. Introduce a colorway entity under the product.

- Product: shared description, reviews, customization policy, category, type, and base pricing.
- Colorway: color name, swatch, its own images, catalogue card color, visibility, and sort order.
- Variant: exact sellable SKU for a colorway and size.
- Catalogue item: one card per visible colorway.
- Product detail URL: `/products/:productSlug?color=:colorwaySlug`.
- Reviews remain product-level unless color-specific reviews are introduced later.
- Cart and orders continue to use the exact variant ID and snapshot color.

This gives black and white T-shirts separate images on the homepage without fragmenting product data, stock, reviews, or analytics.

### 3.2 Server-side order operations

The Orders workspace must query purpose-built endpoints. Do not keep expanding `/api/admin/data` or filter a fixed array of 100 orders in React.

### 3.3 Vendor handoffs are immutable batches

Every generated vendor handoff must be stored as a snapshot. Regenerating a batch later must not silently change quantities because an order was edited or cancelled. Adjustments should create a delta batch or an explicit batch revision with an audit event.

### 3.4 Safe vendor sharing in two stages

- Release 1: `Generate`, `Copy message`, `Download CSV`, and device `Share` actions. A WhatsApp deep link may open with the message prefilled, but the operator presses Send.
- Later optional release: WhatsApp Business Cloud API after vendor consent, approved templates, access controls, delivery tracking, cost review, and secret management are complete.

This avoids making a third-party message API part of the critical launch path.

---

## 4. Studio Orders information architecture

Create the following saved views inside the Orders tab:

1. **Action needed** — paid/confirmed orders with a production or fulfilment blocker.
2. **New for vendor** — eligible order items not included in any sent vendor batch.
3. **Pending with vendor** — previously sent items that are not marked ready, packed, dispatched, cancelled, or refunded.
4. **Customization queue** — customized items grouped by production status.
5. **Ready to ship** — all required line items complete and payment captured.
6. **All orders** — the complete searchable ledger.
7. **Production matrix** — aggregate product → color → size demand.
8. **Vendor batches** — draft, sent, acknowledged, in production, completed, and cancelled batches.

### 4.1 Persistent filter bar

Support combinable filters and encode them in the URL so refresh/back navigation preserves the view:

- Date range: today, last 7 days, current drop, custom range
- Order status
- Payment status
- Fulfilment status
- Vendor/production status
- Product
- Product type
- Colorway/color
- Size
- SKU
- Customized: yes/no
- Hostel/local pickup/shipping method when those fields become available
- Search: order number, customer name, verified phone, SKU
- Sort: newest, oldest, highest value, lowest value, due date, status priority

Add `Clear filters`, a visible active-filter count, and saved presets. Expensive text searches should be debounced.

### 4.2 Summary strip

For the active filters show:

- Orders
- Total pieces
- Paid value
- New vendor pieces
- Pending vendor pieces
- Customized pieces
- Exceptions/blocked pieces

All values must be produced from the same normalized server-side filter set as the ledger.

### 4.3 Production matrix

Display a drillable matrix:

`Product → Colorway → Size → Units`

Recommended desktop layout:

| Product / color | XS | S | M | L | XL | XXL | One size | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Main Building Tee / Black | 1 | 4 | 9 | 7 | 3 | 1 | 0 | 25 |
| Main Building Tee / White | 0 | 3 | 6 | 8 | 2 | 0 | 0 | 19 |

On mobile, render the same information as stacked product/color cards with size chips. Selecting a cell opens the matching order items.

Matrix controls:

- Toggle units vs distinct orders
- Include/exclude unpaid orders
- Include/exclude already batched items
- Group by product, color, size, SKU, or customization
- Export the current filtered matrix

### 4.4 Order ledger

Use paginated rows with:

- Order number and timestamp
- Customer and delivery summary
- Piece count and short item summary
- Total and payment state
- Fulfilment state
- Vendor/batch state
- Customization warning badge
- Exception badge

Clicking a row opens an order detail drawer or full detail page without losing filters or scroll position.

### 4.5 Order detail

Show:

- Customer contact and sanitized delivery address
- Payment, order, and fulfilment timelines
- Every line item with image, product, color, size, SKU, quantity, price, and stock reservation
- Full customization snapshot per line: text, placement, style/font, text color, surcharge, approval, and production status
- Vendor batch membership and sent timestamps
- Internal notes and audit history
- Explicit allowed status actions with confirmation for risky transitions

Do not allow an administrator to alter the historical purchased customization rule snapshot. Corrections require a logged adjustment with before/after values.

---

## 5. Vendor workflow

### 5.1 Eligibility rules

A line item is eligible for a new vendor batch when:

- Payment is captured/paid, or the configured approved payment rule is met.
- The order is not cancelled, refunded, or failed.
- The item is not already present in a sent, acknowledged, in-production, or completed batch.
- Required customization has passed moderation or manual review.
- Product, color, size, SKU, and quantity are complete.

These rules must run on the server inside the batch-creation transaction.

### 5.2 Batch lifecycle

`draft → sent → acknowledged → in_production → ready → completed`

Exceptional transitions:

- `draft → cancelled`
- `sent/acknowledged/in_production → adjustment_required`
- An order cancellation after sending creates an adjustment record; it must not erase the original batch line.

### 5.3 Generated vendor package

Generate three artifacts from the same batch snapshot:

1. **Vendor summary message** — concise and readable in WhatsApp/email.
2. **Production CSV** — aggregate rows by product, colorway, size, and SKU.
3. **Customization CSV** — one row per customized piece or quantity group, including order reference and exact printing instructions.

Add an optional internal fulfilment manifest containing customer delivery data. Do not include customer phone/address in the production vendor files unless the vendor is contractually responsible for shipping.

### 5.4 Message structure

```text
THE IIT DELHI DROP — PRODUCTION UPDATE
Batch: IITD-2026-08-20-01
Cut-off: 20 Aug 2026, 5:30 PM IST

NEW: 18 orders / 29 pieces
Main Building Tee — Black: S 2, M 5, L 4, XL 1 (12)
Main Building Tee — White: S 1, M 4, L 3, XL 2 (10)
Core Memory Hoodie — Navy: M 2, L 3, XL 2 (7)

CUSTOMIZED: 5 pieces
See attached customization sheet. Please verify spellings before production.

PENDING FROM EARLIER BATCHES: 11 pieces
Batch 2026-08-18-01: 7 in production, 4 awaiting confirmation

Please acknowledge quantities and expected ready date.
```

The generated message must include:

- Batch ID and cutoff timestamp with timezone
- New order and piece totals
- Product/color/size breakdown
- Customized piece count and an explicit spelling warning
- Older pending batch summary
- Exceptions excluded from the batch
- Requested acknowledgement and target date
- A checksum or revision number shown in Studio and the exports

### 5.5 Studio batch composer

The operator should be able to:

1. Choose a saved view or filters.
2. Preview eligible and excluded items.
3. Review production totals and customization rows.
4. Enter a requested-ready date and internal/vendor note.
5. Create a draft batch.
6. Download CSVs and copy/share the message.
7. Mark the batch sent only after sharing.
8. Record vendor acknowledgement and promised date.
9. Update production progress in bulk or per line.

Prevent two administrators from batching the same item concurrently through row locking, a uniqueness constraint, and an idempotency key.

---

## 6. Customization in Studio

### 6.1 Product configuration

Extend the Studio product workbench with a **Customization** panel:

- Enabled toggle
- Field label
- Minimum and maximum characters
- Allowed-character policy with a readable preset instead of raw regex by default
- Placement choices
- Style/font choices
- Text-color choices
- Surcharge
- Additional fulfilment days
- Return-policy copy
- Live input preview and validation example

Changing customization rules affects only future quotes/orders. Existing order-item snapshots remain unchanged.

### 6.2 Order visibility

Customized items must be visible in:

- Orders ledger badge and filter
- Order detail item card
- Production matrix customization totals
- Dedicated customization queue
- Vendor summary count
- Customization CSV
- Batch detail and status tracking

### 6.3 Validation corrections

The existing server validates text length and pattern. Extend validation so submitted placement, style, and text color must also be members of the product's allowed arrays. Apply identical validation in quote and final order creation through one shared backend function.

Escape customization text in every HTML, CSV, log, and message context. Protect CSV exports against formula injection by prefixing cells beginning with `=`, `+`, `-`, or `@`.

---

## 7. Colorway merchandising

### 7.1 PostgreSQL model

Add `product_colorways`:

```sql
CREATE TABLE product_colorways (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  swatch_hex TEXT NOT NULL,
  card_color TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  show_in_catalog BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(product_id, slug),
  UNIQUE(product_id, name)
);
```

Add `colorway_id` to `product_variants`, backfill it from distinct `(product_id, color)`, validate all rows, then make it required in a later contract migration. Keep the `order_items.color` snapshot for historical accuracy.

Associate media with colorways by adding nullable `colorway_id` to `product_media`, or introduce `colorway_media` if independent lifecycle management is preferred. A colorway must have one primary image before it can be shown in the catalogue.

Recommended indexes:

- `product_colorways(product_id, active, show_in_catalog, sort_order)`
- `product_variants(colorway_id, size, active)`
- Unique active SKU remains enforced

### 7.2 Catalogue API

Change `/api/catalog` to return catalogue cards rather than only products:

```json
{
  "catalogItemId": "product-id:colorway-id",
  "productId": "...",
  "productSlug": "main-building-tee",
  "colorwayId": "...",
  "colorwaySlug": "black",
  "color": "Black",
  "swatch": "#111111",
  "image": "/media/main-building-tee-black.webp",
  "availableSizes": ["S", "M", "L", "XL"],
  "variants": []
}
```

Rules:

- One active, catalogue-visible colorway produces one card.
- A colorway with no available variants may display as sold out if configured, otherwise it is omitted.
- Filters operate on the colorway's variants.
- Pagination counts colorway cards, not parent products.
- Stable sorting uses product sort order, colorway sort order, and IDs as tie-breakers.

### 7.3 Frontend behavior

- Render black and white as two cards with their own images and swatches.
- Use `productId:colorwayId` as the React key.
- Link each card to the canonical product page with its color query.
- On the product page, color swatches update gallery, active variants, availability, selected size, URL, and mobile buy bar.
- Reset an invalid selected size when switching colors and clearly announce the change to assistive technology.
- Preserve the selected color in cart and checkout via the variant ID.

### 7.4 Studio colorway editor

For each product provide:

- List of colorways with image thumbnail, swatch, active state, catalogue visibility, and stock total
- Add colorway
- Edit name, slug, swatch, card color, images, sort order, and visibility
- Variant matrix for sizes, SKU, price override, stock, and active state
- Preview catalogue card
- Duplicate colorway as a starting point, while requiring new SKUs
- Archive rather than delete any colorway referenced by an order

Publishing should be blocked when a visible colorway lacks a primary image, swatch, or active variant.

---

## 8. Database migration plan

Create an expand-first migration, recommended as `004_order_operations_colorways.sql`:

### Order operations tables

- `order_status_history`
  - order ID, field changed, previous value, new value, note, actor, timestamp
- `order_internal_notes`
  - order ID, note, actor, created timestamp
- `vendor_profiles`
  - name, contact, channel, active, default lead time; restrict sensitive fields
- `vendor_batches`
  - batch number, vendor, filter snapshot, cutoff, requested date, promised date, lifecycle status, revision, checksum, created/sent/acknowledged timestamps, created by
- `vendor_batch_items`
  - batch, order item, product/variant/colorway snapshot, size, quantity, customization snapshot, production status
- `vendor_batch_events`
  - batch, event type, details, actor, timestamp

Important constraints:

- Prevent the same order item from belonging to multiple non-cancelled active batches unless the later record is an explicit delta.
- Enforce non-negative quantities.
- Use foreign keys but retain denormalized snapshots for historical exports.
- Add idempotency key uniqueness for batch creation.

Indexes:

- Orders by payment/order/fulfilment state and created time
- Order items by product, variant, size, color, and order
- Customizations by production and moderation state
- Batch items by batch, order item, and production status
- Optional PostgreSQL trigram index for order/customer/SKU search after measuring query plans

### Backfill

1. Create colorways from existing distinct product variant colors.
2. Select the current primary product image as the temporary primary image for every backfilled colorway.
3. Link variants to colorways.
4. Mark colorways catalogue-visible only after administrators upload the correct color-specific imagery.
5. Preserve all order-item snapshots unchanged.

Run reconciliation reports for products, variants, stock, orders, units, customizations, and monetary totals before and after migration.

---

## 9. API plan

### Order operations

- `GET /api/admin/orders`
  - Server-side filters, search, sort, cursor pagination, compact rows
- `GET /api/admin/orders/summary`
  - Totals and status counts for the same filter contract
- `GET /api/admin/orders/matrix`
  - Product/colorway/size/SKU aggregate with drilldown keys
- `GET /api/admin/orders/:id`
  - Complete order detail, customization snapshots, batch membership, timeline
- `PATCH /api/admin/orders/:id/status`
  - Validated state transition, note, optimistic version, audit event
- `PATCH /api/admin/order-items/:id/production-status`
  - Per-line production progress

### Vendor batches

- `POST /api/admin/vendor-batches/preview`
- `POST /api/admin/vendor-batches`
- `GET /api/admin/vendor-batches`
- `GET /api/admin/vendor-batches/:id`
- `GET /api/admin/vendor-batches/:id/message`
- `GET /api/admin/vendor-batches/:id/production.csv`
- `GET /api/admin/vendor-batches/:id/customizations.csv`
- `POST /api/admin/vendor-batches/:id/mark-sent`
- `POST /api/admin/vendor-batches/:id/acknowledge`
- `PATCH /api/admin/vendor-batches/:id/items`

CSV downloads must stream from the server, use UTF-8 with documented headers, set safe filenames, and be generated from the stored snapshot.

### Product administration

- `GET /api/admin/products/:id`
- `PATCH /api/admin/products/:id/customization`
- `POST /api/admin/products/:id/colorways`
- `PATCH /api/admin/colorways/:id`
- `POST /api/admin/colorways/:id/media`
- `POST /api/admin/colorways/:id/variants`
- `PATCH /api/admin/variants/:id`
- `POST /api/admin/colorways/:id/archive`

Use schema validation for every request. Maintain the current admin authentication boundary but add role checks before vendor exports, customer PII, order mutations, and catalogue publishing.

---

## 10. Frontend module plan

Split the current single-file Studio implementation into focused modules during this work:

```text
src/
  studio/
    orders/
      OrdersWorkspace.jsx
      OrderFilters.jsx
      OrderSummary.jsx
      ProductionMatrix.jsx
      OrderLedger.jsx
      OrderDetail.jsx
      CustomizationQueue.jsx
    vendor/
      BatchComposer.jsx
      BatchDetail.jsx
      VendorMessage.jsx
      ExportActions.jsx
    products/
      ProductEditor.jsx
      CustomizationEditor.jsx
      ColorwayEditor.jsx
      VariantMatrix.jsx
  storefront/
    CatalogCard.jsx
    ColorwaySelector.jsx
```

Add a small API/query layer that supports request cancellation, cache keys based on normalized filters, stale-response protection, and explicit loading/error/empty states.

The Studio desktop layout should favor dense operational information. Mobile Studio should use cards, bottom sheets, and a sticky action bar rather than forcing the desktop table into a narrow viewport.

---

## 11. Delivery phases

### Phase 0 — Specification and test baseline (2–3 days)

- Confirm order/payment/fulfilment state definitions.
- Confirm which payment states are eligible for production.
- Confirm vendor responsibilities and allowed PII.
- Define size ordering per product type.
- Capture current order totals and representative customization cases.
- Add baseline tests for catalogue, Studio login, and admin data.

**Exit:** State diagram, export headers, sample message, and reconciliation fixture are approved.

### Phase 1 — Order query foundation (4–5 days)

- Add migrations, indexes, state history, notes, and shared filter normalization.
- Add paginated order, summary, matrix, and detail endpoints.
- Replace the Orders dependency on `/api/admin/data`.
- Add URL-persistent filters and saved operational views.

**Exit:** Results remain correct beyond 100 orders; summary, matrix, ledger, and drilldown agree for every filter.

### Phase 2 — Customization operations (3–4 days)

- Return full customization snapshots to authorized Studio endpoints.
- Add the customization queue and detail UI.
- Add the product customization rule editor.
- Centralize server validation for text and selected options.
- Add per-line production status and audit events.

**Exit:** An operator can configure future customization and trace every purchased customized item from order to production.

### Phase 3 — Vendor batches and exports (5–6 days)

- Add vendor and batch tables.
- Implement preview and atomic batch creation.
- Generate summary message and both CSV exports.
- Add copy, download, Web Share, and optional WhatsApp prefill.
- Add acknowledgement, promised date, progress, delta, and pending views.

**Exit:** Repeating an action cannot duplicate items; sent exports remain reproducible; new and pending counts are unambiguous.

### Phase 4 — Colorway catalogue cards (5–6 days)

- Add and backfill colorways and media links.
- Add Studio colorway and variant matrix editors.
- Change catalogue result shape to one item per colorway.
- Add color-aware product URLs, galleries, availability, and cart selection.
- Upload accurate imagery for each active colorway.

**Exit:** A two-color T-shirt displays as two correct catalogue cards and both lead to one canonical product page with the matching color selected.

### Phase 5 — Hardening and rollout (3–4 days)

- Load, accessibility, security, and concurrency testing.
- Query-plan review and performance budgets.
- Export and message fixture verification with the vendor.
- Staging migration rehearsal and production backup.
- Feature-flag rollout, monitoring, and rollback rehearsal.

**Exit:** All acceptance criteria pass and operations/vendor owners sign off.

Estimated focused delivery: **4–5 weeks for one full-stack engineer**, or **2–3 weeks with parallel frontend/backend ownership plus QA**.

---

## 12. Testing strategy

### Unit tests

- Order filter normalization and state eligibility
- Product/color/size/SKU aggregation
- Size ordering, including non-apparel `One Size`
- New vs previously batched vs pending classification
- Customization option validation
- Message rendering, totals, revision, and checksum
- CSV escaping and formula-injection protection
- Colorway catalogue-card mapping

### PostgreSQL/integration tests

- Pagination stability while new orders arrive
- Summary/matrix/ledger reconciliation
- Concurrent batch creation cannot duplicate an order item
- Cancellation after send produces an adjustment, not data loss
- Historic customization snapshots survive product-rule changes
- Colorway backfill preserves every variant and stock total
- Archived colorways remain visible in historical orders

### Browser tests

- Combine and clear all order filters
- Restore filters through refresh/back navigation
- Drill from matrix cell to exact line items
- Open order detail and return without losing context
- Configure customization and confirm storefront update
- Generate, copy, download, and mark a vendor batch sent
- Black and white cards both appear on homepage and merchandise section
- Each card opens the correct selected color
- Color switching handles unavailable sizes correctly
- Studio and storefront at 320, 390, 768, 1024, and 1440 px

### Security tests

- Unauthorized order and export access
- Admin role escalation and CSRF/proof enforcement
- Stored XSS through names, notes, and customization text
- CSV injection
- Search SQL injection
- Excessive export range and scraping controls
- PII absence from production-only vendor files
- Audit coverage for every status, batch, export, and correction action

### Performance targets

- Order ledger p95 under 500 ms for normal indexed filters
- Matrix p95 under 800 ms for the active drop/date window
- First 50 ledger rows rendered without downloading all order items
- Export generation streams and does not hold the entire file in memory
- Catalogue p95 regression below 10% after colorway expansion
- No cumulative layout shift from colorway images with declared dimensions

---

## 13. Observability

Add structured events and metrics for:

- Order search latency and result counts
- Matrix query latency
- Batch preview/create/send/acknowledge events
- Excluded batch items by reason
- Export generation failures and durations
- New and pending piece counts by vendor
- Customization items by production status and age
- Orders waiting beyond configured SLA
- Catalogue colorway card count and zero-image/zero-variant publishing errors

Never log full addresses, phone numbers, customization content, raw exports, cookies, or admin proofs. Use safe IDs and correlation IDs.

Alerts should cover failed batch creation, reconciliation mismatch, repeated export failure, orders stuck in paid/unfulfilled state, and vendor items beyond promised date.

---

## 14. Deployment and rollback

1. Ship expand-only database migrations first.
2. Backfill colorways and validate counts with catalogue visibility disabled.
3. Deploy new APIs behind `STUDIO_ORDER_OPS_V2` and `COLORWAY_CATALOG_V2` flags.
4. Run old and new aggregate queries in shadow mode and compare totals.
5. Enable the new Orders workspace for administrators.
6. Create a test vendor batch from staging fixtures and validate with the vendor.
7. Upload correct colorway images and enable colorway catalogue results.
8. Monitor errors, latency, catalogue counts, orders, and conversion.

Rollback:

- Disable the feature flags and return to the existing Studio Orders and product-level catalogue response.
- Do not drop new tables or columns during rollback.
- Preserve created batch snapshots and audit events.
- Repair data through a forward migration; never manually rewrite sent batch history.

---

## 15. Acceptance criteria

### Orders

- More than 100 orders can be searched and paginated without missing or duplicating rows.
- Filters for product, color, size, SKU, payment, fulfilment, date, and customization work together.
- Summary, production matrix, and ledger reconcile to identical piece totals.
- Matrix drilldown returns exactly the contributing line items.
- Order detail exposes every purchased customization field and its production state.

### Vendor operations

- New items have never been included in a sent active batch.
- Pending items were previously sent and are not terminal.
- Only eligible orders enter a production batch.
- One click cannot batch an item twice, even with two administrators operating concurrently.
- The message, production CSV, and customization CSV reconcile exactly.
- A sent batch can be reproduced later with the same revision and checksum.
- Customer PII is absent unless explicitly required for a shipping manifest.

### Customization

- Studio can edit customization rules for future orders.
- Placement, style, text color, text, and surcharge are visible for purchased items.
- Invalid or injected customization choices are rejected server-side.
- Historical customization is unchanged after catalogue configuration edits.

### Colorways

- Each active visible colorway has its own catalogue card and correct image.
- Two colors produce two cards without duplicating the parent product or reviews.
- Product page, selected variant, cart, stock, checkout, and order snapshot agree on color and size.
- Archived colorways disappear from the catalogue but remain readable in past orders.

---

## 16. Decisions required before implementation

1. Which payment states may be sent to production: captured only, paid/captured, or approved cash/manual orders?
2. Does the vendor manufacture only, or also pack/ship to customers?
3. Which channel is preferred: copied WhatsApp message, email, downloadable files, or a later WhatsApp Business API?
4. What is the production cutoff schedule and expected vendor acknowledgement SLA?
5. Can quantities be changed after a batch is sent, or must every change be a delta batch?
6. Which order and production states are authoritative for your real workflow?
7. Are customization rows one per unit when quantity is greater than one, or is one customization applied to the entire line quantity?
8. What is the canonical size order for T-shirts, hoodies, trackpants, and accessories?
9. Should sold-out colorways remain visible?
10. Who can view customer PII, export vendor files, publish colorways, and change order states?

Recommended defaults:

- Send only captured/paid orders.
- Use copy/share plus CSV in the first release.
- Require explicit `Mark sent` and vendor acknowledgement.
- Treat every post-send change as an auditable delta.
- Keep sold-out colorways visible with a sold-out state for the active drop.
- Limit PII to fulfilment administrators; production exports contain order reference only.

---

## 17. Definition of done

This initiative is complete when Studio functions as an operational order control room; the vendor receives a clear, reproducible, and reconciled production handoff; customization is visible and manageable from configuration through fulfilment; and every active product color receives its own accurate catalogue presentation without duplicating product identity.
