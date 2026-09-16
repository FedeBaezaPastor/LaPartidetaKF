BEGIN;

ALTER TABLE public.players ADD COLUMN is_guest boolean NOT NULL DEFAULT false;
ALTER TABLE public.round_players ADD COLUMN is_guest boolean NOT NULL DEFAULT false;
ALTER TABLE public.players ADD CONSTRAINT guest_has_no_account CHECK(NOT is_guest OR auth_user_id IS NULL);

CREATE OR REPLACE FUNCTION public.list_group_game_players(p_group uuid) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 RETURN QUERY SELECT to_jsonb(p) || jsonb_build_object('can_manage',coalesce(public.can_manage_group_messages(p_group),false) AND NOT public.is_app_user_read_only(),'name',CASE WHEN p.auth_user_id IS NULL THEN p.name ELSE coalesce(u.nick,u.display_name,'Cuenta pendiente') END)
 FROM public.players p LEFT JOIN public.user_profiles u ON u.user_id=p.auth_user_id
 WHERE p.group_id=p_group AND (p.auth_user_id IS NULL OR
  ((public.is_group_member(p_group) OR public.can_manage_group_messages(p_group)) AND EXISTS(SELECT 1 FROM public.group_members m WHERE m.group_id=p_group AND m.user_id=p.auth_user_id)))
 ORDER BY p.name;
END $$;

-- Only managers can change whether a reusable group record is a member.
CREATE FUNCTION public.guard_guest_player() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
   IF OLD.is_guest AND OLD.group_id IS NOT NULL THEN PERFORM public.require_group_manager(OLD.group_id); END IF;
   RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' AND (OLD.is_guest OR NEW.is_guest) AND coalesce(OLD.group_id,NEW.group_id) IS NOT NULL THEN
   PERFORM public.require_group_result_writer(coalesce(OLD.group_id,NEW.group_id));
   IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'La identidad de la ficha es inmutable'; END IF;
 END IF;
 IF TG_OP='UPDATE' AND (NEW.is_guest,NEW.group_id) IS DISTINCT FROM (OLD.is_guest,OLD.group_id)
    AND (NEW.group_id IS NOT NULL OR OLD.group_id IS NOT NULL) THEN
   IF OLD.group_id IS NOT NULL THEN PERFORM public.require_group_manager(OLD.group_id); END IF;
   IF NEW.group_id IS NOT NULL AND NEW.group_id IS DISTINCT FROM OLD.group_id THEN PERFORM public.require_group_manager(NEW.group_id); END IF;
 ELSIF TG_OP='INSERT' AND NEW.group_id IS NOT NULL AND NEW.auth_user_id IS NULL THEN
   IF NEW.is_guest THEN PERFORM public.require_group_result_writer(NEW.group_id);
   ELSE PERFORM public.require_group_manager(NEW.group_id); END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guest_player_guard BEFORE INSERT OR UPDATE OR DELETE ON public.players FOR EACH ROW EXECUTE FUNCTION public.guard_guest_player();

