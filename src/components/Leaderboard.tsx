import React, { useState, useEffect } from 'react';
import { GolfRound, RoundPlayer, RoundScore, GameMode } from '../types';
import { Trophy, Medal, Flame, ArrowLeft, Eye, RefreshCw } from 'lucide-react';
import { golfService } from '../services/golfService';

interface LeaderboardProps {
  players: RoundPlayer[];
  rounds: Array<{
    playerId: string;
    scores: Record<number, RoundScore>;
    totalStablefordPoints: number;
  }>;
  currentHole: number;
  onBack: () => void;
  hasGroup?: boolean;
  gameMode?: GameMode;
}

interface RoundStats {
  round: GolfRound;
  players: RoundPlayer[];
  scores: RoundScore[];
}

export const Leaderboard: React.FC<LeaderboardProps> = ({
  players,
  rounds,
  currentHole,
  onBack,
  hasGroup = false,
  gameMode = 'stableford',
}) => {
  const isModeScoring = gameMode !== 'stableford';
  const [allActiveRounds, setAllActiveRounds] = useState<RoundStats[]>([]);
  const [showAllRounds, setShowAllRounds] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadAllActiveRounds();
  }, []);

  const loadAllActiveRounds = async () => {
    try {
      setLoading(true);
      const activeRounds = await golfService.getActiveRounds();

      const roundsWithDetails = await Promise.all(
        activeRounds.map(async (round) => {
          const players = await golfService.getRoundPlayers(round.id);
          const scores = await golfService.getRoundScores(round.id);
          return { round, players, scores };
        })
      );

      setAllActiveRounds(roundsWithDetails);
    } catch (err) {
      console.error('Error loading active rounds:', err);
    } finally {
      setLoading(false);
    }
  };

  const roundsMap = new Map(rounds.map((r) => [r.playerId, r]));

  const playerStats = players.map((player) => {
    const round = roundsMap.get(player.id);
    const totalPoints = isModeScoring
      ? round ? Object.values(round.scores).reduce((sum, s) => sum + (s.mode_points ?? 0), 0) : 0
      : round?.totalStablefordPoints ?? 0;

    return {
      player,
      totalPoints,
      holesCompleted: round ? Object.keys(round.scores).length : 0,
    };
  });

  const sorted = [...playerStats].sort((a, b) => {
    if (b.totalPoints !== a.totalPoints) {
      return b.totalPoints - a.totalPoints;
    }
    return b.holesCompleted - a.holesCompleted;
  });

  const getMedalIcon = (position: number) => {
    if (position === 0) return <Trophy size={24} className="text-yellow-500" />;
    if (position === 1) return <Medal size={24} className="text-gray-400" />;
    if (position === 2) return <Medal size={24} className="text-orange-600" />;
    return null;
  };

  const getPlayerStats = (roundStats: RoundStats, playerId: string) => {
    const playerScores = roundStats.scores.filter((s) => s.player_id === playerId);
    const totalPoints = isModeScoring
      ? playerScores.reduce((sum, s) => sum + (s.mode_points ?? 0), 0)
      : playerScores.reduce((sum, s) => sum + s.stableford_points, 0);
    return {
      scoresEntered: playerScores.length,
      totalPoints,
    };
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-900 to-emerald-800 p-4 md:p-8">
      <div className="max-w-2xl mx-auto">
        <div className="bg-white rounded-lg shadow-2xl overflow-hidden">
          <div className="bg-gradient-to-r from-emerald-700 to-emerald-600 p-6 md:p-8">
            <div className="flex items-center gap-3 mb-2">
              <Trophy size={32} className="text-yellow-400" />
              <h1 className="text-3xl md:text-4xl font-bold text-white">
                {showAllRounds ? 'Todas las Partidas' : 'Clasificación Actual'}
              </h1>
            </div>
            {!showAllRounds && (
              <p className="text-emerald-100">
                Hoyo {currentHole} - {sorted[0]?.player.name || 'En Juego'}
              </p>
            )}
          </div>

          <div className="p-6 md:p-8">
            {hasGroup && (
              <div className="mb-6 flex gap-3">
                <button
                  onClick={() => setShowAllRounds(false)}
                  className={`flex-1 py-3 px-4 rounded-lg font-semibold transition-colors ${
                    !showAllRounds
                      ? 'bg-emerald-600 text-white'
                      : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
                >
                  Mi Partida
                </button>
                <button
                  onClick={() => {
                    setShowAllRounds(true);
                    loadAllActiveRounds();
                  }}
                  className={`flex-1 py-3 px-4 rounded-lg font-semibold transition-colors ${
                    showAllRounds
                      ? 'bg-emerald-600 text-white'
                      : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
                >
                  Todas las Partidas ({allActiveRounds.length})
                </button>
              </div>
            )}

            {!showAllRounds ? (
              <>
                <div className="mb-6">
                  <div className="text-sm text-gray-600 bg-blue-50 p-3 rounded-lg border border-blue-200">
                    <p className="font-semibold text-blue-900">
                      Progreso: {currentHole}/
                      {players.length > 0
                        ? roundsMap.get(players[0].id)?.scores
                          ? Object.keys(roundsMap.get(players[0].id)?.scores ?? {}).length + 1
                          : 1
                        : 1}{' '}
                      hoyos
                    </p>
                  </div>
                </div>

                <div className="space-y-3">
                  {sorted.map((stat, index) => (
                    <div
                      key={stat.player.id}
                      className={`border-2 rounded-lg p-4 flex items-center gap-4 transition-all ${
                        index === 0
                          ? 'bg-gradient-to-r from-yellow-50 to-yellow-100 border-yellow-400'
                          : 'bg-white border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <div className="flex items-center justify-center w-12 h-12 rounded-full font-bold text-lg">
                        {getMedalIcon(index) || (
                          <span className="text-gray-600 font-bold text-xl">{index + 1}</span>
                        )}
                      </div>

                      <div className="flex-1">
                        <p
                          className={`font-bold text-lg ${
                            index === 0 ? 'text-emerald-900' : 'text-gray-800'
                          }`}
                        >
                          {stat.player.name}
                        </p>
                        <div className="flex gap-4 text-sm text-gray-600">
                          <span>HCP: {stat.player.playing_handicap}</span>
                          <span>Hoyos: {stat.holesCompleted}</span>
                        </div>
                      </div>

                      <div className="text-right">
                        <p
                          className={`text-3xl font-bold ${
                            index === 0 ? 'text-yellow-600' : 'text-emerald-700'
                          }`}
                        >
                          {stat.totalPoints}
                        </p>
                        <p className="text-xs text-gray-600">
                          {isModeScoring ? 'Puntos Modal.' : 'Puntos Obtenidos'}
                        </p>
                      </div>

                      {index === 0 && <Flame size={24} className="text-orange-500 animate-pulse" />}
                    </div>
                  ))}
                </div>

                {sorted.length === 0 && (
                  <div className="text-center py-8">
                    <p className="text-gray-500 text-lg">No hay jugadores en la partida</p>
                  </div>
                )}

                <div className="mt-8 border-t pt-6">
                  <h3 className="font-bold text-lg text-gray-800 mb-4">
                    {isModeScoring ? `Detalles de Puntuación (${gameMode === 'match' ? 'Match' : gameMode === 'sindicato' ? 'Sindicato' : 'Parejas'})` : 'Detalles de Puntuación Stableford'}
                  </h3>
                  {isModeScoring ? (
                    <div className="grid grid-cols-1 gap-3 text-sm">
                      {gameMode === 'match' && (
                        <div className="bg-blue-50 p-3 rounded border border-blue-200">
                          <p className="font-semibold text-blue-900">Match Play</p>
                          <p className="text-xs text-blue-700">1 punto por hoyo ganado, 0.5 por hoyo empatado. Gana el jugador con mas hoyos.</p>
                        </div>
                      )}
                      {gameMode === 'sindicato' && (
                        <div className="bg-blue-50 p-3 rounded border border-blue-200">
                          <p className="font-semibold text-blue-900">Sindicato (3 jugadores)</p>
                          <p className="text-xs text-blue-700">6 puntos por hoyo: 4/2/0, 3/3/0, o 4/1/1 segun el resultado.</p>
                        </div>
                      )}
                      {gameMode === 'parejas' && (
                        <div className="bg-blue-50 p-3 rounded border border-blue-200">
                          <p className="font-semibold text-blue-900">Parejas (2 vs 2)</p>
                          <p className="text-xs text-blue-700">1 punto por hoyo ganado por la pareja, 0.5 por empatado. Gana la pareja con mas hoyos.</p>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-3 text-sm">
                      <div className="bg-yellow-50 p-3 rounded border border-yellow-400">
                        <p className="font-semibold text-yellow-900">4 Puntos</p>
                        <p className="text-xs text-yellow-700">Eagle</p>
                      </div>
                      <div className="bg-red-50 p-3 rounded border border-red-500">
                        <p className="font-semibold text-red-900">3 Puntos</p>
                        <p className="text-xs text-red-700">Birdie</p>
                      </div>
                      <div className="bg-white p-3 rounded border-2 border-gray-300">
                        <p className="font-semibold text-gray-900">2 Puntos</p>
                        <p className="text-xs text-gray-700">Par Neto</p>
                      </div>
                      <div className="bg-blue-50 p-3 rounded border border-blue-500">
                        <p className="font-semibold text-blue-900">1 Punto</p>
                        <p className="text-xs text-blue-700">Bogey</p>
                      </div>
                      <div className="bg-black/10 p-3 rounded border border-black">
                        <p className="font-semibold text-gray-900">0 Puntos</p>
                        <p className="text-xs text-gray-700">Doble o peor</p>
                      </div>
                    </div>
                  )}
                </div>
              </>
            ) : (
              <>
                <div className="mb-4 flex justify-end">
                  <button
                    onClick={loadAllActiveRounds}
                    disabled={loading}
                    className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-semibold py-2 px-4 rounded-lg flex items-center gap-2 transition-colors"
                  >
                    <RefreshCw size={18} className={loading ? 'animate-spin' : ''} />
                    Actualizar
                  </button>
                </div>

                {loading && allActiveRounds.length === 0 ? (
                  <div className="text-center py-8">
                    <p className="text-gray-500">Cargando partidas...</p>
                  </div>
                ) : allActiveRounds.length === 0 ? (
                  <div className="text-center py-8">
                    <p className="text-gray-500">No hay partidas activas</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {allActiveRounds.map((roundStats) => {
                      const courseHoles = roundStats.round.num_holes === 9 ? '9 Hoyos' : '18 Hoyos';
                      const sortedPlayers = roundStats.players
                        .map((player) => {
                          const stats = getPlayerStats(roundStats, player.id);
                          return { player, stats };
                        })
                        .sort((a, b) => {
                          if (b.stats.totalPoints !== a.stats.totalPoints) {
                            return b.stats.totalPoints - a.stats.totalPoints;
                          }
                          return a.player.playing_handicap - b.player.playing_handicap;
                        });

                      return (
                        <div
                          key={roundStats.round.id}
                          className="border-2 border-gray-200 rounded-lg overflow-hidden bg-white"
                        >
                          <div className="bg-gray-50 p-4 border-b border-gray-200">
                            <div className="flex items-center justify-between">
                              <div>
                                <p className="font-bold text-lg text-gray-800">{courseHoles}</p>
                                <p className="text-sm text-gray-600">
                                  {roundStats.players.length} Jugadores •{' '}
                                  {getTimeElapsed(roundStats.round.created_at)}
                                </p>
                              </div>
                              <Eye className="text-emerald-600" size={24} />
                            </div>
                          </div>

                          <div className="p-4 space-y-2">
                            {sortedPlayers.map((item, index) => (
                              <div
                                key={item.player.id}
                                className={`p-3 rounded-lg flex items-center justify-between ${
                                  index === 0
                                    ? 'bg-yellow-100 border border-yellow-400'
                                    : 'bg-gray-50 border border-gray-200'
                                }`}
                              >
                                <div className="flex items-center gap-3">
                                  <span className="font-bold text-gray-600 w-6">{index + 1}</span>
                                  <div>
                                    <p className="font-semibold text-gray-800">{item.player.name}</p>
                                    <p className="text-xs text-gray-600">
                                      HCP {item.player.playing_handicap} • {item.stats.scoresEntered}{' '}
                                      hoyos
                                    </p>
                                  </div>
                                </div>
                                <p
                                  className={`text-2xl font-bold ${
                                    index === 0 ? 'text-yellow-600' : 'text-emerald-700'
                                  }`}
                                >
                                  {item.stats.totalPoints}
                                </p>
                              </div>
                            ))}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </>
            )}

            <button
              onClick={onBack}
              className="w-full mt-8 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-4 rounded-lg flex items-center justify-center gap-2 transition-colors"
            >
              <ArrowLeft size={20} />
              Volver a la Tarjeta
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

function getTimeElapsed(createdAt: string): string {
  const now = new Date();
  const created = new Date(createdAt);
  const minutes = Math.floor((now.getTime() - created.getTime()) / 60000);

  if (minutes < 1) return 'Hace segundos';
  if (minutes < 60) return `${minutes}m`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;

  const days = Math.floor(hours / 24);
  return `${days}d`;
}
