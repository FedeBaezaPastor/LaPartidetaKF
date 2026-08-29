/*
  # Fix Archived Rounds - Use Gross Strokes for Result Calculation

  This migration recalculates hole results and player statistics in archived_rounds
  to use gross_strokes instead of net_strokes for determining birdies, eagles, pars, etc.

  ## Changes
  1. Updates hole_scores array to recalculate the 'result' field based on gross_strokes vs par
  2. Updates player_stats.hole_results to recalculate birdies, eagles, pars, bogeys, and double_bogeys
  
  ## Why This Fix is Needed
  Previously, results were calculated using net_strokes (after handicap adjustment).
  However, in golf, birdies, eagles, pars, etc. are defined by gross score relative to par,
  not net score. Net strokes are only used for calculating stableford points and rankings.
*/

-- Function to recalculate all archived rounds
CREATE OR REPLACE FUNCTION fix_archived_rounds_use_gross_strokes()
RETURNS void AS $$
DECLARE
  round_record RECORD;
  hole_score JSONB;
  new_hole_scores JSONB[];
  player_stat JSONB;
  new_player_stats JSONB[];
  par_value INT;
  gross_value INT;
  score_diff INT;
  new_result TEXT;
  player_id_val UUID;
  eagles_count INT;
  birdies_count INT;
  pars_count INT;
  bogeys_count INT;
  double_bogeys_count INT;
  triple_bogey_plus_count INT;
BEGIN
  -- Loop through all archived rounds
  FOR round_record IN SELECT id, hole_scores, player_stats FROM archived_rounds
  LOOP
    -- Initialize arrays
    new_hole_scores := ARRAY[]::JSONB[];
    new_player_stats := ARRAY[]::JSONB[];
    
    -- Step 1: Recalculate hole_scores array
    FOR hole_score IN SELECT * FROM jsonb_array_elements(round_record.hole_scores)
    LOOP
      par_value := (hole_score->>'par')::INT;
      gross_value := (hole_score->>'gross_strokes')::INT;
      score_diff := gross_value - par_value;
      
      -- Determine result based on gross_strokes
      IF score_diff <= -2 THEN
        new_result := 'eagle';
      ELSIF score_diff = -1 THEN
        new_result := 'birdie';
      ELSIF score_diff = 0 THEN
        new_result := 'par';
      ELSIF score_diff = 1 THEN
        new_result := 'bogey';
      ELSIF score_diff = 2 THEN
        new_result := 'double_bogey';
      ELSE
        new_result := 'triple_bogey_plus';
      END IF;
      
      -- Update the result field
      new_hole_scores := array_append(new_hole_scores, jsonb_set(hole_score, '{result}', to_jsonb(new_result)));
    END LOOP;
    
    -- Step 2: Recalculate player_stats.hole_results
    FOR player_stat IN SELECT * FROM jsonb_array_elements(round_record.player_stats)
    LOOP
      player_id_val := (player_stat->>'player_id')::UUID;
      
      -- Count each result type for this player
      eagles_count := 0;
      birdies_count := 0;
      pars_count := 0;
      bogeys_count := 0;
      double_bogeys_count := 0;
      triple_bogey_plus_count := 0;
      
      FOR hole_score IN SELECT * FROM unnest(new_hole_scores)
      LOOP
        IF (hole_score->>'player_id')::UUID = player_id_val THEN
          CASE hole_score->>'result'
            WHEN 'eagle' THEN eagles_count := eagles_count + 1;
            WHEN 'birdie' THEN birdies_count := birdies_count + 1;
            WHEN 'par' THEN pars_count := pars_count + 1;
            WHEN 'bogey' THEN bogeys_count := bogeys_count + 1;
            WHEN 'double_bogey' THEN double_bogeys_count := double_bogeys_count + 1;
            WHEN 'triple_bogey_plus' THEN triple_bogey_plus_count := triple_bogey_plus_count + 1;
          END CASE;
        END IF;
      END LOOP;
      
      -- Update hole_results in player_stat
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
      
      new_player_stats := array_append(new_player_stats, player_stat);
    END LOOP;
    
    -- Update the archived_rounds record
    UPDATE archived_rounds
    SET 
      hole_scores = to_jsonb(new_hole_scores),
      player_stats = to_jsonb(new_player_stats)
    WHERE id = round_record.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the fix
SELECT fix_archived_rounds_use_gross_strokes();

-- Drop the function after use
DROP FUNCTION fix_archived_rounds_use_gross_strokes();