-- Snapshot from the trusted group record, including clients using the old API.
CREATE FUNCTION public.guard_guest_participation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; r public.golf_rounds; v_slope numeric;
BEGIN
 IF TG_OP IN ('UPDATE','DELETE') AND OLD.is_guest THEN
   SELECT * INTO r FROM public.golf_rounds WHERE id=OLD.round_id;
   -- Cascading deletion may already have removed the parent; the reusable
   -- record still identifies the group whose writer must authorize removal.
   IF r.group_id IS NULL THEN SELECT group_id INTO r.group_id FROM public.players WHERE id=OLD.player_id; END IF;
   PERFORM public.require_group_result_writer(r.group_id);
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF TG_OP='UPDATE' THEN
   IF (NEW.is_guest,NEW.round_id,NEW.player_id,NEW.user_id) IS DISTINCT FROM (OLD.is_guest,OLD.round_id,OLD.player_id,OLD.user_id) THEN
     RAISE EXCEPTION 'La condición y la identidad de la participación son inmutables';
   END IF;
   RETURN NEW;
 END IF;
 SELECT * INTO r FROM public.golf_rounds WHERE id=NEW.round_id FOR UPDATE;
 IF r.group_id IS NULL THEN NEW.is_guest:=false; RETURN NEW; END IF;
 SELECT * INTO p FROM public.players WHERE id=NEW.player_id FOR SHARE;
 IF p.id IS NULL OR p.group_id IS DISTINCT FROM r.group_id THEN RAISE EXCEPTION 'El jugador no pertenece a este grupo'; END IF;
 IF p.is_guest THEN
   PERFORM public.require_group_result_writer(r.group_id);
   IF r.status<>'active' THEN RAISE EXCEPTION 'La partida no está disponible en este grupo'; END IF;
   IF EXISTS(SELECT 1 FROM public.round_players WHERE round_id=r.id AND player_id=p.id) THEN RAISE EXCEPTION 'El jugador ya está en la partida'; END IF;
   IF EXISTS(SELECT 1 FROM public.round_players rp JOIN public.golf_rounds gr ON gr.id=rp.round_id WHERE rp.player_id=p.id AND gr.status='active' AND gr.id<>r.id AND gr.group_id=r.group_id) THEN
     RAISE EXCEPTION 'El jugador está en otra partida activa';
   END IF;
   IF (SELECT count(*) FROM public.round_players WHERE round_id=r.id)>=(CASE r.game_mode WHEN 'match' THEN 2 WHEN 'sindicato' THEN 3 ELSE 4 END) THEN
     RAISE EXCEPTION 'La modalidad no admite más jugadores';
   END IF;
 END IF;
 NEW.is_guest:=p.is_guest;
 IF p.auth_user_id IS NULL THEN
   SELECT CASE WHEN r.num_holes=18 THEN t.slope_18 WHEN r.holes_range='10-18' THEN t.slope_9_ii ELSE t.slope_9_i END INTO v_slope FROM public.tees t WHERE t.id=r.tee_id;
   v_slope:=CASE WHEN r.use_slope THEN coalesce(r.manual_slope,v_slope,113) ELSE 113 END;
   NEW.name:=p.name;
   NEW.user_id:=NULL;
   NEW.exact_handicap:=p.exact_handicap; NEW.exact_handicap_18:=p.exact_handicap;
   NEW.playing_handicap:=round(p.exact_handicap*(CASE WHEN r.num_holes=18 THEN 2 ELSE 1 END)*v_slope/113);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER b_guest_participation BEFORE INSERT OR UPDATE OR DELETE ON public.round_players FOR EACH ROW EXECUTE FUNCTION public.guard_guest_participation();

