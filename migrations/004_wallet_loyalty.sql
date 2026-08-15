ALTER TABLE products
  ADD COLUMN IF NOT EXISTS wallet_reward_percent NUMERIC(5,2) NOT NULL DEFAULT 5.00;

ALTER TABLE products
  DROP CONSTRAINT IF EXISTS products_wallet_reward_percent_check;

ALTER TABLE products
  ADD CONSTRAINT products_wallet_reward_percent_check
  CHECK (wallet_reward_percent >= 0 AND wallet_reward_percent <= 100);

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS wallet_applied BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS wallet_reward BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS wallet_accounts(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users ON DELETE CASCADE,
  balance BIGINT NOT NULL DEFAULT 0 CHECK(balance >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS wallet_ledger_entries(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_account_id UUID NOT NULL REFERENCES wallet_accounts ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users ON DELETE CASCADE,
  order_id UUID REFERENCES orders ON DELETE SET NULL,
  entry_type TEXT NOT NULL CHECK(entry_type IN ('reward','redemption','adjustment','refund','expiry')),
  amount BIGINT NOT NULL CHECK(amount <> 0),
  balance_after BIGINT NOT NULL CHECK(balance_after >= 0),
  description TEXT NOT NULL DEFAULT '',
  idempotency_key TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS wallet_ledger_user_created_idx
  ON wallet_ledger_entries(user_id,created_at DESC);

CREATE INDEX IF NOT EXISTS wallet_ledger_order_idx
  ON wallet_ledger_entries(order_id);

INSERT INTO wallet_accounts(user_id)
SELECT id FROM users
ON CONFLICT(user_id) DO NOTHING;
