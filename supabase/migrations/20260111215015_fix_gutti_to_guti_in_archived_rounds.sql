/*
  # Fix Gutti to Guti in archived rounds

  1. Purpose
    - Update "Gutti" to "Guti" in all archived rounds
    - Ensures historical data matches current player information

  2. Changes
    - Update final_ranking array
    - Update player_stats array
    - Update hole_scores array
*/

-- Update all references to Gutti in group 355d0af9-0a96-4d6d-ab5a-ef1c2b203c76
UPDATE archived_rounds
SET
  -- Update final_ranking
  final_ranking = (
    SELECT jsonb_agg(
      CASE 
        WHEN elem->>'player_name' = 'Gutti'
        THEN jsonb_set(elem, '{player_name}', to_jsonb('Guti'::text))
        ELSE elem
      END
    )
    FROM jsonb_array_elements(final_ranking) elem
  ),
  -- Update player_stats
  player_stats = (
    SELECT jsonb_agg(
      CASE 
        WHEN elem->>'player_name' = 'Gutti'
        THEN jsonb_set(elem, '{player_name}', to_jsonb('Guti'::text))
        ELSE elem
      END
    )
    FROM jsonb_array_elements(player_stats) elem
  ),
  -- Update hole_scores
  hole_scores = (
    SELECT jsonb_agg(
      CASE 
        WHEN elem->>'player_name' = 'Gutti'
        THEN jsonb_set(elem, '{player_name}', to_jsonb('Guti'::text))
        ELSE elem
      END
    )
    FROM jsonb_array_elements(hole_scores) elem
  )
WHERE 
  group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  AND EXISTS (
    SELECT 1 FROM jsonb_array_elements(final_ranking) elem
    WHERE elem->>'player_name' = 'Gutti'
  );