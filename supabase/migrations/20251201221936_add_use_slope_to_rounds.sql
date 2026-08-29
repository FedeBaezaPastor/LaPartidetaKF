/*
  # Add use_slope flag to golf rounds

  1. Changes
    - Add `use_slope` boolean column to `golf_rounds` table
    - Default to true to maintain existing behavior
  
  2. Notes
    - When use_slope is true, playing handicap is calculated with slope (current behavior)
    - When use_slope is false, playing handicap equals exact handicap
*/

-- Add use_slope column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'use_slope'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN use_slope BOOLEAN DEFAULT true NOT NULL;
  END IF;
END $$;