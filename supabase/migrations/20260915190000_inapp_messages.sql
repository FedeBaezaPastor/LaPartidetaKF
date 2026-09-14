BEGIN;
CREATE TABLE public.app_message_boxes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), secret_hash text NOT NULL UNIQUE CHECK(secret_hash ~ '^[0-9a-f]{64}$'), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.app_messages (
 id uuid PRIMARY KEY, title text NOT NULL CHECK(length(title) <= 120 AND length(trim(title)) > 0), body text NOT NULL CHECK(length(body) <= 4000 AND length(trim(body)) > 0),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','sent')), author_id uuid NOT NULL, author_alias text NOT NULL,
 recipients jsonb NOT NULL CHECK(jsonb_typeof(recipients)='array' AND jsonb_array_length(recipients) BETWEEN 1 AND 100),
 revision integer NOT NULL DEFAULT 1, scheduled_at timestamptz, sent_at timestamptz, sent_by uuid, sent_by_alias text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.app_message_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), message_id uuid NOT NULL REFERENCES public.app_messages(id),
 kind text NOT NULL CHECK(kind IN ('user','express')), recipient_id uuid NOT NULL, recipient_label text NOT NULL,
 sent_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz, UNIQUE(message_id,kind,recipient_id)
);
CREATE INDEX app_message_inbox ON public.app_message_deliveries(kind,recipient_id,sent_at DESC,id);
ALTER TABLE public.app_message_boxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_message_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_message_boxes,public.app_messages,public.app_message_deliveries FROM PUBLIC,anon,authenticated,service_role;
-- Deliberately no generic read-only guard on these new tables: all access is
-- through narrowly granted functions, including read receipts for blocked users.
CREATE FUNCTION public.message_recipient(p_kind text,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE label text;
BEGIN
 IF p_kind='user' THEN
  SELECT concat_ws(' · ',p.nick,u.email) INTO label FROM auth.users u LEFT JOIN public.user_profiles p ON p.user_id=u.id
  WHERE u.id=p_id AND NOT EXISTS(SELECT 1 FROM public.app_administrators a WHERE a.user_id=u.id)
  AND coalesce(u.raw_app_meta_data->>'app_account_type','')<>'administrator' FOR KEY SHARE OF u;
 ELSIF p_kind='express' THEN
  SELECT 'Express · '||id::text INTO label FROM public.app_message_boxes WHERE id=p_id FOR KEY SHARE;
 END IF;
 IF label IS NULL THEN RAISE EXCEPTION 'Un destinatario ya no está disponible. Revisa la selección.'; END IF;
 RETURN jsonb_build_object('kind',p_kind,'id',p_id,'label',label);
END $$;
CREATE FUNCTION public.admin_message_recipients(p_search text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(p_search,''))) NOT BETWEEN 2 AND 200 THEN RETURN '[]'::jsonb; END IF;
 SELECT coalesce(jsonb_agg(item),'[]'::jsonb) INTO result FROM (
 SELECT jsonb_build_object('kind','user','id',u.id,'label',concat_ws(' · ',p.nick,u.email)) AS item
 FROM auth.users u LEFT JOIN public.user_profiles p ON p.user_id=u.id
 WHERE NOT EXISTS(SELECT 1 FROM public.app_administrators a WHERE a.user_id=u.id)
 AND coalesce(u.raw_app_meta_data->>'app_account_type','')<>'administrator'
 AND strpos(lower(concat_ws(' ',p.nick,u.email,u.id::text)),lower(trim(p_search)))>0
 UNION ALL SELECT jsonb_build_object('kind','express','id',id,'label','Express · '||id::text)
 FROM public.app_message_boxes WHERE id::text=lower(trim(p_search)) LIMIT 25
 ) found;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_save_message(p_id uuid,p_title text,p_body text,p_recipients jsonb,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor public.app_administrators; current_message public.app_messages; item jsonb; targets jsonb:='[]'::jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT * INTO actor FROM public.app_administrators WHERE user_id=auth.uid() AND status='active';
 IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF p_id IS NULL OR length(trim(coalesce(p_title,''))) NOT BETWEEN 1 AND 120 OR length(trim(coalesce(p_body,''))) NOT BETWEEN 1 AND 4000
 OR length(p_title)>120 OR length(p_body)>4000
 OR jsonb_typeof(p_recipients) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Revisa título, texto y destinatarios'; END IF;
 IF jsonb_array_length(p_recipients) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona entre 1 y 100 destinatarios'; END IF;
 FOR item IN SELECT DISTINCT jsonb_build_object('kind',v->>'kind','id',(v->>'id')::uuid) FROM jsonb_array_elements(p_recipients) v ORDER BY 1 LOOP
  targets:=targets||jsonb_build_array(public.message_recipient(item->>'kind',(item->>'id')::uuid));
 END LOOP;
 SELECT * INTO current_message FROM public.app_messages WHERE id=p_id FOR UPDATE;
 IF current_message.status='sent' THEN RAISE EXCEPTION 'Un mensaje enviado no se puede modificar'; END IF;
 IF current_message.id IS NOT NULL AND current_message.revision IS DISTINCT FROM p_revision THEN
  IF current_message.title=trim(p_title) AND current_message.body=p_body AND current_message.recipients=targets THEN RETURN to_jsonb(current_message); END IF;
  RAISE EXCEPTION 'El borrador ha cambiado. Actualízalo antes de guardar.';
 END IF;
 IF current_message.id IS NULL AND p_revision IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Borrador no encontrado'; END IF;
 INSERT INTO public.app_messages(id,title,body,author_id,author_alias,recipients) VALUES(p_id,trim(p_title),p_body,actor.user_id,actor.alias,targets)
 ON CONFLICT(id) DO UPDATE SET title=excluded.title,body=excluded.body,recipients=excluded.recipients,revision=public.app_messages.revision+1,updated_at=now();
 SELECT * INTO current_message FROM public.app_messages WHERE id=p_id;
 RETURN to_jsonb(current_message);
END $$;
CREATE FUNCTION public.admin_send_message(p_id uuid,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor public.app_administrators; msg public.app_messages; item jsonb; targets jsonb:='[]'::jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(20260910,1900);
 SELECT * INTO actor FROM public.app_administrators WHERE user_id=auth.uid() AND status='active';
 IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id FOR UPDATE;
 IF msg.id IS NULL THEN RAISE EXCEPTION 'Borrador no encontrado'; END IF;
 IF msg.status='sent' THEN RETURN to_jsonb(msg); END IF;
 IF msg.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'El borrador ha cambiado. Revisa de nuevo antes de enviar.'; END IF;
 IF msg.scheduled_at IS NOT NULL THEN RAISE EXCEPTION 'La programación de envíos todavía no está habilitada'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(msg.recipients) LOOP
  targets:=targets||jsonb_build_array(public.message_recipient(item->>'kind',(item->>'id')::uuid));
 END LOOP;
 UPDATE public.app_messages SET status='sent',sent_at=now(),sent_by=actor.user_id,sent_by_alias=actor.alias,recipients=targets,updated_at=now() WHERE id=p_id;
 INSERT INTO public.app_message_deliveries(message_id,kind,recipient_id,recipient_label)
 SELECT p_id,v->>'kind',(v->>'id')::uuid,v->>'label' FROM jsonb_array_elements(targets) v;
 INSERT INTO public.app_admin_audit(actor_user_id,actor_alias,action,details)
 VALUES(actor.user_id,actor.alias,'message.sent',jsonb_build_object('message_id',p_id,'title',msg.title,'recipient_count',jsonb_array_length(targets)));
 SELECT * INTO msg FROM public.app_messages WHERE id=p_id;
 RETURN to_jsonb(msg);
END $$;
CREATE FUNCTION public.admin_list_messages(p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('total',(SELECT count(*) FROM public.app_messages),'messages',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT m.id,m.title,m.status,m.author_alias,m.sent_by_alias,m.created_at,m.sent_at,jsonb_array_length(m.recipients) AS recipient_count,
 (SELECT count(*) FROM public.app_message_deliveries d WHERE d.message_id=m.id AND d.read_at IS NOT NULL) AS read_count
 FROM public.app_messages m ORDER BY m.created_at DESC,m.id LIMIT 25 OFFSET p_page*25) t),'[]'::jsonb));
