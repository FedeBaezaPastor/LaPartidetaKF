-- La comprobación visual mejora la experiencia, pero este índice evita que dos
-- registros simultáneos puedan guardar el mismo nick usando mayúsculas distintas.
CREATE UNIQUE INDEX IF NOT EXISTS user_profiles_nick_lower_unique
  ON public.user_profiles (lower(trim(nick)));
