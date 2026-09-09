-- Sustituye únicamente los avatares antiguos generados por DiceBear.
-- Las URLs personalizadas de otros orígenes permanecen intactas.
UPDATE public.user_profiles
SET
  avatar_url = '/avatars/leon.webp',
  updated_at = now()
WHERE avatar_url IS NOT NULL
  AND lower(avatar_url) LIKE 'https://api.dicebear.com/%';
