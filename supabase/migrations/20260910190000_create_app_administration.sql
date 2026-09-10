-- Additive application administration. Player tables and game policies are untouched.
BEGIN;

-- Auth dashboard/admin accounts have no player plan metadata. SQL NULL must return
-- before the existing signup trigger attempts to create a subscription.
CREATE OR REPLACE FUNCTION public.create_subscription_from_signup_plan()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  requested_plan text;
BEGIN
  requested_plan := lower(coalesce(
    NEW.raw_user_meta_data ->> 'requested_plan',
    NEW.raw_user_meta_data ->> 'user_tier',
    NEW.raw_user_meta_data ->> 'tier'
  ));

  IF requested_plan IS NULL OR requested_plan NOT IN ('player', 'team') THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.user_subscriptions (
    user_id,
    plan_type,
    status,
    payment_hash,
    current_period_start,
    current_period_end,
    updated_at
  )
  VALUES (
    NEW.id,
    requested_plan,
    'active',
    'registration',
    now(),
    now() + interval '1 month',
    now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE TABLE public.app_administrators (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  alias text NOT NULL CHECK (alias ~ '^[A-Za-z][A-Za-z0-9_-]{2,31}$'),
  alias_key text GENERATED ALWAYS AS (lower(alias)) STORED UNIQUE,
  status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'disabled')),
  created_by uuid REFERENCES public.app_administrators(user_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.app_admin_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid,
  actor_alias text NOT NULL,
  action text NOT NULL,
  target_user_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX app_admin_audit_recent ON public.app_admin_audit (created_at DESC, id DESC);
CREATE UNIQUE INDEX app_admin_audit_login_once ON public.app_admin_audit (session_id)
  WHERE action = 'administrator.login';

CREATE TABLE public.app_admin_auth_limits (
  key_hash text PRIMARY KEY CHECK (length(key_hash) = 64),
  attempts integer NOT NULL,
  expires_at timestamptz NOT NULL
);

ALTER TABLE public.app_administrators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_admin_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_admin_auth_limits ENABLE ROW LEVEL SECURITY;
-- No client-side writes, including for administrators. Mutations use audited functions.
REVOKE ALL ON public.app_administrators, public.app_admin_audit, public.app_admin_auth_limits FROM anon, authenticated;
GRANT ALL ON public.app_administrators, public.app_admin_audit, public.app_admin_auth_limits TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.app_admin_audit_id_seq TO service_role;

CREATE FUNCTION public.is_app_administrator()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_administrators a
    WHERE a.user_id = auth.uid() AND a.status = 'active'
  );
$$;

CREATE FUNCTION public.get_my_app_administrator()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object('user_id', a.user_id, 'alias', a.alias, 'status', a.status)
  FROM public.app_administrators a WHERE a.user_id = auth.uid();
$$;

