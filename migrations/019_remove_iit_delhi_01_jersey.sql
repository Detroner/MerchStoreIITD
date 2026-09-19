-- Remove the IIT Delhi 01 jersey from the catalogue entirely.
-- order_items carries its own snapshot of every purchase (product_name, slug, sku, size, color,
-- image, unit_price), so detaching the two product foreign keys retires the product without
-- rewriting customer order history. Deleting the product then cascades to its colourways,
-- variants, media and customization options.
DELETE FROM reviews
WHERE product_id IN (SELECT id FROM products WHERE slug='iit-delhi-01-jersey');

DELETE FROM inventory_movements
WHERE variant_id IN (
  SELECT v.id FROM product_variants v
  JOIN products p ON p.id=v.product_id
  WHERE p.slug='iit-delhi-01-jersey'
);

UPDATE order_items
SET product_id=NULL,
    variant_id=NULL
WHERE product_id IN (SELECT id FROM products WHERE slug='iit-delhi-01-jersey');

DELETE FROM products WHERE slug='iit-delhi-01-jersey';
