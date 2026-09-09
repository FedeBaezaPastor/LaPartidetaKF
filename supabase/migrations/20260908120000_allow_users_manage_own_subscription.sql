/*
  Allow authenticated users to read and persist their own selected plan.

  Registration stores the selected plan in auth.users.raw_user_meta_data. Once
  the email has been confirmed, the client creates the user's subscription.
  Without these policies that insert/update is rejected by RLS and the app
  falls back to the Express plan.
*/

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own subscription" ON public.user_subscriptions;
CREATE POLICY "Users can read own subscription"
  ON public.user_subscriptions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own subscription" ON public.user_subscriptions;
CREATE POLICY "Users can create own subscription"
  ON public.user_subscriptions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own subscription" ON public.user_subscriptions;
CREATE POLICY "Users can update own subscription"
  ON public.user_subscriptions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.user_subscriptions TO authenticated;
