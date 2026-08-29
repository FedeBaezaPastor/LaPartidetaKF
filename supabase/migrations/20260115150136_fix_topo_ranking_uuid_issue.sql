/*
  # Fix Topo Ranking UUID Issue

  1. Changes
    - Fixes get_topo_ranking to properly handle UUID selection
    - Uses DISTINCT ON instead of MAX for UUID
*/

DROP FUNCTION IF EXISTS get_topo_ranking(uuid);

CREATE OR REPLACE FUNCTION get_topo_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  handicap_improvement numeric,
  old_handicap numeric,
  new_handicap numeric,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_handicaps AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      (player_stat->>'handicap')::numeric as hcp,
      ar.played_at,
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.played_at ASC) as rn_first,
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.played_at DESC) as rn_last
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  first_handicaps AS (
    SELECT pname, hcp as first_hcp
    FROM player_handicaps
    WHERE rn_first = 1
  ),
  last_handicaps AS (
    SELECT pname, pid, hcp as last_hcp
    FROM player_handicaps
    WHERE rn_last = 1
  ),
  round_counts AS (
    SELECT pname, COUNT(*) as rounds
    FROM player_handicaps
    GROUP BY pname
    HAVING COUNT(*) >= 3
  ),
  player_improvements AS (
    SELECT 
      lh.pname,
      lh.pid,
      fh.first_hcp - lh.last_hcp as improvement,
      fh.first_hcp as old_hcp,
      lh.last_hcp as new_hcp,
      rc.rounds
    FROM last_handicaps lh
    JOIN first_handicaps fh ON lh.pname = fh.pname
    JOIN round_counts rc ON lh.pname = rc.pname
  )
  SELECT 
    pi.pname,
    pi.pid,
    pi.improvement,
    pi.old_hcp,
    pi.new_hcp,
    pi.rounds::bigint
  FROM player_improvements pi
  WHERE pi.improvement > 0
  ORDER BY pi.improvement DESC, pi.new_hcp ASC;
END;
$$;
