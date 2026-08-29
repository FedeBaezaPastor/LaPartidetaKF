import React from 'react';
import { Zap, ShieldCheck, ArrowRight, Lock, CheckCircle2 } from 'lucide-react';
import { UPGRADE_TIERS, TierInfo } from '../services/expressTierGuard';

interface ParTeeUpgradeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectTier: (tier: TierInfo) => void;
}

export const ParTeeUpgradeModal: React.FC<ParTeeUpgradeModalProps> = ({
  isOpen,
  onClose,
  onSelectTier
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fadeIn">
      <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-2xl w-full p-6 md:p-8 shadow-2xl overflow-hidden relative">
        
        {/* Cabecera del Modal */}
        <div className="text-center mb-6">
          <div className="w-12 h-12 bg-amber-500/10 border border-amber-500/20 rounded-2xl flex items-center justify-center mx-auto mb-3 text-amber-400">
            <Lock size={24} />
          </div>
          <span className="bg-slate-800 text-amber-400 border border-amber-500/20 text-xs font-black uppercase px-3 py-1 rounded-full">
            Límite de Tier Alcanzado
          </span>
          <h2 className="text-2xl md:text-3xl font-black text-white mt-3">
            Has consumido tus 4 partidas gratuitas
          </h2>
          <p className="text-slate-400 text-sm mt-1 max-w-md mx-auto">
            Has completado el cupo del plan <span className="text-emerald-400 font-bold">Par Tee Express</span> en este dispositivo.
          </p>
        </div>

        {/* Listado de Planes Superiores */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-6">
          {UPGRADE_TIERS.map((tier) => (
            <div
              key={tier.id}
              onClick={() => onSelectTier(tier)}
              className={`p-4 rounded-2xl border transition-all cursor-pointer flex flex-col justify-between relative ${
                tier.recommended
                  ? 'bg-gradient-to-b from-slate-800 to-slate-900 border-emerald-500/50 hover:border-emerald-400 shadow-lg shadow-emerald-950/50'
                  : 'bg-slate-800/50 border-slate-700/60 hover:border-slate-500'
              }`}
            >
              {tier.recommended && (
                <span className="absolute -top-2.5 left-1/2 -translate-x-1/2 bg-emerald-500 text-slate-950 text-[10px] font-black uppercase px-2 py-0.5 rounded-full">
                  Recomendado
                </span>
              )}
              <div>
                <h3 className="text-white font-bold text-base mb-1">{tier.name}</h3>
                <p className="text-slate-400 text-xs leading-relaxed mb-4">{tier.description}</p>
              </div>
              <button className="w-full py-2 px-3 bg-slate-700 hover:bg-emerald-600 text-white rounded-xl text-xs font-bold transition-colors flex items-center justify-center gap-1">
                <span>Ver Plan</span>
                <ArrowRight size={12} />
              </button>
            </div>
          ))}
        </div>

        {/* Footer Informativo */}
        <div className="pt-4 border-t border-slate-800 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-slate-500">
          <div className="flex items-center gap-1.5">
            <CheckCircle2 size={14} className="text-emerald-400" />
            <span>Guarda tu historial en la nube al actualizar</span>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white transition-colors underline"
          >
            Volver al inicio
          </button>
        </div>

      </div>
    </div>
  );
};