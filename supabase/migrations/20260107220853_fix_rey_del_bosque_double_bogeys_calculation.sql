/*
  # Fix Rey del Bosque Double Bogeys Calculation
  
  1. Changes
    - Recalculate double_bogeys in player_stats to include all results >= par + 2
    - This includes: double bogeys, triple bogeys, and worse
    - Updates all existing archived_rounds to have the correct counts
    
  2. Notes
    - Rey del Bosque should count ALL double bogeys or worse (circle negros)
    - Not just exact double bogeys
*/

-- Update all existing archived rounds to recalculate double_bogeys
DO $$
DECLARE
  round_record RECORD;
  player_stat jsonb;
  hole_score jsonb;
  updated_player_stats jsonb[];
  hole_par integer;
  net_strokes integer;
  double_bogey_count integer;
BEGIN
  -- Loop through each archived round
  FOR round_record IN 
    SELECT id, player_stats, hole_scores
    FROM archived_rounds
  LOOP
    updated_player_stats := ARRAY[]::jsonb[];
    
    -- Loop through each player in this round
    FOR player_stat IN 
      SELECT * FROM jsonb_array_elements(round_record.player_stats)
    LOOP
      double_bogey_count := 0;
      
      -- Count double bogeys or worse for this player
      FOR hole_score IN
        SELECT * FROM jsonb_array_elements(round_record.hole_scores)
        WHERE (hole_score->>'player_name') = (player_stat->>'player_name')
      LOOP
        hole_par := (hole_score->>'par')::integer;
        net_strokes := (hole_score->>'net_strokes')::integer;
        
        -- Count if net_strokes >= par + 2 (double bogey or worse)
        IF net_strokes >= hole_par + 2 THEN
          double_bogey_count := double_bogey_count + 1;
        END IF;
      END LOOP;
      
      -- Update the player_stat with the new double_bogey count
      player_stat := jsonb_set(
        player_stat,
        '{hole_results,double_bogeys}',
        to_jsonb(double_bogey_count)
      );
      
      updated_player_stats := array_append(updated_player_stats, player_stat);
    END LOOP;
    
    -- Update the archived_round with corrected player_stats
    UPDATE archived_rounds
    SET player_stats = to_jsonb(updated_player_stats)
    WHERE id = round_record.id;
  END LOOP;
END $$;
