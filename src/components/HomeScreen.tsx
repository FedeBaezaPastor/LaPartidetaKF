import { WriteButton } from '../context/ReadOnlyContext';
import React from 'react';
import { Zap, LogIn, Plus, Share2, Bell, User, ChevronRight, FlaskConical, CreditCard } from 'lucide-react';
import { PlanType, UserProfile } from '../types';
import { ThemeToggle } from './ThemeToggle';
import { ResetExpressRounds } from './ResetExpressRounds';

interface HomeScreenProps {
  planType: PlanType;
  isAuthenticated: boolean;
  userEmail?: string;
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
  simulatorEnabled: boolean;
  simulatorUpdating: boolean;
  onToggleSimulator: () => void;
  onCycleSimulatorPlan: () => void;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({
  planType,
  isAuthenticated,
  userEmail,
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
  simulatorEnabled,
  simulatorUpdating,
  onToggleSimulator,
  onCycleSimulatorPlan,
}) => {
  const isExpress = planType === 'express';
  const isTeam = planType === 'team';
  const plansButton = (
    <button
      onClick={onShowPlans}
      className="w-full flex items-center justify-center gap-3 bg-card-2 text-ink-2 border border-line px-6 py-3.5 rounded-2xl hover:bg-neutral-hover transition-all font-semibold active:scale-[0.98]"
    >
      <CreditCard className="w-5 h-5 text-accent-ink" />
      Ver planes
    </button>
  );

  return (
    <div className="min-h-screen bg-app flex justify-center px-4 py-4 sm:py-8 transition-colors">
      <div className="max-w-md w-full">
        {/* Top bar */}
        <div className="flex items-center justify-between gap-3 mb-5">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onShowShare}
              title="Compartir la app"
              aria-label="Compartir la app"
              className="relative p-2.5 bg-card border border-line rounded-full shadow-soft hover:bg-card-2 transition-all"
            >
              <Share2 size={20} className="text-ink-2" />
            </button>

            {isAuthenticated && (
              <button
                type="button"
                onClick={onShowNotifications}
                title="Avisos"
                aria-label="Avisos"
                className="relative p-2.5 bg-card border border-line rounded-full shadow-soft hover:bg-card-2 transition-all"
              >
                <Bell size={20} className="text-ink-2" />
                {pendingInvitations > 0 && (
                  <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
                    {pendingInvitations}
                  </span>
                )}
              </button>
            )}

            <ThemeToggle />
          </div>

          {/* Acceso / Perfil */}
          {!isAuthenticated ? (
            <button
              type="button"
              onClick={onShowAuth}
              title="Entrar"
              aria-label="Entrar"
              className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-accent bg-accent text-on-accent shadow-soft transition-all hover:bg-accent-hover active:scale-95 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-current"
            >
              <LogIn size={22} aria-hidden="true" />
            </button>
          ) : (
            <button
              onClick={onShowProfile}
              title="Mi perfil"
              aria-label="Abrir Mi perfil"
              className="flex items-center justify-center w-11 h-11 bg-card border border-line rounded-full shadow-soft hover:bg-card-2 transition-all"
            >
              {profile?.avatar_url ? (
                <img src={profile.avatar_url} alt="" className="w-9 h-9 rounded-full" />
              ) : (
                <User size={21} className="text-ink-2" />
              )}
            </button>
          )}
        </div>

        {isAuthenticated && (
          <div className="bg-card border border-line rounded-2xl px-4 py-3 mb-5 shadow-soft text-center">
            <p className="font-semibold text-ink">¡Bienvenido!</p>
            <div className="flex items-center justify-center gap-2 mt-1 min-w-0">
              <span className="text-sm text-ink-3 truncate">{profile?.nick || userEmail}</span>
              <span className={`shrink-0 text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${
                isTeam ? 'bg-amber-100 text-amber-700' : 'bg-accent-soft text-accent-ink'
              }`}>
                {planType}
              </span>
            </div>
          </div>
        )}

        {/* Logo */}
        <div className="text-center mb-6 sm:mb-8">
          <div className="inline-flex items-center justify-center w-24 h-24 sm:w-28 sm:h-28 rounded-full shadow-card mb-3 overflow-hidden bg-transparent">
            <img src="/images/Omiki.png" alt="OMIKI Golf" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-4xl font-bold text-ink mb-1">OMIKI Golf</h1>
          <p className="text-ink-3">Tu companero de golf</p>
        </div>

        {/* Main buttons */}
        <div className="space-y-3 mb-6">
          <WriteButton
            onClick={onQuickPlay}
            className="w-full flex items-center justify-center gap-3 bg-accent text-on-accent px-6 py-4 rounded-2xl hover:bg-accent-hover transition-all font-semibold text-lg shadow-card active:scale-[0.98]"
          >
            <Zap className="w-6 h-6" />
            {isExpress ? 'Crear Partida Express' : 'Crear Partida'}
          </WriteButton>

          <WriteButton
            onClick={onJoinQuickPlay}
            className="w-full flex items-center justify-center gap-3 bg-card text-accent-ink border-2 border-accent px-6 py-4 rounded-2xl hover:bg-accent-soft transition-all font-semibold text-lg active:scale-[0.98]"
          >
            <LogIn className="w-6 h-6" />
            Unirse a Partida
          </WriteButton>

          {!isTeam && plansButton}

          {isTeam && (
            <WriteButton
              onClick={onCreateTeam}
              className="w-full flex items-center justify-center gap-3 bg-amber-500 text-white px-6 py-4 rounded-2xl hover:bg-amber-600 transition-all font-semibold text-lg shadow-card active:scale-[0.98]"
            >
              <Plus className="w-6 h-6" />
              Crear Team
            </WriteButton>
          )}
        </div>

        <div className="mt-6 flex items-center justify-center gap-3">
          {isExpress && !isAuthenticated && <ResetExpressRounds />}
          <WriteButton
            type="button"
            onClick={onToggleSimulator}
            disabled={simulatorUpdating}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold transition-all disabled:opacity-60 ${
              simulatorEnabled
                ? 'bg-blue-600 text-white shadow-soft'
                : 'bg-card text-ink-3 border border-line hover:bg-card-2'
            }`}
          >
            <FlaskConical size={14} />
            Simulador
          </WriteButton>

          {simulatorEnabled && (
            <WriteButton
              type="button"
              onClick={onCycleSimulatorPlan}
              disabled={simulatorUpdating}
              className="flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold bg-card text-ink-2 shadow-soft hover:bg-card-2 transition-all border border-line disabled:opacity-60"
            >
              Plan: <span className="text-accent-ink capitalize">{planType}</span>
              <ChevronRight size={14} className="text-ink-4" />
            </WriteButton>
          )}

          {isTeam && plansButton}
        </div>

        {simulatorEnabled && (
          <p className="text-center text-xs text-ink-4 mt-2">
            Viendo la app como {profile?.nick || 'usuario'} con plan {planType}
          </p>
        )}

      </div>
    </div>
  );
};
