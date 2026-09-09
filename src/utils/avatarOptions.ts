export interface AvatarOption {
  id: string;
  name: string;
  url: string;
}

export const AVATAR_OPTIONS: AvatarOption[] = [
  { id: 'leon', name: 'El León', url: '/avatars/leon.webp' },
  { id: 'tigre', name: 'El Tigre', url: '/avatars/tigre.webp' },
  { id: 'panda', name: 'El Panda', url: '/avatars/panda.webp' },
  { id: 'oso', name: 'El Oso', url: '/avatars/oso.webp' },
  { id: 'lobo', name: 'El Lobo', url: '/avatars/lobo.webp' },
  { id: 'zorro', name: 'El Zorro', url: '/avatars/zorro.webp' },
  { id: 'coneja', name: 'La Coneja', url: '/avatars/coneja.webp' },
  { id: 'jirafa', name: 'La Jirafa', url: '/avatars/jirafa.webp' },
  { id: 'erizo', name: 'El Erizo', url: '/avatars/erizo.webp' },
  { id: 'ardilla', name: 'La Ardilla', url: '/avatars/ardilla.webp' },
  { id: 'koala', name: 'El Koala', url: '/avatars/koala.webp' },
  { id: 'elefante', name: 'El Elefante', url: '/avatars/elefante.webp' },
  { id: 'pato', name: 'El Pato', url: '/avatars/pato.webp' },
  { id: 'bulldog', name: 'El Bulldog', url: '/avatars/bulldog.webp' },
  { id: 'rinoceronte', name: 'El Rinoceronte', url: '/avatars/rinoceronte.webp' },
];

export const DEFAULT_AVATAR_URL = AVATAR_OPTIONS[0].url;

export const normalizeAvatarUrl = (avatarUrl?: string): string => {
  if (!avatarUrl || avatarUrl.includes('api.dicebear.com/')) return DEFAULT_AVATAR_URL;
  return avatarUrl;
};
