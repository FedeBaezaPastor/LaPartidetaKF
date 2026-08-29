/*
  # Add "no ha pasado de rojas" field to scores

  1. Changes
    - Add `no_paso_rojas` column to `round_scores` table
      - Type: boolean
      - Default: false
      - Tracks when a player didn't pass the red tees on a hole
  
  2. Notes
    - This field helps track when players fail to get past the red tees
    - Used for displaying statistics in the scorecard summary
*/

-- Add no_paso_rojas column to round_scores
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'round_scores' 
    AND column_name = 'no_paso_rojas'
  ) THEN
    ALTER TABLE round_scores ADD COLUMN no_paso_rojas boolean NOT NULL DEFAULT false;
  END IF;
END $$;
