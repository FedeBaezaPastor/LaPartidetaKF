/*
  Unify the legacy Auth registration metadata (user_tier/tier with capitalized
  values) with the current requested_plan subscription model.
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
  requested_plan := lower(coalesce(
    NEW.raw_user_meta_data ->> 'requested_plan',
    NEW.raw_user_meta_data ->> 'user_tier',
    NEW.raw_user_meta_data ->> 'tier'
  ));

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

-- Repair users created by the legacy Auth.tsx registration form.
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
  lower(coalesce(
    users.raw_user_meta_data ->> 'requested_plan',
    users.raw_user_meta_data ->> 'user_tier',
    users.raw_user_meta_data ->> 'tier'
  )),
  'active',
  'registration',
  now(),
  now() + interval '1 month',
  now()
FROM auth.users AS users
WHERE lower(coalesce(
  users.raw_user_meta_data ->> 'requested_plan',
  users.raw_user_meta_data ->> 'user_tier',
  users.raw_user_meta_data ->> 'tier'
)) IN ('player', 'team')
ON CONFLICT (user_id) DO NOTHING;
