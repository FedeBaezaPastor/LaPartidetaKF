/*
  # Update beer statistics to use daily rankings

  1. Changes
    - Recreate get_divend_beer_statistics to use daily_rankings table
    - Recreate get_detailed_player_statistics to calculate beers from daily_rankings
    - Beer statistics now reflect the daily classification logic

  2. Logic
    - Beers are calculated from daily_rankings, not individual rounds
    - Players receive/pay based on their position in the daily leaderboard
    - Odd player counts have a neutral middle position
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS get_divend_beer_statistics();
DROP FUNCTION IF EXISTS get_detailed_player_statistics(uuid);

-- Recreate beer statistics function
CREATE OR REPLACE FUNCTION get_divend_beer_statistics()
RETURNS TABLE (
  player_name text,
  beers_received integer,
  beers_paid integer,
  beer_balance integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dr.player_name,
    COUNT(*) FILTER (WHERE dr.receives_beer = true)::integer as beers_received,
    COUNT(*) FILTER (WHERE dr.pays_beer = true)::integer as beers_paid,
    (COUNT(*) FILTER (WHERE dr.receives_beer = true) - COUNT(*) FILTER (WHERE dr.pays_beer = true))::integer as beer_balance
  FROM daily_rankings dr
  GROUP BY dr.player_name
  ORDER BY beer_balance DESC, player_name ASC;
END;
$$ LANGUAGE plpgsql;

-- Recreate detailed player statistics function
CREATE OR REPLACE FUNCTION get_detailed_player_statistics(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  rounds_played integer,
  total_holes integer,
  avg_score numeric,
  best_score integer,
  worst_score integer,
  total_pars integer,
  total_birdies integer,
  total_eagles integer,
  total_bogeys integer,
  total_double_bogeys integer,
  total_worse integer,
  total_no_paso_rojas integer,
  beers_received integer,
  beers_paid integer,
  beer_balance integer
) AS $$
BEGIN
  RETURN QUERY
  WITH round_stats AS (
    SELECT 
      ar.player_name,
      COUNT(DISTINCT ar.round_id) as rounds_played,
      SUM(ar.holes_played) as total_holes,
      ROUND(AVG(ar.total_points), 2) as avg_score,
      MAX(ar.total_points) as best_score,
      MIN(ar.total_points) as worst_score,
      SUM(ar.pars) as total_pars,
      SUM(ar.birdies) as total_birdies,
      SUM(ar.eagles) as total_eagles,
      SUM(ar.bogeys) as total_bogeys,
      SUM(ar.double_bogeys) as total_double_bogeys,
      SUM(ar.worse_than_double) as total_worse,
      SUM(ar.no_paso_rojas) as total_no_paso_rojas
    FROM archived_rounds ar
    WHERE ar.group_id = p_group_id
    GROUP BY ar.player_name
  ),
  beer_stats AS (
    SELECT 
      dr.player_name,
      COUNT(*) FILTER (WHERE dr.receives_beer = true)::integer as beers_received,
      COUNT(*) FILTER (WHERE dr.pays_beer = true)::integer as beers_paid,
      (COUNT(*) FILTER (WHERE dr.receives_beer = true) - COUNT(*) FILTER (WHERE dr.pays_beer = true))::integer as beer_balance
    FROM daily_rankings dr
    WHERE dr.group_id = p_group_id
    GROUP BY dr.player_name
  )
  SELECT 
    rs.player_name,
    rs.rounds_played,
    rs.total_holes,
    rs.avg_score,
    rs.best_score,
    rs.worst_score,
    rs.total_pars,
    rs.total_birdies,
    rs.total_eagles,
    rs.total_bogeys,
    rs.total_double_bogeys,
    rs.total_worse,
    rs.total_no_paso_rojas,
    COALESCE(bs.beers_received, 0) as beers_received,
    COALESCE(bs.beers_paid, 0) as beers_paid,
    COALESCE(bs.beer_balance, 0) as beer_balance
  FROM round_stats rs
  LEFT JOIN beer_stats bs ON rs.player_name = bs.player_name
  ORDER BY rs.player_name ASC;
END;
$$ LANGUAGE plpgsql;
