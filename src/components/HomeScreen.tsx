import React from 'react';
import { Zap, LogIn, Plus, Share2, Bell, Crown, ChevronRight } from 'lucide-react';
import { PlanType, UserProfile } from '../types';

interface HomeScreenProps {
  planType: PlanType;
  profile: UserProfile | null;
  pendingInvitations: number;
  onQuickPlay: () => void;
  onJoinQuickPlay: () => void;
  onCreateTeam: () => void;
  onShowPlans: () => void;
  onShowProfile: () => void;
  onShowNotifications: () => void;
  onShowAuth: () => void;
  onShowShare: () => void;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({
  planType,
  profile,
  pendingInvitations,
  onQuickPlay,
  onJoinQuickPlay,
  onCreateTeam,
  onShowPlans,
  onShowProfile,
  onShowNotifications,
  onShowAuth,
  onShowShare,
}) => {
  const isExpress = planType === 'express';
  const isTeam = planType === 'team';

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-slate-50 to-emerald-100 flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        {/* Top bar */}
        <div className="flex items-center justify-between mb-8">
          {/* Notifications bell (only for registered users) */}
          {!isExpress && (
            <button
              onClick={onShowNotifications}
              className="relative p-2.5 bg-white/70 backdrop-blur rounded-full shadow-soft hover:bg-white transition-all"
            >
              <Bell size={20} className="text-ink-2" />
              {pendingInvitations > 0 && (
                <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
                  {pendingInvitations}
                </span>
              )}
            </button>
          )}
          {isExpress && <div className="w-10" />}

          {/* Entrance pill / Nick */}
          {isExpress ? (
            <button
              onClick={onShowPlans}
              className="flex items-center gap-2 bg-accent text-on-accent px-5 py-2.5 rounded-full shadow-soft hover:bg-accent-hover transition-all font-semibold text-sm"
            >
              <LogIn size={16} />
              Entrar
            </button>
          ) : (
            <button
              onClick={onShowProfile}
              className="flex items-center gap-2 bg-white/80 backdrop-blur px-4 py-2.5 rounded-full shadow-soft hover:bg-white transition-all"
            >
              {profile?.avatar_url && (
                <img src={profile.avatar_url} alt="avatar" className="w-6 h-6 rounded-full" />
              )}
              <span className="font-semibold text-ink text-sm">{profile?.nick || 'Perfil'}</span>
              {isTeam && <Crown size={16} className="text-amber-500" />}
              <ChevronRight size={16} className="text-ink-4" />
            </button>
          )}
        </div>

        {/* Logo */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-24 h-24 rounded-3xl shadow-card mb-4 overflow-hidden bg-card">
            <img src="/images/Omiki.png" alt="OMIKI Golf" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-4xl font-bold text-ink mb-1">OMIKI Golf</h1>
          <p className="text-ink-3">Tu companero de golf</p>
        </div>

        {/* Main buttons */}
        <div className="space-y-3 mb-6">
          <button
            onClick={onQuickPlay}
            className="w-full flex items-center justify-center gap-3 bg-accent text-on-accent px-6 py-4 rounded-2xl hover:bg-accent-hover transition-all font-semibold text-lg shadow-card active:scale-[0.98]"
          >
            <Zap className="w-6 h-6" />
            {isExpress ? 'Crear Partida Express' : 'Crear Partida'}
          </button>

          <button
            onClick={onJoinQuickPlay}
            className="w-full flex items-center justify-center gap-3 bg-card text-accent-ink border-2 border-accent px-6 py-4 rounded-2xl hover:bg-accent-soft transition-all font-semibold text-lg active:scale-[0.98]"
          >
            <LogIn className="w-6 h-6" />
            Unirse a Partida
          </button>

          {isTeam && (
            <button
              onClick={onCreateTeam}
              className="w-full flex items-center justify-center gap-3 bg-amber-500 text-white px-6 py-4 rounded-2xl hover:bg-amber-600 transition-all font-semibold text-lg shadow-card active:scale-[0.98]"
            >
              <Plus className="w-6 h-6" />
              Crear Team
            </button>
          )}
        </div>

        {/* Share button */}
        <button
          onClick={onShowShare}
          className="w-full flex items-center justify-center gap-2 bg-slate-800 text-white px-6 py-3 rounded-xl hover:bg-slate-900 transition-colors font-medium text-sm shadow"
        >
          <Share2 className="w-5 h-5" />
          Compartir App / Codigo QR
        </button>

      </div>
    </div>
  );
};
