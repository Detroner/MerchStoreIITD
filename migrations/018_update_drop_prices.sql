-- Update the current drop prices while preserving the original prices as strike-through compare prices.
UPDATE products
SET base_price=59900,
    compare_price=79900,
    updated_at=now()
WHERE slug='iit-delhi-01-jersey';

UPDATE product_variants v
SET price_override=59900,
    updated_at=now()
FROM products p
WHERE p.id=v.product_id
  AND p.slug='iit-delhi-01-jersey';

UPDATE products
SET base_price=69900,
    compare_price=79900,
    updated_at=now()
WHERE slug='dogra-drip';

UPDATE product_variants v
SET price_override=69900,
    updated_at=now()
FROM products p
WHERE p.id=v.product_id
  AND p.slug='dogra-drip';
