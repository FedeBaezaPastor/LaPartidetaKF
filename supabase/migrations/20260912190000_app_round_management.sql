BEGIN;
ALTER TABLE public.golf_rounds ADD COLUMN admin_withdrawn_at timestamptz, ADD COLUMN admin_previous_status text;
CREATE FUNCTION public.guard_round_admin_fields() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_app_administrator() THEN
  IF TG_OP='INSERT' THEN
   IF NEW.admin_withdrawn_at IS NOT NULL OR NEW.admin_previous_status IS NOT NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
  ELSE
   IF NEW.admin_withdrawn_at IS DISTINCT FROM OLD.admin_withdrawn_at OR NEW.admin_previous_status IS DISTINCT FROM OLD.admin_previous_status OR OLD.admin_withdrawn_at IS NOT NULL THEN RAISE EXCEPTION 'Partida retirada por administración' USING ERRCODE='42501'; END IF;
  END IF;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER guard_round_admin_fields BEFORE INSERT OR UPDATE ON public.golf_rounds FOR EACH ROW EXECUTE FUNCTION public.guard_round_admin_fields();
CREATE FUNCTION public.guard_withdrawn_round_data() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE withdrawn timestamptz;
BEGIN
 IF TG_OP<>'INSERT' THEN
  SELECT admin_withdrawn_at INTO withdrawn FROM public.golf_rounds WHERE id=OLD.round_id FOR UPDATE;
  IF withdrawn IS NOT NULL THEN RAISE EXCEPTION 'Partida retirada por administración' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_OP<>'DELETE' THEN
  SELECT admin_withdrawn_at INTO withdrawn FROM public.golf_rounds WHERE id=NEW.round_id FOR UPDATE;
  IF withdrawn IS NOT NULL THEN RAISE EXCEPTION 'Partida retirada por administración' USING ERRCODE='42501'; END IF;
  RETURN NEW;
 END IF;
 RETURN OLD;
