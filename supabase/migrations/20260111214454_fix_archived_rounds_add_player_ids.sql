/*
  # Fix archived rounds to include player_id in hole_scores

  1. Purpose
    - Add player_id to hole_scores array in existing archived rounds
    - Match player names to player IDs from the players table
    - Enable player name updates to work correctly with historical data

  2. Changes
    - Update all archived_rounds records
    - Add player_id field to each element in hole_scores JSONB array
    - Match by player_name and group_id to find correct player_id
*/

-- Update hole_scores to include player_id
UPDATE archived_rounds ar
SET hole_scores = (
  SELECT jsonb_agg(
    CASE 
      WHEN elem ? 'player_id' THEN elem
      ELSE (
        SELECT jsonb_set(
          elem, 
          '{player_id}', 
          to_jsonb(p.id::text)
        )
        FROM players p
        WHERE p.name = elem->>'player_name'
          AND p.group_id = ar.group_id
        LIMIT 1
      )
    END
  )
  FROM jsonb_array_elements(ar.hole_scores) elem
)
WHERE EXISTS (
  SELECT 1 
  FROM jsonb_array_elements(ar.hole_scores) elem
  WHERE NOT (elem ? 'player_id')
);