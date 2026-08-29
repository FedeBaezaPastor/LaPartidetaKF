/*
  # Add exact_handicap_18 to round_players

  1. Changes
    - Add `exact_handicap_18` column to `round_players` table
      - This will always store the player's handicap for 18 holes (the standard)
      - We'll use this as the source of truth for all handicap calculations
    - Populate existing records by doubling exact_handicap if num_holes was 9
    - Make exact_handicap nullable (we'll phase it out)

  2. Benefits
    - Simplifies all handicap calculations
    - Follows golf standard (handicaps are always for 18 holes)
    - Eliminates confusion when changing between 9 and 18 holes
    - Single source of truth for handicap value
*/

-- Add the new column
ALTER TABLE round_players 
ADD COLUMN IF NOT EXISTS exact_handicap_18 NUMERIC DEFAULT 0;

-- Populate existing records
-- If the round was 9 holes and exact_handicap was set, multiply by 2
-- Otherwise use exact_handicap as-is
UPDATE round_players rp
SET exact_handicap_18 = CASE 
  WHEN gr.num_holes = 9 THEN rp.exact_handicap * 2
  ELSE rp.exact_handicap
END
FROM golf_rounds gr
WHERE rp.round_id = gr.id
AND rp.exact_handicap_18 = 0;