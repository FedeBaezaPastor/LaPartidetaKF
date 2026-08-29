/*
  # Add reference number to rounds

  1. Changes
    - Add `reference_number` column to `golf_rounds` table
    - Create a function to generate sequential reference numbers
    - Create a trigger to automatically assign reference numbers on insert
  
  2. Notes
    - Reference numbers will be auto-generated starting from 1000
    - Format: Simple sequential number (1000, 1001, 1002, etc.)
*/

-- Add reference_number column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'reference_number'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN reference_number INTEGER UNIQUE;
  END IF;
END $$;

-- Create sequence for reference numbers
CREATE SEQUENCE IF NOT EXISTS golf_rounds_reference_seq START WITH 1000;

-- Create function to generate reference number
CREATE OR REPLACE FUNCTION generate_reference_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reference_number IS NULL THEN
    NEW.reference_number := nextval('golf_rounds_reference_seq');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate reference number
DROP TRIGGER IF EXISTS set_reference_number ON golf_rounds;
CREATE TRIGGER set_reference_number
  BEFORE INSERT ON golf_rounds
  FOR EACH ROW
  EXECUTE FUNCTION generate_reference_number();

-- Backfill existing rounds with reference numbers
UPDATE golf_rounds
SET reference_number = nextval('golf_rounds_reference_seq')
WHERE reference_number IS NULL;