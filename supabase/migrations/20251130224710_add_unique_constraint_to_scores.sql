/*
  # Add unique constraint to round_scores

  1. Changes
    - Add unique constraint on (round_id, player_id, hole_number)
    - This allows upsert operations to work correctly
    - Ensures a player can only have one score per hole per round

  2. Security
    - No changes to RLS policies
*/

-- Add unique constraint to allow upsert operations
ALTER TABLE round_scores 
ADD CONSTRAINT round_scores_unique_score 
UNIQUE (round_id, player_id, hole_number);
