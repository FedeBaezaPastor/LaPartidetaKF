BEGIN;

-- A registered game identity is never inferred from a display name.
ALTER TABLE public.players ADD COLUMN auth_user_id uuid REFERENCES auth.users(id),
 ADD COLUMN handicap_pending boolean NOT NULL DEFAULT false,
 ADD COLUMN member_revision bigint NOT NULL DEFAULT 1;
ALTER TABLE public.players ADD CONSTRAINT linked_player_requires_group CHECK(auth_user_id IS NULL OR group_id IS NOT NULL);
ALTER TABLE public.players DROP CONSTRAINT IF EXISTS players_name_group_id_key;
DROP INDEX IF EXISTS public.players_name_group_id_unique;
CREATE UNIQUE INDEX players_legacy_name_group_unique ON public.players(name,group_id) WHERE auth_user_id IS NULL AND group_id IS NOT NULL;
CREATE UNIQUE INDEX players_group_account_unique ON public.players(group_id,auth_user_id) WHERE auth_user_id IS NOT NULL;
CREATE SEQUENCE public.group_member_versions;
ALTER TABLE public.group_members ADD COLUMN member_revision bigint NOT NULL DEFAULT nextval('public.group_member_versions');
GRANT USAGE ON SEQUENCE public.group_member_versions TO authenticated;

-- Single-use, transaction-local capabilities. Unlike a session setting, these
-- cannot be forged by clients or by an existing RPC accepting arbitrary input.
CREATE TABLE public.group_write_permits(tx bigint, entity uuid, operation text, PRIMARY KEY(tx,entity,operation));
ALTER TABLE public.group_write_permits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_write_permits FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.require_group_manager(p_group uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF NOT coalesce(public.can_manage_group_messages(p_group),false) OR public.is_app_user_read_only() THEN
  RAISE EXCEPTION 'No tienes permiso para administrar este grupo' USING ERRCODE='42501';
 END IF;
END $$;

CREATE FUNCTION public.ensure_group_player(p_group uuid,p_user uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid; v_hcp numeric; v_name text;
BEGIN
 SELECT id INTO v_id FROM public.players WHERE group_id=p_group AND auth_user_id=p_user;
 IF v_id IS NOT NULL THEN RETURN v_id; END IF;
 SELECT exact_handicap,coalesce(nullif(nick,''),nullif(display_name,'')) INTO v_hcp,v_name
 FROM public.user_profiles WHERE user_id=p_user;
 v_id:=gen_random_uuid();
 -- Stable internal name keeps legacy name-based histories disjoint. The UI
 -- reads the current public profile separately and selects by player UUID.
 v_name:=coalesce(v_name,'Cuenta') || ' [cuenta ' || p_user::text || ']';
 INSERT INTO public.group_write_permits VALUES(txid_current(),v_id,'player') ON CONFLICT DO NOTHING;
 INSERT INTO public.players(id,group_id,auth_user_id,name,exact_handicap,exact_handicap_18,handicap_pending)
 VALUES(v_id,p_group,p_user,v_name,CASE WHEN v_hcp BETWEEN 0 AND 54 THEN v_hcp/2 ELSE 0 END,
 CASE WHEN v_hcp BETWEEN 0 AND 54 THEN v_hcp/2 ELSE 0 END,NOT coalesce(v_hcp BETWEEN 0 AND 54,false));
 DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=v_id;
 RETURN v_id;
END $$;

-- Backfill only proven Auth memberships, including historical owners.
INSERT INTO public.group_members(group_id,user_id,role)
 SELECT id,user_auth_id,'admin' FROM public.groups WHERE user_auth_id IS NOT NULL
 ON CONFLICT(group_id,user_id) DO NOTHING;
DO $$ DECLARE m record; BEGIN
 FOR m IN SELECT group_id,user_id FROM public.group_members LOOP
  PERFORM public.ensure_group_player(m.group_id,m.user_id);
 END LOOP;
END $$;

CREATE FUNCTION public.guard_linked_group_player() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (TG_OP='INSERT' AND NEW.auth_user_id IS NULL) OR
    (TG_OP='DELETE' AND OLD.auth_user_id IS NULL) OR
    (TG_OP='UPDATE' AND OLD.auth_user_id IS NULL AND NEW.auth_user_id IS NULL) THEN
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
 END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Retira la membresía; la ficha y sus resultados se conservan' USING ERRCODE='42501'; END IF;
 DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=NEW.id AND operation='player';
 IF NOT FOUND OR public.is_app_user_read_only() THEN RAISE EXCEPTION 'La ficha vinculada requiere una operación autorizada' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.id,NEW.group_id,NEW.auth_user_id,NEW.name) IS DISTINCT FROM (OLD.id,OLD.group_id,OLD.auth_user_id,OLD.name) THEN
   RAISE EXCEPTION 'La identidad de la ficha es inmutable';
  END IF;
  NEW.member_revision:=OLD.member_revision+1;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER linked_group_player_guard BEFORE INSERT OR UPDATE OR DELETE ON public.players
 FOR EACH ROW EXECUTE FUNCTION public.guard_linked_group_player();

CREATE FUNCTION public.list_identified_group_members(p_group uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT (public.is_group_member(p_group) OR public.can_manage_group_messages(p_group)) THEN
  RAISE EXCEPTION 'No tienes acceso a los miembros de este grupo' USING ERRCODE='42501';
 END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
  'id',m.id,'group_id',m.group_id,'user_id',m.user_id,'role',CASE WHEN g.user_auth_id=m.user_id THEN 'admin' ELSE m.role END,
  'joined_at',m.joined_at,'member_revision',m.member_revision,'player_id',p.id,'player_revision',p.member_revision,
  'handicap_18',CASE WHEN p.handicap_pending THEN NULL ELSE p.exact_handicap*2 END,
  'can_manage',public.can_manage_group_messages(p_group) AND NOT public.is_app_user_read_only(),
  'can_remove',g.user_auth_id IS DISTINCT FROM m.user_id AND m.user_id<>auth.uid(),
  'profile',CASE WHEN u.user_id IS NULL THEN NULL ELSE jsonb_build_object('nick',u.nick,'display_name',u.display_name,'avatar_url',u.avatar_url) END
 ) ORDER BY m.joined_at,m.id)
 FROM public.group_members m JOIN public.groups g ON g.id=m.group_id
 JOIN public.players p ON p.group_id=m.group_id AND p.auth_user_id=m.user_id
 LEFT JOIN public.user_profiles u ON u.user_id=m.user_id WHERE m.group_id=p_group),'[]'::jsonb);
