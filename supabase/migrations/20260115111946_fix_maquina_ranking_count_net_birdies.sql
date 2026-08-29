/*
  # Fix Máquina Ranking to Count Net Birdies Correctly

  1. Changes
    - Update get_maquina_ranking function to count birdies based on net_strokes = par - 1
    - Previously counted from player_stats.hole_results.birdies field
    - Now correctly counts from hole_scores where net_strokes = par - 1
  
  2. Details
    - Counts all holes where net_strokes = par - 1 (net birdie)
    - Excludes abandoned holes
    - Aggregates total birdies and best day birdies per player
*/

DROP FUNCTION IF EXISTS get_maquina_ranking(uuid);

CREATE FUNCTION get_maquina_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_birdies bigint,
  best_day_birdies bigint,
  best_day_date timestamptz,
  best_day_course text,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_birdies AS (
    SELECT
      (hs->>'player_name')::text as pname,
      (ps->>'player_id')::uuid as pid,
      ar.id as round_id,
      ar.played_at,
      ar.course_name,
      COUNT(*) FILTER (
        WHERE (hs->>'net_strokes')::int <= (hs->>'par')::int - 1
        AND (hs->>'gross_strokes')::int > 0
        AND (hs->>'abandoned')::boolean IS DISTINCT FROM true
      ) as birdies
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.hole_scores) AS hs
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS ps
    WHERE ar.group_id = p_group_id
      AND hs->>'player_name' = ps->>'player_name'
    GROUP BY (hs->>'player_name')::text, (ps->>'player_id')::uuid, ar.id, ar.played_at, ar.course_name
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(birdies) as total_birdies,
      COUNT(DISTINCT round_id) as total_rounds,
      MAX(birdies) as best_day_birdies
    FROM player_birdies
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pb.pid)
      pb.pid,
      pb.birdies,
      pb.played_at,
      pb.course_name
    FROM player_birdies pb
    INNER JOIN player_totals pt ON pb.pid = pt.pid AND pb.birdies = pt.best_day_birdies
    ORDER BY pb.pid, pb.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_birdies,
    COALESCE(bd.birdies, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_birdies > 0
  ORDER BY pt.total_birdies DESC, pt.pname ASC;
END;
$$;