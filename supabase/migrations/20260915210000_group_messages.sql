BEGIN;
-- Keep historical deliveries when a group is removed; their sender label remains.
ALTER TABLE public.app_messages
 ADD COLUMN sender_kind text NOT NULL DEFAULT 'app' CHECK(sender_kind IN ('app','group')),
 ADD COLUMN source_group_id uuid REFERENCES public.groups(id) ON DELETE SET NULL,
 ADD COLUMN sender_label text NOT NULL DEFAULT 'Administración',
 ADD COLUMN recipient_selection jsonb;
CREATE INDEX app_messages_group_history ON public.app_messages(source_group_id,created_at DESC);

-- Existing public group policies must not let a caller impersonate an owner.
-- Anonymous groups without registered members retain their existing claim flow.
CREATE FUNCTION public.guard_message_group_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.jwt()->>'role','')='service_role' OR public.is_app_administrator() THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='groups' THEN
  IF TG_OP='INSERT' THEN
   IF NEW.user_auth_id IS NOT NULL AND NEW.user_auth_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'No puedes asignar otro propietario' USING ERRCODE='42501'; END IF;
  ELSE
   IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'No se puede cambiar el identificador del grupo' USING ERRCODE='42501'; END IF;
   IF NEW.user_auth_id IS DISTINCT FROM OLD.user_auth_id AND NOT coalesce((
    auth.uid() IS NOT NULL AND (OLD.user_auth_id=auth.uid() OR (OLD.user_auth_id IS NULL AND NEW.user_auth_id=auth.uid() AND (
     (NOT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=OLD.id)
      AND NOT EXISTS(SELECT 1 FROM public.app_messages WHERE source_group_id=OLD.id))
     OR EXISTS(SELECT 1 FROM public.group_members WHERE group_id=OLD.id AND user_id=auth.uid() AND role='admin')
    )))
   ),false) THEN RAISE EXCEPTION 'No puedes cambiar el propietario del grupo' USING ERRCODE='42501'; END IF;
  END IF;
 ELSIF NEW.group_id IS DISTINCT FROM OLD.group_id OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
  RAISE EXCEPTION 'No se puede trasladar una membresía a otra cuenta o grupo' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER message_group_identity BEFORE INSERT OR UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.guard_message_group_identity();
CREATE TRIGGER message_membership_identity BEFORE UPDATE ON public.group_members FOR EACH ROW EXECUTE FUNCTION public.guard_message_group_identity();

CREATE FUNCTION public.can_manage_group_messages(p_group uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM public.app_administrators WHERE user_id=auth.uid())
 AND EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND coalesce(raw_app_meta_data->>'app_account_type','')<>'administrator')
 AND EXISTS(SELECT 1 FROM public.groups g WHERE g.id=p_group AND (g.user_auth_id=auth.uid() OR EXISTS(
 SELECT 1 FROM public.group_members gm WHERE gm.group_id=g.id AND gm.user_id=auth.uid() AND gm.role='admin')));
$$;
CREATE FUNCTION public.message_group_accounts(p_group uuid,p_admins boolean DEFAULT false) RETURNS TABLE(user_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT u.id FROM auth.users u WHERE
 (EXISTS(SELECT 1 FROM public.groups g WHERE g.id=p_group AND g.user_auth_id=u.id)
 OR EXISTS(SELECT 1 FROM public.group_members gm WHERE gm.group_id=p_group AND gm.user_id=u.id AND (NOT p_admins OR gm.role='admin')))
 AND NOT EXISTS(SELECT 1 FROM public.app_administrators a WHERE a.user_id=u.id)
 AND coalesce(u.raw_app_meta_data->>'app_account_type','')<>'administrator';
$$;
CREATE FUNCTION public.message_groups(p_search text DEFAULT '',p_managed_only boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Inicia sesión' USING ERRCODE='42501'; END IF;
 IF length(coalesce(p_search,''))>200 THEN RAISE EXCEPTION 'Búsqueda demasiado larga'; END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT g.id,g.name,g.group_code,
 (SELECT count(*) FROM public.message_group_accounts(g.id,false)) AS member_count,
 (SELECT count(*) FROM public.message_group_accounts(g.id,true)) AS admin_count
 FROM public.groups g WHERE ((NOT p_managed_only AND public.is_app_administrator()) OR public.can_manage_group_messages(g.id))
 AND strpos(lower(concat_ws(' ',g.name,g.group_code,g.id::text)),lower(trim(coalesce(p_search,''))))>0
 ORDER BY g.name,g.id LIMIT 25) t),'[]'::jsonb);