END $$;

CREATE FUNCTION public.manage_group_member(p_group uuid,p_user uuid,p_member_revision bigint,p_player_revision bigint,p_action text,p_handicap_18 numeric DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.group_members; p public.players; v_owner uuid; v_before jsonb;
BEGIN
 PERFORM public.require_group_manager(p_group);
 SELECT user_auth_id INTO v_owner FROM public.groups WHERE id=p_group FOR UPDATE;
 SELECT * INTO m FROM public.group_members WHERE group_id=p_group AND user_id=p_user FOR UPDATE;
 SELECT * INTO p FROM public.players WHERE group_id=p_group AND auth_user_id=p_user FOR UPDATE;
 IF m.id IS NULL OR p.id IS NULL OR m.member_revision IS DISTINCT FROM p_member_revision OR p.member_revision IS DISTINCT FROM p_player_revision THEN
  RAISE EXCEPTION 'El miembro ha cambiado. Actualiza la lista y revisa de nuevo.' USING ERRCODE='40001';
 END IF;
 v_before:=jsonb_build_object('role',m.role,'handicap_18',CASE WHEN p.handicap_pending THEN NULL ELSE p.exact_handicap*2 END,'player_id',p.id);
 IF p_action='handicap' THEN
  IF p_handicap_18 IS NULL OR NOT (p_handicap_18 BETWEEN 0 AND 54) THEN RAISE EXCEPTION 'El hándicap debe estar entre 0 y 54'; END IF;
  INSERT INTO public.group_write_permits VALUES(txid_current(),p.id,'player');
  UPDATE public.players SET exact_handicap=p_handicap_18/2,exact_handicap_18=p_handicap_18/2,handicap_pending=false WHERE id=p.id;
 ELSIF p_action='remove' THEN
  IF p_user=v_owner OR p_user=auth.uid() OR (m.role='admin' AND NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=p_group AND user_id<>p_user AND role='admin')) THEN
   RAISE EXCEPTION 'No puedes retirar al propietario, a ti mismo ni al último administrador';
  END IF;
  INSERT INTO public.group_write_permits VALUES(txid_current(),m.id,'membership');
  DELETE FROM public.group_members WHERE id=m.id;
  -- Delete the previous invitation identity. A new explicit invitation gets a
  -- new UUID, so an old accepted link can never restore this membership.
  DELETE FROM public.group_invitations WHERE group_id=p_group AND invited_user_id=p_user;
 ELSE RAISE EXCEPTION 'Operación no válida'; END IF;
 INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,target_user_id,details)
 VALUES(auth.uid(),'Administrador del Grupo','group.member.'||p_action,p_user,
 jsonb_build_object('group_id',p_group,'before',v_before::text,'after',CASE WHEN p_action='remove' THEN 'Membresía retirada' ELSE jsonb_build_object('handicap_18',p_handicap_18)::text END));