CREATE FUNCTION public.add_group_round_player(p_group uuid,p_round uuid,p_name text,p_handicap numeric,p_is_guest boolean DEFAULT false,p_player uuid DEFAULT NULL)
RETURNS public.round_players LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.golf_rounds; p public.players; result public.round_players; v_slope numeric; v_limit integer;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 PERFORM public.require_group_result_writer(p_group);
 SELECT * INTO r FROM public.golf_rounds WHERE id=p_round FOR UPDATE;
 IF r.id IS NULL OR r.group_id IS DISTINCT FROM p_group OR r.status<>'active' THEN RAISE EXCEPTION 'La partida no está disponible en este grupo'; END IF;
 IF nullif(trim(p_name),'') IS NULL OR p_handicap IS NULL OR p_handicap<0 OR p_handicap>27 OR p_is_guest IS NULL OR p_handicap::text IN ('NaN','Infinity','-Infinity') THEN
   RAISE EXCEPTION 'Indica un nombre y un hándicap válido entre 0 y 54 para 18 hoyos';
 END IF;
 v_limit:=CASE r.game_mode WHEN 'match' THEN 2 WHEN 'sindicato' THEN 3 ELSE 4 END;
 IF (SELECT count(*) FROM public.round_players WHERE round_id=r.id)>=v_limit THEN RAISE EXCEPTION 'La modalidad no admite más jugadores'; END IF;
 IF p_player IS NOT NULL THEN
   SELECT * INTO p FROM public.players WHERE id=p_player AND group_id=p_group FOR UPDATE;
   IF p.id IS NULL THEN RAISE EXCEPTION 'El jugador no está disponible en este grupo'; END IF;
 ELSE
   IF (SELECT count(*) FROM public.players WHERE group_id=p_group AND auth_user_id IS NULL AND lower(name)=lower(trim(p_name)))>1 THEN
     RAISE EXCEPTION 'Hay varias fichas con este nombre. Selecciona al jugador de la lista';
   END IF;
   SELECT * INTO p FROM public.players WHERE group_id=p_group AND auth_user_id IS NULL AND lower(name)=lower(trim(p_name)) FOR UPDATE;
   IF p.id IS NULL THEN
     IF NOT p_is_guest THEN PERFORM public.require_group_manager(p_group); END IF;
     INSERT INTO public.players(group_id,name,exact_handicap,exact_handicap_18,is_guest)
       VALUES(p_group,trim(p_name),p_handicap,p_handicap,p_is_guest) RETURNING * INTO p;
   END IF;
 END IF;
 IF p.auth_user_id IS NOT NULL THEN
   IF p_is_guest THEN RAISE EXCEPTION 'Un miembro registrado no puede añadirse como invitado'; END IF;
   IF p.exact_handicap IS DISTINCT FROM p_handicap THEN RAISE EXCEPTION 'El hándicap ha cambiado. Actualiza y selecciona de nuevo al jugador.' USING ERRCODE='40001'; END IF;
 ELSE
   IF p.is_guest AND NOT p_is_guest THEN
     PERFORM public.require_group_manager(p_group);
     UPDATE public.players SET is_guest=false WHERE id=p.id RETURNING * INTO p;
   ELSIF NOT p.is_guest AND p_is_guest THEN
     RAISE EXCEPTION 'La ficha ya es miembro del grupo. Selecciónala en la lista';
   END IF;
   UPDATE public.players SET exact_handicap=p_handicap,exact_handicap_18=p_handicap,updated_at=now() WHERE id=p.id RETURNING * INTO p;
 END IF;
 IF EXISTS(SELECT 1 FROM public.round_players WHERE round_id=r.id AND player_id=p.id) THEN RAISE EXCEPTION 'El jugador ya está en la partida'; END IF;
 IF EXISTS(SELECT 1 FROM public.round_players rp JOIN public.golf_rounds gr ON gr.id=rp.round_id WHERE rp.player_id=p.id AND gr.status='active' AND gr.id<>r.id AND gr.group_id=p_group) THEN
   RAISE EXCEPTION 'El jugador está en otra partida activa';
 END IF;
 SELECT CASE WHEN r.num_holes=18 THEN t.slope_18 WHEN r.holes_range='10-18' THEN t.slope_9_ii ELSE t.slope_9_i END INTO v_slope FROM public.tees t WHERE t.id=r.tee_id;
 v_slope:=CASE WHEN r.use_slope THEN coalesce(r.manual_slope,v_slope,113) ELSE 113 END;
 INSERT INTO public.round_players(round_id,player_id,name,exact_handicap,exact_handicap_18,playing_handicap,is_guest)
 VALUES(r.id,p.id,p.name,p.exact_handicap,p.exact_handicap,round(p.exact_handicap*(CASE WHEN r.num_holes=18 THEN 2 ELSE 1 END)*v_slope/113),p.is_guest) RETURNING * INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.add_group_round_player(uuid,uuid,text,numeric,boolean,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_group_round_player(uuid,uuid,text,numeric,boolean,uuid) TO authenticated;

-- Use server scores for every sourced group archive.
CREATE OR REPLACE FUNCTION public.guard_linked_archive() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.golf_rounds; has_linked boolean;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF TG_OP='INSERT' THEN
  SELECT * INTO r FROM public.golf_rounds WHERE id=NEW.source_round_id FOR UPDATE;
  has_linked:=EXISTS(SELECT 1 FROM public.round_players rp JOIN public.players p ON p.id=rp.player_id WHERE rp.round_id=r.id AND p.auth_user_id IS NOT NULL)
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.final_ranking,'[]')) f JOIN public.players p ON p.id::text=f->>'player_db_id' WHERE p.auth_user_id IS NOT NULL);
  IF has_linked OR r.id IS NOT NULL THEN
   PERFORM public.require_group_result_writer(NEW.group_id);
   IF r.id IS NULL OR r.group_id IS DISTINCT FROM NEW.group_id OR r.status<>'completed' THEN
    RAISE EXCEPTION 'Es necesaria una partida completada del mismo grupo';
   END IF;
   -- The rank and Spanish Hands used to adjust linked records come from live
   -- scores, never from client-supplied archive JSON. Keep both identity UUIDs.
   WITH participants AS (
    SELECT rp.*,row_number() OVER(ORDER BY rp.created_at,rp.id) AS n FROM public.round_players rp WHERE rp.round_id=r.id
   ), totals AS (
    SELECT rp.*,coalesce((SELECT sum(CASE WHEN coalesce(r.game_mode,'stableford')='stableford' THEN rs.stableford_points ELSE coalesce(rs.mode_points,0) END) FROM public.round_scores rs WHERE rs.player_id=rp.id AND rs.round_id=r.id),0) AS points,
     (SELECT count(*) FROM public.round_scores rs WHERE rs.player_id=rp.id AND rs.round_id=r.id AND rs.spanish_hands) AS hands,
     sum(rp.playing_handicap) OVER(PARTITION BY (rp.n-1)/2) AS team_hcp
    FROM participants rp
   ), ranked AS (
    SELECT *,row_number() OVER(ORDER BY points DESC,CASE WHEN r.game_mode='parejas' THEN team_hcp ELSE playing_handicap END,playing_handicap,created_at,id) AS position FROM totals
   )
   SELECT jsonb_agg(jsonb_build_object('position',position,'player_name',name,'player_id',id,'player_db_id',player_id,'points',points,'hcp_juego',playing_handicap,'handicap',exact_handicap,'game_mode',coalesce(r.game_mode,'stableford')) ORDER BY position),
    jsonb_agg(coalesce((SELECT ps FROM jsonb_array_elements(coalesce(NEW.player_stats,'[]')) ps WHERE ps->>'player_id'=ranked.id::text LIMIT 1),'{}') || jsonb_build_object('player_id',id,'player_db_id',player_id,'player_name',name,'spanish_hands_count',hands) ORDER BY position)
   INTO NEW.final_ranking,NEW.player_stats FROM ranked;
   NEW.handicap_adjusted:=false;
  END IF;
 ELSIF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(OLD.final_ranking,'[]')) f JOIN public.players p ON p.id::text=f->>'player_db_id' WHERE p.auth_user_id IS NOT NULL) THEN
  IF TG_OP='DELETE' THEN PERFORM public.require_group_manager(OLD.group_id);
  ELSIF (NEW.group_id,NEW.final_ranking,NEW.player_stats,NEW.source_round_id) IS DISTINCT FROM (OLD.group_id,OLD.final_ranking,OLD.player_stats,OLD.source_round_id) THEN
   RAISE EXCEPTION 'Los resultados vinculados archivados son inmutables';
  ELSIF OLD.handicap_adjusted AND NOT NEW.handicap_adjusted THEN
   RAISE EXCEPTION 'Los ajustes de esta partida ya se han aplicado';
  END IF;
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;

