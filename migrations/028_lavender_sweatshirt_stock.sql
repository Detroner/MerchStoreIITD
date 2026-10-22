-- Rename the existing colourway in place, preserving IDs, SKUs, media and orders.
UPDATE product_colorways SET name='Lavender',slug='lavender',updated_at=now()
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt')
  AND slug IN ('violet','lavendar','lavender');

UPDATE product_variants v SET color=c.name,updated_at=now()
FROM product_colorways c
WHERE v.colorway_id=c.id AND c.slug='lavender'
  AND c.product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt');

UPDATE products SET
  description=replace(replace(description,'Violet','Lavender'),'Lavendar','Lavender'),
  features=replace(replace(features::text,'Violet','Lavender'),'Lavendar','Lavender')::jsonb,
  updated_at=now()
WHERE slug='winter-sweatshirt';

UPDATE product_media SET alt_text=replace(replace(alt_text,'Violet','Lavender'),'Lavendar','Lavender')
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt');

-- Owner confirmed 20 available Black sweatshirts in each size on 22 October 2026.
-- Keep existing reservations and record the adjustment in the inventory ledger.
WITH current_stock AS MATERIALIZED (
  SELECT v.id,v.stock_on_hand,v.reserved_stock
  FROM product_variants v
  JOIN products p ON p.id=v.product_id
  JOIN product_colorways c ON c.id=v.colorway_id
  WHERE p.slug='winter-sweatshirt' AND c.slug='black'
    AND v.active AND v.size IN ('S','M','L','XL','XXL')
  FOR UPDATE OF v
), updated AS (
  UPDATE product_variants v SET stock_on_hand=20+c.reserved_stock,updated_at=now()
  FROM current_stock c WHERE v.id=c.id
  RETURNING v.id,v.stock_on_hand-c.stock_on_hand AS delta
)
INSERT INTO inventory_movements(variant_id,movement_type,quantity_delta,idempotency_key,reason)
SELECT id,CASE WHEN delta>0 THEN 'receipt'::inventory_movement_kind ELSE 'correction'::inventory_movement_kind END,
  delta,'migration-028-black-stock-'||id,'Owner confirmed 20 available Black sweatshirts per size on 2026-10-22'
FROM updated WHERE delta<>0;
