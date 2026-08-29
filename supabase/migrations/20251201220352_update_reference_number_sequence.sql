/*
  # Update reference number sequence to start from 1

  1. Changes
    - Drop existing sequence and recreate starting from 1
    - Reset existing reference numbers to start from 1
  
  2. Notes
    - Reference numbers will now be 1, 2, 3, etc.
*/

-- Drop existing sequence
DROP SEQUENCE IF EXISTS golf_rounds_reference_seq CASCADE;

-- Create new sequence starting from 1
CREATE SEQUENCE golf_rounds_reference_seq START WITH 1;

-- Reset reference numbers for existing rounds
DO $$
DECLARE
  round_record RECORD;
  counter INTEGER := 1;
BEGIN
  FOR round_record IN 
    SELECT id FROM golf_rounds ORDER BY created_at ASC
  LOOP
    UPDATE golf_rounds 
    SET reference_number = counter 
    WHERE id = round_record.id;
    counter := counter + 1;
  END LOOP;
END $$;

-- Reset sequence to continue from the last assigned number
SELECT setval('golf_rounds_reference_seq', COALESCE((SELECT MAX(reference_number) FROM golf_rounds), 0) + 1, false);