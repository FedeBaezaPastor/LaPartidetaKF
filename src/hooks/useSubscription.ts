import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../services/supabaseClient';
import { userService } from '../services/userService';
import { PlanType, UserProfile } from '../types';

interface SubscriptionState {
  planType: PlanType;
  isPremium: boolean;
  loading: boolean;
  profile: UserProfile | null;
  refresh: () => Promise<void>;
}

export const useSubscription = (): SubscriptionState => {
  const [planType, setPlanType] = useState<PlanType>('express');
  const [isPremium, setIsPremium] = useState(false);
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<UserProfile | null>(null);

  const refresh = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      setPlanType('express');
      setIsPremium(false);
      setProfile(null);
      setLoading(false);
      return;
    }

    try {
      await userService.ensureProfileFromMetadata(user.id, user.user_metadata || {});
      const [p, plan] = await Promise.all([
        userService.getProfile(user.id),
        userService.getPlanType(user.id),
      ]);
      setProfile(p);
      setPlanType(plan);
      setIsPremium(plan !== 'express');
    } catch {
      setPlanType('express');
      setIsPremium(false);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { planType, isPremium, loading, profile, refresh };
};