END $$;

CREATE FUNCTION public.guard_group_membership_lifecycle() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_owner uuid;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT user_auth_id INTO v_owner FROM public.groups WHERE id=coalesce(NEW.group_id,OLD.group_id);
 IF TG_OP='INSERT' THEN
  DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=NEW.user_id AND operation='join:'||NEW.group_id::text;
  IF NOT FOUND AND NOT (NEW.user_id=v_owner AND NEW.user_id=auth.uid()) THEN RAISE EXCEPTION 'Debes aceptar una invitación vigente' USING ERRCODE='42501'; END IF;
  PERFORM public.ensure_group_player(NEW.group_id,NEW.user_id);
 ELSIF TG_OP='DELETE' THEN
  DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=OLD.id AND operation='membership';
  IF NOT FOUND THEN RAISE EXCEPTION 'Utiliza la retirada de miembros con confirmación' USING ERRCODE='42501'; END IF;
 ELSE
  PERFORM public.require_group_manager(OLD.group_id);
  IF (NEW.id,NEW.group_id,NEW.user_id) IS DISTINCT FROM (OLD.id,OLD.group_id,OLD.user_id) THEN RAISE EXCEPTION 'Identidad inmutable'; END IF;
  IF NEW.role<>'admin' AND (OLD.user_id=v_owner OR NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=OLD.group_id AND user_id<>OLD.user_id AND role='admin')) THEN RAISE EXCEPTION 'El grupo necesita un administrador'; END IF;
  NEW.member_revision:=nextval('public.group_member_versions');
 END IF;
 IF public.is_app_user_read_only() THEN RAISE EXCEPTION 'Cuenta en solo lectura' USING ERRCODE='42501'; END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER a_group_membership_lifecycle BEFORE INSERT OR UPDATE OR DELETE ON public.group_members FOR EACH ROW EXECUTE FUNCTION public.guard_group_membership_lifecycle();

CREATE FUNCTION public.initialize_group_owner() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.user_auth_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=NEW.id AND user_id=NEW.user_auth_id) THEN
  INSERT INTO public.group_write_permits VALUES(txid_current(),NEW.user_auth_id,'join:'||NEW.id::text) ON CONFLICT DO NOTHING;
  INSERT INTO public.group_members(group_id,user_id,role) VALUES(NEW.id,NEW.user_auth_id,'admin');
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER initialize_group_owner AFTER INSERT OR UPDATE OF user_auth_id ON public.groups FOR EACH ROW EXECUTE FUNCTION public.initialize_group_owner();

CREATE OR REPLACE FUNCTION public.respond_to_group_invitation(p_invitation uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE invitation public.group_invitations;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF auth.uid() IS NULL OR public.is_app_user_read_only() THEN RAISE EXCEPTION 'No tienes permiso para responder' USING ERRCODE='42501'; END IF;
 IF p_status IS NULL OR p_status NOT IN ('accepted','rejected') THEN RAISE EXCEPTION 'Respuesta no válida'; END IF;
 SELECT * INTO invitation FROM public.group_invitations WHERE id=p_invitation AND invited_user_id=auth.uid() FOR UPDATE;
 IF invitation.id IS NULL THEN RAISE EXCEPTION 'Invitación no disponible' USING ERRCODE='42501'; END IF;
 IF invitation.status<>'pending' THEN
  IF invitation.status=p_status THEN RETURN; END IF;
  RAISE EXCEPTION 'La invitación ya tiene otra respuesta';
 END IF;
 IF p_status='accepted' AND NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=invitation.group_id AND user_id=auth.uid()) THEN
  INSERT INTO public.group_write_permits VALUES(txid_current(),auth.uid(),'join:'||invitation.group_id::text);
  INSERT INTO public.group_members(group_id,user_id,role,invited_by) VALUES(invitation.group_id,auth.uid(),'member',invitation.invited_by);
 END IF;
 INSERT INTO public.group_write_permits VALUES(txid_current(),invitation.id,'invitation');
 UPDATE public.group_invitations SET status=p_status,responded_at=now() WHERE id=invitation.id;
