/*
  # Add completed_at column to golf_rounds table

  1. Changes
    - Add `completed_at` column to `golf_rounds` table to track when rounds are completed
    - This column is nullable because existing rounds don't have completion timestamps
    
  2. Notes
    - Fixes error: "Could not find the 'completed_at' column of 'golf_rounds'"
    - Column is timestamptz to match created_at and updated_at
*/

-- Add completed_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'completed_at'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN completed_at timestamptz;
  END IF;
END $$;
