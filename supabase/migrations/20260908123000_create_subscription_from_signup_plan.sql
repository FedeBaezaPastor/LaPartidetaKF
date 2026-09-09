/*
  Persist the plan selected during registration at database level.

  This does not depend on the browser receiving an authenticated session after
  email confirmation. The backfill also repairs users registered before this
  trigger existed.
*/

CREATE OR REPLACE FUNCTION public.create_subscription_from_signup_plan()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  requested_plan text;
BEGIN
  requested_plan := NEW.raw_user_meta_data ->> 'requested_plan';

  IF requested_plan NOT IN ('player', 'team') THEN
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

DROP TRIGGER IF EXISTS on_auth_user_created_create_subscription ON auth.users;
CREATE TRIGGER on_auth_user_created_create_subscription
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_subscription_from_signup_plan();

-- Repair existing confirmed or pending registrations that already contain the
-- selected plan in their Auth metadata but have no subscription row.
INSERT INTO public.user_subscriptions (
  user_id,
  plan_type,
  status,
  payment_hash,
  current_period_start,
  current_period_end,
  updated_at
)
SELECT
  users.id,
  users.raw_user_meta_data ->> 'requested_plan',
  'active',
  'registration',
  now(),
  now() + interval '1 month',
  now()
FROM auth.users AS users
WHERE users.raw_user_meta_data ->> 'requested_plan' IN ('player', 'team')
ON CONFLICT (user_id) DO NOTHING;
