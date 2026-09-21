ALTER TABLE coupons ADD COLUMN max_discount BIGINT CHECK (max_discount IS NULL OR max_discount > 0);
ALTER TABLE coupons ADD COLUMN deleted_at TIMESTAMPTZ;
