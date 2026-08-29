import React from 'react';
import { X, Trophy, Users, Calendar, MapPin } from 'lucide-react';

interface ArchivedRoundsModalProps {
  rounds: any[];
  onClose: () => void;
  onSelectRound: (round: any) => void;
}

export const ArchivedRoundsModal: React.FC<ArchivedRoundsModalProps> = ({
  rounds,
  onClose,
  onSelectRound,
}) => {
  const sortedRounds = [...rounds].sort((a, b) =>
    new Date(b.played_at).getTime() - new Date(a.played_at).getTime()
  );

  const groupedByDate = sortedRounds.reduce((acc, round) => {
    const dateKey = new Date(round.played_at).toISOString().split('T')[0];
    if (!acc[dateKey]) {
      acc[dateKey] = [];
    }
    acc[dateKey].push(round);
    return acc;
  }, {} as Record<string, any[]>);

  const sortedDates = Object.keys(groupedByDate).sort((a, b) =>
    new Date(b).getTime() - new Date(a).getTime()
  );

  const getWinner = (round: any) => {
    if (!round.final_ranking || round.final_ranking.length === 0) {
      return { name: 'N/A', points: 0 };
    }
    const winner = round.final_ranking[0];
    return {
      name: winner.player_name,
      points: winner.points || winner.total_points,
    };
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
        <div className="flex items-center justify-between p-6 border-b bg-gradient-to-r from-emerald-600 to-emerald-700">
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Trophy size={28} />
            Historial de Partidas
          </h2>
          <button
            onClick={onClose}
            className="text-white hover:bg-emerald-800 p-2 rounded-lg transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <div className="overflow-y-auto p-6">
          {sortedRounds.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">No hay partidas archivadas</p>
            </div>
          ) : (
            <div className="space-y-4">
              {sortedDates.map((dateKey) => {
                const dayRounds = groupedByDate[dateKey];
                const date = new Date(dateKey);
                const formattedDate = date.toLocaleDateString('es-ES', {
                  weekday: 'long',
                  day: 'numeric',
                  month: 'long',
                  year: 'numeric',
                });

                const allPlayers = new Set<string>();
                dayRounds.forEach((round) => {
                  round.final_ranking?.forEach((player: any) => {
                    allPlayers.add(player.player_name);
                  });
                });

                const courses = dayRounds.map((r) => r.course_name);
                const uniqueCourses = [...new Set(courses)];

                return (
                  <button
                    key={dateKey}
                    onClick={() => onSelectRound(dayRounds[0])}
                    className="w-full bg-gradient-to-r from-gray-50 to-gray-100 hover:from-emerald-50 hover:to-emerald-100 border-2 border-gray-300 hover:border-emerald-500 rounded-lg p-5 transition-all shadow-md hover:shadow-lg text-left"
                  >
                    <div className="space-y-3">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <Calendar size={24} className="text-emerald-600" />
                          <div>
                            <p className="text-lg font-bold text-gray-800 capitalize">
                              {formattedDate}
                            </p>
                            <p className="text-sm text-gray-600">
                              {dayRounds.length} {dayRounds.length === 1 ? 'partida' : 'partidas'}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-sm text-gray-600 mb-1">Total jugadores</p>
                          <div className="flex items-center gap-2 justify-end">
                            <Users size={20} className="text-blue-600" />
                            <p className="text-2xl font-bold text-gray-800">{allPlayers.size}</p>
                          </div>
                        </div>
                      </div>

                      <div className="flex flex-wrap gap-2">
                        {uniqueCourses.map((course, idx) => (
                          <div
                            key={idx}
                            className="flex items-center gap-1 bg-white px-3 py-1 rounded-full border border-gray-200"
                          >
                            <MapPin size={14} className="text-emerald-600" />
                            <p className="text-xs font-semibold text-gray-700">{course}</p>
                          </div>
                        ))}
                      </div>

                      <div className="text-sm text-gray-600 bg-white rounded-lg p-2 border border-gray-200">
                        <p className="font-semibold">Haz clic para ver la clasificación completa del día</p>
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="p-4 border-t bg-gray-50">
          <button
            onClick={onClose}
            className="w-full bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-3 rounded-lg transition-colors"
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  );
};