-- Archive all participants, stamp the immutable guest snapshot after the
-- registered-result guard has rebuilt its ranking from the live scores.
CREATE FUNCTION public.snapshot_archive_guests() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.golf_rounds; item jsonb; participant public.round_players;
BEGIN
 IF TG_OP='DELETE' THEN
   IF OLD.group_id IS NOT NULL AND OLD.source_round_id IS NOT NULL THEN PERFORM public.require_group_manager(OLD.group_id); END IF;
   RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' THEN
   IF (NEW.final_ranking,NEW.player_stats,NEW.hole_scores,NEW.group_id,NEW.source_round_id) IS DISTINCT FROM
      (OLD.final_ranking,OLD.player_stats,OLD.hole_scores,OLD.group_id,OLD.source_round_id) THEN
     RAISE EXCEPTION 'Los resultados archivados y la condición de invitado son inmutables';
   END IF;
   RETURN NEW;
 END IF;
 IF NEW.group_id IS NULL THEN RETURN NEW; END IF;
 IF NEW.source_round_id IS NULL THEN
   -- Historical imports without a source cannot claim the new guest metadata.
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.final_ranking,'[]') || coalesce(NEW.player_stats,'[]') || coalesce(NEW.hole_scores,'[]')) f WHERE f ? 'is_guest') THEN
     RAISE EXCEPTION 'Es necesaria una partida de origen para registrar invitados';
   END IF;
   RETURN NEW;
 END IF;
 PERFORM public.require_group_result_writer(NEW.group_id);
 SELECT * INTO r FROM public.golf_rounds WHERE id=NEW.source_round_id FOR UPDATE;
 IF r.id IS NULL OR r.group_id IS DISTINCT FROM NEW.group_id OR r.status<>'completed' THEN RAISE EXCEPTION 'Es necesaria una partida completada del mismo grupo'; END IF;
 IF jsonb_array_length(coalesce(NEW.final_ranking,'[]'))<>(SELECT count(*) FROM public.round_players WHERE round_id=r.id) THEN RAISE EXCEPTION 'El archivo debe incluir a todos los participantes'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.final_ranking) f GROUP BY f->>'player_id' HAVING count(*)>1) THEN RAISE EXCEPTION 'Participantes duplicados en el archivo'; END IF;
 FOR item IN SELECT f FROM jsonb_array_elements(NEW.final_ranking) f LOOP
   SELECT * INTO participant FROM public.round_players WHERE round_id=r.id AND id::text=item->>'player_id';
   IF participant.id IS NULL THEN RAISE EXCEPTION 'Participante desconocido en el archivo'; END IF;
 END LOOP;
 SELECT jsonb_agg(f || jsonb_build_object('is_guest',rp.is_guest,'player_db_id',rp.player_id) ORDER BY ord)
 INTO NEW.final_ranking FROM jsonb_array_elements(NEW.final_ranking) WITH ORDINALITY f(f,ord)
 JOIN public.round_players rp ON rp.round_id=r.id AND rp.id::text=f->>'player_id';
 SELECT coalesce(jsonb_agg(ps || jsonb_build_object('is_guest',rp.is_guest,'player_db_id',rp.player_id) ORDER BY ord),'[]')
 INTO NEW.player_stats FROM jsonb_array_elements(coalesce(NEW.player_stats,'[]')) WITH ORDINALITY ps(ps,ord)
 JOIN public.round_players rp ON rp.round_id=r.id AND rp.id::text=ps->>'player_id';
 SELECT coalesce(jsonb_agg(h || jsonb_build_object('is_guest',rp.is_guest,'player_db_id',rp.player_id) ORDER BY ord),'[]')
 INTO NEW.hole_scores FROM jsonb_array_elements(coalesce(NEW.hole_scores,'[]')) WITH ORDINALITY h(h,ord)
 JOIN public.round_players rp ON rp.round_id=r.id AND rp.id::text=h->>'player_id';
 RETURN NEW;
