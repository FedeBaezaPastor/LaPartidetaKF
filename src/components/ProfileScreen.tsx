import React, { useState } from 'react';
import { ArrowLeft, LogOut, Settings, BarChart3, Gamepad2, Crown, ChevronRight, CreditCard } from 'lucide-react';
import { UserProfile, PlanType } from '../types';

interface ProfileScreenProps {
  profile: UserProfile | null;
  planType: PlanType;
  onBack: () => void;
  onLogout: () => void;
  onShowStats: () => void;
  onShowHistory: () => void;
  onShowUpgrade: () => void;
  onShowProShop: () => void;
  onShowGroups: () => void;
  onShowSettings: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({
  profile,
  planType,
  onBack,
  onLogout,
  onShowStats,
  onShowHistory,
  onShowUpgrade,
  onShowProShop,
  onShowGroups,
  onShowSettings,
}) => {
  const isTeam = planType === 'team';
  const isPlayer = planType === 'player';

  const menuItems = [
    { icon: Gamepad2, label: 'Mis partidas jugadas', onClick: onShowHistory, show: true },
    { icon: BarChart3, label: 'Mis estadisticas', onClick: onShowStats, show: true },
    { icon: Crown, label: 'Mis grupos', onClick: onShowGroups, show: isTeam },
    { icon: CreditCard, label: 'Pro-Shop', onClick: onShowProShop, show: isTeam },
    { icon: Settings, label: 'Mis datos de registro', onClick: onShowSettings, show: true },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-emerald-50">
      <div className="max-w-lg mx-auto px-4 py-6">
        <div className="flex items-center justify-between mb-6">
          <button onClick={onBack} className="flex items-center gap-2 text-ink-3 hover:text-ink">
            <ArrowLeft size={20} />
            Volver
          </button>
          <button
            onClick={onLogout}
            className="flex items-center gap-2 text-red-600 hover:text-red-700 text-sm font-medium"
          >
            <LogOut size={18} />
            Cerrar sesion
          </button>
        </div>

        {/* Profile header */}
        <div className="bg-card rounded-2xl shadow-card p-6 mb-5">
          <div className="flex items-center gap-4">
            {profile?.avatar_url ? (
              <img src={profile.avatar_url} alt="avatar" className="w-16 h-16 rounded-full border-2 border-accent-ring" />
            ) : (
              <div className="w-16 h-16 bg-accent-soft rounded-full flex items-center justify-center">
                <Settings className="text-accent-ink" size={24} />
              </div>
            )}
            <div className="flex-1">
              <h2 className="text-xl font-bold text-ink">{profile?.nick || 'Jugador'}</h2>
              <p className="text-sm text-ink-3">{profile?.display_name || ''}</p>
              <div className="flex items-center gap-2 mt-1">
                <span className={`text-xs font-bold px-2 py-0.5 rounded-full uppercase ${isTeam ? 'bg-amber-100 text-amber-700' : 'bg-accent-soft text-accent-ink'}`}>
                  {planType}
                </span>
                {profile?.exact_handicap !== undefined && (
                  <span className="text-xs text-ink-3">HCP {profile.exact_handicap}</span>
                )}
              </div>
            </div>
            {isTeam && <Crown className="text-amber-500" size={24} />}
          </div>
        </div>

        {/* Upgrade banner for Player */}
        {isPlayer && (
          <button
            onClick={onShowUpgrade}
            className="w-full bg-gradient-to-r from-amber-400 to-amber-500 text-white rounded-2xl p-4 mb-5 shadow-card hover:from-amber-500 hover:to-amber-600 transition-all text-left flex items-center justify-between"
          >
            <div>
              <p className="font-bold">Prueba Team por 30 dias</p>
              <p className="text-sm text-white/90">Crea grupos, invita jugadores y mucho mas</p>
            </div>
            <ChevronRight size={20} />
          </button>
        )}

        {/* Menu items */}
        <div className="bg-card rounded-2xl shadow-card overflow-hidden">
          {menuItems.filter(m => m.show).map((item, i) => (
            <button
              key={i}
              onClick={item.onClick}
              className={`w-full flex items-center gap-3 px-5 py-4 hover:bg-card-2 transition-colors ${i > 0 ? 'border-t border-line' : ''}`}
            >
              <item.icon size={20} className="text-ink-3" />
              <span className="flex-1 text-left font-medium text-ink">{item.label}</span>
              <ChevronRight size={18} className="text-ink-4" />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};
