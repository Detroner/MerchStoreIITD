ALTER TABLE otp_challenges
  ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'demo';

CREATE INDEX IF NOT EXISTS otp_challenges_provider_idx
  ON otp_challenges(provider, created_at DESC);
