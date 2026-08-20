# Product, Image, Video and Deletion Pipeline

## Goal

Give administrators one reliable Studio workflow to create products, upload and arrange images/videos, publish or archive products, and safely remove unused drafts without slowing the Node.js server.

## Current gaps

- The backend has `PATCH /api/admin/products/:id`, but no product-creation endpoint.
- Studio only lists and edits products that already exist.
- Product and colourway media fields accept URLs; they do not upload files.
- `product_media` does not describe videos, posters, file sizes or processing state.
- There is no deletion/archive action in Studio or a corresponding backend endpoint.
- Products referenced by historical orders must not be physically deleted.

## Phase 1 — Data and storage foundation

1. Use a private Azure Blob Storage container named `product-media`.
2. Keep storage credentials in Azure Key Vault; never expose the account key to the browser.
3. Upload from the browser directly to Blob Storage with a short-lived, single-file SAS URL. The Express server only authorizes the upload and stores metadata, so videos do not consume server memory or bandwidth.
4. Add migration `005_product_catalog_management.sql`:
   - extend `product_media` with `media_type` (`image` or `video`), `mime_type`, `file_size`, `poster_key`, `duration_seconds`, `processing_state`, `updated_at`;
   - add `deleted_at` to products for reversible archival bookkeeping;
   - add indexes on `product_media(product_id, colorway_id, sort_order)` and active products;
   - retain existing foreign keys and order history.
5. Media limits:
   - images: JPG, PNG or WebP, maximum 10 MB;
   - videos: MP4 or WebM, maximum 50 MB and 30 seconds;
   - maximum 8 media items per colourway;
   - require alt text for images and a poster image for videos before publishing.

## Phase 2 — Minimal backend API

All routes use the existing administrator authentication, CSRF/admin proof, rate limits and audit log.

### Product lifecycle

- `POST /api/admin/products`
  - validate name, unique slug, category, product type and prices;
  - create the product as `draft`;
  - create its first colourway and supplied size/SKU variants in one SQL transaction;
  - return the complete product for immediate editing.
- `PATCH /api/admin/products/:id`
  - retain the existing endpoint and add descriptions, category/type, sort order and publish validation.
- `DELETE /api/admin/products/:id`
  - default action is a soft delete: set `status='archived'` and `deleted_at=now()`;
  - permanent deletion is permitted only for a draft with no order, review or inventory history;
  - return `409` with a useful explanation when permanent deletion is unsafe.
- `POST /api/admin/products/:id/restore`
  - restore an archived product to `draft`, never directly to active.

### Media lifecycle

- `POST /api/admin/media/upload-intent`
  - accept filename, MIME type, size and target product/colourway;
  - validate ownership and limits;
  - return a short-lived SAS upload URL and generated storage key.
- `POST /api/admin/products/:id/media`
  - register the successfully uploaded blob with media type, alt text, poster and ordering metadata.
- `PATCH /api/admin/media/:id`
  - update alt text, poster, active state and sort order.
- `DELETE /api/admin/media/:id`
  - deactivate the row immediately;
  - delete the blob asynchronously only when no other row references it.
- On failed or abandoned uploads, run a daily cleanup for unregistered blobs older than 24 hours.

## Phase 3 — Studio experience

### Add product

Add a visible `NEW PRODUCT` button to Studio Products. Open a compact four-step drawer:

1. **Basics:** name, slug, descriptions, category, product type, prices and badge.
2. **Options:** colourways, sizes, SKUs, initial stock and customization rules.
3. **Media:** drag/drop images and videos, upload progress, poster selection, alt text and drag-to-reorder.
4. **Review:** desktop/mobile product preview, validation summary, then `SAVE DRAFT` or `PUBLISH`.

Drafts can be saved after step 1. Publishing is blocked until there is at least one active colourway, one purchasable variant and one image.

### Manage media

- Show image/video thumbnails per colourway.
- Support upload, reorder, replace, edit alt text, choose primary media and remove.
- Display upload progress and retry only the failed file.
- Lazy-load videos and use their poster image in catalogue cards; videos play only on the product page after user interaction.

### Archive and delete

- Add `ARCHIVE` to every published product and `DELETE DRAFT` only to eligible drafts.
- Archive confirmation states that the product disappears from the storefront but order history remains.
- Permanent deletion requires typing the product name.
- Add an `Archived` filter with `RESTORE TO DRAFT`.

## Phase 4 — Verification and release

### Automated tests

- Product create transaction succeeds and rolls back cleanly on duplicate slug/SKU.
- Publish validation rejects products without media, colourways or stock variants.
- Upload intent rejects unsupported MIME types, oversized files and non-admin requests.
- Media registration, ordering and deletion preserve the correct primary item.
- Archive removes the product from catalogue APIs; restore returns it to Studio as a draft.
- Permanent deletion is blocked when order/review history exists.
- Phone tests at 320, 390 and 430 px cover the product drawer, media grid, upload progress and confirmation dialogs.

### Release order

1. Provision Blob container, CORS policy and Key Vault secrets.
2. Apply the PostgreSQL migration.
3. Deploy backend routes behind `CATALOG_MANAGEMENT_V2=true`.
4. Deploy the Studio UI and run tests with a draft product.
5. Verify image and video delivery, catalogue visibility, archive/restore and phone layouts.
6. Enable the feature for administrators and monitor upload failures, Blob costs and API errors for 48 hours.

## Acceptance criteria

- An administrator can create a complete product without SQL or code changes.
- Images and videos upload directly to Azure with visible progress and retry.
- Each colourway can have its own ordered gallery and primary image.
- A draft can be published only when it is purchasable and visually complete.
- Archived products disappear from the storefront but remain in historical orders.
- Unsafe permanent deletion is prevented by the backend, not only the UI.
- Product creation and media management are usable on phones without horizontal overflow.
- Uploading a 50 MB video does not route the file through Express or materially increase application memory.

## Suggested implementation size

- Database and storage setup: 0.5 day
- Backend endpoints and validation: 1 day
- Studio workflow and responsive UI: 1–1.5 days
- Tests, deployment and production verification: 0.5 day

Expected total: **3–3.5 focused development days**.
