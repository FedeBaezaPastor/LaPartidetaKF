/*
  # Fix null values in archived rounds arrays

  1. Problem
    - Some hole_scores arrays contain null values causing frontend crashes
    - The trigger function may have introduced nulls during updates

  2. Changes
    - Clean up existing null values in all archived_rounds JSONB arrays
    - Update trigger function to filter out nulls properly
*/

-- First, clean up existing nulls in archived_rounds
UPDATE archived_rounds
SET 
  final_ranking = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(final_ranking) elem
    WHERE elem IS NOT NULL
  ),
  player_stats = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(player_stats) elem
    WHERE elem IS NOT NULL
  ),
  hole_scores = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(hole_scores) elem
    WHERE elem IS NOT NULL
  )
WHERE 
  EXISTS (
    SELECT 1 FROM jsonb_array_elements(hole_scores) elem WHERE elem IS NULL
  )
  OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(final_ranking) elem WHERE elem IS NULL
  )
  OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(player_stats) elem WHERE elem IS NULL
  );

-- Update the trigger function to filter nulls
CREATE OR REPLACE FUNCTION update_player_name_in_archived_rounds()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if the name actually changed
  IF OLD.name IS DISTINCT FROM NEW.name THEN
    
    -- Update archived_rounds for the player's group
    UPDATE archived_rounds
    SET
      -- Update final_ranking (filter out nulls)
      final_ranking = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(final_ranking) elem
        WHERE elem IS NOT NULL
      ),
      -- Update player_stats (filter out nulls)
      player_stats = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(player_stats) elem
        WHERE elem IS NOT NULL
      ),
      -- Update hole_scores (filter out nulls)
      hole_scores = (
        SELECT jsonb_agg(
          CASE 
            WHEN elem->>'player_id' = NEW.id::text
            THEN jsonb_set(elem, '{player_name}', to_jsonb(NEW.name))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(hole_scores) elem
        WHERE elem IS NOT NULL
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