END $$;
CREATE TRIGGER z_archive_guest_snapshot BEFORE INSERT OR UPDATE OR DELETE ON public.archived_rounds FOR EACH ROW EXECUTE FUNCTION public.snapshot_archive_guests();

-- Stable identity for statistical grouping, without assigning an Auth account
-- to legacy results that only contain a name.
CREATE FUNCTION public.statistics_player_id(p_group uuid,p_result jsonb) RETURNS uuid
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT coalesce(nullif(p_result->>'player_db_id','')::uuid,md5('legacy:' || coalesce(p_group::text,'') || ':' || coalesce(p_result->>'player_name',''))::uuid)
$$;

CREATE VIEW public.group_statistics_rounds WITH (security_invoker=true) AS
SELECT ar.id,ar.group_id,ar.course_name,ar.played_at,ar.archived_at,ar.season_id,ar.handicap_adjusted,ar.source_round_id,
 ranking.value AS final_ranking,stats.value AS player_stats,holes.value AS hole_scores
FROM public.archived_rounds ar
CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_agg(f || jsonb_build_object('position',position,'player_id',public.statistics_player_id(ar.group_id,f)) ORDER BY position),'[]') AS value
 FROM (
   SELECT f,row_number() OVER(ORDER BY ord) AS position FROM jsonb_array_elements(coalesce(ar.final_ranking,'[]')) WITH ORDINALITY f(f,ord)
   WHERE NOT coalesce((f->>'is_guest')::boolean,false)
 ) members
) ranking
CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_agg(ps || jsonb_build_object('player_id',public.statistics_player_id(ar.group_id,ps),
   'beers_won',CASE WHEN (f->>'position')::int<=floor(jsonb_array_length(ranking.value)/2.0) THEN 1 ELSE 0 END,
   'beers_paid',CASE WHEN (f->>'position')::int>ceil(jsonb_array_length(ranking.value)/2.0) THEN 1 ELSE 0 END) ORDER BY ord),'[]') AS value
 FROM jsonb_array_elements(coalesce(ar.player_stats,'[]')) WITH ORDINALITY ps(ps,ord)
 JOIN jsonb_array_elements(ranking.value) f ON public.statistics_player_id(ar.group_id,ps)::text=f->>'player_id'
 WHERE NOT coalesce((ps->>'is_guest')::boolean,false)
) stats
CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_agg(h || jsonb_build_object('player_id',public.statistics_player_id(ar.group_id,h)) ORDER BY ord),'[]') AS value
 FROM jsonb_array_elements(coalesce(ar.hole_scores,'[]')) WITH ORDINALITY h(h,ord)
 WHERE NOT coalesce((h->>'is_guest')::boolean,false)
) holes
WHERE jsonb_array_length(ranking.value)>0;
GRANT SELECT ON public.group_statistics_rounds TO anon,authenticated;
REVOKE ALL ON FUNCTION public.guard_guest_player(),public.guard_guest_participation(),public.snapshot_archive_guests() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION apply_handicap_adjustments_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
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
  WHERE id = p_round_id FOR UPDATE;

  IF NOT FOUND OR v_round.handicap_adjusted THEN RETURN; END IF;
  SELECT final_ranking,player_stats INTO v_round.final_ranking,v_round.player_stats
  FROM public.group_statistics_rounds WHERE id=p_round_id;
  IF NOT FOUND THEN
    UPDATE public.archived_rounds SET handicap_adjusted=true WHERE id=p_round_id;
    RETURN;
  END IF;

  v_total_players := jsonb_array_length(v_round.final_ranking);
  IF v_total_players = 0 THEN RETURN; END IF;
  v_top_positions := FLOOR(v_total_players / 2.0);

  FOR v_player IN
    SELECT
      (fr->>'position')::integer AS position,
      fr->>'player_name' AS player_name,
      p.id AS player_id, p.auth_user_id,
      p.exact_handicap_18,
      p.playing_handicap,
      COALESCE((
        SELECT (ps->>'spanish_hands_count')::integer
        FROM jsonb_array_elements(COALESCE(v_round.player_stats, '[]'::jsonb)) ps
        WHERE (ps->>'player_db_id'=p.id::text OR (nullif(ps->>'player_db_id','') IS NULL AND p.auth_user_id IS NULL AND ps->>'player_name'=fr->>'player_name'))
        LIMIT 1
      ), 0) AS spanish_hands_count
    FROM jsonb_array_elements(v_round.final_ranking) fr
    JOIN players p ON p.group_id=v_round.group_id AND (p.id::text=fr->>'player_db_id' OR (nullif(fr->>'player_db_id','') IS NULL AND p.auth_user_id IS NULL AND p.name=fr->>'player_name'))
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
      IF v_player.auth_user_id IS NOT NULL THEN
        PERFORM public.require_group_result_writer(v_round.group_id);
        INSERT INTO public.group_write_permits VALUES(txid_current(),v_player.player_id,'player');
        INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,target_user_id,details)
        VALUES(auth.uid(),coalesce((SELECT nick FROM public.user_profiles WHERE user_id=auth.uid()),'Jugador del grupo'),'group.member.results',v_player.auth_user_id,
          jsonb_build_object('group_id',v_round.group_id,'archive_id',p_round_id,'before',(v_old_exact*2)::text,'after',(v_new_exact*2)::text));
      END IF;
      UPDATE players SET
        exact_handicap = v_new_exact,
        exact_handicap_18 = v_new_exact,
        playing_handicap = v_new_playing,
        updated_at = now()
      WHERE id = v_player.player_id;

      IF v_player.auth_user_id IS NOT NULL THEN
        INSERT INTO public.group_write_permits VALUES(txid_current(),v_player.player_id,'ledger') ON CONFLICT DO NOTHING;
      END IF;
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
      DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=v_player.player_id AND operation='ledger';
    END IF;
  END LOOP;

  UPDATE archived_rounds SET handicap_adjusted = true WHERE id = p_round_id;
