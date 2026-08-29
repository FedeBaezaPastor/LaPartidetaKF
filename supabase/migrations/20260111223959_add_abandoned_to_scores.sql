/*
  # Add abandoned field to scores

  1. Changes
    - Add `abandoned` column to `round_scores` table
      - Type: boolean
      - Default: false
      - Tracks when a player has abandoned the round (only for quick play)
  
  2. Notes
    - This field is used only in quick play (partideta rápida)
    - When a player is marked as abandoned, their scores won't count toward totals
    - The scorecard will show a dash (-) instead of their score
*/

-- Add abandoned column to round_scores
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'round_scores' 
    AND column_name = 'abandoned'
  ) THEN
    ALTER TABLE round_scores ADD COLUMN abandoned boolean NOT NULL DEFAULT false;
  END IF;
END $$;