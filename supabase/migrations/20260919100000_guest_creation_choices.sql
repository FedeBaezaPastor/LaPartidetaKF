-- Preserve the usual writer permission for new unlinked player records.
-- Promoting an existing guest still requires a group manager.
BEGIN;

CREATE OR REPLACE FUNCTION public.guard_guest_player() RETURNS trigger
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
   PERFORM public.require_group_result_writer(NEW.group_id);
 END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.add_group_round_player(p_group uuid,p_round uuid,p_name text,p_handicap numeric,p_is_guest boolean DEFAULT false,p_player uuid DEFAULT NULL)
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

COMMIT;
