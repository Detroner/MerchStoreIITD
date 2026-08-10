WITH product_seed(name,slug,category_slug,type_slug,price,compare_price,badge,color,description,featured,customizable,sort_order) AS (VALUES
('Core Memory Hoodie','core-memory-hoodie','apparel','hoodie',249900,299900,'CAMPUS FAVE','#163ea8','Heavyweight brushed cotton built for late labs and early Delhi winters.',TRUE,TRUE,1),
('Main Building Tee','main-building-tee','apparel','t-shirt',99900,129900,'NEW DROP','#ed3b24','A relaxed everyday tee with a bold architectural graphic.',TRUE,TRUE,2),
('Red Brick Cap','red-brick-cap','accessories','cap',69900,79900,'LIMITED','#f5ba32','Six-panel cotton cap with an embroidered campus-inspired mark.',TRUE,FALSE,3),
('All-Nighter Mug','all-nighter-mug','home','mug',44900,0,'','#22222a','Enamel mug for caffeine, chai and unreasonable deadlines.',FALSE,TRUE,4),
('Hauz Khas Tote','hauz-khas-tote','accessories','bag',59900,0,'LOW IMPACT','#1b7f61','Roomy canvas tote with reinforced straps and an inside pocket.',FALSE,TRUE,5),
('Workshop Socks','workshop-socks','apparel','t-shirt',34900,0,'ALMOST GONE','#8c4ac9','Cushioned crew socks made for long walks across campus.',FALSE,FALSE,6),
('Lecture Hall Trackpants','lecture-hall-trackpants','apparel','trackpants',159900,189900,'FRESH CUT','#183c9f','Relaxed straight-leg trackpants with deep pockets and a clean campus mark.',TRUE,TRUE,7),
('Drafting Desk Notebook','drafting-desk-notebook','stationery','stationery',29900,0,'STUDIO PICK','#e66f3d','A lay-flat notebook for sketches, equations and half-formed breakthroughs.',FALSE,TRUE,8)
)
INSERT INTO products(category_id,product_type_id,name,slug,short_description,description,base_price,compare_price,badge,card_color,status,featured,customizable,sort_order,rating_average,approved_review_count)
SELECT c.id,t.id,s.name,s.slug,s.description,s.description,s.price,s.compare_price,s.badge,s.color,'active',s.featured,s.customizable,s.sort_order,CASE WHEN s.sort_order<5 THEN 4.60 ELSE 0 END,CASE WHEN s.sort_order<5 THEN 12-s.sort_order ELSE 0 END
FROM product_seed s JOIN categories c ON c.slug=s.category_slug JOIN product_types t ON t.slug=s.type_slug ON CONFLICT(slug) DO NOTHING;

INSERT INTO product_media(product_id,storage_key,alt_text,sort_order)
SELECT id,'/assets/merch-hero.png',name,1 FROM products ON CONFLICT DO NOTHING;

WITH apparel AS (SELECT id,base_price,slug FROM products WHERE slug IN('core-memory-hoodie','main-building-tee','workshop-socks','lecture-hall-trackpants')),
variants(size,color,n) AS (VALUES('S','Navy',1),('M','Navy',2),('L','Navy',3),('XL','Navy',4),('S','Cream',5),('M','Cream',6),('L','Cream',7),('XL','Cream',8))
INSERT INTO product_variants(product_id,sku,size,color,stock_on_hand)
SELECT a.id,'IITD-'||upper(substr(a.slug,1,3))||'-'||lpad(v.n::text,2,'0'),v.size,v.color,8-v.n/2 FROM apparel a CROSS JOIN variants v ON CONFLICT DO NOTHING;

INSERT INTO product_variants(product_id,sku,size,color,stock_on_hand)
SELECT id,'IITD-'||upper(substr(slug,1,3))||'-01','One Size','Campus Edition',24 FROM products WHERE slug NOT IN('core-memory-hoodie','main-building-tee','workshop-socks','lecture-hall-trackpants') ON CONFLICT DO NOTHING;

INSERT INTO product_customization_options(product_id,enabled,field_label,max_characters,placements,styles,text_colors,surcharge,added_fulfilment_days)
SELECT id,TRUE,'Name or nickname',16,'["Front chest","Back","Sleeve"]','["Campus Block","Notebook Script"]','["White","Red","Cobalt"]',14900,2 FROM products WHERE customizable ON CONFLICT(product_id) DO NOTHING;

INSERT INTO coupons(code,type,value,min_order,usage_limit,per_customer_limit) VALUES('IITD10','percentage',10,99900,500,1),('FREESHIP','free_shipping',0,49900,250,1) ON CONFLICT DO NOTHING;
