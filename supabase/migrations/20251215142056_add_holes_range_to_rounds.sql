/*
  # Add holes_range to golf_rounds table

  1. Changes
    - Add `holes_range` column to `golf_rounds` table
      - Stores which 9 holes are being played: '1-9' or '10-18'
      - Only relevant for 9-hole rounds
      - Defaults to '1-9' for backward compatibility
    
  2. Notes
    - This field allows players to choose whether to play the front nine (holes 1-9)
      or the back nine (holes 10-18) when playing a 9-hole round
    - For 18-hole rounds, this field will typically be null or ignored
*/

-- Add holes_range column to golf_rounds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'holes_range'
  ) THEN
    ALTER TABLE golf_rounds 
    ADD COLUMN holes_range text DEFAULT '1-9' CHECK (holes_range IN ('1-9', '10-18'));
  END IF;
END $$;