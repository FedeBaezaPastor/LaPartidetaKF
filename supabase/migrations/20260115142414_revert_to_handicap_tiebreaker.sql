/*
  # Revert to Handicap-Based Tiebreaker for Award Rankings

  1. Changes
    - Reverts all ranking functions to use handicap as tiebreaker
    - Restores original ordering logic (lower handicap wins in case of tie)

  2. Notes
    - This is the correct behavior for golf rankings
*/

-- Function to get "El Patrocinador" ranking (most beers paid)
DROP FUNCTION IF EXISTS get_patrocinador_ranking(uuid);
CREATE OR REPLACE FUNCTION get_patrocinador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_beers_paid bigint,
  total_rounds bigint,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'beers_paid')::integer)::bigint as beers_paid,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.beers_paid,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.beers_paid DESC, psg.avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Barra Libre" ranking (most beers received)
DROP FUNCTION IF EXISTS get_barra_libre_ranking(uuid);
CREATE OR REPLACE FUNCTION get_barra_libre_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_beers_won bigint,
  total_rounds bigint,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'beers_won')::integer)::bigint as beers_won,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.beers_won,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.beers_won DESC, psg.avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Corto" ranking (most "no pasó de rojas")
DROP FUNCTION IF EXISTS get_corto_ranking(uuid);
CREATE OR REPLACE FUNCTION get_corto_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.no_paso_count,
    psg.avg_handicap,
    psg.rounds
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.no_paso_count DESC, psg.avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "Driver de Oro" ranking (fewest "no pasó de rojas")
DROP FUNCTION IF EXISTS get_driver_oro_ranking(uuid);
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.no_paso_count,
    psg.avg_handicap,
    psg.rounds
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.no_paso_count ASC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "El Shark" ranking (most daily wins)
DROP FUNCTION IF EXISTS get_shark_ranking(uuid);
CREATE OR REPLACE FUNCTION get_shark_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_wins bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'daily_wins')::integer)::bigint as wins,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.wins,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.wins DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "El Metrónomo" ranking (best average score)
DROP FUNCTION IF EXISTS get_metronomo_ranking(uuid);
CREATE OR REPLACE FUNCTION get_metronomo_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  average_score numeric,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      AVG((player_stat->>'stableford_points')::numeric) as avg_score,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
    HAVING COUNT(*) >= 3
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.avg_score,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.avg_score DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "El Viciado" ranking (most rounds played)
DROP FUNCTION IF EXISTS get_viciado_ranking(uuid);
CREATE OR REPLACE FUNCTION get_viciado_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      COUNT(*)::bigint as rounds,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.rounds DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "El Francotirador" ranking (most eagles)
DROP FUNCTION IF EXISTS get_francotirador_ranking(uuid);
CREATE OR REPLACE FUNCTION get_francotirador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_eagles bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_hole_results AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (jsonb_array_elements((player_stat->'hole_results')::jsonb)->>'result')::text as result,
      (player_stat->>'handicap')::numeric as hcp
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_stats_grouped AS (
    SELECT 
      pname,
      COUNT(*) FILTER (WHERE result = 'Eagle') as eagles,
      AVG(hcp) as avg_handicap,
      (SELECT COUNT(*) FROM archived_rounds ar2 
       CROSS JOIN jsonb_array_elements(ar2.player_stats) AS ps2
       WHERE ar2.group_id = p_group_id 
       AND (ps2->>'player_name')::text = phr.pname)::bigint as rounds
    FROM player_hole_results phr
    GROUP BY pname
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.eagles::bigint,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  WHERE psg.eagles > 0
  ORDER BY psg.eagles DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "La Máquina" ranking (most birdies)
DROP FUNCTION IF EXISTS get_maquina_ranking(uuid);
CREATE OR REPLACE FUNCTION get_maquina_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_birdies bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_hole_results AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (jsonb_array_elements((player_stat->'hole_results')::jsonb)->>'result')::text as result,
      (player_stat->>'handicap')::numeric as hcp
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_stats_grouped AS (
    SELECT 
      pname,
      COUNT(*) FILTER (WHERE result = 'Birdie') as birdies,
      AVG(hcp) as avg_handicap,
      (SELECT COUNT(*) FROM archived_rounds ar2 
       CROSS JOIN jsonb_array_elements(ar2.player_stats) AS ps2
       WHERE ar2.group_id = p_group_id 
       AND (ps2->>'player_name')::text = phr.pname)::bigint as rounds
    FROM player_hole_results phr
    GROUP BY pname
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.birdies::bigint,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  WHERE psg.birdies > 0
  ORDER BY psg.birdies DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "Amigo del +1" ranking (most bogeys)
DROP FUNCTION IF EXISTS get_amigo_del_mas_uno_ranking(uuid);
CREATE OR REPLACE FUNCTION get_amigo_del_mas_uno_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_bogeys bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_hole_results AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (jsonb_array_elements((player_stat->'hole_results')::jsonb)->>'result')::text as result,
      (player_stat->>'handicap')::numeric as hcp
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_stats_grouped AS (
    SELECT 
      pname,
      COUNT(*) FILTER (WHERE result = 'Bogey') as bogeys,
      AVG(hcp) as avg_handicap,
      (SELECT COUNT(*) FROM archived_rounds ar2 
       CROSS JOIN jsonb_array_elements(ar2.player_stats) AS ps2
       WHERE ar2.group_id = p_group_id 
       AND (ps2->>'player_name')::text = phr.pname)::bigint as rounds
    FROM player_hole_results phr
    GROUP BY pname
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.bogeys::bigint,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  WHERE psg.bogeys > 0
  ORDER BY psg.bogeys DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "Rey del Bosque" ranking (most double bogeys or worse)
DROP FUNCTION IF EXISTS get_rey_del_bosque_ranking(uuid);
CREATE OR REPLACE FUNCTION get_rey_del_bosque_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_double_bogeys_plus bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_hole_results AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (jsonb_array_elements((player_stat->'hole_results')::jsonb)->>'result')::text as result,
      (player_stat->>'handicap')::numeric as hcp
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_stats_grouped AS (
    SELECT 
      pname,
      COUNT(*) FILTER (WHERE result IN ('Double Bogey', 'Triple Bogey+')) as db_plus,
      AVG(hcp) as avg_handicap,
      (SELECT COUNT(*) FROM archived_rounds ar2 
       CROSS JOIN jsonb_array_elements(ar2.player_stats) AS ps2
       WHERE ar2.group_id = p_group_id 
       AND (ps2->>'player_name')::text = phr.pname)::bigint as rounds
    FROM player_hole_results phr
    GROUP BY pname
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.db_plus::bigint,
    psg.rounds,
    psg.avg_handicap
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  WHERE psg.db_plus > 0
  ORDER BY psg.db_plus DESC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;

-- Function to get "El Topo" ranking (best handicap improvement)
DROP FUNCTION IF EXISTS get_topo_ranking(uuid);
CREATE OR REPLACE FUNCTION get_topo_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  handicap_improvement numeric,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_handicaps AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'handicap')::numeric as hcp,
      ar.completed_at,
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.completed_at ASC) as first_round,
      ROW_NUMBER() OVER (PARTITION BY (player_stat->>'player_name')::text ORDER BY ar.completed_at DESC) as last_round
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  ),
  player_improvements AS (
    SELECT 
      pname,
      MAX(CASE WHEN first_round = 1 THEN hcp END) - MAX(CASE WHEN last_round = 1 THEN hcp END) as improvement,
      MAX(CASE WHEN last_round = 1 THEN hcp END) as current_hcp,
      COUNT(*) as rounds
    FROM player_handicaps
    GROUP BY pname
    HAVING COUNT(*) >= 3
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    pi_imp.pname,
    pi.pid,
    pi_imp.improvement,
    pi_imp.rounds::bigint,
    pi_imp.current_hcp
  FROM player_improvements pi_imp
  LEFT JOIN player_ids pi ON pi_imp.pname = pi.pname
  WHERE pi_imp.improvement > 0
  ORDER BY pi_imp.improvement DESC, pi_imp.current_hcp ASC
  LIMIT 20;
END;
$$;
