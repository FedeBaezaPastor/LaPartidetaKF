/*
  # Add automatic player name update trigger

  1. Purpose
    - Automatically update player names in archived rounds when changed in players table
    - Ensures historical data stays in sync with current player information

  2. Changes
    - Create trigger function to update archived_rounds JSONB fields
    - Add trigger on players table for UPDATE operations
    - Updates final_ranking, player_stats, and hole_scores arrays
*/

-- Create function to update player name in archived rounds
CREATE OR REPLACE FUNCTION update_player_name_in_archived_rounds()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if the name actually changed
  IF OLD.name IS DISTINCT FROM NEW.name THEN
    
    -- Update archived_rounds for the player's group
    UPDATE archived_rounds
    SET
      -- Update final_ranking
      final_ranking = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(final_ranking) elem
      ),
      -- Update player_stats
      player_stats = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(player_stats) elem
      ),
      -- Update hole_scores
      hole_scores = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(hole_scores) elem
      )
    WHERE 
      group_id = NEW.group_id
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(final_ranking) elem
        WHERE elem->>'player_id' = NEW.id::text
      );
    
    -- Also update daily_rankings table
    UPDATE daily_rankings
    SET player_name = NEW.name
    WHERE player_id = NEW.id;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on players table
DROP TRIGGER IF EXISTS trigger_update_player_name_in_archived_rounds ON players;

CREATE TRIGGER trigger_update_player_name_in_archived_rounds
  AFTER UPDATE ON players
  FOR EACH ROW
  EXECUTE FUNCTION update_player_name_in_archived_rounds();