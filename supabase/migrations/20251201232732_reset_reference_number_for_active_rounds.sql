/*
  # Reset reference number logic for active rounds

  1. Changes
    - Remove the sequence-based reference number
    - Add a function to calculate the next reference number based on active rounds only
    - Update the trigger to use this new function
  
  2. Notes
    - Reference numbers now start from 1 each time all active rounds are deleted
    - Reference numbers are based on active rounds count, not all-time rounds
*/

-- Drop the existing sequence
DROP SEQUENCE IF EXISTS golf_rounds_reference_seq CASCADE;

-- Create a function to get the next reference number based on active rounds
CREATE OR REPLACE FUNCTION get_next_reference_number()
RETURNS INTEGER AS $$
BEGIN
  RETURN COALESCE((SELECT MAX(reference_number) FROM golf_rounds WHERE status = 'active'), 0) + 1;
END;
$$ LANGUAGE plpgsql;

-- Update the trigger function to use the new logic
CREATE OR REPLACE FUNCTION set_reference_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reference_number IS NULL THEN
    NEW.reference_number := get_next_reference_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger (drop if exists first)
DROP TRIGGER IF EXISTS set_reference_number_trigger ON golf_rounds;

CREATE TRIGGER set_reference_number_trigger
BEFORE INSERT ON golf_rounds
FOR EACH ROW
EXECUTE FUNCTION set_reference_number();