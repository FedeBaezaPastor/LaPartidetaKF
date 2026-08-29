/*
  # Fix Award Rankings to Use hole_results Object Structure

  1. Changes
    - Recreates get_francotirador_ranking (eagles)
    - Recreates get_maquina_ranking (birdies)  
    - Recreates get_amigo_del_mas_uno_ranking (bogeys)
    - Recreates get_rey_del_bosque_ranking (double bogeys+)
    - Fixes get_topo_ranking (uses played_at instead of completed_at)
    - Creates get_la_paliza (biggest victory margin)
    - Fixes get_shark_ranking to calculate wins correctly
    
  2. Details
    - All functions now read from player_stats->hole_results object
    - Uses direct JSON property access instead of jsonb_array_elements
*/

-- Drop and recreate get_francotirador_ranking (Eagles)
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
  )
  SELECT 
    pe.pname,
    MAX(pe.pid) as player_id,
    SUM(pe.eagles)::bigint as total_eagles,
    COUNT(DISTINCT pe.round_id)::bigint as total_rounds,
    MAX(pe.eagles)::bigint as best_single_day,
    AVG(pe.hcp)::numeric as avg_handicap
  FROM player_eagles pe
  GROUP BY pe.pname
  HAVING SUM(pe.eagles) > 0
  ORDER BY total_eagles DESC, avg_handicap ASC;
END;
$$;

-- Drop and recreate get_maquina_ranking (Birdies)
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
  )
  SELECT 
    pb.pname,
    MAX(pb.pid) as player_id,
    SUM(pb.birdies)::bigint as total_birdies,
    COUNT(DISTINCT pb.round_id)::bigint as total_rounds,
    MAX(pb.birdies)::bigint as best_single_day,
    AVG(pb.hcp)::numeric as avg_handicap
  FROM player_birdies pb
  GROUP BY pb.pname
  HAVING SUM(pb.birdies) > 0
  ORDER BY total_birdies DESC, avg_handicap ASC;
END;
$$;

-- Drop and recreate get_amigo_del_mas_uno_ranking (Bogeys)
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
  )
  SELECT 
    pb.pname,
    MAX(pb.pid) as player_id,
    SUM(pb.bogeys)::bigint as total_bogeys,
    COUNT(DISTINCT pb.round_id)::bigint as total_rounds,
    MAX(pb.bogeys)::bigint as best_single_day,
    AVG(pb.hcp)::numeric as avg_handicap
  FROM player_bogeys pb
  GROUP BY pb.pname
  HAVING SUM(pb.bogeys) > 0
  ORDER BY total_bogeys DESC, avg_handicap ASC;
END;
$$;

-- Drop and recreate get_rey_del_bosque_ranking (Double Bogeys+)
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
  )
  SELECT 
    pdb.pname,
    MAX(pdb.pid) as player_id,
    SUM(pdb.db_plus)::bigint as total_double_bogeys_plus,
    COUNT(DISTINCT pdb.round_id)::bigint as total_rounds,
    MAX(pdb.db_plus)::bigint as best_single_day,
    AVG(pdb.hcp)::numeric as avg_handicap
  FROM player_db_plus pdb
  GROUP BY pdb.pname
  HAVING SUM(pdb.db_plus) > 0
  ORDER BY total_double_bogeys_plus DESC, avg_handicap ASC;
END;
$$;

-- Drop and recreate get_topo_ranking (Handicap improvement)
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
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.played_at ASC) as first_round,
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.played_at DESC) as last_round
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_improvements AS (
    SELECT 
      pname,
      MAX(CASE WHEN last_round = 1 THEN pid END) as pid,
      MAX(CASE WHEN first_round = 1 THEN hcp END) - MAX(CASE WHEN last_round = 1 THEN hcp END) as improvement,
      MAX(CASE WHEN first_round = 1 THEN hcp END) as old_hcp,
      MAX(CASE WHEN last_round = 1 THEN hcp END) as new_hcp,
      COUNT(*) as rounds
    FROM player_handicaps
    GROUP BY pname
    HAVING COUNT(*) >= 3
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

-- Create get_la_paliza (Biggest victory margin)
DROP FUNCTION IF EXISTS get_la_paliza(uuid);

CREATE OR REPLACE FUNCTION get_la_paliza(p_group_id uuid)
RETURNS TABLE (
  winner_name text,
  winner_id uuid,
  winner_points integer,
  second_place_name text,
  second_place_points integer,
  point_difference integer,
  course_name text,
  played_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_rounds AS (
    SELECT 
      ar.id,
      ar.course_name,
      ar.played_at,
      (ranking->>'player_name')::text as pname,
      (ranking->>'player_id')::uuid as pid,
      (ranking->>'points')::int as points,
      ROW_NUMBER() OVER (PARTITION BY ar.id ORDER BY (ranking->>'points')::int DESC) as position
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking
    WHERE ar.group_id = p_group_id
  ),
  victory_margins AS (
    SELECT 
      first.pname as winner_name,
      first.pid as winner_id,
      first.points as winner_points,
      second.pname as second_name,
      second.points as second_points,
      (first.points - second.points) as margin,
      first.course_name,
      first.played_at
    FROM ranked_rounds first
    JOIN ranked_rounds second ON first.id = second.id AND second.position = 2
    WHERE first.position = 1
  )
  SELECT 
    vm.winner_name,
    vm.winner_id,
    vm.winner_points,
    vm.second_name,
    vm.second_points,
    vm.margin,
    vm.course_name,
    vm.played_at
  FROM victory_margins vm
  ORDER BY vm.margin DESC
  LIMIT 1;
END;
$$;

-- Fix get_shark_ranking to calculate wins correctly
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
  player_wins AS (
    SELECT 
      pr.pname,
      MAX(pr.pid) as pid,
      COUNT(DISTINCT pr.round_id) as total_rounds,
      COUNT(DISTINCT w.round_id) as wins,
      AVG(pr.hcp) as avg_hcp
    FROM player_rounds pr
    LEFT JOIN winners w ON pr.pname = w.winner_name AND pr.round_id = w.round_id
    GROUP BY pr.pname
  )
  SELECT 
    pw.pname,
    pw.pid,
    pw.wins::bigint,
    pw.total_rounds::bigint,
    ROUND((pw.wins::numeric / NULLIF(pw.total_rounds, 0)::numeric * 100), 1) as win_pct,
    pw.avg_hcp::numeric
  FROM player_wins pw
  WHERE pw.wins > 0
  ORDER BY pw.wins DESC, pw.avg_hcp ASC;
END;
$$;
