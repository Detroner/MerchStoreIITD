-- Add the IIT Delhi 01 maroon jersey as a reversible catalogue product.
-- The two tracked media files are the front and back halves of the supplied source image.
INSERT INTO products(name,slug,short_description,description,base_price,compare_price,card_color,status,featured,customizable,sort_order)
VALUES(
  'IIT Delhi 01 Jersey',
  'iit-delhi-01-jersey',
  'A maroon IIT Delhi varsity jersey with the 01 mark on the back.',
  'A campus-first maroon jersey with contrast athletic stripes, IIT Delhi lettering on the front and 01 on the back.',
  119900,
  149900,
  '#6a1e24',
  'active',
  TRUE,
  FALSE,
  2
)
ON CONFLICT(slug) DO UPDATE SET
  name=EXCLUDED.name,
  short_description=EXCLUDED.short_description,
  description=EXCLUDED.description,
  base_price=EXCLUDED.base_price,
  compare_price=EXCLUDED.compare_price,
  card_color=EXCLUDED.card_color,
  status='active',
  featured=TRUE,
  customizable=FALSE,
  updated_at=now();

INSERT INTO product_colorways(product_id,name,slug,swatch_hex,card_color,show_in_catalog,sort_order)
SELECT id,'Maroon','maroon','#6a1e24','#6a1e24',TRUE,0
FROM products WHERE slug='iit-delhi-01-jersey'
ON CONFLICT(product_id,name) DO UPDATE SET
  slug=EXCLUDED.slug,
  swatch_hex=EXCLUDED.swatch_hex,
  card_color=EXCLUDED.card_color,
  active=TRUE,
  show_in_catalog=TRUE,
  sort_order=0,
  updated_at=now();

INSERT INTO product_variants(product_id,colorway_id,sku,size,color,stock_on_hand)
SELECT p.id,c.id,'IITD-JERSEY-MAROON-'||s.size,s.size,'Maroon',12
FROM products p
JOIN product_colorways c ON c.product_id=p.id AND c.name='Maroon'
CROSS JOIN (VALUES ('S'),('M'),('L'),('XL')) AS s(size)
WHERE p.slug='iit-delhi-01-jersey'
ON CONFLICT(sku) DO UPDATE SET
  product_id=EXCLUDED.product_id,
  colorway_id=EXCLUDED.colorway_id,
  color=EXCLUDED.color,
  active=TRUE,
  updated_at=now();

INSERT INTO product_media(product_id,colorway_id,storage_key,alt_text,width,height,sort_order,active,is_thumbnail,media_type,mime_type,file_size,processing_state)
SELECT p.id,c.id,'/media/iitd-jersey-front.jpg','IIT Delhi 01 Jersey maroon front view',640,853,0,TRUE,TRUE,'image','image/jpeg',51796,'ready'
FROM products p JOIN product_colorways c ON c.product_id=p.id AND c.name='Maroon'
WHERE p.slug='iit-delhi-01-jersey'
  AND NOT EXISTS (SELECT 1 FROM product_media pm WHERE pm.product_id=p.id AND pm.colorway_id=c.id AND pm.storage_key='/media/iitd-jersey-front.jpg');

INSERT INTO product_media(product_id,colorway_id,storage_key,alt_text,width,height,sort_order,active,is_thumbnail,media_type,mime_type,file_size,processing_state)
SELECT p.id,c.id,'/media/iitd-jersey-back.jpg','IIT Delhi 01 Jersey maroon back view',640,853,1,TRUE,FALSE,'image','image/jpeg',43171,'ready'
FROM products p JOIN product_colorways c ON c.product_id=p.id AND c.name='Maroon'
WHERE p.slug='iit-delhi-01-jersey'
  AND NOT EXISTS (SELECT 1 FROM product_media pm WHERE pm.product_id=p.id AND pm.colorway_id=c.id AND pm.storage_key='/media/iitd-jersey-back.jpg');
