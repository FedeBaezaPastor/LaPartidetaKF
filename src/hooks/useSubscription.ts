import { useEffect, useState } from 'react';
import { supabase } from '../services/supabaseClient';

export const useSubscription = () => {
  const [isPremium, setIsPremium] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const check = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        setIsPremium(false);
        setLoading(false);
        return;
      }

      const { data } = await supabase
        .from('user_subscriptions')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

      const active = data && new Date(data.current_period_end) > new Date();
      setIsPremium(!!active);
      setLoading(false);
    };

    check();
  }, []);

  return { isPremium, loading };
};