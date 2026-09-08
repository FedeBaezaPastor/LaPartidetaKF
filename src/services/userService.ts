import { supabase } from './supabaseClient';
import { UserProfile, GroupMember, GroupInvitation, PlanType } from '../types';

export const userService = {
  async getProfile(userId: string): Promise<UserProfile | null> {
    const { data, error } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();
    if (error) throw error;
    return data as UserProfile | null;
  },

  async checkNickAvailable(nick: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('is_nick_available', {
      candidate: nick,
    });
    if (error) throw error;
    return Boolean(data);
  },

  async createProfile(profile: Omit<UserProfile, 'id' | 'created_at' | 'updated_at'>): Promise<UserProfile> {
    const { data, error } = await supabase
      .from('user_profiles')
      .insert(profile)
      .select()
      .single();
    if (error) throw error;
    return data as UserProfile;
  },

  async updateProfile(userId: string, updates: Partial<UserProfile>): Promise<UserProfile> {
    const { data, error } = await supabase
      .from('user_profiles')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('user_id', userId)
      .select()
      .single();
    if (error) throw error;
    return data as UserProfile;
  },

  async searchByNick(nick: string): Promise<UserProfile[]> {
    const { data, error } = await supabase.rpc('search_user_profiles', {
      search_term: nick,
    });
    if (error) throw error;
    return (data || []) as UserProfile[];
  },

  async getPlanType(userId: string): Promise<PlanType> {
    const { data, error } = await supabase
      .from('user_subscriptions')
      .select('plan_type, status, current_period_end')
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();
    if (error) throw error;
    if (!data) return 'express';
    if (data.current_period_end && new Date(data.current_period_end) < new Date()) {
      return 'express';
    }
    return (data.plan_type as PlanType) || 'express';
  },

  async setPlanType(userId: string, planType: PlanType, paymentRef?: string): Promise<void> {
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + 1);

    const { error } = await supabase
      .from('user_subscriptions')
      .upsert({
        user_id: userId,
        plan_type: planType,
        status: 'active',
        payment_hash: paymentRef,
        current_period_start: new Date().toISOString(),
        current_period_end: expiresAt.toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });
    if (error) throw error;
  },

  async getGroupMembers(groupId: string): Promise<GroupMember[]> {
    const { data, error } = await supabase
      .from('group_members')
      .select(`
        *,
        profile:user_profiles!user_id(*)
      `)
      .eq('group_id', groupId)
      .order('joined_at', { ascending: true });
    if (error) throw error;
    return (data || []) as unknown as GroupMember[];
  },

  async addGroupMember(groupId: string, userId: string, role: 'admin' | 'member' = 'member', invitedBy?: string): Promise<void> {
    const { error } = await supabase
      .from('group_members')
      .insert({
        group_id: groupId,
        user_id: userId,
        role,
        invited_by: invitedBy,
      });
    if (error) throw error;
  },

  async removeGroupMember(groupId: string, userId: string): Promise<void> {
    const { error } = await supabase
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', userId);
    if (error) throw error;
  },

  async updateMemberRole(groupId: string, userId: string, role: 'admin' | 'member'): Promise<void> {
    const { error } = await supabase
      .from('group_members')
      .update({ role })
      .eq('group_id', groupId)
      .eq('user_id', userId);
    if (error) throw error;
  },

  async getPendingInvitations(userId: string): Promise<GroupInvitation[]> {
    const { data, error } = await supabase
      .from('group_invitations')
      .select(`
        *,
        group:groups!group_id(*),
        inviter_profile:user_profiles!invited_by(nick, display_name, avatar_url)
      `)
      .eq('invited_user_id', userId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []) as unknown as GroupInvitation[];
  },

  async sendInvitation(groupId: string, invitedUserId: string, invitedBy: string, message?: string): Promise<void> {
    const { error } = await supabase
      .from('group_invitations')
      .insert({
        group_id: groupId,
        invited_user_id: invitedUserId,
        invited_by: invitedBy,
        status: 'pending',
        message,
      });
    if (error) throw error;
  },

  async respondToInvitation(invitationId: string, status: 'accepted' | 'rejected'): Promise<void> {
    const { error } = await supabase
      .from('group_invitations')
      .update({
        status,
        responded_at: new Date().toISOString(),
      })
      .eq('id', invitationId);
    if (error) throw error;
  },

  async getInvitationCount(userId: string): Promise<number> {
    const { count, error } = await supabase
      .from('group_invitations')
      .select('*', { count: 'exact', head: true })
      .eq('invited_user_id', userId)
      .eq('status', 'pending');
    if (error) throw error;
    return count || 0;
  },
};
