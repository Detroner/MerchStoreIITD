-- Preserve product/colourway IDs, inventory quantities and existing order history.
UPDATE product_variants SET active=FALSE
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt') AND size='XS';

UPDATE product_colorways SET name='Violet',slug='violet',swatch_hex='#b58ab5',sort_order=1
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt')
  AND slug IN ('lavendar','lavender')
  AND NOT EXISTS (SELECT 1 FROM product_colorways other WHERE other.product_id=product_colorways.product_id AND other.slug='violet');
UPDATE product_variants v SET color=c.name FROM product_colorways c
WHERE v.colorway_id=c.id AND c.slug='violet'
  AND c.product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt');

UPDATE product_customization_options SET max_characters=50,
  allowed_pattern=$pattern$^[A-Za-z0-9 ._-]{1,16}(?:\n[A-Za-z0-9 ._-]{1,16}){0,2}$$pattern$,
  field_label='Your text · middle back · up to 3 lines',updated_at=now()
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt');

UPDATE product_media SET storage_key='/assets/winter/sweatshirt-violet-back.png',
  alt_text='Violet Sweatshirt back — personalize your name',mime_type='image/png',file_size=NULL
WHERE product_id IN (SELECT id FROM products WHERE slug='winter-sweatshirt')
  AND storage_key='/media/82a1b7d1-828a-49cc-b1f2-d70e2d3bf242.jpg';

UPDATE products SET description='An IIT Delhi crewneck in Black or Violet, finished with up to three lines of white Allison lettering at the middle back. Part of the Winter Collection.',
  features='["Winter Collection / Drop 02","Black or Violet crewneck","Up to 3 personalized lines at the middle back","White Allison lettering","Personalization included"]'
WHERE slug='winter-sweatshirt';
