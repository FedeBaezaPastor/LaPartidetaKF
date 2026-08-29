/*
  # Update DIVEND Statistics to Use Player Stats

  1. Changes
    - Update `get_divend_statistics()` to calculate "El Corto" and "El Driver de Oro" from archived_rounds.player_stats
    - This ensures that historical data is correctly included

  2. Notes
    - For rounds with player_stats, use that data
    - For rounds without player_stats (old rounds), the stats won't be available
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

  -- El Patrocinador: Most beers paid (from archived_rounds)
  RETURN QUERY
  WITH beer_payers AS (
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

  -- El Barra libre: Most beers received (from archived_rounds)
  RETURN QUERY
  WITH beer_receivers AS (
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

  -- El Corto: Most "No pasó de Rojas" (from archived_rounds.player_stats)
  RETURN QUERY
  WITH no_paso_counts AS (
    SELECT 
      (player_stat->>'player_name')::text as player_name,
      p.id as player_id,
      (player_stat->>'no_paso_rojas_count')::integer as no_paso_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    INNER JOIN players p ON p.name = (player_stat->>'player_name')::text AND p.group_id = v_group_id
    WHERE ar.group_id = v_group_id
      AND ar.player_stats IS NOT NULL
      AND ar.player_stats != '[]'::jsonb
  )
  SELECT 
    'corto'::text as stat_type,
    npc.player_name,
    npc.player_id,
    SUM(npc.no_paso_count)::bigint as value
  FROM no_paso_counts npc
  GROUP BY npc.player_name, npc.player_id
  ORDER BY SUM(npc.no_paso_count) DESC, npc.player_name ASC
  LIMIT 1;

  -- El Driver de Oro: Least "No pasó de Rojas" (from archived_rounds.player_stats)
  RETURN QUERY
  WITH no_paso_counts AS (
    SELECT 
      (player_stat->>'player_name')::text as player_name,
      p.id as player_id,
      (player_stat->>'no_paso_rojas_count')::integer as no_paso_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    INNER JOIN players p ON p.name = (player_stat->>'player_name')::text AND p.group_id = v_group_id
    WHERE ar.group_id = v_group_id
      AND ar.player_stats IS NOT NULL
      AND ar.player_stats != '[]'::jsonb
  )
  SELECT 
    'driver_oro'::text as stat_type,
    npc.player_name,
    npc.player_id,
    SUM(npc.no_paso_count)::bigint as value
  FROM no_paso_counts npc
  GROUP BY npc.player_name, npc.player_id
  HAVING COUNT(*) > 0
  ORDER BY SUM(npc.no_paso_count) ASC, npc.player_name ASC
  LIMIT 1;
END;
$$;