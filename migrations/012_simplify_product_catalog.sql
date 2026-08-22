ALTER TABLE products
  ADD COLUMN IF NOT EXISTS features JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE products
SET features = '[]'::jsonb
WHERE features IS NULL OR jsonb_typeof(features) <> 'array';

DROP INDEX IF EXISTS products_catalog_category_idx;
DROP INDEX IF EXISTS products_catalog_type_idx;

ALTER TABLE products
  DROP CONSTRAINT IF EXISTS products_category_id_fkey,
  DROP COLUMN IF EXISTS category_id,
  DROP COLUMN IF EXISTS product_type_id,
  DROP COLUMN IF EXISTS badge;

DROP TABLE IF EXISTS product_types;
DROP TABLE IF EXISTS categories;

CREATE INDEX IF NOT EXISTS products_catalog_sort_idx
  ON products(status, sort_order, created_at DESC);
