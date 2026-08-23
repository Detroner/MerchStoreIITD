INSERT INTO settings(key,value) VALUES
  ('darkStoryCopy','#bcd4ff'),
  ('darkKineticBackground','#222a4a')
ON CONFLICT(key) DO NOTHING;
