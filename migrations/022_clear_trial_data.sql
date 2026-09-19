-- One-off reset: the store's orders, customers and reviews to this point were trial runs.
-- Rows only, no schema changes. The catalogue (products, variants, colourways, media,
-- customization rules), the storefront settings, hostels, categories, product types and coupons
-- are deliberately kept, so the shop still works and is ready for real orders.
--
-- Deletes run child-before-parent so every foreign key stays satisfied. The whole migration runs
-- in one transaction, so a mistake rolls back rather than half-wiping the store.
DELETE FROM review_media;
DELETE FROM reviews;
DELETE FROM order_item_customizations;
DELETE FROM vendor_batch_events;
DELETE FROM vendor_batch_items;
DELETE FROM vendor_batches;
DELETE FROM vendor_profiles;
DELETE FROM inventory_movements;
DELETE FROM coupon_redemptions;
DELETE FROM payment_attempts;
DELETE FROM payment_webhook_events;
DELETE FROM order_status_history;
DELETE FROM order_internal_notes;
DELETE FROM wallet_ledger_entries;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM wallet_accounts;
DELETE FROM addresses;
DELETE FROM customer_sessions;
DELETE FROM otp_challenges;
DELETE FROM audit_log;
DELETE FROM users;

-- Reserved stock was held against trial orders that no longer exist. Left alone it would show as
-- permanently unavailable units in the stock desk, and nothing remains that could ever release it.
UPDATE product_variants
SET reserved_stock=0,
    updated_at=now()
WHERE reserved_stock<>0;

-- Star ratings and review counts are denormalised onto the product, so they have to come down with
-- the reviews that produced them.
UPDATE products
SET rating_average=0,
    approved_review_count=0,
    updated_at=now()
WHERE rating_average<>0 OR approved_review_count<>0;