CREATE FUNCTION public.list_app_administrators()
RETURNS TABLE (user_id uuid, alias text, status text, email text, created_by uuid,
              created_at timestamptz, activated_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  RETURN QUERY SELECT a.user_id, a.alias, a.status, u.email::text, a.created_by, a.created_at, a.activated_at
    FROM public.app_administrators a JOIN auth.users u ON u.id = a.user_id ORDER BY a.created_at, a.user_id;
END;
$$;

CREATE FUNCTION public.list_app_admin_audit(p_before_id bigint DEFAULT NULL)
RETURNS SETOF public.app_admin_audit
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  RETURN QUERY SELECT * FROM public.app_admin_audit e
    WHERE p_before_id IS NULL OR e.id < p_before_id ORDER BY e.id DESC LIMIT 50;
END;
$$;

CREATE FUNCTION public.set_app_administrator_active(p_user_id uuid, p_active boolean, p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor public.app_administrators;
  target public.app_administrators;
  next_status text;
BEGIN
  -- Serializes concurrent invitations/state changes, including last-admin checks.
  PERFORM pg_advisory_xact_lock(20260910, 1900);
  SELECT * INTO actor FROM public.app_administrators WHERE user_id = auth.uid() AND status = 'active';
  IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  IF p_active IS NULL OR length(trim(coalesce(p_reason, ''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION 'Indica un motivo de entre 3 y 500 caracteres';
  END IF;
  SELECT * INTO target FROM public.app_administrators WHERE user_id = p_user_id;
  IF target.user_id IS NULL THEN RAISE EXCEPTION 'Administrador no encontrado'; END IF;
  next_status := CASE WHEN NOT p_active THEN 'disabled' WHEN target.activated_at IS NULL THEN 'invited' ELSE 'active' END;
  IF next_status = target.status THEN RETURN; END IF;
  IF target.status = 'active' AND next_status <> 'active'
    AND (SELECT count(*) FROM public.app_administrators WHERE status = 'active') <= 1 THEN
    RAISE EXCEPTION 'No puedes desactivar al último administrador activo';
  END IF;
  UPDATE public.app_administrators SET status = next_status, updated_at = now() WHERE user_id = p_user_id;
  INSERT INTO public.app_admin_audit (actor_user_id, actor_alias, action, target_user_id, details)
  VALUES (actor.user_id, actor.alias, 'administrator.status_changed', p_user_id,
    jsonb_build_object('alias', target.alias, 'before', target.status, 'after', next_status, 'reason', trim(p_reason)));
END;
$$;

CREATE FUNCTION public.record_app_admin_login()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor public.app_administrators; sid uuid;
BEGIN
  SELECT * INTO actor FROM public.app_administrators WHERE user_id = auth.uid() AND status = 'active';
  IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  sid := (auth.jwt() ->> 'session_id')::uuid;
  IF sid IS NULL THEN RAISE EXCEPTION 'Sesión no válida' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.app_admin_audit (actor_user_id, actor_alias, action, target_user_id, session_id)
  VALUES (actor.user_id, actor.alias, 'administrator.login', actor.user_id, sid)
  ON CONFLICT (session_id) WHERE action = 'administrator.login' DO NOTHING;
END;
$$;

CREATE FUNCTION public.record_app_admin_invitation_sent(p_actor_id uuid, p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor public.app_administrators; target_alias text;
BEGIN
  SELECT * INTO actor FROM public.app_administrators WHERE user_id = p_actor_id AND status = 'active';
  IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  SELECT alias INTO target_alias FROM public.app_administrators WHERE user_id = p_user_id AND status = 'invited';
  IF target_alias IS NULL THEN RAISE EXCEPTION 'Invitación no encontrada'; END IF;
  INSERT INTO public.app_admin_audit (actor_user_id, actor_alias, action, target_user_id, details)
  VALUES (actor.user_id, actor.alias, 'administrator.invitation_sent', p_user_id, jsonb_build_object('alias', target_alias));
END;
$$;

-- Only the server may attach a freshly created Auth account to an administrator.
CREATE FUNCTION public.register_app_administrator(p_actor_id uuid, p_user_id uuid, p_alias text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor public.app_administrators;
BEGIN
  PERFORM pg_advisory_xact_lock(20260910, 1900);
  SELECT * INTO actor FROM public.app_administrators WHERE user_id = p_actor_id AND status = 'active';
  IF actor.user_id IS NULL THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id
    AND raw_app_meta_data ->> 'app_account_type' = 'administrator') THEN
    RAISE EXCEPTION 'La cuenta no se ha creado mediante el flujo administrativo';
  END IF;
  INSERT INTO public.app_administrators (user_id, alias, created_by) VALUES (p_user_id, trim(p_alias), actor.user_id);
  INSERT INTO public.app_admin_audit (actor_user_id, actor_alias, action, target_user_id, details)
  VALUES (actor.user_id, actor.alias, 'administrator.invited', p_user_id, jsonb_build_object('alias', trim(p_alias)));
END;
$$;

-- Run once from the SQL Editor after inviting a NEW, separate account in Auth.
CREATE FUNCTION public.bootstrap_app_administrator(p_user_id uuid, p_alias text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(20260910, 1900);
  IF EXISTS (SELECT 1 FROM public.app_administrators) THEN RAISE EXCEPTION 'El primer administrador ya existe'; END IF;
  IF EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = p_user_id)
     OR EXISTS (SELECT 1 FROM public.user_subscriptions WHERE user_id = p_user_id) THEN
    RAISE EXCEPTION 'Utiliza una cuenta administrativa nueva, separada de tu jugador';
  END IF;
  INSERT INTO public.app_administrators (user_id, alias) VALUES (p_user_id, trim(p_alias));
  UPDATE auth.users SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
    || '{"app_account_type":"administrator"}'::jsonb WHERE id = p_user_id;
  INSERT INTO public.app_admin_audit (actor_alias, action, target_user_id, details)
  VALUES ('Configuración inicial', 'administrator.bootstrapped', p_user_id, jsonb_build_object('alias', trim(p_alias)));
END;
$$;

-- Auth manages password storage. Record only that it changed; never its value/hash.
CREATE FUNCTION public.audit_app_admin_password_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE target public.app_administrators;
BEGIN
  IF NEW.encrypted_password IS NOT DISTINCT FROM OLD.encrypted_password THEN RETURN NEW; END IF;
  PERFORM pg_advisory_xact_lock(20260910, 1900);
  SELECT * INTO target FROM public.app_administrators WHERE user_id = NEW.id;
  IF target.user_id IS NULL THEN RETURN NEW; END IF;
  IF target.status = 'disabled' THEN RAISE EXCEPTION 'Cuenta administrativa desactivada' USING ERRCODE = '42501'; END IF;
  IF target.status = 'invited' THEN
    UPDATE public.app_administrators SET status = 'active', activated_at = now(), updated_at = now() WHERE user_id = NEW.id;
  END IF;
  INSERT INTO public.app_admin_audit (actor_alias, action, target_user_id, details)
  VALUES ('Supabase Auth', 'administrator.password_changed', NEW.id,
    jsonb_build_object('alias', target.alias, 'activated', target.status = 'invited'));
  RETURN NEW;
END;
$$;
CREATE TRIGGER audit_app_admin_password_change
  AFTER UPDATE OF encrypted_password ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.audit_app_admin_password_change();

CREATE FUNCTION public.consume_app_admin_auth_limit(p_key_hash text, p_limit integer, p_seconds integer)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE total integer;
BEGIN
  IF p_limit NOT BETWEEN 1 AND 1000 OR p_seconds NOT BETWEEN 1 AND 86400 THEN RAISE EXCEPTION 'Límite inválido'; END IF;
  DELETE FROM public.app_admin_auth_limits WHERE expires_at < now();
  INSERT INTO public.app_admin_auth_limits (key_hash, attempts, expires_at)
  VALUES (p_key_hash, 1, now() + make_interval(secs => p_seconds))
  ON CONFLICT (key_hash) DO UPDATE SET attempts = public.app_admin_auth_limits.attempts + 1
  RETURNING attempts INTO total;
  RETURN total <= p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.is_app_administrator(), public.get_my_app_administrator(),
  public.list_app_administrators(), public.list_app_admin_audit(bigint),
  public.set_app_administrator_active(uuid, boolean, text), public.record_app_admin_login(),
  public.record_app_admin_invitation_sent(uuid, uuid),
  public.register_app_administrator(uuid, uuid, text), public.bootstrap_app_administrator(uuid, text),
  public.audit_app_admin_password_change(), public.consume_app_admin_auth_limit(text, integer, integer)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_app_administrator(), public.get_my_app_administrator(),
  public.list_app_administrators(), public.list_app_admin_audit(bigint),
  public.set_app_administrator_active(uuid, boolean, text), public.record_app_admin_login()

  TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_app_admin_invitation_sent(uuid, uuid), public.register_app_administrator(uuid, uuid, text),
  public.bootstrap_app_administrator(uuid, text), public.consume_app_admin_auth_limit(text, integer, integer)
  TO service_role;

-- Retire the old shared-email/PIN administration access. Group/test PINs are unchanged.
DO $$ DECLARE policy_record record;
BEGIN
  IF to_regclass('public.admin_config') IS NOT NULL THEN
    FOR policy_record IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'admin_config' LOOP
      EXECUTE format('DROP POLICY %I ON public.admin_config', policy_record.policyname);
    END LOOP;
    ALTER TABLE public.admin_config ENABLE ROW LEVEL SECURITY;
    REVOKE ALL ON public.admin_config FROM anon, authenticated;
  END IF;
END $$;

COMMIT;
