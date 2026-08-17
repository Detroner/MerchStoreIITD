INSERT INTO settings(key,value) VALUES
  ('darkPrimary','#ff6b4a'),
  ('darkSecondary','#5f7cff'),
  ('darkAccent','#f5ce3e'),
  ('darkBackground','#17171d'),
  ('darkInk','#f4eddf')
ON CONFLICT(key) DO NOTHING;
