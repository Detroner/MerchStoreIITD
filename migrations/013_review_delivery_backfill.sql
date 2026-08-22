UPDATE order_items i
SET delivered_at = COALESCE(i.delivered_at, o.updated_at, now())
FROM orders o
WHERE o.id = i.order_id
  AND o.fulfilment_status = 'delivered'
  AND i.delivered_at IS NULL;

CREATE INDEX IF NOT EXISTS order_items_review_eligibility_idx
  ON order_items(order_id, delivered_at)
  WHERE delivered_at IS NOT NULL;
