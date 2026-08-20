CREATE TYPE vendor_batch_status AS ENUM ('draft','sent','acknowledged','in_production','ready','completed','adjustment_required','cancelled');

CREATE TABLE product_colorways(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  swatch_hex TEXT NOT NULL DEFAULT '#17171d',
  card_color TEXT NOT NULL DEFAULT '#163ea8',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  show_in_catalog BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(product_id,name),
  UNIQUE(product_id,slug)
);

ALTER TABLE product_variants ADD COLUMN colorway_id UUID REFERENCES product_colorways;
ALTER TABLE product_media ADD COLUMN colorway_id UUID REFERENCES product_colorways ON DELETE CASCADE;

INSERT INTO product_colorways(product_id,name,slug,swatch_hex,card_color,sort_order)
SELECT DISTINCT v.product_id,v.color,
  trim(both '-' FROM regexp_replace(lower(v.color),'[^a-z0-9]+','-','g')),
  CASE lower(v.color)
    WHEN 'black' THEN '#17171d' WHEN 'white' THEN '#f7f4ea'
    WHEN 'navy' THEN '#16305c' WHEN 'cream' THEN '#eee2c8'
    WHEN 'red' THEN '#ed3b24' ELSE p.card_color END,
  p.card_color,
  dense_rank() OVER(PARTITION BY v.product_id ORDER BY v.color)
FROM product_variants v JOIN products p ON p.id=v.product_id
ON CONFLICT(product_id,name) DO NOTHING;

UPDATE product_variants v SET colorway_id=c.id
FROM product_colorways c WHERE c.product_id=v.product_id AND c.name=v.color;
ALTER TABLE product_variants ALTER COLUMN colorway_id SET NOT NULL;

CREATE TABLE order_status_history(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders ON DELETE CASCADE,
  field_name TEXT NOT NULL CHECK(field_name IN('order_status','payment_status','fulfilment_status')),
  previous_value TEXT NOT NULL,
  next_value TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  actor_type TEXT NOT NULL DEFAULT 'admin',
  actor_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_internal_notes(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders ON DELETE CASCADE,
  note TEXT NOT NULL CHECK(length(note) BETWEEN 1 AND 1000),
  actor_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vendor_profiles(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  contact_label TEXT NOT NULL DEFAULT '',
  channel TEXT NOT NULL DEFAULT 'manual' CHECK(channel IN('manual','whatsapp','email')),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  lead_time_days INTEGER NOT NULL DEFAULT 7 CHECK(lead_time_days BETWEEN 0 AND 90),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO vendor_profiles(name,contact_label) VALUES('Primary production vendor','Production desk') ON CONFLICT(name) DO NOTHING;

CREATE TABLE vendor_batches(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_no TEXT UNIQUE NOT NULL,
  vendor_id UUID REFERENCES vendor_profiles,
  status vendor_batch_status NOT NULL DEFAULT 'draft',
  filter_snapshot JSONB NOT NULL DEFAULT '{}',
  cutoff_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  requested_ready_at TIMESTAMPTZ,
  promised_ready_at TIMESTAMPTZ,
  vendor_note TEXT NOT NULL DEFAULT '',
  internal_note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0),
  checksum TEXT NOT NULL,
  idempotency_key TEXT UNIQUE NOT NULL,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vendor_batch_items(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES vendor_batches ON DELETE CASCADE,
  order_item_id UUID NOT NULL REFERENCES order_items,
  product_id UUID,
  variant_id UUID,
  product_name TEXT NOT NULL,
  sku TEXT NOT NULL,
  color TEXT NOT NULL,
  size TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK(quantity>0),
  customization_snapshot JSONB,
  production_status TEXT NOT NULL DEFAULT 'pending' CHECK(production_status IN('pending','approved','in_production','ready','completed','blocked','cancelled')),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(batch_id,order_item_id)
);

CREATE UNIQUE INDEX vendor_batch_items_active_order_idx ON vendor_batch_items(order_item_id) WHERE active;

CREATE TABLE vendor_batch_events(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES vendor_batches ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  detail JSONB NOT NULL DEFAULT '{}',
  actor_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX colorways_catalog_idx ON product_colorways(product_id,sort_order) WHERE active AND show_in_catalog;
CREATE INDEX variants_colorway_size_idx ON product_variants(colorway_id,size,active);
CREATE INDEX orders_ops_idx ON orders(payment_status,fulfilment_status,order_status,created_at DESC);
CREATE INDEX order_items_ops_idx ON order_items(product_id,color,size,created_at DESC);
CREATE INDEX customizations_production_idx ON order_item_customizations(production_status,moderation_status,created_at);
CREATE INDEX vendor_batches_status_idx ON vendor_batches(status,created_at DESC);
CREATE INDEX vendor_batch_items_status_idx ON vendor_batch_items(batch_id,production_status);
