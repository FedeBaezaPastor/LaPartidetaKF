/*
  # Revert Beer Calculation to Correct Half-Split Logic

  1. Changes
    - Revert to correct beer calculation logic
    - Even number: top half receives, bottom half pays
    - Odd number: top floor(n/2) receives, middle is neutral, bottom floor(n/2) pays

  2. Notes
    - This is the correct DIVEND logic
    - Example with 18 players: top 9 receive, bottom 9 pay
    - Example with 21 players: top 10 receive, position 11 neutral, bottom 10 pay
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

  -- Get total number of players in the round
  SELECT COUNT(DISTINCT player_id) INTO v_total_players
  FROM scores
  WHERE round_id = p_round_id;

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
      p.id as player_id,
      SUM(s.points) as total_points
    FROM players p
    INNER JOIN scores s ON s.player_id = p.id
    WHERE s.round_id = p_round_id
    GROUP BY p.id
    ORDER BY SUM(s.points) DESC, p.name ASC
  )
  LOOP
    v_position := v_position + 1;
    
    IF v_position <= v_receiver_count THEN
      -- Top positions: receivers
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'receiver', v_position);
    ELSIF v_position >= v_payer_start THEN
      -- Bottom positions: payers
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'payer', v_position);
    ELSE
      -- Middle position (only for odd number): neutral
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'neutral', v_position);
    END IF;
  END LOOP;
END;
$$;