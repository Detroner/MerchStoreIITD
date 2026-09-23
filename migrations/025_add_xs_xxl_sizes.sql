-- XS and XXL for every product that is already sized S-XL, one row per colour it is sold in.
-- Products sold as 'One Size' are untouched, because the source rows are the existing 'S' variants.
--
-- Stock deliberately starts at zero. The storefront only lists a size whose stock is above zero,
-- so nothing changes for customers until someone enters a real quantity in Studio. Seeding a
-- number here would let people buy garments that may not exist.
--
-- The SKU extends the S variant's own code rather than being rebuilt from the product slug and
-- colour. A rebuilt code could collide for two colours sharing their first letters, and with
-- ON CONFLICT DO NOTHING that collision would silently drop a size instead of failing. Extending
-- a SKU that is already unique cannot collide. Studio can edit stock, price and active, but it
-- cannot rename a SKU, so this is the name the size keeps.
INSERT INTO product_variants(product_id,colorway_id,sku,size,color,stock_on_hand,active)
SELECT s.product_id,
       s.colorway_id,
       s.sku||'-'||n.size,
       n.size,
       s.color,
       0,
       TRUE
FROM product_variants s
CROSS JOIN (VALUES ('XS'),('XXL')) AS n(size)
WHERE s.size='S'
ON CONFLICT DO NOTHING;
