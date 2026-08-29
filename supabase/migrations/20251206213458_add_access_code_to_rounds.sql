/*
  # Add Access Code to Rounds

  1. Changes
    - Add `access_code` column to `golf_rounds` table
      - Type: text (6 character alphanumeric code)
      - Not nullable with default random generation
      - Unique to ensure no duplicate codes
    
  2. Purpose
    - Enable secure access control for rounds
    - Allow players to join/edit only rounds they have the code for
    - Keep leaderboards public while protecting score entry

  3. Implementation Details
    - Uses random 6-character uppercase alphanumeric codes (A-Z, 0-9)
    - Generated automatically on insert via trigger
    - Indexed for fast lookup
*/

-- Add access_code column to golf_rounds table
ALTER TABLE golf_rounds 
ADD COLUMN IF NOT EXISTS access_code text;

-- Create function to generate random access code
CREATE OR REPLACE FUNCTION generate_access_code()
RETURNS text AS $$
DECLARE
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude similar chars like I,1,O,0
  result text := '';
  i integer;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate access code on insert
CREATE OR REPLACE FUNCTION set_access_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.access_code IS NULL THEN
    NEW.access_code := generate_access_code();
    -- Ensure uniqueness by checking if code already exists
    WHILE EXISTS (SELECT 1 FROM golf_rounds WHERE access_code = NEW.access_code) LOOP
      NEW.access_code := generate_access_code();
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and create new one
DROP TRIGGER IF EXISTS set_access_code_trigger ON golf_rounds;
CREATE TRIGGER set_access_code_trigger
  BEFORE INSERT ON golf_rounds
  FOR EACH ROW
  EXECUTE FUNCTION set_access_code();

-- Update existing rounds with access codes
DO $$
DECLARE
  round_record RECORD;
  new_code text;
BEGIN
  FOR round_record IN SELECT id FROM golf_rounds WHERE access_code IS NULL LOOP
    new_code := generate_access_code();
    -- Ensure uniqueness
    WHILE EXISTS (SELECT 1 FROM golf_rounds WHERE access_code = new_code) LOOP
      new_code := generate_access_code();
    END LOOP;
    UPDATE golf_rounds SET access_code = new_code WHERE id = round_record.id;
  END LOOP;
END $$;

-- Make access_code NOT NULL after populating existing records
ALTER TABLE golf_rounds 
ALTER COLUMN access_code SET NOT NULL;

-- Add unique constraint
ALTER TABLE golf_rounds 
ADD CONSTRAINT golf_rounds_access_code_unique UNIQUE (access_code);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_golf_rounds_access_code ON golf_rounds(access_code);