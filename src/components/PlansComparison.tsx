import React, { useState } from 'react';
import { ArrowLeft, Zap, User, Users, Check, X, Info, LogIn } from 'lucide-react';
import { PlanType } from '../types';

interface PlansComparisonProps {
  onBack: () => void;
  onSelectPlan: (plan: PlanType) => void;
  onShowAuth?: () => void;
}

interface PlanFeature {
  label: string;
  express: boolean | string;
  player: boolean | string;
  team: boolean | string;
}

const features: PlanFeature[] = [
  { label: 'Partidas Express', express: '4 gratis', player: 'Ilimitadas', team: 'Ilimitadas' },
  { label: 'Stableford', express: true, player: true, team: true },
  { label: 'Modalidad Medal', express: false, player: true, team: true },
  { label: 'Modalidad Match', express: false, player: true, team: true },
  { label: 'Modalidad Sindicato', express: false, player: true, team: true },
  { label: 'Estadisticas en la nube', express: false, player: true, team: true },
  { label: 'Historial de partidas', express: false, player: true, team: true },
  { label: 'Crear Teams (grupos)', express: false, player: false, team: true },
  { label: 'Invitar jugadores por Nick', express: false, player: false, team: true },
  { label: 'Ligas y clasificaciones de grupo', express: false, player: false, team: true },
  { label: 'Hoyo 19 (gamificacion)', express: false, player: false, team: true },
  { label: 'Pro-Shop (ampliaciones)', express: false, player: false, team: true },
];

