/*
  # Add exact_handicap_18 to players table

  1. Changes
    - Add `exact_handicap_18` column to `players` table
      - This stores the player's handicap for 18 holes (the standard)
      - Used as the source of truth for all handicap calculations
    - Populate existing records with exact_handicap value (assuming they were for 18 holes)

  2. Benefits
    - Consistent with round_players table
    - Allows storing player's standard 18-hole handicap
*/

-- Add the new column to players table
ALTER TABLE players 
ADD COLUMN IF NOT EXISTS exact_handicap_18 NUMERIC DEFAULT 0;

-- Populate existing records (assume existing handicaps are for 18 holes)
UPDATE players
SET exact_handicap_18 = exact_handicap
WHERE exact_handicap_18 = 0;