END $$;
CREATE FUNCTION public.group_message_recipients(p_group uuid,p_search text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.can_manage_group_messages(p_group) THEN RAISE EXCEPTION 'No administras este grupo' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(p_search,''))) NOT BETWEEN 2 AND 200 THEN RETURN '[]'::jsonb; END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT 'user' AS kind,u.id,coalesce(nullif(p.nick,''),nullif(p.display_name,''),'Usuario '||u.id::text) AS label
 FROM public.message_group_accounts(p_group,false) a JOIN auth.users u ON u.id=a.user_id LEFT JOIN public.user_profiles p ON p.user_id=u.id
 WHERE strpos(lower(concat_ws(' ',p.nick,p.display_name,u.email,u.id::text)),lower(trim(p_search)))>0 ORDER BY u.id LIMIT 25
 )t),'[]'::jsonb);
END $$;

-- Normalize selections separately from concrete deliveries. Never trust client labels.
CREATE FUNCTION public.resolve_message_selection(p_selection jsonb,p_group uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item jsonb; target jsonb; selection jsonb:='[]'; targets jsonb:='[]'; group_name text; member record; group_count integer;
BEGIN
 IF jsonb_typeof(p_selection) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Selección inválida'; END IF;
 IF jsonb_array_length(p_selection) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona entre 1 y 100 destinatarios o grupos'; END IF;
 FOR item IN SELECT DISTINCT jsonb_build_object('kind',v->>'kind','id',(v->>'id')::uuid) FROM jsonb_array_elements(p_selection)v ORDER BY 1 LOOP
  IF item->>'kind' IN ('group','group_admins') THEN
   IF p_group IS NOT NULL AND (item->>'id')::uuid<>p_group THEN RAISE EXCEPTION 'Solo puedes enviar a tu grupo' USING ERRCODE='42501'; END IF;
   SELECT name INTO group_name FROM public.groups WHERE id=(item->>'id')::uuid FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Grupo no disponible. Revisa la selección.'; END IF;
   selection:=selection||jsonb_build_array(item||jsonb_build_object('label',coalesce(group_name,'Grupo')));
   group_count:=0;
   FOR member IN SELECT user_id FROM public.message_group_accounts((item->>'id')::uuid,item->>'kind'='group_admins') LOOP
    targets:=targets||jsonb_build_array(jsonb_build_object('kind','user','id',member.user_id)); group_count:=group_count+1;
   END LOOP;
   IF group_count=0 THEN RAISE EXCEPTION 'El grupo seleccionado no tiene destinatarios registrados'; END IF;
  ELSIF item->>'kind' IN ('user','express') THEN
   target:=public.message_recipient(item->>'kind',(item->>'id')::uuid);
   selection:=selection||jsonb_build_array(target); targets:=targets||jsonb_build_array(item);
  ELSE RAISE EXCEPTION 'Tipo de destinatario no válido'; END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(t.item ORDER BY t.item),'[]') INTO targets FROM (SELECT DISTINCT value AS item FROM jsonb_array_elements(targets))t;
 IF jsonb_array_length(targets) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'El envío supera el límite de 100 destinatarios únicos'; END IF;
 target:='[]';
 FOR item IN SELECT value FROM jsonb_array_elements(targets) LOOP
  IF p_group IS NOT NULL THEN
   IF item->>'kind'<>'user' OR NOT EXISTS(SELECT 1 FROM public.message_group_accounts(p_group,false) WHERE user_id=(item->>'id')::uuid) THEN
    RAISE EXCEPTION 'Un destinatario ya no pertenece a tu grupo. Revisa la selección.' USING ERRCODE='42501';
   END IF;
   PERFORM public.message_recipient('user',(item->>'id')::uuid);
   SELECT item||jsonb_build_object('label',coalesce(nullif(p.nick,''),nullif(p.display_name,''),'Usuario '||u.id::text)) INTO item
   FROM auth.users u LEFT JOIN public.user_profiles p ON p.user_id=u.id WHERE u.id=(item->>'id')::uuid;
  ELSE item:=public.message_recipient(item->>'kind',(item->>'id')::uuid); END IF;
  target:=target||jsonb_build_array(item);
 END LOOP;
 -- Redact private email labels from a group administrator's individual selections.
 IF p_group IS NOT NULL THEN
  SELECT jsonb_agg(CASE WHEN s->>'kind'='user' THEN (SELECT v FROM jsonb_array_elements(target)v WHERE v->>'id'=s->>'id') ELSE s END ORDER BY s) INTO selection FROM jsonb_array_elements(selection)s;
 END IF;
 RETURN jsonb_build_object('selection',selection,'recipients',target);
