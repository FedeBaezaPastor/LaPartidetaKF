import React from 'react';

interface HandshakeModalProps {
  isOpen: boolean;
  winnerName: string;
  marginText: string;
  gameMode: string;
  onContinue: () => void;
  onFinishRound?: () => void;
}

export const HandshakeModal: React.FC<HandshakeModalProps> = ({
  isOpen,
  winnerName,
  marginText,
  gameMode,
  onContinue,
  onFinishRound,
}) => {
  if (!isOpen) return null;

  const handleFinish = async () => {
    if (onFinishRound) await onFinishRound();
  };

  const modeLabel = gameMode === 'match'
    ? 'Match Play'
    : gameMode === 'sindicato'
      ? 'Sindicato'
      : 'Parejas';

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl shadow-2xl max-w-sm w-full p-6 text-center transform animate-in fade-in zoom-in duration-200">
        <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4 text-3xl">
          🤝
        </div>

        <h2 className="text-2xl font-bold text-gray-900 mb-1">¡Partida decidida!</h2>
        <p className="text-sm text-gray-500 mb-6 uppercase tracking-wider font-semibold">{modeLabel}</p>

        <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 mb-5">
          <p className="text-xs text-emerald-800 font-medium mb-1">Ganador</p>
          <p className="text-xl font-extrabold text-emerald-950 mb-2">{winnerName}</p>
          <span className="inline-block bg-emerald-600 text-white text-xs font-bold px-3 py-1 rounded-full">
            Resultado: {marginText}
          </span>
        </div>

        <p className="text-sm text-gray-700 font-medium mb-4">
          El resultado ya no puede cambiar. ¿Quieres finalizar la partida igualmente?
        </p>

        <div className="space-y-3">
          <button
            onClick={onContinue}
            className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 px-4 rounded-xl transition-colors shadow-lg shadow-emerald-600/30"
          >
            No, seguir jugando
          </button>
          <button
            onClick={handleFinish}
            className="w-full bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-3 px-4 rounded-xl transition-colors"
          >
            Sí, finalizar partida
          </button>
        </div>
      </div>
    </div>
  );
};
