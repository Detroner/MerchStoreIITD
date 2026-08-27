-- Add hostel-only delivery settings while keeping legacy address rows readable.
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS hostel_id UUID REFERENCES hostels;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS room_number TEXT;
CREATE INDEX IF NOT EXISTS addresses_hostel_lookup_idx ON addresses(user_id,hostel_id,room_number);
