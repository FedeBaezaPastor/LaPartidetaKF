/*
  # Update Access Code to 4 Digits

  1. Changes
    - Update `generate_access_code` function to generate 4-digit codes instead of 6 characters
    - Use only numbers (0-9) for simplicity
    
  2. Purpose
    - Make access codes shorter and easier to share
    - Simpler to type on mobile devices
*/

-- Update function to generate 4-digit access code
CREATE OR REPLACE FUNCTION generate_access_code()
RETURNS text AS $$
DECLARE
  chars text := '0123456789';
  result text := '';
  i integer;
BEGIN
  FOR i IN 1..4 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Update existing rounds with new 4-digit codes
DO $$
DECLARE
  round_record RECORD;
  new_code text;
BEGIN
  FOR round_record IN SELECT id FROM golf_rounds LOOP
    new_code := generate_access_code();
    -- Ensure uniqueness
    WHILE EXISTS (SELECT 1 FROM golf_rounds WHERE access_code = new_code AND id != round_record.id) LOOP
      new_code := generate_access_code();
    END LOOP;
    UPDATE golf_rounds SET access_code = new_code WHERE id = round_record.id;
  END LOOP;
END $$;