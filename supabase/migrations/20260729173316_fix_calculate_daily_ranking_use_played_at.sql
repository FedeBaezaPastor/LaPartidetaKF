/*
# Fix calculate_daily_ranking to use played_at instead of archived_at

## Problem
The `calculate_daily_ranking` function filters archived rounds by
`DATE(ar.archived_at) = p_date`. However, the auto-trigger
`auto_calculate_daily_ranking()` passes `DATE(NEW.played_at)` as `p_date`.

When rounds were archived the same day they were played, `archived_at` and
`played_at` fell on the same date and the filter worked. But now rounds can be
archived days later (e.g. via the "Actualizar HCP" flow), so `archived_at`
(today) no longer matches `played_at` (the day the round was actually played).
The function finds zero matching rows and inserts nothing into
`daily_rankings`, which breaks all downstream statistics (beer rankings,
award rankings, handicap history, etc.).

## Fix
Change the WHERE clause in `calculate_daily_ranking` from
`DATE(ar.archived_at) = p_date` to `DATE(ar.played_at) = p_date` so the
function consistently groups by the date the round was played, matching what
the trigger passes.

## Recalculation
After replacing the function, recalculate daily rankings for all existing
archived rounds to repair any missing or stale data caused by the old filter.

## No schema changes
No tables, columns, indexes, or policies are altered — only a function body
is replaced and existing data is recalculated.
*/

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
      AND DATE(ar.played_at) = p_date
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

-- Recalculate daily rankings for all existing archived rounds
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT DISTINCT
      group_id,
      DATE(played_at) as ranking_date
    FROM archived_rounds
    WHERE group_id IS NOT NULL
    ORDER BY ranking_date DESC
  LOOP
    PERFORM calculate_daily_ranking(rec.group_id, rec.ranking_date);
    RAISE NOTICE 'Recalculated daily ranking for group % on date %', rec.group_id, rec.ranking_date;
  END LOOP;
END;
$$;
