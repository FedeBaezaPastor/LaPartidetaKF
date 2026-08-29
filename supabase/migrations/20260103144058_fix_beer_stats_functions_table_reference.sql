/*
  # Fix Beer Stats Functions - Table Reference

  1. Changes
    - Update calculate_beer_stats_for_round function to use round_scores instead of scores
    - Update get_divend_statistics function to use round_scores instead of scores
    - Update round_players references where needed

  2. Notes
    - This fixes the "relation 'scores' does not exist" error when archiving rounds
    - The correct table name is round_scores, not scores
*/

-- Update calculate_beer_stats_for_round function
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
  FROM round_players
  WHERE round_id = p_round_id;

  -- If no players, exit early
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
      rp.id as player_id,
      SUM(rs.stableford_points) as total_points,
      rp.name as player_name
    FROM round_players rp
    INNER JOIN round_scores rs ON rs.player_id = rp.id AND rs.round_id = p_round_id
    WHERE rp.round_id = p_round_id
    GROUP BY rp.id, rp.name
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

-- Update get_divend_statistics function
CREATE OR REPLACE FUNCTION get_divend_statistics()
RETURNS TABLE (
  stat_type text,
  player_name text,
  player_id uuid,
  value bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_group_id uuid;
BEGIN
  -- Get group_id for DIVEND
  SELECT id INTO v_group_id
  FROM groups
  WHERE name = 'DIVEND'
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RETURN;
  END IF;

  -- El Patrocinador: Most beers paid
  RETURN QUERY
  SELECT 
    'patrocinador'::text as stat_type,
    p.name as player_name,
    p.id as player_id,
    COUNT(*)::bigint as value
  FROM beer_stats bs
  INNER JOIN players p ON p.id = bs.player_id
  WHERE bs.status = 'payer'
    AND p.group_id = v_group_id
  GROUP BY p.id, p.name
  ORDER BY COUNT(*) DESC, p.name ASC
  LIMIT 1;

  -- El Barra libre: Most beers received
  RETURN QUERY
  SELECT 
    'barra_libre'::text as stat_type,
    p.name as player_name,
    p.id as player_id,
    COUNT(*)::bigint as value
  FROM beer_stats bs
  INNER JOIN players p ON p.id = bs.player_id
  WHERE bs.status = 'receiver'
    AND p.group_id = v_group_id
  GROUP BY p.id, p.name
  ORDER BY COUNT(*) DESC, p.name ASC
  LIMIT 1;

  -- El Corto: Most "No pasó de Rojas" (from archived rounds)
  RETURN QUERY
  SELECT 
    'corto'::text as stat_type,
    elem->>'player_name' as player_name,
    p.id as player_id,
    COUNT(*)::bigint as value
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS elem
  INNER JOIN players p ON p.name = (elem->>'player_name')::text AND p.group_id = v_group_id
  WHERE ar.group_id = v_group_id
    AND (elem->>'no_paso_rojas_count')::integer > 0
  GROUP BY elem->>'player_name', p.id
  ORDER BY SUM((elem->>'no_paso_rojas_count')::integer) DESC
  LIMIT 1;

  -- El Driver de Oro: Least "No pasó de Rojas" (but must have played)
  RETURN QUERY
  SELECT 
    'driver_oro'::text as stat_type,
    elem->>'player_name' as player_name,
    p.id as player_id,
    COALESCE(SUM((elem->>'no_paso_rojas_count')::integer), 0)::bigint as value
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS elem
  INNER JOIN players p ON p.name = (elem->>'player_name')::text AND p.group_id = v_group_id
  WHERE ar.group_id = v_group_id
  GROUP BY elem->>'player_name', p.id
  HAVING COUNT(*) > 0
  ORDER BY COALESCE(SUM((elem->>'no_paso_rojas_count')::integer), 0) ASC
  LIMIT 1;
END;
$$;