export const PlansComparison: React.FC<PlansComparisonProps> = ({ onBack, onSelectPlan, onShowAuth }) => {
  const [selectedPlan, setSelectedPlan] = useState<PlanType | null>(null);

  const renderValue = (value: boolean | string) => {
    if (value === true) return <Check className="w-5 h-5 text-accent-ink mx-auto" />;
    if (value === false) return <X className="w-5 h-5 text-ink-4 mx-auto" />;
    return <span className="text-sm font-semibold text-ink-2">{value}</span>;
  };

  return (
    <div className="min-h-screen bg-app transition-colors">
      <div className="max-w-5xl mx-auto px-4 py-6">
        <button
          onClick={onBack}
          className="flex items-center gap-2 text-ink-3 hover:text-ink transition-colors mb-6"
        >
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-ink mb-2">Lleva tu golf al siguiente nivel</h1>
          <p className="text-ink-3">Elige el plan que mejor se adapta a tu juego</p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 mb-8">
          {/* Express */}
          <div className="bg-card rounded-2xl shadow-card p-6 flex flex-col border-2 border-line hover:border-line-2 transition-all">
            <div className="w-12 h-12 bg-card-2 rounded-full flex items-center justify-center mb-4">
              <Zap className="w-6 h-6 text-ink-3" />
            </div>
            <h2 className="text-xl font-bold text-ink">Express</h2>
            <p className="text-3xl font-bold text-ink mt-2">Gratis</p>
            <p className="text-sm text-ink-3 mb-4">Para probar la app</p>
            <ul className="space-y-2 text-sm text-ink-3 mb-6 flex-1">
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> 4 partidas gratis</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Modalidad Stableford</li>
              <li className="flex items-center gap-2"><X size={16} className="text-ink-4" /> Sin estadisticas en la nube</li>
            </ul>
            <button
              onClick={() => onSelectPlan('express')}
              className="w-full bg-card-2 hover:bg-neutral-hover text-ink-2 font-semibold py-3 rounded-xl transition-colors"
            >
              Empezar gratis
            </button>
          </div>

          {/* Player */}
          <div className="bg-card rounded-2xl shadow-card p-6 flex flex-col border-2 border-accent-ring transition-all">
            <div className="w-12 h-12 bg-accent-soft rounded-full flex items-center justify-center mb-4">
              <User className="w-6 h-6 text-accent-ink" />
            </div>
            <h2 className="text-xl font-bold text-ink">Player</h2>
            <p className="text-3xl font-bold text-ink mt-2">2,99&euro;<span className="text-base font-normal text-ink-3">/mes</span></p>
            <p className="text-sm text-ink-3 mb-4">Para jugadores habituales</p>
            <ul className="space-y-2 text-sm text-ink-3 mb-6 flex-1">
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Partidas ilimitadas</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Todas las modalidades</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Estadisticas en la nube</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Historial completo</li>
            </ul>
            <button
              onClick={() => setSelectedPlan('player')}
              className="w-full bg-accent hover:bg-accent-hover text-on-accent font-semibold py-3 rounded-xl transition-colors"
            >
               Registrarse
            </button>
          </div>

          {/* Team */}
          <div className="bg-card rounded-2xl shadow-card p-6 flex flex-col border-2 border-amber-400 relative">
            <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-amber-500 text-white text-xs font-bold px-3 py-1 rounded-full">
              RECOMENDADO
            </div>
            <div className="w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center mb-4">
              <Users className="w-6 h-6 text-amber-600" />
            </div>
            <h2 className="text-xl font-bold text-ink">Team</h2>
            <p className="text-3xl font-bold text-ink mt-2">5,99&euro;<span className="text-base font-normal text-ink-3">/mes</span></p>
            <p className="text-sm text-ink-3 mb-4">Para grupos y clubes</p>
            <ul className="space-y-2 text-sm text-ink-3 mb-6 flex-1">
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Todo lo de Player</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Crear Teams</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Invitar por Nick</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Hoyo 19</li>
              <li className="flex items-center gap-2"><Check size={16} className="text-accent-ink" /> Pro-Shop</li>
            </ul>
            <button
              onClick={() => setSelectedPlan('team')}
              className="w-full bg-amber-500 hover:bg-amber-600 text-white font-semibold py-3 rounded-xl transition-colors"
            >
              Registrarse
            </button>
          </div>
        </div>

        {/* Feature comparison table */}
        <div className="bg-card rounded-2xl shadow-card overflow-hidden hidden md:block">
          <table className="w-full">
            <thead>
              <tr className="bg-card-2 border-b border-line">
                <th className="text-left px-6 py-4 text-sm font-semibold text-ink-2">Caracteristica</th>
                <th className="px-6 py-4 text-sm font-semibold text-ink-2">Express</th>
                <th className="px-6 py-4 text-sm font-semibold text-accent-ink">Player</th>
                <th className="px-6 py-4 text-sm font-semibold text-amber-700">Team</th>
              </tr>
            </thead>
            <tbody>
              {features.map((f, i) => (
                <tr key={i} className={i % 2 === 0 ? 'bg-card' : 'bg-card-2'}>
                  <td className="px-6 py-3 text-sm text-ink-2">{f.label}</td>
                  <td className="px-6 py-3 text-center">{renderValue(f.express)}</td>
                  <td className="px-6 py-3 text-center">{renderValue(f.player)}</td>
                  <td className="px-6 py-3 text-center">{renderValue(f.team)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {selectedPlan && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
            <div className="bg-card rounded-2xl max-w-md w-full p-6 shadow-card">
              <div className="flex items-start gap-3 mb-4">
                <Info className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
                <div>
                  <h3 className="font-bold text-ink">Has elegido el plan {selectedPlan === 'player' ? 'Player' : 'Team'}</h3>
                  <p className="text-sm text-ink-3 mt-1">Vamos a crear tu cuenta. Necesitamos algunos datos para configurar tu perfil.</p>
                </div>
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => setSelectedPlan(null)}
                  className="flex-1 bg-card-2 hover:bg-neutral-hover text-ink-2 font-semibold py-2.5 rounded-xl transition-colors"
                >
                  Cancelar
                </button>
                <button
                  onClick={() => onSelectPlan(selectedPlan)}
                  className="flex-1 bg-accent hover:bg-accent-hover text-on-accent font-semibold py-2.5 rounded-xl transition-colors"
                >
                  Continuar
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Login link for existing users */}
        {onShowAuth && (
          <div className="text-center mt-6 pb-6">
            <p className="text-sm text-ink-3 mb-2">¿Ya tienes cuenta?</p>
            <button
              onClick={onShowAuth}
              className="inline-flex items-center gap-2 text-accent-ink font-semibold hover:underline transition-colors"
            >
              <LogIn size={16} />
              Iniciar sesión
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
