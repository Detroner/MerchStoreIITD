-- Rename the Dogra product and make its Black colourway the canonical first view.
UPDATE products SET name='The Dogra Drip', updated_at=now() WHERE slug='dogra-drip' AND name IS DISTINCT FROM 'The Dogra Drip';

WITH ranked AS (SELECT id,ROW_NUMBER() OVER (ORDER BY CASE WHEN lower(name)='black' THEN 0 ELSE 1 END,sort_order,id)-1 AS next_sort_order FROM product_colorways WHERE product_id=(SELECT id FROM products WHERE slug='dogra-drip') AND active)
UPDATE product_colorways c SET sort_order=ranked.next_sort_order,updated_at=now() FROM ranked WHERE c.id=ranked.id;

UPDATE product_media pm SET alt_text=regexp_replace(pm.alt_text,'Dogra (Drop|Drip)','The Dogra Drip','gi') WHERE pm.product_id=(SELECT id FROM products WHERE slug='dogra-drip');
