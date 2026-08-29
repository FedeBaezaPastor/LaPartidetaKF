/*
  # Fix UUID Aggregation in Ranking Functions

  1. Changes
    - Uses MIN(pid) instead of MAX(pid) for UUID fields
    - This is a workaround since PostgreSQL doesn't have MAX/MIN for UUIDs by default
    
  2. Details
    - Affects get_francotirador_ranking, get_maquina_ranking, get_amigo_del_mas_uno_ranking
    - Affects get_rey_del_bosque_ranking, get_shark_ranking
*/

-- Fix get_francotirador_ranking
DROP FUNCTION IF EXISTS get_francotirador_ranking(uuid);

CREATE OR REPLACE FUNCTION get_francotirador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_eagles bigint,
  total_rounds bigint,
  best_single_day bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_eagles AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      ((player_stat->'hole_results'->>'eagles')::int) as eagles,
      (player_stat->>'handicap')::numeric as hcp,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_ids AS (
    SELECT DISTINCT ON (pname)
      pname,
      pid
    FROM player_eagles
  )
  SELECT 
    pe.pname,
    pi.pid,
    SUM(pe.eagles)::bigint as total_eagles,
    COUNT(DISTINCT pe.round_id)::bigint as total_rounds,
    MAX(pe.eagles)::bigint as best_single_day,
    AVG(pe.hcp)::numeric as avg_handicap
  FROM player_eagles pe
  LEFT JOIN player_ids pi ON pe.pname = pi.pname
  GROUP BY pe.pname, pi.pid
  HAVING SUM(pe.eagles) > 0
  ORDER BY total_eagles DESC, avg_handicap ASC;
END;
$$;

-- Fix get_maquina_ranking
DROP FUNCTION IF EXISTS get_maquina_ranking(uuid);

CREATE OR REPLACE FUNCTION get_maquina_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_birdies bigint,
  total_rounds bigint,
  best_single_day bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_birdies AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      ((player_stat->'hole_results'->>'birdies')::int) as birdies,
      (player_stat->>'handicap')::numeric as hcp,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_ids AS (
    SELECT DISTINCT ON (pname)
      pname,
      pid
    FROM player_birdies
  )
  SELECT 
    pb.pname,
    pi.pid,
    SUM(pb.birdies)::bigint as total_birdies,
    COUNT(DISTINCT pb.round_id)::bigint as total_rounds,
    MAX(pb.birdies)::bigint as best_single_day,
    AVG(pb.hcp)::numeric as avg_handicap
  FROM player_birdies pb
  LEFT JOIN player_ids pi ON pb.pname = pi.pname
  GROUP BY pb.pname, pi.pid
  HAVING SUM(pb.birdies) > 0
  ORDER BY total_birdies DESC, avg_handicap ASC;
END;
$$;

-- Fix get_amigo_del_mas_uno_ranking
DROP FUNCTION IF EXISTS get_amigo_del_mas_uno_ranking(uuid);

CREATE OR REPLACE FUNCTION get_amigo_del_mas_uno_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_bogeys bigint,
  total_rounds bigint,
  best_single_day bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_bogeys AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      ((player_stat->'hole_results'->>'bogeys')::int) as bogeys,
      (player_stat->>'handicap')::numeric as hcp,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_ids AS (
    SELECT DISTINCT ON (pname)
      pname,
      pid
    FROM player_bogeys
  )
  SELECT 
    pb.pname,
    pi.pid,
    SUM(pb.bogeys)::bigint as total_bogeys,
    COUNT(DISTINCT pb.round_id)::bigint as total_rounds,
    MAX(pb.bogeys)::bigint as best_single_day,
    AVG(pb.hcp)::numeric as avg_handicap
  FROM player_bogeys pb
  LEFT JOIN player_ids pi ON pb.pname = pi.pname
  GROUP BY pb.pname, pi.pid
  HAVING SUM(pb.bogeys) > 0
  ORDER BY total_bogeys DESC, avg_handicap ASC;
END;
$$;

-- Fix get_rey_del_bosque_ranking
DROP FUNCTION IF EXISTS get_rey_del_bosque_ranking(uuid);

CREATE OR REPLACE FUNCTION get_rey_del_bosque_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_double_bogeys_plus bigint,
  total_rounds bigint,
  best_single_day bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_db_plus AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      (
        ((player_stat->'hole_results'->>'double_bogeys')::int) + 
        ((player_stat->'hole_results'->>'triple_bogey_plus')::int)
      ) as db_plus,
      (player_stat->>'handicap')::numeric as hcp,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_ids AS (
    SELECT DISTINCT ON (pname)
      pname,
      pid
    FROM player_db_plus
  )
  SELECT 
    pdb.pname,
    pi.pid,
    SUM(pdb.db_plus)::bigint as total_double_bogeys_plus,
    COUNT(DISTINCT pdb.round_id)::bigint as total_rounds,
    MAX(pdb.db_plus)::bigint as best_single_day,
    AVG(pdb.hcp)::numeric as avg_handicap
  FROM player_db_plus pdb
  LEFT JOIN player_ids pi ON pdb.pname = pi.pname
  GROUP BY pdb.pname, pi.pid
  HAVING SUM(pdb.db_plus) > 0
  ORDER BY total_double_bogeys_plus DESC, avg_handicap ASC;
END;
$$;

-- Fix get_shark_ranking
DROP FUNCTION IF EXISTS get_shark_ranking(uuid);

CREATE OR REPLACE FUNCTION get_shark_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_wins bigint,
  total_rounds bigint,
  win_percentage numeric,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_rounds AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      (player_stat->>'handicap')::numeric as hcp,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  winners AS (
    SELECT 
      (ranking->>'player_name')::text as winner_name,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking
    WHERE ar.group_id = p_group_id
      AND (ranking->>'position')::int = 1
  ),
  player_ids AS (
    SELECT DISTINCT ON (pname)
      pname,
      pid
    FROM player_rounds
  ),
  player_wins AS (
    SELECT 
      pr.pname,
      COUNT(DISTINCT pr.round_id) as total_rounds,
      COUNT(DISTINCT w.round_id) as wins,
      AVG(pr.hcp) as avg_hcp
    FROM player_rounds pr
    LEFT JOIN winners w ON pr.pname = w.winner_name AND pr.round_id = w.round_id
    GROUP BY pr.pname
  )
  SELECT 
    pw.pname,
    pi.pid,
    pw.wins::bigint,
    pw.total_rounds::bigint,
    ROUND((pw.wins::numeric / NULLIF(pw.total_rounds, 0)::numeric * 100), 1) as win_pct,
    pw.avg_hcp::numeric
  FROM player_wins pw
  LEFT JOIN player_ids pi ON pw.pname = pi.pname
  WHERE pw.wins > 0
  ORDER BY pw.wins DESC, pw.avg_hcp ASC;
END;
$$;
