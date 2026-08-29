/*
  # Fix DIVEND Statistics for Missing Players

  1. Changes
    - Update `get_divend_statistics()` to not require players to exist in players table
    - Use player names directly from archived_rounds for Patrocinador and Barra Libre
    - Only use players table for Corto and Driver de Oro (which need player_id)
  
  2. Notes
    - This fixes the issue where players in archived_rounds but not in players table were being ignored
    - Patrocinador and Barra Libre calculations now work with all historical data
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
  -- No longer requires player to exist in players table
  RETURN QUERY
  WITH beer_payers AS (
    SELECT 
      (elem->>'player_name')::text as player_name,
      1::bigint as beer_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) WITH ORDINALITY AS elem_ord(elem, pos)
    WHERE ar.group_id = v_group_id
      AND pos > (jsonb_array_length(ar.final_ranking) / 2.0)
      AND (jsonb_array_length(ar.final_ranking) % 2 = 0 OR pos > (jsonb_array_length(ar.final_ranking) / 2.0 + 1))
  )
  SELECT 
    'patrocinador'::text as stat_type,
    bp.player_name,
    p.id as player_id,
    SUM(bp.beer_count)::bigint as value
  FROM beer_payers bp
  LEFT JOIN players p ON p.name = bp.player_name AND p.group_id = v_group_id
  GROUP BY bp.player_name, p.id
  ORDER BY SUM(bp.beer_count) DESC, bp.player_name ASC
  LIMIT 1;

  -- El Barra libre: Most beers received (from archived_rounds)
  -- No longer requires player to exist in players table
  RETURN QUERY
  WITH beer_receivers AS (
    SELECT 
      (elem->>'player_name')::text as player_name,
      1::bigint as beer_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) WITH ORDINALITY AS elem_ord(elem, pos)
    WHERE ar.group_id = v_group_id
      AND pos <= (jsonb_array_length(ar.final_ranking) / 2)
  )
  SELECT 
    'barra_libre'::text as stat_type,
    br.player_name,
    p.id as player_id,
    SUM(br.beer_count)::bigint as value
  FROM beer_receivers br
  LEFT JOIN players p ON p.name = br.player_name AND p.group_id = v_group_id
  GROUP BY br.player_name, p.id
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
