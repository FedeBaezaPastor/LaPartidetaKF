import React, { useState, useEffect } from 'react';
import { GolfHole, RoundPlayer, RoundScore, GameMode } from '../types';
import { HoleCard } from './HoleCard';
import { ConfirmModal } from './ConfirmModal';
import { CourseChangeModal } from './CourseChangeModal';
import { CourseChangeConfirmModal } from './CourseChangeConfirmModal';
import { ScoreSymbol } from './ScoreSymbol';
import { golfService } from '../services/golfService';
import { getStrokesReceived, calculateScoreToPar, checkMatchPlayStatus, checkParejasStatus, checkSindicatoStatus } from '../utils/calculations';
import { ChevronLeft, ChevronRight, Trophy, Home, Lock, MapPin, Eye, EyeOff } from 'lucide-react';
import { HandshakeModal } from './HandshakeModal';

interface ScorecardProps {
  holes: GolfHole[];
  players: RoundPlayer[];
  rounds: Array<{
    playerId: string;
    scores: Record<number, RoundScore>;
    totalStablefordPoints: number;
  }>;
  currentHole: number;
  numHoles: 9 | 18;
  roundId?: string;
  courseId?: string;
  accessCode?: string;
  hasEditAccess?: boolean;
  courseName?: string;
  groupCode?: string | null;
  gameMode?: GameMode;
  onHoleChange: (holeNumber: number) => void;
  onScoreChange: (playerId: string, holeNumber: number, score: any) => void;
  onShowLeaderboard: () => void;
  onResetGame: () => void;
  onFinishRound: () => void;
  onCourseChanged?: (courseId: string, numHoles: 9 | 18, holes: GolfHole[], players?: RoundPlayer[]) => void;
}

