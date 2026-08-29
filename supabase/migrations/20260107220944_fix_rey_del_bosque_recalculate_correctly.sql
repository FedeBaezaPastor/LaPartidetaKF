/*
  # Fix Rey del Bosque - Recalculate Double Bogeys Correctly
  
  1. Changes
    - Properly recalculate double_bogeys in player_stats for all archived rounds
    - Count all scores where net_strokes >= par + 2 (double bogey or worse)
    
  2. Notes
    - Previous migration had issues with jsonb array handling
    - This version uses a cleaner approach
*/

-- Update all existing archived rounds to recalculate double_bogeys
UPDATE archived_rounds ar
SET player_stats = (
  SELECT jsonb_agg(
    CASE 
      WHEN ps->'hole_results' IS NOT NULL THEN
        jsonb_set(
          ps,
          '{hole_results,double_bogeys}',
          to_jsonb((
            SELECT COUNT(*)
            FROM jsonb_array_elements(ar.hole_scores) AS hs
            WHERE (hs->>'player_name') = (ps->>'player_name')
              AND (hs->>'net_strokes')::integer >= (hs->>'par')::integer + 2
          ))
        )
      ELSE ps
    END
  )
  FROM jsonb_array_elements(ar.player_stats) AS ps
)
WHERE player_stats IS NOT NULL;