END $$;

CREATE FUNCTION public.guard_group_invitation_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF TG_OP='INSERT' THEN
  PERFORM public.require_group_manager(NEW.group_id);
  IF NEW.status<>'pending' OR NEW.invited_by<>auth.uid() THEN RAISE EXCEPTION 'Invitación no válida'; END IF;
 ELSE
  DELETE FROM public.group_write_permits WHERE tx=txid_current() AND entity=OLD.id AND operation='invitation';
  IF NOT FOUND THEN RAISE EXCEPTION 'Responde mediante la operación de invitaciones' USING ERRCODE='42501'; END IF;
  IF (NEW.id,NEW.group_id,NEW.invited_user_id,NEW.invited_by) IS DISTINCT FROM (OLD.id,OLD.group_id,OLD.invited_user_id,OLD.invited_by) THEN RAISE EXCEPTION 'Identidad inmutable'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER group_invitation_identity BEFORE INSERT OR UPDATE ON public.group_invitations FOR EACH ROW EXECUTE FUNCTION public.guard_group_invitation_identity();

-- Limit the new public surface; helpers and trigger entry points are private.
REVOKE ALL ON FUNCTION public.require_group_manager(uuid),public.ensure_group_player(uuid,uuid),public.guard_linked_group_player(),public.guard_group_membership_lifecycle(),public.initialize_group_owner(),public.guard_group_invitation_identity() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.list_identified_group_members(uuid),public.manage_group_member(uuid,uuid,bigint,bigint,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_identified_group_members(uuid),public.manage_group_member(uuid,uuid,bigint,bigint,text,numeric) TO authenticated;

CREATE FUNCTION public.list_group_game_players(p_group uuid) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 RETURN QUERY SELECT to_jsonb(p) || jsonb_build_object('name',CASE WHEN p.auth_user_id IS NULL THEN p.name ELSE coalesce(u.nick,u.display_name,'Cuenta pendiente') END)
 FROM public.players p LEFT JOIN public.user_profiles u ON u.user_id=p.auth_user_id
 WHERE p.group_id=p_group AND (p.auth_user_id IS NULL OR
  ((public.is_group_member(p_group) OR public.can_manage_group_messages(p_group)) AND EXISTS(SELECT 1 FROM public.group_members m WHERE m.group_id=p_group AND m.user_id=p.auth_user_id)))
 ORDER BY p.name;
END $$;

-- All inserts, including direct REST inserts, take the handicap snapshot from
-- the group record. Updating that record never updates existing round rows.
CREATE FUNCTION public.guard_registered_round_player() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; r public.golf_rounds; v_slope numeric;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF (NEW.player_id,NEW.round_id,NEW.user_id) IS DISTINCT FROM (OLD.player_id,OLD.round_id,OLD.user_id)
   AND (EXISTS(SELECT 1 FROM public.players WHERE id IN (OLD.player_id,NEW.player_id) AND auth_user_id IS NOT NULL)) THEN
   RAISE EXCEPTION 'La identidad de la participación es inmutable' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
 END IF;
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT * INTO p FROM public.players WHERE id=NEW.player_id FOR SHARE;
 IF p.auth_user_id IS NULL THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT * INTO r FROM public.golf_rounds WHERE id=NEW.round_id FOR UPDATE;
 IF public.is_app_user_read_only() OR NOT (public.is_group_member(p.group_id) OR public.can_manage_group_messages(p.group_id)) OR r.group_id IS DISTINCT FROM p.group_id
 OR NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=p.group_id AND user_id=p.auth_user_id) THEN
  RAISE EXCEPTION 'El jugador no está disponible en este grupo' USING ERRCODE='42501';
 END IF;
 IF p.handicap_pending THEN RAISE EXCEPTION 'Hándicap pendiente: debe completarlo el administrador del grupo'; END IF;
 IF NEW.exact_handicap IS DISTINCT FROM p.exact_handicap THEN RAISE EXCEPTION 'El hándicap ha cambiado. Actualiza y selecciona de nuevo al jugador.' USING ERRCODE='40001'; END IF;
 IF EXISTS(SELECT 1 FROM public.round_players WHERE round_id=r.id AND player_id=p.id) THEN RAISE EXCEPTION 'El jugador ya está en la partida'; END IF;
 SELECT CASE WHEN r.num_holes=18 THEN t.slope_18 WHEN r.holes_range='10-18' THEN t.slope_9_ii ELSE t.slope_9_i END INTO v_slope FROM public.tees t WHERE t.id=r.tee_id;
 v_slope:=CASE WHEN r.use_slope THEN coalesce(r.manual_slope,v_slope,113) ELSE 113 END;
 SELECT coalesce(nick,display_name,'Cuenta registrada') INTO NEW.name FROM public.user_profiles WHERE user_id=p.auth_user_id;
 NEW.name:=coalesce(NEW.name,'Cuenta registrada');
 NEW.user_id:=p.auth_user_id;
 NEW.exact_handicap:=p.exact_handicap; NEW.exact_handicap_18:=p.exact_handicap;
 NEW.playing_handicap:=round(p.exact_handicap*(CASE WHEN r.num_holes=18 THEN 2 ELSE 1 END)*v_slope/113);
 RETURN NEW;
