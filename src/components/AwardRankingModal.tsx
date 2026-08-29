import React from 'react';
import { X } from 'lucide-react';

interface RankingEntry {
  player_name: string;
  player_id: string;
  value: number;
  handicap: number | null;
  rounds_played: number;
}

interface AwardRankingModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  description: string;
  ranking: RankingEntry[];
  valueLabel: string;
  colorScheme: {
    bg: string;
    border: string;
    text: string;
    accent: string;
  };
}

export const AwardRankingModal: React.FC<AwardRankingModalProps> = ({
  isOpen,
  onClose,
  title,
  description,
  ranking,
  valueLabel,
  colorScheme,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
        <div className={`${colorScheme.bg} p-6 border-b-4 ${colorScheme.border}`}>
          <div className="flex items-center justify-between">
            <div>
              <h2 className={`text-2xl font-bold ${colorScheme.text}`}>{title}</h2>
              <p className="text-sm text-gray-700 mt-1">{description}</p>
            </div>
            <button
              onClick={onClose}
              className="text-gray-700 hover:text-gray-900 transition-colors"
            >
              <X size={24} />
            </button>
          </div>
        </div>

        <div className="p-6 overflow-y-auto max-h-[calc(80vh-140px)]">
          {ranking.length === 0 ? (
            <p className="text-center text-gray-500 py-8">No hay datos disponibles</p>
          ) : (
            <div className="space-y-3">
              {ranking.map((entry, index) => (
                <div
                  key={entry.player_id || `${entry.player_name}-${index}`}
                  className={`p-4 rounded-lg border flex items-center justify-between transition-all ${
                    index === 0
                      ? `${colorScheme.bg} ${colorScheme.border} border-2 shadow-lg`
                      : index === 1
                      ? 'bg-slate-100 border-slate-400 border-2 shadow-md'
                      : index === 2
                      ? 'bg-amber-50 border-amber-400 border-2 shadow-md'
                      : 'bg-white border-gray-200 hover:bg-gray-50'
                  }`}
                >
                  <div className="flex items-center gap-4 flex-1">
                    <div
                      className={`text-xl font-bold w-10 h-10 flex items-center justify-center rounded-full ${
                        index === 0
                          ? `${colorScheme.accent} ${colorScheme.text}`
                          : index === 1
                          ? 'bg-slate-400 text-white'
                          : index === 2
                          ? 'bg-amber-500 text-white'
                          : 'bg-gray-300 text-gray-700'
                      }`}
                    >
                      {index + 1}
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-lg text-gray-800">{entry.player_name}</p>
                      <div className="flex gap-4 text-sm text-gray-600 mt-1">
                        <span>{entry.rounds_played} partidas</span>
                        {entry.handicap !== null && entry.handicap !== undefined && (
                          <span>HCP Medio: {Number(entry.handicap).toFixed(1)}</span>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className={`text-3xl font-bold ${index === 0 ? colorScheme.text : 'text-gray-700'}`}>
                      {entry.value}
                    </p>
                    <p className="text-xs text-gray-500 mt-1">{valueLabel}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};