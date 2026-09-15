BEGIN;

-- One transaction: an invitation is never accepted without its membership.
CREATE FUNCTION public.respond_to_group_invitation(p_invitation uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE invitation public.group_invitations;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 IF auth.uid() IS NULL OR public.is_app_user_read_only() THEN
  RAISE EXCEPTION 'No tienes permiso para responder a esta invitación' USING ERRCODE='42501';
 END IF;
 IF p_status IS NULL OR p_status NOT IN ('accepted','rejected') THEN RAISE EXCEPTION 'Respuesta no válida'; END IF;
 SELECT * INTO invitation FROM public.group_invitations WHERE id=p_invitation AND invited_user_id=auth.uid() FOR UPDATE;
 IF invitation.id IS NULL THEN RAISE EXCEPTION 'Invitación no disponible' USING ERRCODE='42501'; END IF;
 IF invitation.status<>'pending' AND invitation.status<>p_status THEN RAISE EXCEPTION 'La invitación ya tiene otra respuesta. Actualiza la lista.'; END IF;
 IF p_status='accepted' THEN
  INSERT INTO public.group_members(group_id,user_id,role,invited_by)
  VALUES(invitation.group_id,auth.uid(),'member',invitation.invited_by)
  ON CONFLICT(group_id,user_id) DO NOTHING;
 END IF;
 UPDATE public.group_invitations SET status=p_status,responded_at=coalesce(responded_at,now()) WHERE id=invitation.id;
END $$;
REVOKE ALL ON FUNCTION public.respond_to_group_invitation(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_group_invitation(uuid,text) TO authenticated;
COMMIT;