END $$;
CREATE TRIGGER a_registered_round_player BEFORE INSERT OR UPDATE ON public.round_players FOR EACH ROW EXECUTE FUNCTION public.guard_registered_round_player();
REVOKE ALL ON FUNCTION public.guard_registered_round_player(),public.list_group_game_players(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_group_game_players(uuid) TO anon,authenticated;


ALTER TABLE public.archived_rounds ADD COLUMN source_round_id uuid;
CREATE UNIQUE INDEX archived_round_source_unique ON public.archived_rounds(source_round_id) WHERE source_round_id IS NOT NULL;
CREATE FUNCTION public.require_group_result_writer(p_group uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF auth.uid() IS NULL OR public.is_app_user_read_only() OR NOT (public.is_group_member(p_group) OR public.can_manage_group_messages(p_group)) THEN
  RAISE EXCEPTION 'No tienes permiso para guardar resultados de este grupo' USING ERRCODE='42501';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.require_group_result_writer(uuid) FROM PUBLIC,anon,authenticated;
-- Automatic adjustments retain the existing formula; registered identities use
-- the explicit game-record UUID, never a historical name.
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
        WHERE (ps->>'player_db_id'=p.id::text OR (p.auth_user_id IS NULL AND ps->>'player_name'=fr->>'player_name'))
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

CREATE FUNCTION public.guard_linked_archive() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.golf_rounds; has_linked boolean;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF TG_OP='INSERT' THEN
  SELECT * INTO r FROM public.golf_rounds WHERE id=NEW.source_round_id FOR UPDATE;
  has_linked:=EXISTS(SELECT 1 FROM public.round_players rp JOIN public.players p ON p.id=rp.player_id WHERE rp.round_id=r.id AND p.auth_user_id IS NOT NULL)
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.final_ranking,'[]')) f JOIN public.players p ON p.id::text=f->>'player_db_id' WHERE p.auth_user_id IS NOT NULL);
  IF has_linked THEN
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
CREATE TRIGGER linked_archive_guard BEFORE INSERT OR UPDATE OR DELETE ON public.archived_rounds FOR EACH ROW EXECUTE FUNCTION public.guard_linked_archive();
CREATE OR REPLACE FUNCTION public.revert_handicap_adjustments_for_round() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a record;
BEGIN
 FOR a IN SELECT h.*,p.auth_user_id FROM public.handicap_adjustments h JOIN public.players p ON p.id=h.player_id WHERE h.archived_round_id=OLD.id LOOP
  IF a.auth_user_id IS NOT NULL THEN
   PERFORM public.require_group_manager(OLD.group_id);
   INSERT INTO public.group_write_permits VALUES(txid_current(),a.player_id,'player');
   INSERT INTO public.group_write_permits VALUES(txid_current(),a.player_id,'ledger') ON CONFLICT DO NOTHING;
   INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,target_user_id,details)
    SELECT auth.uid(),'Administrador del Grupo','group.member.results_reverted',a.auth_user_id,
    jsonb_build_object('group_id',OLD.group_id,'archive_id',OLD.id,'before',(p.exact_handicap*2)::text,'after',(a.hcp_before*2)::text) FROM public.players p WHERE p.id=a.player_id;
  END IF;
  UPDATE public.players SET exact_handicap=CASE WHEN a.adjustment<>0 THEN a.hcp_before ELSE exact_handicap END,
   exact_handicap_18=CASE WHEN a.adjustment<>0 THEN a.hcp_before ELSE exact_handicap_18 END,
   playing_handicap=coalesce(a.playing_handicap_before,playing_handicap),updated_at=now() WHERE id=a.player_id;
 END LOOP;
 DELETE FROM public.handicap_adjustments WHERE archived_round_id=OLD.id;
 DELETE FROM public.group_write_permits WHERE tx=txid_current() AND operation='ledger';
 RETURN OLD;
