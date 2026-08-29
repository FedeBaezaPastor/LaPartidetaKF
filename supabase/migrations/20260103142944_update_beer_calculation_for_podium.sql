/*
  # Update Beer Calculation Logic

  1. Changes
    - Update beer calculation to award beers to top 3 (podium)
    - Last place still pays
    - Middle positions are neutral

  2. Notes
    - Replaces previous even/odd split logic
    - More straightforward: podium wins, last pays
*/

CREATE OR REPLACE FUNCTION calculate_beer_stats_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_players integer;
  v_record record;
  v_position integer;
BEGIN
  -- Delete existing beer stats for this round
  DELETE FROM beer_stats WHERE round_id = p_round_id;

  -- Get total number of players in the round
  SELECT COUNT(DISTINCT player_id) INTO v_total_players
  FROM scores
  WHERE round_id = p_round_id;

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
    
    IF v_position <= 3 THEN
      -- Top 3 positions: receivers (podium)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'receiver', v_position);
    ELSIF v_position = v_total_players THEN
      -- Last position: payer
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'payer', v_position);
    ELSE
      -- Middle positions: neutral
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'neutral', v_position);
    END IF;
  END LOOP;
END;
$$;