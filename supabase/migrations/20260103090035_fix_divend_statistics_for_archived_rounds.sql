/*
  # Fix DIVEND Statistics for Archived Rounds

  1. Changes
    - Update `get_divend_statistics()` function to calculate stats from both beer_stats AND archived_rounds
    - This ensures that historical data is included in the statistics

  2. Notes
    - Beer stats for new rounds are calculated when archiving
    - For historical rounds, we calculate from archived_rounds directly
*/

-- Drop old function
DROP FUNCTION IF EXISTS get_divend_statistics();

-- Create updated function
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
  WHERE group_code = 'DIVEND'
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RETURN;
  END IF;

  -- El Patrocinador: Most beers paid (from beer_stats + archived_rounds)
  RETURN QUERY
  WITH beer_payers AS (
    -- From beer_stats table (new rounds)
    SELECT 
      p.name as player_name,
      p.id as player_id,
      COUNT(*) as beer_count
    FROM beer_stats bs
    INNER JOIN players p ON p.id = bs.player_id
    WHERE bs.status = 'payer'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    
    UNION ALL
    
    -- From archived_rounds (historical data)
    SELECT 
      (elem->>'player_name')::text as player_name,
      p.id as player_id,
      1::bigint as beer_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) WITH ORDINALITY AS elem_ord(elem, pos)
    INNER JOIN players p ON p.name = (elem->>'player_name')::text AND p.group_id = v_group_id
    WHERE ar.group_id = v_group_id
      AND pos > (jsonb_array_length(ar.final_ranking) / 2.0)
      AND (jsonb_array_length(ar.final_ranking) % 2 = 0 OR pos > (jsonb_array_length(ar.final_ranking) / 2.0 + 1))
  )
  SELECT 
    'patrocinador'::text as stat_type,
    bp.player_name,
    bp.player_id,
    SUM(bp.beer_count)::bigint as value
  FROM beer_payers bp
  GROUP BY bp.player_name, bp.player_id
  ORDER BY SUM(bp.beer_count) DESC, bp.player_name ASC
  LIMIT 1;

  -- El Barra libre: Most beers received (from beer_stats + archived_rounds)
  RETURN QUERY
  WITH beer_receivers AS (
    -- From beer_stats table (new rounds)
    SELECT 
      p.name as player_name,
      p.id as player_id,
      COUNT(*) as beer_count
    FROM beer_stats bs
    INNER JOIN players p ON p.id = bs.player_id
    WHERE bs.status = 'receiver'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    
    UNION ALL
    
    -- From archived_rounds (historical data)
    SELECT 
      (elem->>'player_name')::text as player_name,
      p.id as player_id,
      1::bigint as beer_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) WITH ORDINALITY AS elem_ord(elem, pos)
    INNER JOIN players p ON p.name = (elem->>'player_name')::text AND p.group_id = v_group_id
    WHERE ar.group_id = v_group_id
      AND pos <= (jsonb_array_length(ar.final_ranking) / 2)
  )
  SELECT 
    'barra_libre'::text as stat_type,
    br.player_name,
    br.player_id,
    SUM(br.beer_count)::bigint as value
  FROM beer_receivers br
  GROUP BY br.player_name, br.player_id
  ORDER BY SUM(br.beer_count) DESC, br.player_name ASC
  LIMIT 1;

  -- El Corto: Most "No pasó de Rojas"
  RETURN QUERY
  SELECT 
    'corto'::text as stat_type,
    p.name as player_name,
    p.id as player_id,
    COUNT(*)::bigint as value
  FROM scores s
  INNER JOIN players p ON p.id = s.player_id
  INNER JOIN golf_rounds gr ON gr.id = s.round_id
  WHERE s.no_paso_rojas = true
    AND gr.status = 'completed'
    AND p.group_id = v_group_id
  GROUP BY p.id, p.name
  ORDER BY COUNT(*) DESC, p.name ASC
  LIMIT 1;

  -- El Driver de Oro: Least "No pasó de Rojas" (but must have played)
  RETURN QUERY
  SELECT 
    'driver_oro'::text as stat_type,
    p.name as player_name,
    p.id as player_id,
    COUNT(CASE WHEN s.no_paso_rojas = true THEN 1 END)::bigint as value
  FROM players p
  INNER JOIN scores s ON s.player_id = p.id
  INNER JOIN golf_rounds gr ON gr.id = s.round_id
  WHERE gr.status = 'completed'
    AND p.group_id = v_group_id
  GROUP BY p.id, p.name
  HAVING COUNT(*) > 0
  ORDER BY COUNT(CASE WHEN s.no_paso_rojas = true THEN 1 END) ASC, p.name ASC
  LIMIT 1;
END;
$$;