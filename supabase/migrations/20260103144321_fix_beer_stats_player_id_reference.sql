/*
  # Fix Beer Stats Player ID Reference

  1. Changes
    - Update calculate_beer_stats_for_round to use player_id from players table
    - Only include players that have a player_id (exclude temporary players)
    - This fixes foreign key constraint violation error

  2. Notes
    - The beer_stats table references players.id, not round_players.id
    - Temporary players (with null player_id) are excluded from beer stats
*/

CREATE OR REPLACE FUNCTION calculate_beer_stats_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_players integer;
  v_receiver_count integer;
  v_payer_start integer;
  v_record record;
  v_position integer;
BEGIN
  -- Delete existing beer stats for this round
  DELETE FROM beer_stats WHERE round_id = p_round_id;

  -- Get total number of players in the round (only those with player_id)
  SELECT COUNT(DISTINCT rp.player_id) INTO v_total_players
  FROM round_players rp
  WHERE rp.round_id = p_round_id
    AND rp.player_id IS NOT NULL;

  -- If no players with player_id, exit early
  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  -- Calculate receiver count and payer start position
  v_receiver_count := v_total_players / 2;
  
  IF v_total_players % 2 = 0 THEN
    -- Even: top half receives, bottom half pays
    v_payer_start := v_receiver_count + 1;
  ELSE
    -- Odd: top floor(n/2) receives, middle is neutral, bottom floor(n/2) pays
    v_payer_start := v_receiver_count + 2;
  END IF;

  -- Calculate leaderboard positions and insert beer stats
  v_position := 0;
  
  FOR v_record IN (
    SELECT 
      rp.player_id,
      SUM(rs.stableford_points) as total_points,
      rp.name as player_name
    FROM round_players rp
    INNER JOIN round_scores rs ON rs.player_id = rp.id AND rs.round_id = p_round_id
    WHERE rp.round_id = p_round_id
      AND rp.player_id IS NOT NULL
    GROUP BY rp.player_id, rp.name
    ORDER BY SUM(rs.stableford_points) DESC, rp.name ASC
  )
  LOOP
    v_position := v_position + 1;
    
    IF v_position <= v_receiver_count THEN
      -- Top positions: receivers (blue)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'receiver', v_position);
    ELSIF v_position >= v_payer_start THEN
      -- Bottom positions: payers (red)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'payer', v_position);
    ELSE
      -- Middle position (only for odd number): neutral (yellow)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'neutral', v_position);
    END IF;
  END LOOP;
END;
$$;