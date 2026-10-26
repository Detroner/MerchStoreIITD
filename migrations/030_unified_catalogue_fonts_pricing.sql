-- One current selling price across all Dogra colour/size variants; past orders are immutable.
UPDATE products SET base_price=69900,updated_at=now() WHERE slug='dogra-drip';
UPDATE product_variants v SET price_override=NULL,updated_at=now() FROM products p WHERE p.id=v.product_id AND p.slug='dogra-drip';

UPDATE product_customization_options o
SET styles='["Allison","Story Script","Erica One","Kavoon","Jim Nightshade"]'::jsonb,updated_at=now()
FROM products p WHERE p.id=o.product_id AND p.slug='winter-sweatshirt';

-- Update catalogue copy only; keep customer order snapshots, images and stock intact.
UPDATE products SET description='An IIT Delhi crewneck in Black or Lavender, finished with up to three lines of white lettering in your chosen font at the middle back.',
 short_description='Your campus. Your words. Your font.',
 features='["The IIT Delhi Drop","Black or Lavender crewneck","Up to 3 personalized lines at the middle back","Five lettering styles","Personalization included"]'::jsonb,
 updated_at=now() WHERE slug='winter-sweatshirt';
INSERT INTO settings(key,value) VALUES('marqueeText','BIG IDEAS ✦ GOOD THREADS ✦ CAMPUS CULTURE ✦ BUILT TO WANDER') ON CONFLICT(key) DO NOTHING;
