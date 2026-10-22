-- Retire only the owner's test colourway; preserve records and order history.
UPDATE product_variants SET active=FALSE,updated_at=now()
WHERE colorway_id IN (SELECT c.id FROM product_colorways c JOIN products p ON p.id=c.product_id
  WHERE p.slug='chill-hai' AND c.slug='test');
UPDATE product_colorways SET active=FALSE,show_in_catalog=FALSE,updated_at=now()
WHERE product_id IN (SELECT id FROM products WHERE slug='chill-hai') AND slug='test';

-- Rename the real black colourway in place, preserving its IDs, SKUs and quantities.
UPDATE product_colorways SET name='Black',slug='black',swatch_hex='#17171d',updated_at=now()
WHERE product_id IN (SELECT id FROM products WHERE slug='chill-hai') AND slug='default'
  AND NOT EXISTS (SELECT 1 FROM product_colorways other WHERE other.product_id=product_colorways.product_id AND other.slug='black');
UPDATE product_variants v SET color=c.name,updated_at=now() FROM product_colorways c
WHERE v.colorway_id=c.id AND c.slug='black'
  AND c.product_id IN (SELECT id FROM products WHERE slug='chill-hai');
