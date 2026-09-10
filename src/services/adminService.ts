import type { UserProfile, PlanType } from '../types';
import type { User } from '@supabase/supabase-js';
import { supabase } from './supabaseClient';

export interface AdminAccount {
  user_id: string;
  alias: string;
  status: 'invited' | 'active' | 'disabled';
}

export interface AdminDirectoryEntry extends AdminAccount {
  email: string;
  created_by: string | null;
  created_at: string;
  activated_at: string | null;
}

export interface AdminAuditEntry {
  id: number;
  actor_user_id: string | null;
  actor_alias: string;
  action: string;
  target_user_id: string | null;
  details: { alias?: string; before?: string; after?: string; reason?: string; activated?: boolean };
  created_at: string;
}

async function invoke<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke(name, { body });
  if (error) {
    let message = 'El servicio administrativo no está disponible. Inténtalo de nuevo.';
    if (error.context instanceof Response) {
      try {
        const response = await error.context.json();
        if (typeof response.error === 'string') message = response.error;
      } catch { /* Keep a useful message if the gateway returns non-JSON. */ }
    }
    throw new Error(message);
  }
  return data as T;
}

export interface ManagedUser {
 user_id: string; email: string; created_at: string; nick?: string; display_name?: string;
 read_only: boolean; plan: PlanType;
 profile?: UserProfile | null;
 subscription?: {plan_type: PlanType; status: string; current_period_end: string | null} | null;
}
export const adminService = {
 async users(search = '', plan = '', blocked: boolean | null = null, page = 0): Promise<{users: ManagedUser[]; total: number}> {
  const {data,error}=await supabase.rpc('admin_list_app_users',{p_search:search,p_plan:plan,p_blocked:blocked,p_page:page});
  if(error) throw error; return data;
 },
 async user(id: string): Promise<ManagedUser> {
  const {data,error}=await supabase.rpc('admin_get_app_user',{p_user_id:id}); if(error) throw error; return data;
 },
 async updateUser(user: ManagedUser, action: string, values: Record<string,unknown>, reason: string): Promise<ManagedUser> {
  const {data,error}=await supabase.rpc('admin_update_app_user',{p_user_id:user.user_id,p_action:action,p_values:values,p_reason:reason,p_expected:user});
  if(error) throw error; return data;
 },
  async getAccount(user: User): Promise<AdminAccount | null> {
    const { data, error } = await supabase.rpc('get_my_app_administrator');
    if (error) {
      // Deploy the frontend before the additive migration without breaking players.
      // Known administrative identities must NEVER fall through into the player app.
      if (error.code === 'PGRST202' && user.app_metadata?.app_account_type !== 'administrator') return null;
      throw new Error('No se han podido comprobar los permisos de esta cuenta.');
    }
    if (!data && user.app_metadata?.app_account_type === 'administrator') {
      throw new Error('La cuenta administrativa necesita completar su configuración.');
    }
    if (data && data.user_id !== user.id) throw new Error('La sesión ha cambiado. Vuelve a entrar.');
    return data as AdminAccount | null;
  },

  async login(alias: string, password: string) {
    const data = await invoke<{ session: { access_token: string; refresh_token: string } }>('admin-auth', { action: 'login', alias, password });
    const { data: session, error } = await supabase.auth.setSession(data.session);
    if (error || !session.user) throw error || new Error('No se ha podido iniciar sesión.');
    return session.user;
  },

  async recover(alias: string) {
    await invoke('admin-auth', { action: 'recover', alias });
  },

  async list(): Promise<AdminDirectoryEntry[]> {
    const { data, error } = await supabase.rpc('list_app_administrators');
    if (error) throw error;
    return data || [];
  },

  async audit(beforeId?: number): Promise<AdminAuditEntry[]> {
    const { data, error } = await supabase.rpc('list_app_admin_audit', { p_before_id: beforeId ?? null });
    if (error) throw error;
    return data || [];
  },

  async recordLogin() {
    const { error } = await supabase.rpc('record_app_admin_login');
    if (error) throw error;
  },

  async invite(alias: string, email: string) {
    return invoke<{ emailSent: boolean; message?: string }>('admin-management', { action: 'invite', alias, email });
  },

  async resend(userId: string) {
    return invoke<{ emailSent: boolean; message?: string }>('admin-management', { action: 'resend', userId });
  },

  async setActive(userId: string, active: boolean, reason: string) {
    const { error } = await supabase.rpc('set_app_administrator_active', { p_user_id: userId, p_active: active, p_reason: reason });
    if (error) throw error;
  },
};
