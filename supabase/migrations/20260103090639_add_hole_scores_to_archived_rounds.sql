/*
  # Add Hole Scores to Archived Rounds

  1. Changes
    - Add `hole_scores` column to archived_rounds to store detailed score data
    - This enables calculation of eagles, birdies, pars, bogeys, etc. for player statistics

  2. Structure
    - hole_scores: JSONB array with objects containing:
      - player_name: text
      - hole_number: integer
      - par: integer
      - gross_strokes: integer
      - net_strokes: integer
      - stableford_points: integer
      - result: text (eagle, birdie, par, bogey, double_bogey, triple_bogey_plus)

  3. Notes
    - This is for future rounds - existing rounds won't have this detailed data
    - Enables full Phase 1 statistics calculations
*/

-- Add hole_scores column to archived_rounds
ALTER TABLE archived_rounds
ADD COLUMN IF NOT EXISTS hole_scores jsonb DEFAULT '[]'::jsonb;