END $$;
CREATE TRIGGER guard_withdrawn_scores BEFORE INSERT OR UPDATE OR DELETE ON public.round_scores FOR EACH ROW EXECUTE FUNCTION public.guard_withdrawn_round_data();
CREATE TRIGGER guard_withdrawn_players BEFORE INSERT OR UPDATE OR DELETE ON public.round_players FOR EACH ROW EXECUTE FUNCTION public.guard_withdrawn_round_data();
CREATE FUNCTION public.admin_list_app_rounds(p_search text DEFAULT '',p_status text DEFAULT '',p_kind text DEFAULT '',p_page integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page<0 OR p_page>100000 OR length(p_search)>200 OR p_kind NOT IN ('','quick','group') OR p_status NOT IN ('','active','completed','archived','cancelled','deleted','withdrawn') THEN RAISE EXCEPTION 'Filtro inválido'; END IF;
 WITH filtered AS (
 SELECT r.id,r.reference_number,r.created_at,r.updated_at,r.user_id,r.group_id,r.game_mode,r.num_holes,c.name AS course_name,r.status,r.admin_withdrawn_at,
 (SELECT count(*) FROM public.round_players p WHERE p.round_id=r.id) AS players_count
 FROM public.golf_rounds r LEFT JOIN public.golf_courses c ON c.id=r.course_id
 WHERE (p_kind='' OR (p_kind='quick' AND r.group_id IS NULL) OR (p_kind='group' AND r.group_id IS NOT NULL))
 AND (p_status='' OR (p_status='withdrawn' AND r.admin_withdrawn_at IS NOT NULL) OR (r.admin_withdrawn_at IS NULL AND r.status=p_status))
 AND (coalesce(p_search,'')='' OR strpos(lower(concat_ws(' ',r.id::text,r.reference_number::text,r.user_id,r.group_id::text,c.name)),lower(p_search))>0
 OR EXISTS(SELECT 1 FROM public.round_players p WHERE p.round_id=r.id AND strpos(lower(p.name),lower(p_search))>0))
 ), page AS (SELECT * FROM filtered ORDER BY created_at DESC,id LIMIT 25 OFFSET p_page*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM filtered),'rounds',coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM page),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_get_app_round(p_round_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('round',to_jsonb(r),'course_name',c.name,
 'players',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at,p.id) FROM public.round_players p WHERE p.round_id=r.id),'[]'::jsonb),
 'scores',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.hole_number,s.player_id) FROM public.round_scores s WHERE s.round_id=r.id),'[]'::jsonb)) INTO result
 FROM public.golf_rounds r LEFT JOIN public.golf_courses c ON c.id=r.course_id WHERE r.id=p_round_id;
 IF result IS NULL THEN RAISE EXCEPTION 'Partida no encontrada'; END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_change_app_round(p_round_id uuid,p_action text,p_reason text,p_expected timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.golf_rounds; actor public.app_administrators; next_status text;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT * INTO actor FROM public.app_administrators WHERE user_id=auth.uid() AND status='active';
 IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'Indica un motivo de entre 3 y 500 caracteres'; END IF;
 SELECT * INTO r FROM public.golf_rounds WHERE id=p_round_id FOR UPDATE;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Partida no encontrada'; END IF;
 IF r.group_id IS NOT NULL THEN RAISE EXCEPTION 'Las partidas de grupo son solo de consulta en esta fase'; END IF;
 IF r.updated_at IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'La partida ha cambiado. Actualiza la ficha.'; END IF;
 IF (p_action='reopen' OR (p_action='restore' AND r.admin_previous_status='active')) AND EXISTS (
  SELECT 1 FROM public.golf_rounds other WHERE other.id<>r.id AND other.user_id=r.user_id AND other.group_id IS NULL AND other.status='active' AND other.admin_withdrawn_at IS NULL
 ) THEN RAISE EXCEPTION 'Ya existe otra partida rápida en curso para este identificador. Finalízala antes de reabrir o restaurar esta partida.'; END IF;
 IF p_action='withdraw' AND r.admin_withdrawn_at IS NULL THEN
  UPDATE public.golf_rounds SET admin_withdrawn_at=now(),admin_previous_status=status,status='deleted' WHERE id=r.id;
 ELSIF p_action='restore' AND r.admin_withdrawn_at IS NOT NULL THEN
  UPDATE public.golf_rounds SET status=admin_previous_status,admin_withdrawn_at=NULL,admin_previous_status=NULL WHERE id=r.id;
 ELSIF p_action='complete' AND r.status='active' AND r.admin_withdrawn_at IS NULL THEN
  UPDATE public.golf_rounds SET status='completed',completed_at=now() WHERE id=r.id;
 ELSIF p_action='reopen' AND r.status IN ('completed','archived') AND r.admin_withdrawn_at IS NULL THEN
  UPDATE public.golf_rounds SET status='active',completed_at=NULL WHERE id=r.id;
 ELSE RAISE EXCEPTION 'Acción no permitida para el estado actual'; END IF;
 SELECT status INTO next_status FROM public.golf_rounds WHERE id=r.id;
 INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,details)
 VALUES(actor.user_id,actor.alias,'round.'||p_action,jsonb_build_object('round_id',r.id,'reason',trim(p_reason),'before',r.status,'after',next_status,'express_slot_released',p_action='withdraw'));
 RETURN public.admin_get_app_round(r.id);
END $$;
CREATE FUNCTION public.count_available_quick_rounds(p_owner text) RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT count(*) FROM public.golf_rounds WHERE user_id=p_owner AND group_id IS NULL AND admin_withdrawn_at IS NULL;
$$;
REVOKE ALL ON FUNCTION public.guard_round_admin_fields(),public.guard_withdrawn_round_data(),public.admin_list_app_rounds(text,text,text,integer),public.admin_get_app_round(uuid),public.admin_change_app_round(uuid,text,text,timestamptz),public.count_available_quick_rounds(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_app_rounds(text,text,text,integer),public.admin_get_app_round(uuid),public.admin_change_app_round(uuid,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_available_quick_rounds(text) TO anon,authenticated;
COMMIT;
