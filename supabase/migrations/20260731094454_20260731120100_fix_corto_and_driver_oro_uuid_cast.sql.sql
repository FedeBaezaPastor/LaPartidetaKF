
DROP FUNCTION IF EXISTS get_corto_ranking(text);
CREATE OR REPLACE FUNCTION get_corto_ranking(p_group_id text)
RETURNS TABLE(player_name text, no_paso_rojas_count bigint)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (stat->>'player_name')::text AS player_name,
    COALESCE((stat->>'no_paso_rojas_count')::bigint, 0) AS no_paso_rojas_count
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS stat
  WHERE ar.group_id::text = p_group_id
  GROUP BY (stat->>'player_name')::text
  ORDER BY no_paso_rojas_count DESC
  LIMIT 10;
END;
$$;

DROP FUNCTION IF EXISTS get_driver_oro_ranking(text);
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id text)
RETURNS TABLE(player_name text, no_paso_rojas_count bigint)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (stat->>'player_name')::text AS player_name,
    COALESCE((stat->>'no_paso_rojas_count')::bigint, 0) AS no_paso_rojas_count
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS stat
  WHERE ar.group_id::text = p_group_id
  GROUP BY (stat->>'player_name')::text
  ORDER BY no_paso_rojas_count ASC
  LIMIT 10;
END;
$$;
