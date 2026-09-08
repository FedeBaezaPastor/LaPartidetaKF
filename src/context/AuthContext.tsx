// src/context/AuthContext.tsx
import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '../services/supabaseClient';

export interface UserSubscription {
  planType: string;
  status: string;
  currentPeriodEnd?: string | null;
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  subscription: UserSubscription | null;
  loading: boolean;
  logout: () => Promise<void>;
  refreshSubscription: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({} as AuthContextType);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [subscription, setSubscription] = useState<UserSubscription | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  const fetchSubscription = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('user_subscriptions')
        .select('plan_type, status, current_period_end')
        .eq('user_id', userId)
        .maybeSingle();

      if (!error && data) {
        setSubscription({
          planType: data.plan_type,
          status: data.status,
          currentPeriodEnd: data.current_period_end,
        });
      } else {
        setSubscription(null);
      }
    } catch {
      setSubscription(null);
    }
  };

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session: currentSession } }) => {
      setSession(currentSession);
      setUser(currentSession?.user ?? null);
      if (currentSession?.user) {
        fetchSubscription(currentSession.user.id);
      }
      setLoading(false);
    });

    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (event, currentSession) => {
        setSession(currentSession);
        setUser(currentSession?.user ?? null);

        if (currentSession?.user) {
          await fetchSubscription(currentSession.user.id);
        } else {
          setSubscription(null);
        }
        setLoading(false);
      }
    );

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, []);

  const logout = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setSession(null);
    setSubscription(null);
  };

  const refreshSubscription = async () => {
    if (user) {
      await fetchSubscription(user.id);
    }
  };

  return (
    <AuthContext.Provider
      value={{ user, session, subscription, loading, logout, refreshSubscription }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);