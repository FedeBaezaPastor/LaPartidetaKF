/*
  # Fix Phase 2 Statistics Functions - Null Handling
  
  1. Updates
    - Add better null handling for all Phase 2 statistics functions
    - Handle cases where hole_results might not exist in player_stats
    - Add COALESCE to handle null values
    
  2. Notes
    - This makes the functions more robust for existing data that may not have all fields
*/

-- Update Francotirador ranking to handle missing hole_results
CREATE OR REPLACE FUNCTION get_francotirador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_eagles bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_eagles AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'eagles')::integer, 0) as eagles,
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
      SUM(eagles) as total_eagles,
      COUNT(*) as total_rounds,
      MAX(eagles) as best_day_eagles
    FROM player_eagles
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pname)
      pe.pname,
      pe.eagles,
      pe.played_at,
      pe.course_name
    FROM player_eagles pe
    INNER JOIN player_totals pt ON pe.pname = pt.pname AND pe.eagles = pt.best_day_eagles
    ORDER BY pe.pname, pe.played_at ASC
  )
  SELECT 
    pt.pname,
    pt.pid,
    pt.total_eagles,
    COALESCE(bd.eagles::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  WHERE pt.total_eagles > 0
  ORDER BY pt.total_eagles DESC, bd.eagles DESC;
END;
$$ LANGUAGE plpgsql;

-- Update Maquina ranking
CREATE OR REPLACE FUNCTION get_maquina_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_birdies bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_birdies AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'birdies')::integer, 0) as birdies,
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
      SUM(birdies) as total_birdies,
      COUNT(*) as total_rounds,
      MAX(birdies) as best_day_birdies
    FROM player_birdies
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pb.pname)
      pb.pname,
      pb.birdies,
      pb.played_at,
      pb.course_name
    FROM player_birdies pb
    INNER JOIN player_totals pt ON pb.pname = pt.pname AND pb.birdies = pt.best_day_birdies
    ORDER BY pb.pname, pb.played_at ASC
  )
  SELECT 
    pt.pname,
    pt.pid,
    pt.total_birdies,
    COALESCE(bd.birdies::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  WHERE pt.total_birdies > 0
  ORDER BY pt.total_birdies DESC, bd.birdies DESC;
END;
$$ LANGUAGE plpgsql;

-- Update Amigo del +1 ranking
CREATE OR REPLACE FUNCTION get_amigo_del_mas_uno_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_bogeys bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_bogeys AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'bogeys')::integer, 0) as bogeys,
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
      SUM(bogeys) as total_bogeys,
      COUNT(*) as total_rounds,
      MAX(bogeys) as best_day_bogeys
    FROM player_bogeys
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pb.pname)
      pb.pname,
      pb.bogeys,
      pb.played_at,
      pb.course_name
    FROM player_bogeys pb
    INNER JOIN player_totals pt ON pb.pname = pt.pname AND pb.bogeys = pt.best_day_bogeys
    ORDER BY pb.pname, pb.played_at ASC
  )
  SELECT 
    pt.pname,
    pt.pid,
    pt.total_bogeys,
    COALESCE(bd.bogeys::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  WHERE pt.total_bogeys > 0
  ORDER BY pt.total_bogeys DESC, bd.bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Update Rey del Bosque ranking
CREATE OR REPLACE FUNCTION get_rey_del_bosque_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_double_bogeys bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_double_bogeys AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'double_bogeys')::integer, 0) as double_bogeys,
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
      SUM(double_bogeys) as total_double_bogeys,
      COUNT(*) as total_rounds,
      MAX(double_bogeys) as best_day_double_bogeys
    FROM player_double_bogeys
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pdb.pname)
      pdb.pname,
      pdb.double_bogeys,
      pdb.played_at,
      pdb.course_name
    FROM player_double_bogeys pdb
    INNER JOIN player_totals pt ON pdb.pname = pt.pname AND pdb.double_bogeys = pt.best_day_double_bogeys
    ORDER BY pdb.pname, pdb.played_at ASC
  )
  SELECT 
    pt.pname,
    pt.pid,
    pt.total_double_bogeys,
    COALESCE(bd.double_bogeys::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  WHERE pt.total_double_bogeys > 0
  ORDER BY pt.total_double_bogeys DESC, bd.double_bogeys DESC;
END;
$$ LANGUAGE plpgsql;