export const Scorecard: React.FC<ScorecardProps> = ({
  holes,
  players,
  rounds,
  currentHole,
  numHoles,
  roundId,
  courseId,
  accessCode,
  hasEditAccess = true,
  courseName = '',
  groupCode = null,
  gameMode = 'stableford',
  onHoleChange,
  onScoreChange,
  onShowLeaderboard,
  onResetGame,
  onFinishRound,
  onCourseChanged,
}) => {
  const isDivend = groupCode === 'DIVEND';
  const isModeScoring = gameMode !== 'stableford';
  const modeLabels: Record<GameMode, string> = {
    stableford: 'Stableford',
    match: 'Match Play',
    sindicato: 'Sindicato',
    parejas: 'Parejas',
  };
  const [showFinishModal, setShowFinishModal] = useState(false);
  const [showAccessCode, setShowAccessCode] = useState(false);

  useEffect(() => {
    console.log('📊 Scorecard: Players prop updated:', players.map(p => ({ name: p.name, playing_handicap: p.playing_handicap })));
  }, [players]);

  const [showCourseChangeModal, setShowCourseChangeModal] = useState(false);
  const [showCourseConfirmModal, setShowCourseConfirmModal] = useState(false);
  const [selectedCourse, setSelectedCourse] = useState<{id: string; name: string} | null>(null);
  const [changingCourse, setChangingCourse] = useState(false);
  const [error, setError] = useState('');
  const playableHoles = holes;
  const hole = playableHoles[currentHole - 1];
  const roundsMap = new Map(rounds.map((r) => [r.playerId, r]));

  const allScoresComplete = players.every((player) => {
    const round = roundsMap.get(player.id);
    return playableHoles.every((h) => round?.scores[h.hole_number]);
  });

  const isLastHole = currentHole === playableHoles.length;

  const handleFinishWithConfirm = () => {
    console.log('📋 Abriendo modal de confirmación de finalización...');
    setShowFinishModal(true);
  };

  const handleConfirmFinish = async () => {
    setShowFinishModal(false);
    try {
      await onFinishRound();
    } catch (err) {
      console.error('Error al finalizar la partida:', err);
    }
  };

  const handleSelectCourse = (course: { id: string; name: string; description?: string | null }) => {
    setSelectedCourse({ id: course.id, name: course.name });
    setShowCourseChangeModal(false);
    setShowCourseConfirmModal(true);
  };

  const handleConfirmCourseChange = async (selectedHoles: 9 | 18) => {
    if (!onCourseChanged || !roundId || !selectedCourse) return;

    try {
      setChangingCourse(true);
      setError('');

      const { holes: newHoles, players: updatedPlayers } = await golfService.changeCourse(
        roundId,
        selectedCourse.id,
        selectedHoles
      );

      console.log('📊 Scorecard: Players after course change:', updatedPlayers?.map(p => ({ name: p.name, playing: p.playing_handicap })));

      onCourseChanged(selectedCourse.id, selectedHoles, newHoles, updatedPlayers);
      setShowCourseConfirmModal(false);
      setSelectedCourse(null);
    } catch (err) {
      console.error('Error changing course:', err);
      setError('Error al cambiar el campo');
    } finally {
      setChangingCourse(false);
    }
  };

  const [handshakeData, setHandshakeData] = useState<{
    isOpen: boolean;
    winner: string;
    margin: string;
  } | null>(null);
  const [handshakeAcknowledged, setHandshakeAcknowledged] = useState(false);

  useEffect(() => {
    setHandshakeAcknowledged(false);
    setHandshakeData(null);
  }, [roundId, gameMode]);

  useEffect(() => {
    if (handshakeAcknowledged) return;

    if (gameMode === 'match') {
      const result = checkMatchPlayStatus(roundsMap, players, playableHoles);
      if (result.isFinished && !handshakeData?.isOpen) {
        setHandshakeData({ isOpen: true, winner: result.leaderName, margin: result.marginText });
      }
    } else if (gameMode === 'parejas') {
      const result = checkParejasStatus(roundsMap, players, playableHoles);
      if (result.isFinished && !handshakeData?.isOpen) {
        setHandshakeData({ isOpen: true, winner: result.leaderName, margin: result.marginText });
      }
    } else if (gameMode === 'sindicato') {
      const result = checkSindicatoStatus(roundsMap, players, playableHoles);
      if (result.isFinished && !handshakeData?.isOpen) {
        setHandshakeData({ isOpen: true, winner: result.leaderName, margin: result.marginText });
      }
    }
  }, [rounds, players, gameMode, handshakeAcknowledged]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-50 to-emerald-100 p-4 md:p-8">
      <div className="max-w-2xl mx-auto">
        <div className="bg-white rounded-lg shadow-2xl p-6 md:p-8">
          <div className="flex items-center justify-between mb-6">
            <button
              onClick={onResetGame}
              className="bg-gray-200 hover:bg-gray-300 text-gray-800 p-2 rounded-lg transition-colors"
              title="Volver al menú principal"
            >
              <Home size={20} />
            </button>
            <h1 className="text-2xl md:text-3xl font-bold text-emerald-900 flex-1 text-center">
              Tarjeta de Puntuación
            </h1>
            <button
              onClick={onShowLeaderboard}
              className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg flex items-center gap-2 font-semibold transition-colors"
            >
              <Trophy size={20} />
              <span className="hidden sm:inline">Clasificación</span>
            </button>
          </div>

          <div className="mb-4 bg-emerald-600 rounded-lg p-4 text-white">
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-lg font-bold">{courseName || 'Campo de Golf'}</span>
                  {isModeScoring && (
                    <span className="bg-white/25 text-white text-xs font-bold px-2 py-0.5 rounded-md uppercase tracking-wide">
                      {modeLabels[gameMode]}
                    </span>
                  )}
                  {hasEditAccess && onCourseChanged && roundId && courseId && (
                    <button
                      onClick={() => setShowCourseChangeModal(true)}
                      disabled={changingCourse}
                      className="bg-white/20 hover:bg-white/30 text-white text-xs px-2 py-1 rounded-md flex items-center gap-1 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      title="Cambiar campo de golf"
                    >
                      <MapPin size={12} />
                      Cambiar
                    </button>
                  )}
                </div>
                <p className="text-sm text-white/90 mt-1">
                  Hoyo {currentHole} de {numHoles}
                </p>
              </div>
            </div>
          </div>

          {accessCode && hasEditAccess && (
            <div className="mb-4 bg-white border-2 border-emerald-200 rounded-lg p-4 shadow-sm">
              <div className="flex items-center gap-2 justify-between">
                <div className="flex items-center gap-2">
                  <Lock className="text-emerald-600" size={20} />
                  <span className="text-sm font-medium text-gray-700">
                    Código de Acceso:
                  </span>
                  <code className="text-2xl font-bold text-emerald-700 tracking-[0.5em] ml-2">
                    {showAccessCode ? accessCode : <span className="text-base">••••</span>}
                  </code>
                </div>
                <button
                  onClick={() => setShowAccessCode(!showAccessCode)}
                  className="p-2 hover:bg-emerald-50 rounded-lg transition-colors"
                  aria-label={showAccessCode ? 'Ocultar código' : 'Mostrar código'}
                >
                  {showAccessCode ? (
                    <EyeOff className="text-emerald-600" size={20} />
                  ) : (
                    <Eye className="text-emerald-600" size={20} />
                  )}
                </button>
              </div>
              <p className="text-xs text-gray-600 mt-2">
                Comparte este código con otros jugadores para que puedan ver y editar puntuaciones
              </p>
            </div>
          )}

          {error && (
            <div className="mb-4 bg-red-50 border-l-4 border-red-500 p-3 rounded">
              <p className="text-red-700 text-sm">{error}</p>
            </div>
          )}

          {!hasEditAccess && (
            <div className="mb-4 bg-amber-50 border border-amber-200 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Lock className="text-amber-600" size={20} />
                <span className="text-sm font-medium text-amber-900">
                  Solo lectura - No tienes permiso para editar esta partida
                </span>
              </div>
            </div>
          )}

          {hole && (
            <div className="mb-6">
              <HoleCard
                hole={hole}
                players={players}
                scores={Object.fromEntries(
                  players.map((p) => [p.id, roundsMap.get(p.id)?.scores[hole.hole_number]])
                )}
                numHoles={numHoles}
                allHoles={holes}
                allHoleScores={Object.fromEntries(
                  players.map((p) => [p.id, roundsMap.get(p.id)?.scores || {}])
                )}
                readonly={!hasEditAccess}
                groupCode={groupCode}
                gameMode={gameMode}
                teamAssignments={gameMode === 'parejas' && players.length === 4 ? Object.fromEntries(players.map((p, i) => [p.id, i < 2 ? 0 : 1])) : undefined}
                onScoreChange={(playerId, score) => {
                  onScoreChange(playerId, hole.hole_number, score);
                }}
              />
            </div>
          )}

          <div className="mb-6">
            <div className="relative">
              <div className="w-full bg-gray-200 rounded-full h-3 shadow-inner">
                <div
                  className="bg-gradient-to-r from-emerald-500 to-emerald-600 h-3 rounded-full transition-all duration-300 shadow-sm"
                  style={{ width: `${(currentHole / playableHoles.length) * 100}%` }}
                />
              </div>
              <p className="text-sm font-medium text-gray-700 mt-2 text-center">
                Hoyo {currentHole} de {playableHoles.length}
              </p>
            </div>
          </div>

          <div className="flex gap-3 mb-6">
            <button
              onClick={() => onHoleChange(Math.max(1, currentHole - 1))}
              disabled={currentHole === 1}
              className="flex-1 bg-gray-200 hover:bg-gray-300 disabled:opacity-50 disabled:cursor-not-allowed text-gray-800 font-semibold py-3 rounded-lg flex items-center justify-center gap-2 transition-colors"
            >
              <ChevronLeft size={20} />
              Anterior
            </button>

            {isLastHole && allScoresComplete ? (
              <button
                onClick={handleFinishWithConfirm}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg flex items-center justify-center gap-2 transition-colors"
              >
                <Trophy size={20} />
                Finalizar Partida
              </button>
            ) : (
              <button
                onClick={() => onHoleChange(Math.min(playableHoles.length, currentHole + 1))}
                disabled={currentHole === playableHoles.length}
                className="flex-1 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg flex items-center justify-center gap-2 transition-colors"
              >
                Siguiente
                <ChevronRight size={20} />
              </button>
            )}
          </div>

          <div className="border-t pt-4">
            <h3 className="font-semibold text-gray-700 mb-3">Tabla de Golpes</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-100 border-b">
                    <th className="text-left p-2 font-semibold text-gray-700">Jugador</th>
                    {playableHoles.map((h) => (
                      <th key={h.hole_number} className="text-center p-2 font-semibold text-gray-700 min-w-[40px]">
                        <div className="flex flex-col items-center gap-0.5">
                          <span>{h.hole_number}</span>
                          <span className="text-xs font-normal text-gray-500">
                            P{h.par}•H{h.stroke_index}
                          </span>
                        </div>
                      </th>
                    ))}
                    <th className="text-center p-2 font-semibold text-gray-700 bg-gray-200 min-w-[50px]">
                      <div className="flex flex-col items-center gap-0.5">
                        <span>Total</span>
                        <span className="text-xs font-normal text-gray-500">Brutos</span>
                      </div>
                    </th>
                    <th className="text-center p-2 font-semibold text-gray-700 bg-emerald-100 min-w-[50px]">
                      <div className="flex flex-col items-center gap-0.5">
                        <span>Total</span>
                        <span className="text-xs font-normal text-gray-500">Netos</span>
                      </div>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {players.map((player) => {
                    const round = roundsMap.get(player.id);
                    const hasAbandonedScores = false;

                    const totalGrossStrokes = playableHoles.reduce((sum, h) => {
                      const score = round?.scores[h.hole_number];
                      if (!score?.gross_strokes) return sum;
                      return sum + score.gross_strokes;
                    }, 0);

                    const totalNetStrokes = playableHoles.reduce((sum, h) => {
                      const score = round?.scores[h.hole_number];
                      if (!score?.gross_strokes) return sum;

                      return sum + (score.gross_strokes - (score.strokes_received || 0));
                    }, 0);

                    return (
                      <tr key={player.id} className="border-b hover:bg-gray-50">
                        <td className="p-2 font-medium text-gray-800">
                          <div className="flex items-center gap-2">
                            {gameMode === 'parejas' && players.length === 4 && (
                              <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${players.indexOf(player) < 2 ? 'bg-blue-100 text-blue-800' : 'bg-orange-100 text-orange-800'}`}>
                                {players.indexOf(player) < 2 ? 'P1' : 'P2'}
                              </span>
                            )}
                            <span className="truncate">{player.name}</span>
                          </div>
                        </td>
                        {playableHoles.map((h) => {
                          const score = round?.scores[h.hole_number];
                          const allStrokeIndexes = holes.map(hole => hole.stroke_index);
                          const strokesReceived = getStrokesReceived(
                            player.playing_handicap,
                            h.stroke_index,
                            numHoles,
                            allStrokeIndexes
                          );

                          return (
                            <td
                              key={h.hole_number}
                              className={`text-center p-2 relative ${
                                h.hole_number === currentHole ? 'bg-emerald-100 font-bold' : ''
                              }`}
                            >
                              <div className="flex flex-col items-center justify-center gap-1">
                                {score ? (
                                  <div className="w-7 h-7 flex items-center justify-center">
                                    <ScoreSymbol
                                      grossStrokes={score.gross_strokes}
                                      par={h.par}
                                      strokesReceived={strokesReceived}
                                      abandoned={score.abandoned}
                                    />
                                  </div>
                                ) : (
                                  <div className="w-7 h-7 flex items-center justify-center">
                                    <span className="text-gray-300">-</span>
                                  </div>
                                )}
                                <div className="flex gap-0.5 h-1 min-h-[4px]">
                                  {strokesReceived > 0 && Array.from({ length: strokesReceived }).map((_, idx) => (
                                    <div
                                      key={idx}
                                      className="w-1 h-1 rounded-full bg-blue-500"
                                      title={`${strokesReceived} golpe${strokesReceived > 1 ? 's' : ''} recibido${strokesReceived > 1 ? 's' : ''}`}
                                    />
                                  ))}
                                </div>
                              </div>
                            </td>
                          );
                        })}
                        <td
                          className={`text-center p-2 font-bold ${
                            hasAbandonedScores
                              ? 'text-gray-500'
                              : 'bg-gray-100 text-gray-900'
                          }`}
                          style={hasAbandonedScores ? {
                            background: 'repeating-linear-gradient(45deg, #e5e7eb, #e5e7eb 5px, #d1d5db 5px, #d1d5db 10px)'
                          } : undefined}
                        >
                          {hasAbandonedScores ? '-' : (totalGrossStrokes > 0 ? totalGrossStrokes : '-')}
                        </td>
                        <td
                          className={`text-center p-2 font-bold ${
                            hasAbandonedScores
                              ? 'text-gray-500'
                              : 'bg-emerald-50 text-emerald-900'
                          }`}
                          style={hasAbandonedScores ? {
                            background: 'repeating-linear-gradient(45deg, #e5e7eb, #e5e7eb 5px, #d1d5db 5px, #d1d5db 10px)'
                          } : undefined}
                        >
                          {hasAbandonedScores ? '-' : (totalGrossStrokes > 0 ? totalNetStrokes : '-')}
                        </td>
                      </tr>
                    );
                  })}
                  {isModeScoring && gameMode !== 'sindicato' && (
                    <tr className="border-b-2 border-emerald-300 bg-emerald-50">
                      <td className="p-2 font-bold text-emerald-800 text-xs uppercase tracking-wide">Marcador</td>
                      {playableHoles.map((h) => {
                        const holeScores = players.map((p) => {
                          const s = roundsMap.get(p.id)?.scores[h.hole_number];
                          return s ? s.mode_points ?? 0 : null;
                        });
                        const allPlayed = holeScores.every((v) => v !== null);
                        if (!allPlayed) {
                          return (
                            <td key={h.hole_number} className="text-center p-2">
                              <span className="text-gray-300 text-xs">-</span>
                            </td>
                          );
                        }
                        if (gameMode === 'match' && players.length === 2) {
                          const diff = (holeScores[0] ?? 0) - (holeScores[1] ?? 0);
                          const label = diff > 0 ? `${players[0].name.slice(0, 3).toUpperCase()}` : diff < 0 ? `${players[1].name.slice(0, 3).toUpperCase()}` : 'AS';
                          const color = diff > 0 ? 'bg-emerald-200 text-emerald-900' : diff < 0 ? 'bg-gray-200 text-gray-700' : 'bg-gray-100 text-gray-500';
                          return (
                            <td key={h.hole_number} className="text-center p-1">
                              <span className={`text-[10px] font-bold px-1 py-0.5 rounded ${color}`}>{label}</span>
                            </td>
                          );
                        }
                        if (gameMode === 'parejas' && players.length === 4) {
                          let t0Accum = 0, t1Accum = 0;
                          playableHoles.forEach((ph) => {
                            const ps = players.map((p) => {
                              const s = roundsMap.get(p.id)?.scores[ph.hole_number];
                              return s ? s.mode_points ?? 0 : null;
                            });
                            if (ps.every((v) => v !== null)) {
                              t0Accum += ps[0] ?? 0;
                              t1Accum += ps[2] ?? 0;
                            }
                          });
                          const label = `${t0Accum}-${t1Accum}`;
                          const color = t0Accum > t1Accum ? 'bg-emerald-200 text-emerald-900' : t0Accum < t1Accum ? 'bg-gray-200 text-gray-700' : 'bg-gray-100 text-gray-500';
                          return (
                            <td key={h.hole_number} className="text-center p-1">
                              <span className={`text-[10px] font-bold px-1 py-0.5 rounded ${color}`}>{label}</span>
                            </td>
                          );
                        }
                        return (
                          <td key={h.hole_number} className="text-center p-2">
                            <span className="text-gray-400 text-xs">·</span>
                          </td>
                        );
                      })}
                      <td colSpan={2} className="text-center p-2">
                        {(() => {
                          if (gameMode === 'match' && players.length === 2) {
                            let p0Won = 0, p1Won = 0;
                            playableHoles.forEach((h) => {
                              const s0 = roundsMap.get(players[0].id)?.scores[h.hole_number];
                              const s1 = roundsMap.get(players[1].id)?.scores[h.hole_number];
                              if (s0 && s1) {
                                if ((s0.mode_points ?? 0) > (s1.mode_points ?? 0)) p0Won++;
                                else if ((s0.mode_points ?? 0) < (s1.mode_points ?? 0)) p1Won++;
                              }
                            });
                            const diff = p0Won - p1Won;
                            const label = diff > 0 ? `${diff}UP` : diff < 0 ? `${Math.abs(diff)}UP` : 'AS';
                            const color = diff > 0 ? 'bg-emerald-600 text-white' : diff < 0 ? 'bg-gray-500 text-white' : 'bg-gray-200 text-gray-700';
                            return <span className={`text-xs font-bold px-2 py-1 rounded ${color}`}>{label}</span>;
                          }
                          if (gameMode === 'parejas' && players.length === 4) {
                            let t0 = 0, t1 = 0;
                            playableHoles.forEach((h) => {
                              const s0 = roundsMap.get(players[0].id)?.scores[h.hole_number];
                              const s2 = roundsMap.get(players[2].id)?.scores[h.hole_number];
                              if (s0 && s2) {
                                t0 += s0.mode_points ?? 0;
                                t1 += s2.mode_points ?? 0;
                              }
                            });
                            const label = `${t0}-${t1}`;
                            const color = t0 > t1 ? 'bg-emerald-600 text-white' : t0 < t1 ? 'bg-gray-500 text-white' : 'bg-gray-200 text-gray-700';
                            return <span className={`text-xs font-bold px-2 py-1 rounded ${color}`}>{label}</span>;
                          }
                          return <span className="text-gray-400 text-xs">-</span>;
                        })()}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="mt-3 flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-xs text-gray-600">
              <div className="flex items-center gap-1.5">
                <div className="w-4 h-4 rounded-full bg-gradient-to-br from-yellow-400 to-amber-500 border border-gray-300"></div>
                <span>Eagle</span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="w-4 h-4 rounded-full bg-red-500 border border-gray-300"></div>
                <span>Birdie</span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="w-4 h-4 rounded-full bg-white border-2 border-gray-300"></div>
                <span>Par</span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="w-4 h-4 rounded-full bg-blue-500 border border-gray-300"></div>
                <span>Bogey</span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="w-4 h-4 rounded-full bg-black border border-gray-300"></div>
                <span>Doble bogey+</span>
              </div>
            </div>

            <h3 className="font-semibold text-gray-700 mb-3 mt-6">Resumen de Puntos Stableford</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
              {players.map((player) => {
                const round = roundsMap.get(player.id);
                const totalPoints = round?.totalStablefordPoints ?? 0;
                const hasAbandonedScores = false;

                const totalGrossStrokes = playableHoles.reduce((sum, h) => {
                  const score = round?.scores[h.hole_number];
                  if (!score?.gross_strokes) return sum;
                  return sum + (score?.gross_strokes || 0);
                }, 0);

                const coursePar = playableHoles.reduce((sum, h) => sum + h.par, 0);
                const scoreToPar = totalGrossStrokes > 0
                  ? calculateScoreToPar(totalGrossStrokes, coursePar, player.playing_handicap, numHoles)
                  : null;

                return (
                  <div
                    key={player.id}
                    className={`bg-gradient-to-br border-2 rounded-lg p-3 text-center ${
                      hasAbandonedScores
                        ? 'from-gray-50 to-gray-100 border-gray-300'
                        : 'from-emerald-50 to-emerald-100 border-emerald-300'
                    }`}
                  >
                    <div className="flex items-center justify-center gap-2">
                      {gameMode === 'parejas' && players.length === 4 && (
                        <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${players.indexOf(player) < 2 ? 'bg-blue-100 text-blue-800' : 'bg-orange-100 text-orange-800'}`}>
                          {players.indexOf(player) < 2 ? 'P1' : 'P2'}
                        </span>
                      )}
                      <p className="text-sm font-semibold text-gray-800 truncate">{player.name}</p>
                    </div>
                    {hasAbandonedScores ? (
                      <>
                        <p className="text-2xl font-bold text-gray-400">-</p>
                        <p className="text-xs text-gray-500">Abandonado</p>
                      </>
                    ) : (
                      <>
                        <p className="text-2xl font-bold text-emerald-700">{totalPoints}</p>
                        <p className="text-xs text-gray-600">Puntos Stableford</p>
                        {scoreToPar && (
                          <div className="mt-2 pt-2 border-t border-emerald-300">
                            <p className={`text-xl font-bold ${
                              scoreToPar.value === 0 ? 'text-gray-700' :
                              scoreToPar.value < 0 ? 'text-green-600' :
                              'text-red-600'
                            }`}>
                              {scoreToPar.display}
                            </p>
                            <p className="text-xs text-gray-600">vs Par Personal</p>
                          </div>
                        )}
                      </>
                    )}
                  </div>
                );
              })}
            </div>

            {isDivend && (
              <>
                <h3 className="font-semibold text-gray-700 mb-3 mt-6">No pasó de rojas</h3>
                <div className="space-y-3">
                  {players.map((player) => {
                    const round = roundsMap.get(player.id);
                    const noPasoRojasHoles: number[] = [];

                    playableHoles.forEach((h) => {
                      const score = round?.scores[h.hole_number];
                      if (score?.no_paso_rojas) {
                        noPasoRojasHoles.push(h.hole_number);
                      }
                    });

                    const noPasoRojasCount = noPasoRojasHoles.length;
                    const holesList = noPasoRojasHoles.length > 0
                      ? `Hoyo: ${noPasoRojasHoles.join(', ')}`
                      : 'Ninguno';

                    return (
                      <div
                        key={player.id}
                        className="bg-red-50 border-2 border-red-200 rounded-lg p-3 flex items-center justify-between"
                      >
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            {gameMode === 'parejas' && players.length === 4 && (
                              <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${players.indexOf(player) < 2 ? 'bg-blue-100 text-blue-800' : 'bg-orange-100 text-orange-800'}`}>
                                {players.indexOf(player) < 2 ? 'P1' : 'P2'}
                              </span>
                            )}
                            <p className="font-semibold text-gray-800">{player.name}</p>
                          </div>
                          <p className="text-xs text-gray-600">{holesList}</p>
                        </div>
                        <div className="bg-red-100 border-2 border-red-300 rounded-lg px-4 py-2 min-w-[60px] text-center">
                          <p className="text-2xl font-bold text-red-600">{noPasoRojasCount}</p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </>
            )}

          </div>
        </div>
      </div>

      {showFinishModal && (
        <ConfirmModal
          message="¿Finalizar la partida? Esto marcará la ronda como completada."
          onConfirm={handleConfirmFinish}
          onCancel={() => setShowFinishModal(false)}
        />
      )}

      {showCourseChangeModal && courseId && (
        <CourseChangeModal
          currentCourseId={courseId}
          currentCourseName={courseName}
          onSelectCourse={handleSelectCourse}
          onClose={() => setShowCourseChangeModal(false)}
        />
      )}

      {showCourseConfirmModal && selectedCourse && (
        <CourseChangeConfirmModal
          currentCourseName={courseName}
          newCourseName={selectedCourse.name}
          currentNumHoles={numHoles}
          onConfirm={handleConfirmCourseChange}
          onCancel={() => {
            setShowCourseConfirmModal(false);
            setSelectedCourse(null);
          }}
        />
      )}

      {handshakeData && (
        <HandshakeModal
          isOpen={handshakeData.isOpen}
          winnerName={handshakeData.winner}
          marginText={handshakeData.margin}
          gameMode={gameMode}
          onContinue={() => {
            setHandshakeAcknowledged(true);
            setHandshakeData(null);
          }}
          onFinishRound={onFinishRound}
        />
      )}
    </div>
  );
};
