/*
  # Fix Archived Rounds Missing Statistics Data
  
  1. Changes
    - Updates existing archived_rounds to include missing player_stats fields
    - Recalculates player_id, handicap, beers_won, beers_paid, and hole_results for all archived rounds
    - This migration reads from the hole_scores data to reconstruct the missing statistics
  
  2. Notes
    - This is a data migration that fixes historical data
    - Future rounds will be archived with complete data automatically
*/

-- Create a temporary function to recalculate player stats for archived rounds
CREATE OR REPLACE FUNCTION recalculate_archived_player_stats()
RETURNS void AS $$
DECLARE
  round_record RECORD;
  player_stat RECORD;
  new_player_stats jsonb;
  player_hole_scores jsonb;
  eagles_count int;
  birdies_count int;
  bogeys_count int;
  double_bogeys_count int;
  total_players int;
  receiver_count int;
  payer_start int;
  player_position int;
  beers_won int;
  beers_paid int;
  found_player_id uuid;
  found_handicap numeric;
BEGIN
  -- Loop through all archived rounds
  FOR round_record IN 
    SELECT id, player_stats, hole_scores, final_ranking
    FROM archived_rounds
  LOOP
    new_player_stats := '[]'::jsonb;
    total_players := jsonb_array_length(round_record.final_ranking);
    receiver_count := FLOOR(total_players / 2.0)::int;
    
    IF total_players % 2 = 0 THEN
      payer_start := receiver_count + 1;
    ELSE
      payer_start := receiver_count + 2;
    END IF;
    
    -- Loop through each player in player_stats
    FOR player_stat IN 
      SELECT 
        value->>'player_name' as player_name,
        (value->>'no_paso_rojas_count')::int as no_paso_rojas_count,
        (value->>'total_holes_played')::int as total_holes_played
      FROM jsonb_array_elements(round_record.player_stats)
    LOOP
      -- Get player position from final_ranking
      SELECT (value->>'position')::int INTO player_position
      FROM jsonb_array_elements(round_record.final_ranking)
      WHERE value->>'player_name' = player_stat.player_name
      LIMIT 1;
      
      -- Calculate beers
      IF player_position <= receiver_count THEN
        beers_won := 1;
        beers_paid := 0;
      ELSIF player_position >= payer_start THEN
        beers_won := 0;
        beers_paid := 1;
      ELSE
        beers_won := 0;
        beers_paid := 0;
      END IF;
      
      -- Get player_id and handicap from final_ranking
      SELECT 
        (value->>'player_id')::uuid,
        (value->>'handicap')::numeric
      INTO found_player_id, found_handicap
      FROM jsonb_array_elements(round_record.final_ranking)
      WHERE value->>'player_name' = player_stat.player_name
      LIMIT 1;
      
      -- If player_id or handicap is null, try to get from players table
      IF found_player_id IS NULL THEN
        SELECT id, exact_handicap INTO found_player_id, found_handicap
        FROM players
        WHERE name = player_stat.player_name
        LIMIT 1;
      END IF;
      
      -- Calculate hole results from hole_scores
      SELECT 
        COUNT(*) FILTER (WHERE (hs.value->>'result')::text = 'eagle') as eagles,
        COUNT(*) FILTER (WHERE (hs.value->>'result')::text = 'birdie') as birdies,
        COUNT(*) FILTER (WHERE (hs.value->>'result')::text = 'bogey') as bogeys,
        COUNT(*) FILTER (WHERE (hs.value->>'result')::text = 'double_bogey') as double_bogeys
      INTO eagles_count, birdies_count, bogeys_count, double_bogeys_count
      FROM jsonb_array_elements(round_record.hole_scores) as hs
      WHERE hs.value->>'player_name' = player_stat.player_name;
      
      -- Build new player stat entry with all fields
      new_player_stats := new_player_stats || jsonb_build_object(
        'player_name', player_stat.player_name,
        'player_id', found_player_id,
        'handicap', COALESCE(found_handicap, 0),
        'no_paso_rojas_count', player_stat.no_paso_rojas_count,
        'total_holes_played', player_stat.total_holes_played,
        'beers_won', beers_won,
        'beers_paid', beers_paid,
        'hole_results', jsonb_build_object(
          'eagles', COALESCE(eagles_count, 0),
          'birdies', COALESCE(birdies_count, 0),
          'bogeys', COALESCE(bogeys_count, 0),
          'double_bogeys', COALESCE(double_bogeys_count, 0)
        )
      );
    END LOOP;
    
    -- Update the archived round with new player_stats
    UPDATE archived_rounds
    SET player_stats = new_player_stats
    WHERE id = round_record.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the function to recalculate all stats
SELECT recalculate_archived_player_stats();

-- Drop the temporary function
DROP FUNCTION recalculate_archived_player_stats();
