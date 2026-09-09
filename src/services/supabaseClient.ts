import { createClient } from '@supabase/supabase-js';
import { safeStorage } from '../utils/safeStorage';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing environment variables:', {
    hasUrl: !!supabaseUrl,
    hasKey: !!supabaseKey,
  });
  throw new Error('Supabase URL and Anon Key are required. Please check your .env file.');
}

let supabaseClient;

try {
  supabaseClient = createClient(supabaseUrl, supabaseKey, {
    auth: {
      storage: safeStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true,
      storageKey: 'supabase.auth.token',
    },
  });
} catch (error) {
  console.error('Error creating Supabase client:', error);
  supabaseClient = createClient(supabaseUrl, supabaseKey, {
    auth: {
      storage: safeStorage,
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
      storageKey: 'supabase.auth.token',
    },
  });
}

export const supabase = supabaseClient;

export const clearStoredAuthSession = (): void => {
  const isAuthKey = (key: string) =>
    key === 'supabase.auth.token' || /^sb-.*-auth-token$/.test(key);

  safeStorage.removeItem('supabase.auth.token');

  for (const storage of [window.localStorage, window.sessionStorage]) {
    try {
      const keys = Array.from({ length: storage.length }, (_, index) => storage.key(index))
        .filter((key): key is string => Boolean(key));
      keys.filter(isAuthKey).forEach((key) => storage.removeItem(key));
    } catch {
      // Private browsing may make browser storage unavailable. SafeStorage has
      // already cleared the in-memory session used by this client.
    }
  }
};
