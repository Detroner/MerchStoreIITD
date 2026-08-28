-- Keep the hoodie and its historical records, but remove it from public catalogue/product queries.
UPDATE products
SET status='archived',
    featured=FALSE,
    updated_at=now()
WHERE slug='core-memory-hoodie'
  AND status <> 'archived';
