/*
  # Fix holes_range column to allow NULL

  1. Changes
    - Drop existing CHECK constraint
    - Modify holes_range to allow NULL values
    - Add new CHECK constraint that allows NULL, '1-9', or '10-18'
    - Set default to NULL
    - Update existing 18-hole rounds to have NULL holes_range
  
  2. Notes
    - holes_range should only have a value when playing 9 holes on an 18-hole course
    - For 18-hole rounds or 9-hole rounds on a 9-hole course, it should be NULL
    - This allows Costa Azahar (9 physical holes) to properly duplicate holes for 18-hole rounds
*/

-- Drop the old constraint if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'golf_rounds_holes_range_check'
  ) THEN
    ALTER TABLE golf_rounds DROP CONSTRAINT golf_rounds_holes_range_check;
  END IF;
END $$;

-- Modify the column to allow NULL and change default
ALTER TABLE golf_rounds 
  ALTER COLUMN holes_range DROP DEFAULT,
  ALTER COLUMN holes_range DROP NOT NULL;

-- Add new CHECK constraint that allows NULL
ALTER TABLE golf_rounds 
  ADD CONSTRAINT golf_rounds_holes_range_check 
  CHECK (holes_range IS NULL OR holes_range IN ('1-9', '10-18'));

-- Set default to NULL
ALTER TABLE golf_rounds 
  ALTER COLUMN holes_range SET DEFAULT NULL;

-- Update existing 18-hole rounds to have NULL holes_range
UPDATE golf_rounds 
SET holes_range = NULL 
WHERE num_holes = 18;