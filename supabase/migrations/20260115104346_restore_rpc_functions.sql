-- ============================================================
-- FUNCIONES RPC - LÓGICA DE NEGOCIO
-- ============================================================

-- Función: calculate_daily_ranking
CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM daily_rankings
  WHERE group_id = p_group_id
    AND ranking_date = p_date;

  WITH player_totals AS (
    SELECT
      p_group_id as group_id,
      p_date as ranking_date,
      (elem->>'player_name')::text as player_name,
      SUM((elem->>'points')::numeric) as total_points,
      MIN((elem->>'hcp_juego')::integer) as hcp_juego,
      SUM(
        COALESCE(
          (SELECT SUM((score->>'gross_strokes')::integer)
           FROM jsonb_array_elements(ar.hole_scores) AS score
           WHERE score->>'player_name' = elem->>'player_name'
          ), 0)
      ) as total_strokes,
      SUM((elem->>'points')::numeric) as total_stableford_net
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND DATE(ar.archived_at) = p_date
    GROUP BY (elem->>'player_name')::text
  ),
  ranked_players AS (
    SELECT
      group_id,
      ranking_date,
      player_name,
      total_points,
      hcp_juego,
      total_strokes,
      total_stableford_net,
      ROW_NUMBER() OVER (
        ORDER BY
          total_points DESC,
          hcp_juego ASC,
          player_name ASC
      ) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
  )
  INSERT INTO daily_rankings (
    group_id,
    ranking_date,
    player_name,
    total_points,
    hcp_juego,
    position,
    receives_beer,
    pays_beer,
    total_strokes,
    total_stableford_net,
    handicap_play
  )
  SELECT
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.hcp_juego,
    rp.position,
    rp.position <= FLOOR(pc.total / 2.0) as receives_beer,
    CASE
      WHEN pc.total % 2 = 0 THEN rp.position > (pc.total / 2)
      ELSE rp.position > FLOOR(pc.total / 2.0) + 1
    END as pays_beer,
    rp.total_strokes,
    rp.total_stableford_net,
    rp.hcp_juego::numeric
  FROM ranked_players rp
  CROSS JOIN player_count pc;
END;
$$;

-- Función: get_patrocinador_ranking
CREATE OR REPLACE FUNCTION get_patrocinador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  total_beers_paid bigint,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    COUNT(*) FILTER (WHERE dr.pays_beer = true) as total_beers_paid,
    COUNT(DISTINCT dr.ranking_date) as total_rounds
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.pays_beer = true) > 0
  ORDER BY total_beers_paid DESC, player_name ASC
  LIMIT 10;
END;
$$;

-- Función: get_barra_libre_ranking
CREATE OR REPLACE FUNCTION get_barra_libre_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  total_beers_won bigint,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    COUNT(*) FILTER (WHERE dr.receives_beer = true) as total_beers_won,
    COUNT(DISTINCT dr.ranking_date) as total_rounds
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.receives_beer = true) > 0
  ORDER BY total_beers_won DESC, player_name ASC
  LIMIT 10;
END;
$$;

-- Función: get_corto_ranking
CREATE OR REPLACE FUNCTION get_corto_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  current_handicap numeric,
  rounds_played bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.name as player_name,
    p.exact_handicap as current_handicap,
    COUNT(DISTINCT dr.ranking_date) as rounds_played
  FROM players p
  LEFT JOIN daily_rankings dr ON dr.player_name = p.name AND dr.group_id = p.group_id
  WHERE p.group_id = p_group_id
  GROUP BY p.id, p.name, p.exact_handicap
  ORDER BY p.exact_handicap ASC, rounds_played DESC
  LIMIT 10;
END;
$$;

