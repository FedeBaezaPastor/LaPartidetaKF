/*
  # Update player name in archived rounds
  
  1. New Function
    - `update_player_name_in_archived_rounds(player_id_param uuid, new_name_param text)`
      - Updates player name in all archived rounds
      - Updates name in final_ranking JSONB array
      - Updates name in player_stats JSONB array
      - Updates name in hole_scores JSONB array
      - Returns the old name and count of updated records
  
  2. Purpose
    - Ensures player name consistency across all historical data
    - Prevents duplicate player entries in statistics
    - Maintains data integrity when renaming players
*/

CREATE OR REPLACE FUNCTION update_player_name_in_archived_rounds(
  player_id_param uuid,
  new_name_param text
)
RETURNS TABLE(old_name text, updated_count integer) AS $$
DECLARE
  old_player_name text;
  updated_records integer := 0;
BEGIN
  -- Get the current name from the players table
  SELECT name INTO old_player_name
  FROM players
  WHERE id = player_id_param;
  
  IF old_player_name IS NULL THEN
    RAISE EXCEPTION 'Player with id % not found', player_id_param;
  END IF;
  
  -- Update all archived_rounds where this player appears
  WITH updated AS (
    UPDATE archived_rounds
    SET
      -- Update final_ranking JSONB array
      final_ranking = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = player_id_param::text 
            THEN jsonb_set(elem, '{player_name}', to_jsonb(new_name_param))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(final_ranking) elem
      ),
      -- Update player_stats JSONB array
      player_stats = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = player_id_param::text 
            THEN jsonb_set(elem, '{player_name}', to_jsonb(new_name_param))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(player_stats) elem
      ),
      -- Update hole_scores JSONB array
      hole_scores = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = player_id_param::text 
            THEN jsonb_set(elem, '{player_name}', to_jsonb(new_name_param))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(hole_scores) elem
      ),
      updated_at = now()
    WHERE 
      -- Only update records where the player appears
      EXISTS (
        SELECT 1 FROM jsonb_array_elements(final_ranking) elem
        WHERE elem->>'player_id' = player_id_param::text
      )
    RETURNING 1
  )
  SELECT COUNT(*)::integer INTO updated_records FROM updated;
  
  RETURN QUERY SELECT old_player_name, updated_records;
END;
$$ LANGUAGE plpgsql;