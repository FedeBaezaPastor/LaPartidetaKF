import React from 'react';

interface ScoreSymbolProps {
  grossStrokes: number;
  par: number;
  strokesReceived: number;
}

export const ScoreSymbol: React.FC<ScoreSymbolProps> = ({
  grossStrokes,
  par,
  strokesReceived,
}) => {
  const netStrokes = grossStrokes - strokesReceived;
  const difference = netStrokes - par;

  const renderSymbol = () => {
    if (difference <= -2) {
      return (
        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-yellow-400 to-amber-500 flex items-center justify-center shadow-md">
          <span className="text-sm font-bold text-black">{grossStrokes}</span>
        </div>
      );
    } else if (difference === -1) {
      return (
        <div className="w-7 h-7 rounded-full bg-red-500 flex items-center justify-center shadow-md">
          <span className="text-sm font-bold text-white">{grossStrokes}</span>
        </div>
      );
    } else if (difference === 0) {
      return (
        <div className="w-7 h-7 rounded-full bg-white border-2 border-gray-300 flex items-center justify-center shadow-sm">
          <span className="text-sm font-bold text-black">{grossStrokes}</span>
        </div>
      );
    } else if (difference === 1) {
      return (
        <div className="w-7 h-7 rounded-full bg-blue-500 flex items-center justify-center shadow-md">
          <span className="text-sm font-bold text-white">{grossStrokes}</span>
        </div>
      );
    } else {
      return (
        <div className="w-7 h-7 rounded-full bg-black flex items-center justify-center shadow-md">
          <span className="text-sm font-bold text-white">{grossStrokes}</span>
        </div>
      );
    }
  };

  return renderSymbol();
};