-- Función: get_driver_oro_ranking
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  avg_points numeric,
  total_rounds bigint,
  total_points numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    ROUND(AVG(dr.total_points), 2) as avg_points,
    COUNT(DISTINCT dr.ranking_date) as total_rounds,
    SUM(dr.total_points) as total_points
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(DISTINCT dr.ranking_date) >= 3
  ORDER BY avg_points DESC, total_rounds DESC
  LIMIT 10;
END;
$$;

-- Función: get_francotirador_ranking
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

-- Función: get_maquina_ranking
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

-- Función: get_amigo_del_mas_uno_ranking
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

-- Función: get_rey_del_bosque_ranking
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

-- Función: get_detailed_player_statistics
CREATE OR REPLACE FUNCTION get_detailed_player_statistics(p_group_id uuid, p_player_id uuid)
RETURNS TABLE (
  total_rounds bigint,
  total_holes bigint,
  avg_score numeric,
  best_score integer,
  worst_score integer,
  total_birdies bigint,
  total_pars bigint,
  total_bogeys bigint,
  total_double_bogeys bigint,
  total_beers_won bigint,
  total_beers_paid bigint,
  current_handicap numeric,
  handicap_trend text
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_player_name text;
BEGIN
  SELECT name INTO v_player_name
  FROM players
  WHERE id = p_player_id AND group_id = p_group_id;

  RETURN QUERY
  WITH round_stats AS (
    SELECT
      COALESCE((stat->>'total_holes_played')::integer, 0) as holes,
      COALESCE((stat->'hole_results'->>'birdies')::integer, 0) as birdies,
      COALESCE((stat->'hole_results'->>'pars')::integer, 0) as pars,
      COALESCE((stat->'hole_results'->>'bogeys')::integer, 0) as bogeys,
      COALESCE((stat->'hole_results'->>'double_bogeys')::integer, 0) as double_bogeys
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS stat
    WHERE ar.group_id = p_group_id
      AND (stat->>'player_name')::text = v_player_name
  ),
  beer_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE receives_beer = true) as beers_won,
      COUNT(*) FILTER (WHERE pays_beer = true) as beers_paid
    FROM daily_rankings
    WHERE group_id = p_group_id
      AND player_name = v_player_name
  ),
  score_stats AS (
    SELECT
      COUNT(DISTINCT ranking_date) as rounds,
      AVG(total_points) as avg_pts,
      MAX(total_points::integer) as best_pts,
      MIN(total_points::integer) as worst_pts
    FROM daily_rankings
    WHERE group_id = p_group_id
      AND player_name = v_player_name
  ),
  player_info AS (
    SELECT exact_handicap
    FROM players
    WHERE id = p_player_id
  )
  SELECT
    COALESCE(ss.rounds, 0) as total_rounds,
    COALESCE(SUM(rs.holes), 0) as total_holes,
    COALESCE(ROUND(ss.avg_pts, 2), 0) as avg_score,
    COALESCE(ss.best_pts, 0) as best_score,
    COALESCE(ss.worst_pts, 0) as worst_score,
    COALESCE(SUM(rs.birdies), 0) as total_birdies,
    COALESCE(SUM(rs.pars), 0) as total_pars,
    COALESCE(SUM(rs.bogeys), 0) as total_bogeys,
    COALESCE(SUM(rs.double_bogeys), 0) as total_double_bogeys,
    COALESCE(bs.beers_won, 0) as total_beers_won,
    COALESCE(bs.beers_paid, 0) as total_beers_paid,
    COALESCE(pi.exact_handicap, 0) as current_handicap,
    'stable'::text as handicap_trend
  FROM round_stats rs
  CROSS JOIN beer_stats bs
  CROSS JOIN score_stats ss
  CROSS JOIN player_info pi
  GROUP BY ss.rounds, ss.avg_pts, ss.best_pts, ss.worst_pts, bs.beers_won, bs.beers_paid, pi.exact_handicap;
END;
$$;

-- Función: reset_reference_sequence
CREATE OR REPLACE FUNCTION reset_reference_sequence(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN;
END;
$$;