END $$;

CREATE FUNCTION public.save_message_v2(p_id uuid,p_title text,p_body text,p_selection jsonb,p_revision integer,p_group uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor_alias text; msg public.app_messages; resolved jsonb; label text:='Administración';
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 -- Keep membership/role changes from racing review/save and publish.
 LOCK TABLE public.group_members IN SHARE MODE;
 IF p_group IS NULL THEN
  SELECT alias INTO actor_alias FROM public.app_administrators WHERE user_id=auth.uid() AND status='active';
  IF actor_alias IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 ELSE
  PERFORM 1 FROM public.groups WHERE id=p_group FOR SHARE;
  IF NOT public.can_manage_group_messages(p_group) OR public.is_app_user_read_only() THEN RAISE EXCEPTION 'No tienes permiso para escribir a este grupo' USING ERRCODE='42501'; END IF;
  SELECT 'Grupo · '||coalesce(name,'Sin nombre') INTO label FROM public.groups WHERE id=p_group;
  SELECT coalesce(nullif(nick,''),nullif(display_name,''),'Administrador de grupo') INTO actor_alias FROM public.user_profiles WHERE user_id=auth.uid();
  actor_alias:=coalesce(actor_alias,'Administrador de grupo');
 END IF;
 IF p_id IS NULL OR length(coalesce(p_title,''))>120 OR length(coalesce(p_body,''))>4000 OR p_title !~ '\S' OR p_body !~ '\S' OR p_title IS NULL OR p_body IS NULL THEN RAISE EXCEPTION 'Revisa título y texto obligatorios'; END IF;
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id FOR UPDATE;
 IF msg.id IS NOT NULL THEN
  IF msg.sender_kind IS DISTINCT FROM (CASE WHEN p_group IS NULL THEN 'app' ELSE 'group' END) OR msg.source_group_id IS DISTINCT FROM p_group
   OR (p_group IS NOT NULL AND msg.author_id<>auth.uid()) THEN RAISE EXCEPTION 'No puedes modificar este borrador' USING ERRCODE='42501'; END IF;
  IF msg.status='sent' THEN RAISE EXCEPTION 'Un mensaje enviado no se puede modificar'; END IF;
 END IF;
 resolved:=public.resolve_message_selection(p_selection,p_group);
 IF msg.id IS NOT NULL AND msg.revision IS DISTINCT FROM p_revision THEN
  IF msg.title=trim(p_title) AND msg.body=p_body AND msg.recipients=resolved->'recipients' AND coalesce(msg.recipient_selection,msg.recipients)=resolved->'selection' THEN RETURN to_jsonb(msg); END IF;
  RAISE EXCEPTION 'El borrador ha cambiado. Actualízalo antes de guardar.';
 END IF;
 IF msg.id IS NULL AND p_revision IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Borrador no encontrado'; END IF;
 INSERT INTO public.app_messages(id,title,body,author_id,author_alias,recipients,recipient_selection,sender_kind,source_group_id,sender_label)
 VALUES(p_id,trim(p_title),p_body,auth.uid(),actor_alias,resolved->'recipients',resolved->'selection',CASE WHEN p_group IS NULL THEN 'app' ELSE 'group' END,p_group,label)
 ON CONFLICT(id) DO UPDATE SET title=excluded.title,body=excluded.body,recipients=excluded.recipients,recipient_selection=excluded.recipient_selection,sender_label=excluded.sender_label,revision=public.app_messages.revision+1,updated_at=now();
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id; RETURN to_jsonb(msg);
END $$;
CREATE FUNCTION public.send_message_v2(p_id uuid,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE msg public.app_messages; actor_alias text; resolved jsonb; old_ids jsonb; new_ids jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 LOCK TABLE public.group_members IN SHARE MODE;
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id FOR UPDATE;
 IF msg.id IS NULL THEN RAISE EXCEPTION 'Borrador no encontrado'; END IF;
 IF msg.sender_kind='app' THEN
  SELECT alias INTO actor_alias FROM public.app_administrators WHERE user_id=auth.uid() AND status='active';
  IF actor_alias IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 ELSE
  PERFORM 1 FROM public.groups WHERE id=msg.source_group_id FOR SHARE;
  IF NOT public.can_manage_group_messages(msg.source_group_id) OR public.is_app_user_read_only() OR msg.author_id<>auth.uid() THEN RAISE EXCEPTION 'No tienes permiso para enviar este mensaje' USING ERRCODE='42501'; END IF;
  SELECT coalesce(nullif(nick,''),nullif(display_name,''),'Administrador de grupo') INTO actor_alias FROM public.user_profiles WHERE user_id=auth.uid();
  actor_alias:=coalesce(actor_alias,'Administrador de grupo');
 END IF;
 IF msg.status='sent' THEN RETURN to_jsonb(msg); END IF;
 IF msg.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'El borrador ha cambiado. Revisa de nuevo antes de enviar.'; END IF;
 IF msg.scheduled_at IS NOT NULL THEN RAISE EXCEPTION 'La programación de envíos todavía no está habilitada'; END IF;
 resolved:=public.resolve_message_selection(coalesce(msg.recipient_selection,msg.recipients),msg.source_group_id);
 SELECT jsonb_agg(jsonb_build_object('kind',v->>'kind','id',v->>'id') ORDER BY v->>'kind',v->>'id') INTO old_ids FROM jsonb_array_elements(msg.recipients)v;
 SELECT jsonb_agg(jsonb_build_object('kind',v->>'kind','id',v->>'id') ORDER BY v->>'kind',v->>'id') INTO new_ids FROM jsonb_array_elements(resolved->'recipients')v;
 IF old_ids IS DISTINCT FROM new_ids THEN RAISE EXCEPTION 'Los miembros del grupo han cambiado. Vuelve a editar y revisar el envío.'; END IF;
 UPDATE public.app_messages SET status='sent',sent_at=now(),sent_by=auth.uid(),sent_by_alias=actor_alias,recipients=resolved->'recipients',updated_at=now() WHERE id=p_id;
 INSERT INTO public.app_message_deliveries(message_id,kind,recipient_id,recipient_label)
 SELECT p_id,v->>'kind',(v->>'id')::uuid,v->>'label' FROM jsonb_array_elements(resolved->'recipients')v;
 INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,details)
 VALUES(auth.uid(),actor_alias,CASE WHEN msg.sender_kind='app' THEN 'message.sent' ELSE 'group.message.sent' END,
 jsonb_build_object('message_id',p_id,'title',msg.title,'recipient_count',jsonb_array_length(msg.recipients),'group_id',msg.source_group_id,'sender',msg.sender_label));
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id; RETURN to_jsonb(msg);
END $$;
-- Preserve already deployed clients while closing alternative publish paths.
CREATE OR REPLACE FUNCTION public.admin_save_message(p_id uuid,p_title text,p_body text,p_recipients jsonb,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 RETURN public.save_message_v2(p_id,p_title,p_body,p_recipients,p_revision,NULL);
END $$;
CREATE OR REPLACE FUNCTION public.admin_send_message(p_id uuid,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 RETURN public.send_message_v2(p_id,p_revision);
END $$;
CREATE FUNCTION public.list_group_messages(p_group uuid,p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.can_manage_group_messages(p_group) THEN RAISE EXCEPTION 'No administras este grupo' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('total',(SELECT count(*) FROM public.app_messages WHERE source_group_id=p_group AND (status='sent' OR author_id=auth.uid())),
 'messages',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT m.id,m.title,m.status,m.author_alias,m.sent_by_alias,m.sender_label,m.sender_kind,m.source_group_id,m.created_at,m.sent_at,jsonb_array_length(m.recipients) AS recipient_count,
 (SELECT count(*) FROM public.app_message_deliveries d WHERE d.message_id=m.id AND d.read_at IS NOT NULL) AS read_count
 FROM public.app_messages m WHERE m.source_group_id=p_group AND (m.status='sent' OR m.author_id=auth.uid()) ORDER BY m.created_at DESC,m.id LIMIT 25 OFFSET p_page*25)t),'[]'::jsonb));
END $$;
CREATE FUNCTION public.get_group_message(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE msg public.app_messages;
BEGIN
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id;
 IF msg.id IS NULL OR NOT public.can_manage_group_messages(msg.source_group_id) OR (msg.status='draft' AND msg.author_id<>auth.uid()) THEN RAISE EXCEPTION 'Mensaje no disponible' USING ERRCODE='42501'; END IF;
 RETURN to_jsonb(msg)||jsonb_build_object('deliveries',coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.recipient_label) FROM public.app_message_deliveries d WHERE d.message_id=msg.id),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.admin_list_messages(p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('total',(SELECT count(*) FROM public.app_messages),'messages',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT m.id,m.title,m.status,m.sender_label,m.sender_kind,m.source_group_id,m.author_alias,m.sent_by_alias,m.created_at,m.sent_at,jsonb_array_length(m.recipients) AS recipient_count,
 (SELECT count(*) FROM public.app_message_deliveries d WHERE d.message_id=m.id AND d.read_at IS NOT NULL) AS read_count
 FROM public.app_messages m ORDER BY m.created_at DESC,m.id LIMIT 25 OFFSET p_page*25) t),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.message_inbox(p_kind text,p_recipient uuid,p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_page IS NULL OR p_page NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('unread',(SELECT count(*) FROM public.app_message_deliveries WHERE kind=p_kind AND recipient_id=p_recipient AND read_at IS NULL),
 'total',(SELECT count(*) FROM public.app_message_deliveries WHERE kind=p_kind AND recipient_id=p_recipient),
 'messages',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT d.id,m.title,m.sender_label,d.sent_at,d.read_at FROM public.app_message_deliveries d JOIN public.app_messages m ON m.id=d.message_id
 WHERE d.kind=p_kind AND d.recipient_id=p_recipient ORDER BY d.sent_at DESC,d.id LIMIT 25 OFFSET p_page*25) t),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.message_open(p_kind text,p_recipient uuid,p_delivery uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 UPDATE public.app_message_deliveries SET read_at=coalesce(read_at,now()) WHERE id=p_delivery AND kind=p_kind AND recipient_id=p_recipient;
 IF NOT FOUND THEN RAISE EXCEPTION 'Mensaje no encontrado' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',d.id,'title',m.title,'body',m.body,'sender_label',m.sender_label,'sent_at',d.sent_at,'read_at',d.read_at) INTO result
 FROM public.app_message_deliveries d JOIN public.app_messages m ON m.id=d.message_id WHERE d.id=p_delivery;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.guard_message_group_identity(),public.can_manage_group_messages(uuid),public.message_group_accounts(uuid,boolean),public.message_groups(text,boolean),public.group_message_recipients(uuid,text),public.resolve_message_selection(jsonb,uuid),public.save_message_v2(uuid,text,text,jsonb,integer,uuid),public.send_message_v2(uuid,integer),public.list_group_messages(uuid,integer),public.get_group_message(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.message_groups(text,boolean),public.group_message_recipients(uuid,text),public.save_message_v2(uuid,text,text,jsonb,integer,uuid),public.send_message_v2(uuid,integer),public.list_group_messages(uuid,integer),public.get_group_message(uuid) TO authenticated;
COMMIT;
