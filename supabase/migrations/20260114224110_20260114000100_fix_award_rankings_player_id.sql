/*
  # Fix Award Rankings Player ID Extraction

  1. Problem
    - Award ranking functions return null for player_id
    - This causes the frontend to not display rankings correctly
    - Player IDs need to be properly extracted from player_stats JSONB

  2. Solution
    - Fix all award ranking functions to properly extract and cast player_id as UUID
    - Ensure proper filtering (e.g., only show players with eagles > 0 for Francotirador)

  3. Security
    - No RLS changes needed
*/

-- Fix Francotirador ranking to properly extract player_id
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
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.eagles,
      pe.played_at,
      pe.course_name
    FROM player_eagles pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.eagles = pt.best_day_eagles
    ORDER BY pe.pid, pe.played_at ASC
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
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_eagles > 0
  ORDER BY pt.total_eagles DESC, bd.eagles DESC;
END;
$$ LANGUAGE plpgsql;

-- Fix Maquina ranking
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
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.birdies,
      pe.played_at,
      pe.course_name
    FROM player_birdies pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.birdies = pt.best_day_birdies
    ORDER BY pe.pid, pe.played_at ASC
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
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_birdies > 0
  ORDER BY pt.total_birdies DESC, bd.birdies DESC;
END;
$$ LANGUAGE plpgsql;

-- Fix Amigo del +1 ranking
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
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.bogeys,
      pe.played_at,
      pe.course_name
    FROM player_bogeys pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.bogeys = pt.best_day_bogeys
    ORDER BY pe.pid, pe.played_at ASC
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
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_bogeys > 0
  ORDER BY pt.total_bogeys DESC, bd.bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Fix Rey del Bosque ranking
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
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.double_bogeys,
      pe.played_at,
      pe.course_name
    FROM player_double_bogeys pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.double_bogeys = pt.best_day_double_bogeys
    ORDER BY pe.pid, pe.played_at ASC
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
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_double_bogeys > 0
  ORDER BY pt.total_double_bogeys DESC, bd.double_bogeys DESC;
END;
$$ LANGUAGE plpgsql;
