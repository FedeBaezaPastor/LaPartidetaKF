-- Spanish Hands: marca por hoyo que suma +1 al ajuste de handicap de la ronda.
ALTER TABLE round_scores
  ADD COLUMN IF NOT EXISTS spanish_hands boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION apply_handicap_adjustments_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_round RECORD;
  v_total_players integer;
  v_top_positions integer;
  v_player RECORD;
  v_old_exact numeric;
  v_old_playing numeric;
  v_new_exact numeric;
  v_new_playing numeric;
  v_adjustment numeric;
  v_playing_adj integer;
BEGIN
  SELECT id, group_id, played_at, final_ranking, player_stats, handicap_adjusted
  INTO v_round
  FROM archived_rounds
  WHERE id = p_round_id;

  IF NOT FOUND OR v_round.handicap_adjusted THEN RETURN; END IF;

  v_total_players := jsonb_array_length(v_round.final_ranking);
  IF v_total_players = 0 THEN RETURN; END IF;
  v_top_positions := FLOOR(v_total_players / 2.0);

  FOR v_player IN
    SELECT
      (fr->>'position')::integer AS position,
      fr->>'player_name' AS player_name,
      p.id AS player_id,
      p.exact_handicap_18,
      p.playing_handicap,
      COALESCE((
        SELECT (ps->>'spanish_hands_count')::integer
        FROM jsonb_array_elements(COALESCE(v_round.player_stats, '[]'::jsonb)) ps
        WHERE ps->>'player_name' = fr->>'player_name'
        LIMIT 1
      ), 0) AS spanish_hands_count
    FROM jsonb_array_elements(v_round.final_ranking) fr
    JOIN players p ON p.name = fr->>'player_name' AND p.group_id = v_round.group_id
    ORDER BY (fr->>'position')::integer
  LOOP
    v_old_exact := v_player.exact_handicap_18;
    v_old_playing := COALESCE(v_player.playing_handicap, v_old_exact);
    v_adjustment := 0;
    v_playing_adj := 0;

    IF v_player.position <= v_top_positions THEN
      v_adjustment := -1;
      v_playing_adj := -1;
    ELSIF NOT (v_total_players % 2 = 1 AND v_player.position = v_top_positions + 1) THEN
      v_adjustment := 1;
      v_playing_adj := 1;
    END IF;

    -- Cada Spanish Hands suma un punto, independientemente de la posición.
    v_adjustment := v_adjustment + v_player.spanish_hands_count;
    v_playing_adj := v_playing_adj + v_player.spanish_hands_count;

    v_new_exact := LEAST(12, GREATEST(0, v_old_exact + v_adjustment));
    v_new_playing := LEAST(12, GREATEST(0, v_old_playing + v_playing_adj));
    v_adjustment := v_new_exact - v_old_exact;
    v_playing_adj := v_new_playing - v_old_playing;

    IF v_adjustment != 0 OR v_playing_adj != 0 THEN
      UPDATE players SET
        exact_handicap = v_new_exact,
        exact_handicap_18 = v_new_exact,
        playing_handicap = v_new_playing,
        updated_at = now()
      WHERE id = v_player.player_id;

      INSERT INTO handicap_adjustments (
        group_id, player_id, player_name, adjustment_date,
        ranking_position, hcp_before, hcp_after, adjustment,
        playing_handicap_before, archived_round_id
      ) VALUES (
        v_round.group_id, v_player.player_id, v_player.player_name,
        DATE(v_round.played_at), v_player.position,
        v_old_exact, v_new_exact, v_adjustment,
        v_old_playing, p_round_id
      )
      ON CONFLICT (group_id, player_id, archived_round_id)
      DO UPDATE SET
        ranking_position = EXCLUDED.ranking_position,
        hcp_before = EXCLUDED.hcp_before,
        hcp_after = EXCLUDED.hcp_after,
        adjustment = EXCLUDED.adjustment,
        playing_handicap_before = EXCLUDED.playing_handicap_before,
        created_at = now();
    END IF;
  END LOOP;

  UPDATE archived_rounds SET handicap_adjusted = true WHERE id = p_round_id;
END;
$$;