END $$;
CREATE FUNCTION public.admin_get_message(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 SELECT to_jsonb(m)||jsonb_build_object('deliveries',coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.recipient_label) FROM public.app_message_deliveries d WHERE d.message_id=m.id),'[]'::jsonb)) INTO result FROM public.app_messages m WHERE m.id=p_id;
 IF result IS NULL THEN RAISE EXCEPTION 'Mensaje no encontrado'; END IF; RETURN result;
END $$;
CREATE FUNCTION public.message_inbox(p_kind text,p_recipient uuid,p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_page IS NULL OR p_page NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('unread',(SELECT count(*) FROM public.app_message_deliveries WHERE kind=p_kind AND recipient_id=p_recipient AND read_at IS NULL),
 'total',(SELECT count(*) FROM public.app_message_deliveries WHERE kind=p_kind AND recipient_id=p_recipient),
 'messages',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
 SELECT d.id,m.title,d.sent_at,d.read_at FROM public.app_message_deliveries d JOIN public.app_messages m ON m.id=d.message_id
 WHERE d.kind=p_kind AND d.recipient_id=p_recipient ORDER BY d.sent_at DESC,d.id LIMIT 25 OFFSET p_page*25) t),'[]'::jsonb));
END $$;
CREATE FUNCTION public.message_open(p_kind text,p_recipient uuid,p_delivery uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 UPDATE public.app_message_deliveries SET read_at=coalesce(read_at,now()) WHERE id=p_delivery AND kind=p_kind AND recipient_id=p_recipient;
 IF NOT FOUND THEN RAISE EXCEPTION 'Mensaje no encontrado' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',d.id,'title',m.title,'body',m.body,'sent_at',d.sent_at,'read_at',d.read_at) INTO result
 FROM public.app_message_deliveries d JOIN public.app_messages m ON m.id=d.message_id WHERE d.id=p_delivery;
 RETURN result;
END $$;
CREATE FUNCTION public.my_message_inbox(p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Inicia sesión' USING ERRCODE='42501'; END IF;
 RETURN public.message_inbox('user',auth.uid(),p_page);
END $$;
CREATE FUNCTION public.my_message_open(p_delivery uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Inicia sesión' USING ERRCODE='42501'; END IF;
 RETURN public.message_open('user',auth.uid(),p_delivery);
END $$;
-- Only the Express Edge Function receives these service-only grants.
CREATE FUNCTION public.register_message_box(p_hash text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid;
BEGIN
 INSERT INTO public.app_message_boxes(secret_hash) VALUES(p_hash) ON CONFLICT(secret_hash) DO NOTHING;
 SELECT id INTO result FROM public.app_message_boxes WHERE secret_hash=p_hash; RETURN result;
END $$;
CREATE FUNCTION public.express_message_request(p_id uuid,p_hash text,p_delivery uuid DEFAULT NULL,p_page integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.app_message_boxes WHERE id=p_id AND secret_hash=p_hash) THEN RAISE EXCEPTION 'Buzón no disponible' USING ERRCODE='42501'; END IF;
 IF p_delivery IS NOT NULL THEN RETURN public.message_open('express',p_id,p_delivery); END IF;
 RETURN public.message_inbox('express',p_id,p_page);
END $$;
REVOKE ALL ON FUNCTION public.message_recipient(text,uuid),public.admin_message_recipients(text),public.admin_save_message(uuid,text,text,jsonb,integer),public.admin_send_message(uuid,integer),public.admin_list_messages(integer),public.admin_get_message(uuid),public.message_inbox(text,uuid,integer),public.message_open(text,uuid,uuid),public.my_message_inbox(integer),public.my_message_open(uuid),public.register_message_box(text),public.express_message_request(uuid,text,uuid,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_message_recipients(text),public.admin_save_message(uuid,text,text,jsonb,integer),public.admin_send_message(uuid,integer),public.admin_list_messages(integer),public.admin_get_message(uuid),public.my_message_inbox(integer),public.my_message_open(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_message_box(text),public.express_message_request(uuid,text,uuid,integer) TO service_role;
COMMIT;
