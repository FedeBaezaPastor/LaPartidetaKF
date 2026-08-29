/*
  # Fix Rey del Bosque - Include Triple Bogey+ in Count

  1. Changes
    - Update get_rey_del_bosque_ranking function to count double bogeys AND triple bogey+
    - Total should be: double_bogeys + triple_bogey_plus
    
  2. Security
    - No RLS changes
*/

-- Drop and recreate the function with correct calculation
DROP FUNCTION IF EXISTS get_rey_del_bosque_ranking(uuid);

CREATE OR REPLACE FUNCTION get_rey_del_bosque_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_double_bogeys_plus bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_bad_holes AS (
    SELECT
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'double_bogeys')::integer, 0) + 
      COALESCE((player_stat->'hole_results'->>'triple_bogey_plus')::integer, 0) as double_bogeys_plus,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
      AND player_stat->'hole_results' IS NOT NULL
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(double_bogeys_plus) as total_double_bogeys_plus,
      COUNT(*) as total_rounds,
      MAX(double_bogeys_plus) as best_day_double_bogeys_plus
    FROM player_bad_holes
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.double_bogeys_plus,
      pe.played_at,
      pe.course_name
    FROM player_bad_holes pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.double_bogeys_plus = pt.best_day_double_bogeys_plus
    ORDER BY pe.pid, pe.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_double_bogeys_plus,
    COALESCE(bd.double_bogeys_plus::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  ORDER BY pt.total_double_bogeys_plus DESC, pt.pname ASC;
END;
$$;