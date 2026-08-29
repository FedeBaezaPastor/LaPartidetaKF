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
