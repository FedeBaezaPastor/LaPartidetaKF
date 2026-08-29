/*
  # Create Phase 2 Statistics Functions
  
  1. New Functions
    - `get_killer_ranking()` - Returns player with best single-round score (most points in one round)
    - `get_paquete_ranking()` - Returns player with worst single-round score (least points in one round)
    - `get_shark_ranking()` - Returns player with most wins
    - `get_metronomo_ranking()` - Returns most consistent player (best average, min 20 rounds)
    - `get_viciado_ranking()` - Returns player with most rounds played
    - `get_francotirador_ranking()` - Returns player with most eagles (single day and overall)
    - `get_maquina_ranking()` - Returns player with most birdies (single day and overall)
    - `get_amigo_del_mas_uno_ranking()` - Returns player with most bogeys (single day and overall)
    - `get_rey_del_bosque_ranking()` - Returns player with most double bogeys (single day and overall)
    - `get_topo_ranking()` - Returns player with biggest handicap improvement
    - `get_la_paliza()` - Returns biggest victory margin
    - `get_head_to_head(player1_name, player2_name)` - Returns head-to-head comparison between two players
    
  2. Returns
    Each function returns appropriate data structure for the ranking type
    
  3. Notes
    - All functions work with group_id parameter
    - Rankings use archived_rounds data
    - Some rankings differentiate between single-day records and overall season records
*/

-- Function to get "El Killer" (best single round score)
CREATE OR REPLACE FUNCTION get_killer_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  best_score integer,
  course_name text,
  played_at timestamptz,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    (ranking_entry->>'points')::integer as best_score,
    ar.course_name,
    ar.played_at,
    (ranking_entry->>'handicap')::numeric
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  ORDER BY best_score DESC, ar.played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Paquete" (worst single round score)
CREATE OR REPLACE FUNCTION get_paquete_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  worst_score integer,
  course_name text,
  played_at timestamptz,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    (ranking_entry->>'points')::integer as worst_score,
    ar.course_name,
    ar.played_at,
    (ranking_entry->>'handicap')::numeric
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  ORDER BY worst_score ASC, ar.played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Shark" (most wins)
CREATE OR REPLACE FUNCTION get_shark_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_wins bigint,
  total_rounds bigint,
  win_percentage numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    COUNT(*) FILTER (WHERE (ranking_entry->>'position')::integer = 1) as total_wins,
    COUNT(*) as total_rounds,
    ROUND((COUNT(*) FILTER (WHERE (ranking_entry->>'position')::integer = 1)::numeric / COUNT(*)::numeric) * 100, 1) as win_percentage
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  GROUP BY ranking_entry->>'player_name', ranking_entry->>'player_id'
  ORDER BY total_wins DESC, win_percentage DESC, total_rounds DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Metrónomo" (most consistent player, min 20 rounds)
CREATE OR REPLACE FUNCTION get_metronomo_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  average_score numeric,
  total_rounds bigint,
  std_deviation numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    ROUND(AVG((ranking_entry->>'points')::numeric), 2) as average_score,
    COUNT(*) as total_rounds,
    ROUND(STDDEV((ranking_entry->>'points')::numeric), 2) as std_deviation
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  GROUP BY ranking_entry->>'player_name', ranking_entry->>'player_id'
  HAVING COUNT(*) >= 20
  ORDER BY average_score DESC, std_deviation ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Viciado" (most rounds played)
CREATE OR REPLACE FUNCTION get_viciado_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_rounds bigint,
  average_score numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    COUNT(*) as total_rounds,
    ROUND(AVG((ranking_entry->>'points')::numeric), 2) as average_score
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  GROUP BY ranking_entry->>'player_name', ranking_entry->>'player_id'
  ORDER BY total_rounds DESC, average_score DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Francotirador" (most eagles)
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
      (player_stat->'hole_results'->>'eagles')::integer as eagles,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
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
    bd.eagles::bigint,
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  ORDER BY pt.total_eagles DESC, bd.eagles DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "La Máquina" (most birdies)
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
      (player_stat->'hole_results'->>'birdies')::integer as birdies,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
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
    bd.birdies::bigint,
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  ORDER BY pt.total_birdies DESC, bd.birdies DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Amigo del +1" (most bogeys)
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
      (player_stat->'hole_results'->>'bogeys')::integer as bogeys,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
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
    bd.bogeys::bigint,
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  ORDER BY pt.total_bogeys DESC, bd.bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Rey del Bosque" (most double bogeys)
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
      (player_stat->'hole_results'->>'double_bogeys')::integer as double_bogeys,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
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
    bd.double_bogeys::bigint,
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pname = bd.pname
  ORDER BY pt.total_double_bogeys DESC, bd.double_bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Topo" (biggest handicap improvement)
