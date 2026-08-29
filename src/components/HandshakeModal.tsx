import React from 'react';
import { Handshake, Trophy } from 'lucide-react';

interface HandshakeModalProps {
  isOpen: boolean;
  winnerName: string;
  marginText: string;
  gameMode: string;
  onClose: () => void;
  onFinishRound?: () => void;
}

export const HandshakeModal: React.FC<HandshakeModalProps> = ({
  isOpen,
  winnerName,
  marginText,
  gameMode,
  onClose,
  onFinishRound,
}) => {
  if (!isOpen) return null;

  const handleConfirm = async () => {
    onClose();
    if (onFinishRound) {
      await onFinishRound(); // Esto cambia la BD a 'finished' y debe resetear la vista activa a RoundSetup
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl shadow-2xl max-w-sm w-full p-6 text-center transform animate-in fade-in zoom-in duration-200">
        <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4 text-emerald-600">
          🤝
        </div>
        
        <h2 className="text-2xl font-bold text-gray-900 mb-1">¡Partida Decidida!</h2>
        <p className="text-sm text-gray-500 mb-6 uppercase tracking-wider font-semibold">
          {gameMode === 'match' ? 'Match Play' : 'Parejas'}
        </p>

        <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 mb-6">
          <p className="text-xs text-emerald-800 font-medium mb-1">Ganador</p>
          <p className="text-xl font-extrabold text-emerald-950 mb-2">{winnerName}</p>
          <span className="inline-block bg-emerald-600 text-white text-xs font-bold px-3 py-1 rounded-full">
            Resultado: {marginText}
          </span>
        </div>

        <button
          onClick={handleConfirm}
          className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 px-4 rounded-xl transition-colors shadow-lg shadow-emerald-600/30"
        >
          Entendido (La partida se finalizará)
        </button>
      </div>
    </div>
  );
};