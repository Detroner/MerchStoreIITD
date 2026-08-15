UPDATE product_customization_options
SET placements='["Front"]'::jsonb,
    updated_at=now();
