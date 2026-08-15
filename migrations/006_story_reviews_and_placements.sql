INSERT INTO settings(key,value) VALUES
  ('storyEyebrow','OUR STORY'),
  ('storyHero','Made of red brick & big ideas.'),
  ('storyLead','The IIT Delhi Drop is campus energy, made wearable.'),
  ('storyMottoLabel','THE MOTTO'),
  ('storyMotto',E'THINK\nLOUD.'),
  ('storyClosing','Designed on campus. Worn everywhere.'),
  ('storyImage','/assets/merch-hero.png'),
  ('storyCta','EXPLORE THE DROP')
ON CONFLICT(key) DO NOTHING;

UPDATE products p
SET rating_average=COALESCE((SELECT ROUND(AVG(r.rating)::numeric,2) FROM reviews r WHERE r.product_id=p.id AND r.status='approved'),0),
    approved_review_count=COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.product_id=p.id AND r.status='approved'),0),
    updated_at=now();

UPDATE product_customization_options
SET placements=CASE
  WHEN placements ? 'Front' THEN placements
  WHEN placements ? 'Front chest' THEN placements - 'Front chest' || '["Front"]'::jsonb
  ELSE '["Front"]'::jsonb
END,
updated_at=now();