END $$;
CREATE OR REPLACE FUNCTION public.auto_calculate_daily_ranking() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 BEGIN
  PERFORM public.calculate_daily_ranking(NEW.group_id,coalesce(NEW.played_at,NEW.archived_at)::date);
 EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Daily ranking failed for archive %',NEW.id;
 END;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.final_ranking,'[]')) f JOIN public.players p ON p.id::text=f->>'player_db_id' WHERE p.auth_user_id IS NOT NULL) THEN
  -- Linked handicap failures must roll back the archive, never disappear in
  -- the compatibility handler used by legacy archives.
  PERFORM public.apply_handicap_adjustments_for_round(NEW.id);
 ELSE
  BEGIN PERFORM public.apply_handicap_adjustments_for_round(NEW.id);
  EXCEPTION WHEN OTHERS THEN RAISE LOG 'Legacy handicap adjustment failed for archive %',NEW.id; END;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_linked_archive(),public.revert_handicap_adjustments_for_round(),public.apply_handicap_adjustments_for_round(uuid) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.guard_linked_handicap_ledger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.players WHERE id=coalesce(NEW.player_id,OLD.player_id) AND auth_user_id IS NOT NULL)
 OR (TG_OP='UPDATE' AND EXISTS(SELECT 1 FROM public.players WHERE id=OLD.player_id AND auth_user_id IS NOT NULL)) THEN
  IF NOT EXISTS(SELECT 1 FROM public.group_write_permits WHERE tx=txid_current() AND entity=coalesce(NEW.player_id,OLD.player_id) AND operation='ledger') THEN
   RAISE EXCEPTION 'El historial de ajustes requiere una operación autorizada' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER linked_handicap_ledger BEFORE INSERT OR UPDATE OR DELETE ON public.handicap_adjustments FOR EACH ROW EXECUTE FUNCTION public.guard_linked_handicap_ledger();
REVOKE ALL ON FUNCTION public.guard_linked_handicap_ledger() FROM PUBLIC,anon,authenticated;

-- New rankings keep explicit registered identities apart from legacy names.
-- Existing ranking rows remain unlinked and are not recalculated by migration.
ALTER TABLE public.daily_rankings ADD COLUMN game_player_id uuid;
ALTER TABLE public.daily_rankings DROP CONSTRAINT IF EXISTS daily_rankings_group_id_ranking_date_player_name_key;
CREATE UNIQUE INDEX daily_rankings_legacy_identity ON public.daily_rankings(group_id,ranking_date,player_name) WHERE game_player_id IS NULL;
CREATE UNIQUE INDEX daily_rankings_account_identity ON public.daily_rankings(group_id,ranking_date,game_player_id) WHERE game_player_id IS NOT NULL;
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
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    LEFT JOIN players linked ON linked.id::text=elem->>'player_db_id' AND linked.auth_user_id IS NOT NULL AND linked.group_id=ar.group_id
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


REVOKE TRUNCATE ON public.players,public.group_members,public.group_invitations,public.handicap_adjustments FROM PUBLIC,anon,authenticated;
COMMIT;
