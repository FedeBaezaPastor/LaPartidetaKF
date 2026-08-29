/*
  # Fix reference number race condition

  1. Problem
    - The current `get_next_reference_number()` function has a race condition
    - Multiple simultaneous round creations can get the same reference number
    - This causes duplicate key violations
  
  2. Solution
    - Use PostgreSQL sequence which is thread-safe and atomic
    - Sequence automatically handles concurrent requests
    - Keep reference numbers sequential and avoid duplicates
  
  3. Changes
    - Create a sequence for reference numbers starting at 1
    - Update trigger function to use sequence instead of MAX() query
    - Sequence will be automatically incremented on each insert
*/

-- Create sequence for reference numbers
CREATE SEQUENCE IF NOT EXISTS golf_rounds_reference_seq START WITH 1;

-- Set the sequence to the next available number based on existing rounds
SELECT setval('golf_rounds_reference_seq', COALESCE((SELECT MAX(reference_number) FROM golf_rounds WHERE status = 'active'), 0) + 1, false);

-- Drop the old function that had the race condition
DROP FUNCTION IF EXISTS get_next_reference_number();

-- Update the trigger function to use the sequence
CREATE OR REPLACE FUNCTION set_reference_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reference_number IS NULL THEN
    NEW.reference_number := nextval('golf_rounds_reference_seq');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure the trigger exists (recreate if needed)
DROP TRIGGER IF EXISTS set_reference_number_trigger ON golf_rounds;

CREATE TRIGGER set_reference_number_trigger
BEFORE INSERT ON golf_rounds
FOR EACH ROW
EXECUTE FUNCTION set_reference_number();