CREATE OR REPLACE FUNCTION get_topo_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  handicap_improvement numeric,
  old_handicap numeric,
  new_handicap numeric,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH first_last_handicaps AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      FIRST_VALUE((player_stat->>'handicap')::numeric) OVER (PARTITION BY player_stat->>'player_name' ORDER BY ar.played_at ASC) as first_handicap,
      FIRST_VALUE((player_stat->>'handicap')::numeric) OVER (PARTITION BY player_stat->>'player_name' ORDER BY ar.played_at DESC) as last_handicap,
      COUNT(*) OVER (PARTITION BY player_stat->>'player_name') as rounds_count
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT DISTINCT
    pname,
    pid,
    first_handicap - last_handicap as improvement,
    first_handicap,
    last_handicap,
    rounds_count
  FROM first_last_handicaps
  WHERE first_handicap - last_handicap > 0
  ORDER BY improvement DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "La Paliza" (biggest victory margin)
CREATE OR REPLACE FUNCTION get_la_paliza(p_group_id uuid)
RETURNS TABLE (
  winner_name text,
  winner_points integer,
  second_place_name text,
  second_place_points integer,
  point_difference integer,
  course_name text,
  played_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  WITH ranked_rounds AS (
    SELECT 
      ar.course_name,
      ar.played_at,
      (ranking_entry->>'player_name')::text as player_name,
      (ranking_entry->>'points')::integer as points,
      (ranking_entry->>'position')::integer as position
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
    WHERE ar.group_id = p_group_id
  ),
  victory_margins AS (
    SELECT 
      r1.player_name as winner,
      r1.points as winner_pts,
      r2.player_name as second,
      r2.points as second_pts,
      r1.points - r2.points as margin,
      r1.course_name,
      r1.played_at
    FROM ranked_rounds r1
    JOIN ranked_rounds r2 ON r1.course_name = r2.course_name 
      AND r1.played_at = r2.played_at 
      AND r1.position = 1 
      AND r2.position = 2
  )
  SELECT 
    winner,
    winner_pts,
    second,
    second_pts,
    margin,
    course_name,
    played_at
  FROM victory_margins
  ORDER BY margin DESC, played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get head-to-head comparison between two players
CREATE OR REPLACE FUNCTION get_head_to_head(p_group_id uuid, player1_name text, player2_name text)
RETURNS TABLE (
  player1_wins bigint,
  player2_wins bigint,
  ties bigint,
  total_meetings bigint,
  player1_avg_score numeric,
  player2_avg_score numeric,
  player1_best_score integer,
  player2_best_score integer
) AS $$
BEGIN
  RETURN QUERY
  WITH player_performances AS (
    SELECT 
      ar.id as round_id,
      ar.played_at,
      (ranking_entry->>'player_name')::text as player_name,
      (ranking_entry->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
    WHERE ar.group_id = p_group_id
      AND (ranking_entry->>'player_name')::text IN (player1_name, player2_name)
  ),
  round_matchups AS (
    SELECT 
      p1.round_id,
      p1.points as p1_points,
      p2.points as p2_points
    FROM player_performances p1
    JOIN player_performances p2 ON p1.round_id = p2.round_id
    WHERE p1.player_name = player1_name AND p2.player_name = player2_name
  )
  SELECT 
    COUNT(*) FILTER (WHERE p1_points > p2_points) as player1_wins,
    COUNT(*) FILTER (WHERE p2_points > p1_points) as player2_wins,
    COUNT(*) FILTER (WHERE p1_points = p2_points) as ties,
    COUNT(*) as total_meetings,
    ROUND(AVG(p1_points), 2) as player1_avg,
    ROUND(AVG(p2_points), 2) as player2_avg,
    MAX(p1_points) as player1_best,
    MAX(p2_points) as player2_best
  FROM round_matchups;
END;
$$ LANGUAGE plpgsql;