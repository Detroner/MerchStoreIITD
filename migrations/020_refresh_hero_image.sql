-- The hero artwork was replaced at the same path, and /assets is served with a one-day
-- Cache-Control, so returning visitors would keep the previous image until it expired.
-- Version the URL to retire those cached copies immediately.
-- Only the seeded default is rewritten, so a hero image chosen in Studio is left alone.
UPDATE settings
SET value='/assets/merch-hero.png?v=20260919'
WHERE key='heroImage'
  AND value='/assets/merch-hero.png';
