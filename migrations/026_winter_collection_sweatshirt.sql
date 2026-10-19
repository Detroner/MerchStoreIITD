-- Drop 02. Inventory starts at zero until real quantities are entered in Studio.
INSERT INTO products(name,slug,short_description,description,base_price,card_color,status,featured,customizable,sort_order,features)
VALUES('Sweatshirt','winter-sweatshirt','Winter Collection / Drop 02',
  'A black crewneck with IIT Delhi on the front and your name in white Allison lettering at the middle back. Part of the Winter Collection.',
  89900,'#929290','active',TRUE,TRUE,-10,
  '["Winter Collection / Drop 02","Black crewneck","Personalized name at the middle back","White Allison lettering","Personalization included"]')
ON CONFLICT(slug) DO NOTHING;

-- Keep it in the API catalogue for cart validation; the storefront groups it in Drop 02.
INSERT INTO product_colorways(product_id,name,slug,swatch_hex,card_color,show_in_catalog)
SELECT id,'Black','black','#17171d','#929290',TRUE FROM products WHERE slug='winter-sweatshirt'
ON CONFLICT(product_id,slug) DO NOTHING;

INSERT INTO product_variants(product_id,colorway_id,sku,size,color,stock_on_hand)
SELECT p.id,c.id,'IITD-WINTER-SWEAT-BLK-'||s.size,s.size,'Black',0
FROM products p JOIN product_colorways c ON c.product_id=p.id AND c.slug='black'
CROSS JOIN (VALUES('XS'),('S'),('M'),('L'),('XL'),('XXL')) s(size)
WHERE p.slug='winter-sweatshirt' ON CONFLICT(sku) DO NOTHING;

INSERT INTO product_media(product_id,colorway_id,storage_key,alt_text,sort_order,is_thumbnail,mime_type)
SELECT p.id,c.id,m.url,m.alt,m.sort,m.thumbnail,m.mime
FROM products p JOIN product_colorways c ON c.product_id=p.id AND c.slug='black'
CROSS JOIN (VALUES
  ('/assets/winter/sweatshirt-front.jpg','Sweatshirt front — IIT Delhi',0,TRUE,'image/jpeg'),
  ('/assets/winter/sweatshirt-back.png','Sweatshirt back — personalize your name',1,FALSE,'image/png')
) m(url,alt,sort,thumbnail,mime)
WHERE p.slug='winter-sweatshirt' AND NOT EXISTS(SELECT 1 FROM product_media pm WHERE pm.product_id=p.id AND pm.storage_key=m.url);

INSERT INTO product_customization_options(product_id,enabled,field_label,max_characters,placements,styles,text_colors,surcharge)
SELECT id,TRUE,'Your name · middle back',16,'["Back"]','["Allison"]','["White"]',0
FROM products WHERE slug='winter-sweatshirt' ON CONFLICT(product_id) DO NOTHING;
