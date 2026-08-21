ALTER TABLE product_media
  ADD COLUMN IF NOT EXISTS is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE;

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY product_id, colorway_id
           ORDER BY sort_order, created_at, id
         ) AS position
  FROM product_media
  WHERE active AND deleted_at IS NULL AND media_type = 'image'
)
UPDATE product_media pm
SET is_thumbnail = (ranked.position = 1)
FROM ranked
WHERE ranked.id = pm.id
  AND NOT EXISTS (
    SELECT 1
    FROM product_media existing
    WHERE existing.product_id = pm.product_id
      AND existing.colorway_id IS NOT DISTINCT FROM pm.colorway_id
      AND existing.is_thumbnail
      AND existing.active
      AND existing.deleted_at IS NULL
  );

CREATE UNIQUE INDEX IF NOT EXISTS product_media_one_thumbnail_idx
  ON product_media (
    product_id,
    COALESCE(colorway_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE is_thumbnail AND active AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS product_media_thumbnail_lookup_idx
  ON product_media(product_id, colorway_id, is_thumbnail, sort_order)
  WHERE active AND deleted_at IS NULL;
