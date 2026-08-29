/*
  # Fix Player Stats - Use Net Strokes for Hole Results

  1. Changes
    - Recalculate hole_results in player_stats for archived rounds
    - Use net_strokes instead of gross_strokes for all calculations
    - Eagles: net_strokes <= par - 2
    - Birdies: net_strokes = par - 1
    - Pars: net_strokes = par
    - Bogeys: net_strokes = par + 1
    - Double Bogeys: net_strokes = par + 2
    - Triple Bogey+: net_strokes >= par + 3
    
  2. Security
    - No RLS changes
*/

-- Update player_stats for all archived rounds to use net_strokes
DO $$
DECLARE
  round_record RECORD;
  player_record RECORD;
  new_player_stats jsonb := '[]'::jsonb;
  player_stat jsonb;
  eagles_count int;
  birdies_count int;
  pars_count int;
  bogeys_count int;
  double_bogeys_count int;
  triple_bogey_plus_count int;
BEGIN
  -- Loop through all archived rounds
  FOR round_record IN 
    SELECT id, hole_scores, player_stats
    FROM archived_rounds
  LOOP
    new_player_stats := '[]'::jsonb;
    
    -- Loop through each player in the round
    FOR player_stat IN 
      SELECT * FROM jsonb_array_elements(round_record.player_stats)
    LOOP
      -- Calculate eagles
      SELECT COUNT(*)::int INTO eagles_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int <= (hs->>'par')::int - 2
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Calculate birdies
      SELECT COUNT(*)::int INTO birdies_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int = (hs->>'par')::int - 1
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Calculate pars
      SELECT COUNT(*)::int INTO pars_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int = (hs->>'par')::int
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Calculate bogeys
      SELECT COUNT(*)::int INTO bogeys_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int = (hs->>'par')::int + 1
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Calculate double bogeys
      SELECT COUNT(*)::int INTO double_bogeys_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int = (hs->>'par')::int + 2
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Calculate triple bogey+
      SELECT COUNT(*)::int INTO triple_bogey_plus_count
      FROM jsonb_array_elements(round_record.hole_scores) AS hs
      WHERE hs->>'player_name' = player_stat->>'player_name'
        AND (hs->>'net_strokes')::int >= (hs->>'par')::int + 3
        AND (hs->>'gross_strokes')::int > 0
        AND COALESCE((hs->>'abandoned')::boolean, false) = false;
      
      -- Update hole_results for this player
      player_stat := jsonb_set(
        player_stat,
        '{hole_results}',
        jsonb_build_object(
          'eagles', eagles_count,
          'birdies', birdies_count,
          'pars', pars_count,
          'bogeys', bogeys_count,
          'double_bogeys', double_bogeys_count,
          'triple_bogey_plus', triple_bogey_plus_count
        )
      );
      
      new_player_stats := new_player_stats || player_stat;
    END LOOP;
    
    -- Update the round with new player_stats
    UPDATE archived_rounds
    SET player_stats = new_player_stats
    WHERE id = round_record.id;
  END LOOP;
END $$;