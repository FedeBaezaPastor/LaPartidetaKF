import React, { useState, useEffect } from 'react';
import { GolfHole, RoundPlayer, RoundScore, GameMode } from '../types';
import { calculateScore, getStrokesReceived, calculateModePoints, ModeScoreInput } from '../utils/calculations';
import { ChevronDown, Trash2, Minus } from 'lucide-react';
import { HoleInOneModal } from './HoleInOneModal';
import { CongratulationsModal } from './CongratulationsModal';

interface HoleCardProps {
  hole: GolfHole;
  players: RoundPlayer[];
  scores: Record<string, RoundScore | undefined>;
  numHoles: 9 | 18;
  allHoles: GolfHole[];
  allHoleScores?: Record<string, Record<number, RoundScore | undefined>>;
  readonly?: boolean;
  groupCode?: string | null;
  gameMode?: GameMode;
  teamAssignments?: Record<string, 0 | 1>;
  onScoreChange: (playerId: string, score: any) => void;
}

export const HoleCard: React.FC<HoleCardProps> = ({
  hole,
  players,
  scores,
  numHoles,
  allHoles,
  readonly = false,
  groupCode = null,
  gameMode = 'stableford',
  teamAssignments = {},
  allHoleScores = {},
  onScoreChange,
}) => {
  const isDivend = groupCode === 'DIVEND';
  const isModeScoring = gameMode !== 'stableford';
  const [expandedPlayerId, setExpandedPlayerId] = useState<string | null>(null);
  const [firstDigit, setFirstDigit] = useState<number | null>(null);
  const [pendingPlayerId, setPendingPlayerId] = useState<string | null>(null);
  const [showHoleInOneModal, setShowHoleInOneModal] = useState(false);
  const [showCongratulationsModal, setShowCongratulationsModal] = useState(false);
  const [congratsPlayerName, setCongratsPlayerName] = useState('');
  const [pendingNoPasoRojas, setPendingNoPasoRojas] = useState<Record<string, boolean>>({});

  const computeModePointsForPlayer = (playerId: string, grossStrokesVal: number, strokesRecv: number, abandonedVal: boolean): number => {
    if (!isModeScoring) return 0;
    const allScores: ModeScoreInput[] = players.map(p => {
      const pscore = scores[p.id];
      if (p.id === playerId) {
        return { playerId: p.id, netStrokes: abandonedVal ? 999 : grossStrokesVal - strokesRecv, abandoned: abandonedVal };
      }
      if (!pscore || pscore.abandoned) return { playerId: p.id, netStrokes: 999, abandoned: true };
      return { playerId: p.id, netStrokes: pscore.net_strokes, abandoned: false };
    });
    return calculateModePoints(gameMode, playerId, allScores, teamAssignments);
  };
  useEffect(() => {
    console.log('🎯 HoleCard: Players prop received:', players.map(p => ({ name: p.name, playing_handicap: p.playing_handicap })));
  }, [players]);

  const getMatchStatus = (): { label: string; leader: string | null; diff: number } => {
    if (!isModeScoring || players.length < 2) return { label: '', leader: null, diff: 0 };
    const totals = players.map((p) => {
      let won = 0;
      let lost = 0;
      let totalPoints = 0;
      for (const h of allHoles) {
        const ps = allHoleScores[p.id]?.[h.hole_number];
        if (ps && !ps.abandoned) {
          totalPoints += ps.mode_points ?? 0;
          const pts = ps.mode_points ?? 0;
          if (pts === 1) won++;
          else if (pts === 0) lost++;
        }
      }
      return { playerId: p.id, name: p.name, won, lost, totalPoints };
    });
    if (gameMode === 'match' && totals.length === 2) {
      const diff = totals[0].won - totals[1].won;
      if (diff > 0) return { label: `${diff}UP`, leader: totals[0].name, diff };
      if (diff < 0) return { label: `${Math.abs(diff)}UP`, leader: totals[1].name, diff };
      return { label: 'AS', leader: null, diff: 0 };
    }
    if (gameMode === 'parejas' && totals.length === 4) {
      const team0 = totals.filter((t) => teamAssignments[t.playerId] === 0);
      const team1 = totals.filter((t) => teamAssignments[t.playerId] === 1);
      // Both players on a team have identical mode_points, so use one player's total per team
      const team0Pts = team0.length > 0 ? team0[0].totalPoints : 0;
      const team1Pts = team1.length > 0 ? team1[0].totalPoints : 0;
      const diff = team0Pts - team1Pts;
      if (diff > 0) return { label: `${diff}UP`, leader: 'Equipo 1', diff };
      if (diff < 0) return { label: `${Math.abs(diff)}UP`, leader: 'Equipo 2', diff };
      return { label: 'AS', leader: null, diff: 0 };
    }
    if (gameMode === 'sindicato' && totals.length === 3) {
      const sorted = [...totals].sort((a, b) => b.totalPoints - a.totalPoints);
      const leader = sorted[0];
      const tied = sorted[0].totalPoints === sorted[1].totalPoints;
      return {
        label: tied ? 'AS' : `${leader.name}`,
        leader: tied ? null : leader.name,
        diff: sorted[0].totalPoints - sorted[1].totalPoints,
      };
    }
    return { label: '', leader: null, diff: 0 };
  };

  const matchStatus = getMatchStatus();

  const handleToggleExpanded = (playerId: string, isCurrentlyExpanded: boolean) => {
    if (readonly) return;

    if (isCurrentlyExpanded) {
      // Intentando cerrar el desplegable
      if (firstDigit === 1 && pendingPlayerId === playerId) {
        // Hay un "1" pendiente, mostrar modal de confirmación
        setShowHoleInOneModal(true);
        return;
      }
      // No hay dígito pendiente, cerrar normalmente
      setExpandedPlayerId(null);
      setFirstDigit(null);
      setPendingPlayerId(null);
      setPendingNoPasoRojas(prev => {
        const newState = { ...prev };
        delete newState[playerId];
        return newState;
      });
    } else {
      // Abriendo el desplegable
      setExpandedPlayerId(playerId);
      setFirstDigit(null);
      setPendingPlayerId(null);
    }
  };

  const handleNumberClick = (playerId: string, num: number, player: RoundPlayer) => {
    if (firstDigit === 1 && pendingPlayerId === playerId) {
      const twoDigitNumber = 10 + num;
      const newScore = calculateScore(twoDigitNumber, player.playing_handicap, {
        par: hole.par,
        strokeIndex: hole.stroke_index,
      }, numHoles, allHoles);
      if (pendingNoPasoRojas[playerId]) {
        newScore.no_paso_rojas = true;
      }
      newScore.abandoned = false;
      newScore.mode_points = computeModePointsForPlayer(playerId, twoDigitNumber, newScore.strokesReceived, false);
      onScoreChange(playerId, newScore);
      setExpandedPlayerId(null);
      setFirstDigit(null);
      setPendingPlayerId(null);
      setPendingNoPasoRojas(prev => {
        const newState = { ...prev };
        delete newState[playerId];
        return newState;
      });
    } else if (num === 1) {
      // Marcando el 1, esperar segundo dígito
      setFirstDigit(1);
      setPendingPlayerId(playerId);
    } else {
      // Cualquier otro número, registrar y cerrar
      const newScore = calculateScore(num, player.playing_handicap, {
        par: hole.par,
        strokeIndex: hole.stroke_index,
      }, numHoles, allHoles);
      if (pendingNoPasoRojas[playerId]) {
        newScore.no_paso_rojas = true;
      }
      newScore.abandoned = false;
      newScore.mode_points = computeModePointsForPlayer(playerId, num, newScore.strokesReceived, false);
      onScoreChange(playerId, newScore);
      setExpandedPlayerId(null);
      setFirstDigit(null);
      setPendingPlayerId(null);
      setPendingNoPasoRojas(prev => {
        const newState = { ...prev };
        delete newState[playerId];
        return newState;
      });
    }
  };

  const handleConfirmHoleInOne = () => {
    if (pendingPlayerId) {
      const player = players.find(p => p.id === pendingPlayerId);
      if (player) {
        const newScore = calculateScore(1, player.playing_handicap, {
          par: hole.par,
          strokeIndex: hole.stroke_index,
        }, numHoles, allHoles);
        if (pendingNoPasoRojas[pendingPlayerId]) {
          newScore.no_paso_rojas = true;
        }
        newScore.abandoned = false;
        newScore.mode_points = computeModePointsForPlayer(pendingPlayerId, 1, newScore.strokesReceived, false);
        onScoreChange(pendingPlayerId, newScore);
        setCongratsPlayerName(player.name);
        setShowCongratulationsModal(true);
      }
    }
    setShowHoleInOneModal(false);
    setExpandedPlayerId(null);
    setFirstDigit(null);
    setPendingPlayerId(null);
    setPendingNoPasoRojas(prev => {
      const newState = { ...prev };
      if (pendingPlayerId) delete newState[pendingPlayerId];
      return newState;
    });
  };

  const handleCancelHoleInOne = () => {
    setShowHoleInOneModal(false);
    // Mantener el desplegable abierto y resetear el primer dígito
    setFirstDigit(null);
  };

  /*const getScoreColor = (points: number): string => {
    if (points >= 3) return 'bg-green-100 border-green-500';
    if (points === 2) return 'bg-red-100 border-red-500';
    if (points === 1) return 'bg-yellow-100 border-yellow-500';
    if (points === 0) return 'bg-gray-100 border-black text-black'; // Borde negro y fondo neutro
    if (points === '-') return 'bg-black-100 border-yellow-500';
    return 'bg-blue-100 border-blue-500';
  };*/
const getScoreColor = (points: number, isAbandoned?: boolean): string => {
  if (isAbandoned) return 'bg-gray-100 border-black text-black';               // Raya / Abandonado (Guión)
  if (points === 0) return 'bg-black border-black text-white';                 // Doble bogey+ / 0 pts (Fondo Negro, Texto Blanco)
  if (points === 1) return 'bg-blue-100 border-blue-500 text-blue-900';        // Bogey
  if (points === 2) return 'bg-white border-gray-400 text-gray-800';          // Par
  if (points === 3) return 'bg-red-100 border-red-500 text-red-900';          // Birdie
  if (points >= 4) return 'bg-yellow-100 border-yellow-500 text-yellow-900'; // Eagle o mejor
  
  return 'bg-gray-100 border-gray-300';
};

  /*const getPointsText = (points: number): string => {
  if (points === 0) return '-';
  if (points >= 5) return `${points}+ pts`;
  return `${points} pts`;
};*/
  const getPointsText = (points: number, isAbandoned?: boolean): string => {
  if (isAbandoned) return '-';
  if (points >= 5) return `${points}+ pts`;
  return `${points} pts`;
};

  return (
    <div className="bg-white rounded-lg shadow-md border-2 border-gray-200 overflow-hidden">
      <div className="bg-gradient-to-r from-emerald-700 to-emerald-600 p-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-2xl font-bold text-white">Hoyo {hole.hole_number}</h3>
            <div className="flex gap-4 mt-1 text-emerald-100">
              <span className="font-semibold">Par {hole.par}</span>
              <span>HCP {hole.stroke_index}</span>
            </div>
          </div>
        </div>
      </div>

      <div className="p-4 space-y-3">
        {players.map((player, playerIndex) => {
          const score = scores[player.id];
          const isExpanded = expandedPlayerId === player.id;
          const isParejas = gameMode === 'parejas' && players.length === 4;
          const team = teamAssignments[player.id] ?? (playerIndex < 2 ? 0 : 1);
          const teamLabel = team === 0 ? 'P1' : 'P2';
          const teamClasses = team === 0
            ? 'border-blue-400 ring-1 ring-blue-100'
            : 'border-orange-400 ring-1 ring-orange-100';

          return (
            <div key={player.id} className={`border-2 rounded-lg overflow-hidden ${isParejas ? teamClasses : 'border-gray-200'}`}>
              <button
                onClick={() => handleToggleExpanded(player.id, isExpanded)}
                disabled={readonly}
                className="w-full bg-gray-50 hover:bg-gray-100 disabled:cursor-not-allowed p-3 flex items-center justify-between transition-colors"
              >
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2">
                    {isParejas && (
                      <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${team === 0 ? 'bg-blue-100 text-blue-800' : 'bg-orange-100 text-orange-800'}`}>
                        {teamLabel}
                      </span>
                    )}
                    <p className="font-semibold text-gray-800">{player.name}</p>
                  </div>
                  <p className="text-xs text-gray-600">HCP {player.playing_handicap}</p>
                </div>
                {/* FBP-Ini}
                {score ? (
                  score.abandoned ? (
                    <div className="text-gray-400 font-semibold text-2xl">-</div>
                  ) : (
                    <div className={`px-4 py-2 rounded-lg border-2 font-bold text-lg ${getScoreColor(score.stableford_points)}`}>
                      {getPointsText(score.stableford_points)} pts
                    </div>
                  )
                ) : (
                  <div className="text-gray-400 font-semibold">-</div>
                )}
                {FBP-Fin*/}
                {score ? (
                  (() => {
                    // Es raya si está marcado como abandonado o no se registraron golpes brutos
                    const isRaya = score.abandoned || score.gross_strokes === 0;
                    const isParejas = gameMode === 'parejas';
                
                    const displayPoints = isModeScoring ? (score.mode_points ?? 0) : score.stableford_points;
                    const modeText = isParejas
                      ? (score.abandoned ? '-' : `${score.gross_strokes}`)
                      : isModeScoring
                      ? (score.abandoned ? '-' : `${displayPoints} pts`)
                      : getPointsText(score.stableford_points, isRaya);
                    return (
                      <div
                        className={`px-4 py-2 rounded-lg border-2 font-bold text-lg flex items-center justify-center min-w-[75px] ${getScoreColor(
                          isParejas ? score.stableford_points : (isModeScoring ? displayPoints : score.stableford_points),
                          isRaya
                        )}`}
                      >
                        {modeText}
                      </div>
                    );
                  })()
                ) : (
                  // Hoyo pendiente / No asignado aún (gris tenue sin marco)
                  <div className="text-gray-300 font-light text-xl px-4 flex items-center justify-center min-w-[75px]">
                    -
                  </div>
                )}
                <ChevronDown
                  size={20}
                  className={`ml-2 text-gray-600 transition-transform ${
                    isExpanded ? 'rotate-180' : ''
                  }`}
                />
              </button>

              {isExpanded && (() => {
                const allStrokeIndexes = allHoles.map(h => h.stroke_index);
                const strokesReceived = getStrokesReceived(
                  player.playing_handicap,
                  hole.stroke_index,
                  numHoles,
                  allStrokeIndexes
                );

                return (
                  <div className="bg-gray-50 border-t border-gray-200 p-3 space-y-3">
                    <div>
                      <label className="block text-xs font-semibold text-gray-700 mb-2">
                        {firstDigit === 1 && pendingPlayerId === player.id ? (
                          <span className="text-emerald-600">Segundo dígito (1 + ?)</span>
                        ) : (
                          'Número de Golpes'
                        )}
                      </label>

                      <div className="grid grid-cols-5 gap-1.5">
                        {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) => (
                          <button
                            key={num}
                            type="button"
                            onClick={() => handleNumberClick(player.id, num, player)}
                            className={`h-11 rounded-lg font-bold text-lg transition-colors shadow-sm active:scale-95 ${
                              firstDigit === 1 && pendingPlayerId === player.id
                                ? 'bg-yellow-500 hover:bg-yellow-600 text-white'
                                : 'bg-emerald-600 hover:bg-emerald-700 text-white'
                            }`}
                          >
                            {firstDigit === 1 && pendingPlayerId === player.id ? `1${num}` : num}
                          </button>
                        ))}

                        <button
                          type="button"
                          onClick={() => {
                            const newScore = calculateScore(10, player.playing_handicap, {
                              par: hole.par,
                              strokeIndex: hole.stroke_index,
                            }, numHoles, allHoles);
                            if (pendingNoPasoRojas[player.id]) {
                              newScore.no_paso_rojas = true;
                            }
                            newScore.abandoned = false;
                            newScore.mode_points = computeModePointsForPlayer(player.id, 10, newScore.strokesReceived, false);
                            onScoreChange(player.id, newScore);
                            setExpandedPlayerId(null);
                            setFirstDigit(null);
                            setPendingPlayerId(null);
                            setPendingNoPasoRojas(prev => {
                              const newState = { ...prev };
                              delete newState[player.id];
                              return newState;
                            });
                          }}
                          className="h-11 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-bold text-lg transition-colors shadow-sm active:scale-95"
                        >
                          10
                        </button>

                        <button
                          type="button"
                          onClick={() => {
                            const isQuickPlay = groupCode === null;
                            if (isQuickPlay) {
                              const newScore = {
                                gross_strokes: 0,
                                strokes_received: 0,
                                net_strokes: 0,
                                stableford_points: 0,
                                no_paso_rojas: false,
                                abandoned: true,
                                mode_points: 0,
                              };
                              onScoreChange(player.id, newScore);
                            } else {
                              const maxStrokes = hole.par + strokesReceived + 3;
                              const newScore = calculateScore(maxStrokes, player.playing_handicap, {
                                par: hole.par,
                                strokeIndex: hole.stroke_index,
                              }, numHoles, allHoles);
                              if (pendingNoPasoRojas[player.id]) {
                                newScore.no_paso_rojas = true;
                              }
                              newScore.mode_points = computeModePointsForPlayer(player.id, maxStrokes, newScore.strokesReceived, false);
                              onScoreChange(player.id, { ...newScore, stableford_points: 0, abandoned: false });
                            }
                            setExpandedPlayerId(null);
                            setFirstDigit(null);
                            setPendingPlayerId(null);
                            setPendingNoPasoRojas(prev => {
                              const newState = { ...prev };
                              delete newState[player.id];
                              return newState;
                            });
                          }}
                          className="h-11 bg-gray-600 hover:bg-gray-700 text-white rounded-lg font-bold transition-colors shadow-sm active:scale-95 flex items-center justify-center"
                        >
                          <Minus size={20} />
                        </button>

                        <button
                          type="button"
                          onClick={() => {
                            const newScore = {
                              gross_strokes: 0,
                              strokes_received: strokesReceived,
                              net_strokes: 0,
                              stableford_points: 0,
                              no_paso_rojas: pendingNoPasoRojas[player.id] || false,
                              abandoned: true,
                              mode_points: computeModePointsForPlayer(player.id, 0, strokesReceived, true),
                            };
                            onScoreChange(player.id, newScore);
                            setExpandedPlayerId(null);
                            setFirstDigit(null);
                            setPendingPlayerId(null);
                            setPendingNoPasoRojas(prev => {
                              const newState = { ...prev };
                              delete newState[player.id];
                              return newState;
                            });
                          }}
                          className="h-11 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold transition-colors shadow-sm active:scale-95 flex items-center justify-center"
                        >
                          <Trash2 size={20} />
                        </button>
                      </div>
                    </div>

                    <div className="bg-white p-2 rounded-lg border border-gray-300">
                      <div className="flex justify-around text-center text-xs">
                        <div>
                          <p className="text-gray-500">Recib.</p>
                          <p className="font-bold text-blue-700">{strokesReceived}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Brutos</p>
                          <p className="font-bold text-gray-800">{score?.gross_strokes || 0}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Netos</p>
                          <p className="font-bold text-emerald-700">
                            {score?.gross_strokes ? (score.gross_strokes - strokesReceived) : 0}
                          </p>
                        </div>
                        <div>
                          <p className="text-gray-500">{isModeScoring ? 'Modal' : 'Puntos'}</p>
                          <p className="font-bold text-emerald-700">{isModeScoring ? (score?.mode_points ?? 0) : (score?.stableford_points || 0)}</p>
                        </div>
                      </div>
                    </div>

                    {isDivend && (
                      <button
                        type="button"
                        onClick={() => {
                          if (score && score.gross_strokes > 0) {
                            const newNoPasoRojas = !score.no_paso_rojas;
                            const updatedScore = {
                              ...score,
                              grossStrokes: score.gross_strokes,
                              strokesReceived: strokesReceived,
                              netStrokes: score.net_strokes,
                              stablefordPoints: score.stableford_points,
                              no_paso_rojas: newNoPasoRojas,
                            };
                            onScoreChange(player.id, updatedScore);
                          } else {
                            setPendingNoPasoRojas(prev => ({
                              ...prev,
                              [player.id]: !prev[player.id]
                            }));
                          }
                        }}
                        className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                          (score?.no_paso_rojas || pendingNoPasoRojas[player.id])
                            ? 'bg-red-600 hover:bg-red-700 text-white'
                            : 'bg-gray-200 hover:bg-gray-300 text-gray-700'
                        }`}
                      >
                        {(score?.no_paso_rojas || pendingNoPasoRojas[player.id]) ? '✓ No pasó de rojas' : 'Marcar: No pasó de rojas'}
                      </button>
                    )}
                  </div>
                );
              })()}
            </div>
          );
        })}
      </div>

      {isModeScoring && matchStatus.label && (
        <div className="border-t-2 border-emerald-200 bg-emerald-50 p-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-emerald-700 uppercase tracking-wide">Marcador</span>
            </div>
            <div className="flex items-center gap-3">
              {gameMode === 'match' && players.map((p) => {
                const total = allHoles.reduce((sum, h) => {
                  const ps = allHoleScores[p.id]?.[h.hole_number];
                  return ps && !ps.abandoned ? sum + (ps.mode_points ?? 0) : sum;
                }, 0);
                const isLeader = matchStatus.leader === p.name;
                return (
                  <div key={p.id} className="flex items-center gap-1.5">
                    <span className={`text-sm font-bold ${isLeader ? 'text-emerald-900' : 'text-gray-600'}`}>
                      {p.name}
                    </span>
                    <span className={`text-sm font-bold ${isLeader ? 'text-emerald-700' : 'text-gray-500'}`}>
                      {total}
                    </span>
                  </div>
                );
              })}
              {gameMode === 'sindicato' && [...players].sort((a, b) => {
                const totalA = allHoles.reduce((sum, h) => {
                  const ps = allHoleScores[a.id]?.[h.hole_number];
                  return ps && !ps.abandoned ? sum + (ps.mode_points ?? 0) : sum;
                }, 0);
                const totalB = allHoles.reduce((sum, h) => {
                  const ps = allHoleScores[b.id]?.[h.hole_number];
                  return ps && !ps.abandoned ? sum + (ps.mode_points ?? 0) : sum;
                }, 0);
                return totalB - totalA;
              }).map((p) => {
                const total = allHoles.reduce((sum, h) => {
                  const ps = allHoleScores[p.id]?.[h.hole_number];
                  return ps && !ps.abandoned ? sum + (ps.mode_points ?? 0) : sum;
                }, 0);
                const isLeader = matchStatus.leader === p.name;
                return (
                  <div key={p.id} className="flex items-center gap-1.5">
                    <span className={`text-sm font-bold ${isLeader ? 'text-emerald-900' : 'text-gray-600'}`}>
                      {p.name}
                    </span>
                    <span className={`text-sm font-bold ${isLeader ? 'text-emerald-700' : 'text-gray-500'}`}>
                      {total} pts
                    </span>
                  </div>
                );
              })}
              {gameMode === 'parejas' && players.length === 4 && (() => {
                const teamAssignmentsLocal = Object.fromEntries(players.map((p, i) => [p.id, i < 2 ? 0 : 1]));
                const team0 = players.filter((p) => teamAssignmentsLocal[p.id] === 0);
                const team1 = players.filter((p) => teamAssignmentsLocal[p.id] === 1);
                // Both players on a team have identical mode_points, so use one player's total per team
                const team0Pts = team0.length > 0 ? allHoles.reduce((s, h) => {
                  const ps = allHoleScores[team0[0].id]?.[h.hole_number];
                  return ps && !ps.abandoned ? s + (ps.mode_points ?? 0) : s;
                }, 0) : 0;
                const team1Pts = team1.length > 0 ? allHoles.reduce((s, h) => {
                  const ps = allHoleScores[team1[0].id]?.[h.hole_number];
                  return ps && !ps.abandoned ? s + (ps.mode_points ?? 0) : s;
                }, 0) : 0;
                return (
                  <div className="flex items-center gap-2 text-sm font-bold">
                    <span className="text-xs font-bold px-1.5 py-0.5 rounded bg-blue-200 text-blue-900">P1</span>
                    <span className="text-gray-700">{team0.map(p => p.name).join('/')}</span>
                    <span className={`px-2 py-0.5 rounded-lg ${team0Pts > team1Pts ? 'bg-emerald-600 text-white' : team0Pts < team1Pts ? 'bg-gray-300 text-gray-600' : 'bg-gray-200 text-gray-700'}`}>
                      {team0Pts}-{team1Pts}
                    </span>
                    <span className="text-gray-700">{team1.map(p => p.name).join('/')}</span>
                    <span className="text-xs font-bold px-1.5 py-0.5 rounded bg-orange-200 text-orange-900">P2</span>
                  </div>
                );
              })()}
              {gameMode !== 'sindicato' && gameMode !== 'parejas' && (
                <div className={`px-3 py-1 rounded-lg font-bold text-sm ${
                  matchStatus.diff > 0
                    ? 'bg-emerald-600 text-white'
                    : matchStatus.diff < 0
                    ? 'bg-gray-400 text-white'
                    : 'bg-gray-200 text-gray-700'
                }`}>
                  {matchStatus.label}
                </div>
              )}

            </div>
          </div>
        </div>
      )}

      {showHoleInOneModal && pendingPlayerId && (
        <HoleInOneModal
          playerName={players.find(p => p.id === pendingPlayerId)?.name || ''}
          onConfirm={handleConfirmHoleInOne}
          onCancel={handleCancelHoleInOne}
        />
      )}

      {showCongratulationsModal && (
        <CongratulationsModal
          playerName={congratsPlayerName}
          onClose={() => setShowCongratulationsModal(false)}
        />
      )}
    </div>
  );
};
