-- The MSG91 widget flow runs entirely server-side, so the send call returns a reqId that the
-- later verify call has to quote. Store it against the challenge rather than in the browser,
-- which is what keeps the widget token and the authkey off the client entirely.
ALTER TABLE otp_challenges
  ADD COLUMN IF NOT EXISTS provider_ref TEXT;