END;
$$;


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
      max((elem->>'player_name')::text) as player_name,
      linked.id as game_player_id,
      SUM((elem->>'points')::numeric) as total_points,
      MIN((elem->>'hcp_juego')::integer) as hcp_juego,
      SUM(
        COALESCE(
          (SELECT SUM((score->>'gross_strokes')::integer)
           FROM jsonb_array_elements(ar.hole_scores) AS score
           WHERE (linked.id IS NOT NULL AND score->>'player_id'=elem->>'player_id') OR (linked.id IS NULL AND score->>'player_name'=elem->>'player_name')
          ), 0)
      ) as total_strokes,
      SUM((elem->>'points')::numeric) as total_stableford_net
    FROM public.group_statistics_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    LEFT JOIN players linked ON linked.id::text=elem->>'player_db_id' AND linked.group_id=ar.group_id
    WHERE ar.group_id = p_group_id
      AND DATE(ar.played_at) = p_date
    GROUP BY linked.id, CASE WHEN linked.id IS NULL THEN (elem->>'player_name')::text ELSE NULL END
  ),
  ranked_players AS (
    SELECT
      group_id,
      ranking_date,
      player_name,
      game_player_id,
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
    game_player_id,
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
    rp.game_player_id,
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

-- Existing read-only award RPCs retain their signatures and grants. Patch only
-- their archive read relation to the RLS-respecting member projection. Reject
-- unexpected write bodies instead of risking a change in historical behavior.
DO $$
DECLARE fn record; definition text;
BEGIN
 FOR fn IN SELECT p.oid,p.proname,p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN (
  'get_amigo_del_mas_uno_ranking','get_corto_ranking','get_driver_oro_ranking','get_detailed_player_statistics',
  'get_francotirador_ranking','get_killer_ranking','get_la_paliza','get_maquina_ranking',
  'get_paquete_ranking','get_rey_del_bosque_ranking','get_shark_ranking','get_viciado_ranking','get_metronomo_ranking',
  'get_topo_ranking','get_head_to_head','get_hoyo_muerte','get_hoyo_gloria','get_mejor_ronda_campo')
 LOOP
   IF fn.prosrc ~* '\m(insert|update|delete|truncate)\M' THEN RAISE EXCEPTION 'Unexpected write in statistics function %',fn.proname; END IF;
   definition:=pg_get_functiondef(fn.oid);
   definition:=regexp_replace(definition,'\m(public\.)?archived_rounds\M','public.group_statistics_rounds','gi');
   EXECUTE definition;
 END LOOP;
END $$;

-- The beer ledger is round-specific. Keep its existing schema and calculation,
-- but remove guests before counting and ranking participants.
DO $$
DECLARE fn oid; definition text;
BEGIN
 SELECT p.oid INTO fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='calculate_beer_stats_for_round' AND p.pronargs=1;
 -- Some current schemas use daily_rankings only and have no separate beer RPC.
 IF fn IS NULL THEN RETURN; END IF;
 definition:=pg_get_functiondef(fn);
 definition:=regexp_replace(definition,'\m(public\.)?round_players\M','(SELECT * FROM public.round_players WHERE NOT is_guest)','gi');
 EXECUTE definition;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
