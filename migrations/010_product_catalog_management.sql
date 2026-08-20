DO $$ BEGIN
  CREATE TYPE product_media_type AS ENUM ('image','video');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE product_media
  ADD COLUMN IF NOT EXISTS media_type product_media_type NOT NULL DEFAULT 'image',
  ADD COLUMN IF NOT EXISTS mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
  ADD COLUMN IF NOT EXISTS file_size BIGINT CHECK(file_size IS NULL OR file_size >= 0),
  ADD COLUMN IF NOT EXISTS poster_key TEXT,
  ADD COLUMN IF NOT EXISTS duration_seconds NUMERIC(7,2) CHECK(duration_seconds IS NULL OR duration_seconds >= 0),
  ADD COLUMN IF NOT EXISTS processing_state TEXT NOT NULL DEFAULT 'ready',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS product_media_gallery_idx
  ON product_media(product_id,colorway_id,sort_order)
  WHERE active AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS products_admin_status_idx
  ON products(status,deleted_at,updated_at DESC);
