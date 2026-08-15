ALTER TABLE addresses
  ALTER COLUMN label SET DEFAULT 'Home';

UPDATE addresses
SET label=COALESCE(NULLIF(BTRIM(label),''),'Home'),
    line_2=NULLIF(BTRIM(line_2),''),
    updated_at=now();
