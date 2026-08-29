import React, { useState, useEffect } from 'react';
import { GolfCourse, GolfHole, Group, Tee, GameMode } from '../types';
import { golfService } from '../services/golfService';
import { ChevronRight, Flag, Copy, Check, LogOut, ArrowLeft, Info } from 'lucide-react';
import { HolesRangeModal } from './HolesRangeModal';
import { AdminPinModal } from './AdminPinModal';
import { adminPinUtils } from '../utils/adminPin';
import { safeStorage } from '../utils/safeStorage';
import { expressTierGuard } from '../services/expressTierGuard';
import { ParTeeUpgradeModal } from './ParTeeUpgradeModal';
import { trackExpressGameCreated } from '../services/expressTierGuard';
import { supabase } from '../services/supabaseClient';
import { getUserId } from '../utils/userId';

interface RoundSetupProps {
  onRoundCreated: (roundId: string, courseId: string, numHoles: 9 | 18, useSlope: boolean) => void;
  onViewActiveRounds: () => void;
  onViewGamePoints: () => void;
  onViewStatistics?: () => void;
  onJoinWithCode: () => void;
  onLeaveGroup: () => void;
  onBack?: () => void;
  currentGroup?: Group | null;
  isGroupCreator?: boolean;
  hasLimitedAccess?: boolean;
}

export const RoundSetup: React.FC<RoundSetupProps> = ({
  onRoundCreated,
  onViewActiveRounds,
  onViewGamePoints,
  onViewStatistics,
  onJoinWithCode,
  onLeaveGroup,
  onBack,
  currentGroup,
  isGroupCreator = true,
  hasLimitedAccess = false,
}) => {
  const [courses, setCourses] = useState<GolfCourse[]>([]);
  const [selectedCourse, setSelectedCourse] = useState<string | null>(null);
  const [selectedCourseName, setSelectedCourseName] = useState<string>('');
  const [selectedCourseHoleCount, setSelectedCourseHoleCount] = useState<number>(18);
  const [numHoles, setNumHoles] = useState<9 | 18>(9);
  const [holesRange, setHolesRange] = useState<'1-9' | '10-18'>('1-9');
  const [useSlope, setUseSlope] = useState<boolean>(false);
  const [tees, setTees] = useState<Tee[]>([]);
  const [selectedTeeId, setSelectedTeeId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [activeRoundsCount, setActiveRoundsCount] = useState(0);
  const [codeCopied, setCodeCopied] = useState(false);
  const [showHolesRangeModal, setShowHolesRangeModal] = useState(false);
  const [pendingNumHoles, setPendingNumHoles] = useState<9 | 18 | null>(null);
  const [showAdminPinModal, setShowAdminPinModal] = useState(false);
  const [pinError, setPinError] = useState('');
  const [completedRounds, setCompletedRounds] = useState<any[]>([]);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);
  const [gameMode, setGameMode] = useState<GameMode>('stableford');
  const [completedRoundsCount, setCompletedRoundsCount] = useState<number>(0);

  // Estado para controlar las partidas restantes del usuario no registrado
  const MAX_GUEST_ROUNDS = 4;
  const [remainingGuestRounds, setRemainingGuestRounds] = useState<number | null>(null);

  useEffect(() => {
    loadCourses();
    loadActiveRoundsCount();
    loadCompletedRounds();
    loadGuestRoundsCount();
  }, []);

  const loadGuestRoundsCount = async () => {
    if (!currentGroup) {
      try {
        const userId = getUserId();
        const { count, error } = await supabase
          .from('golf_rounds')
          .select('id', { count: 'exact', head: true })
          .eq('user_id', userId);

        if (!error && count !== null) {
          setRemainingGuestRounds(Math.max(0, MAX_GUEST_ROUNDS - count));
        }
      } catch (err) {
        console.error('Error al contar partidas del usuario anónimo:', err);
      }
    }
  };

  useEffect(() => {
    const loadCourseDetails = async () => {
      if (selectedCourse) {
        try {
          const holeCount = await golfService.getCourseHoleCount(selectedCourse);
          setSelectedCourseHoleCount(holeCount);

          const course = courses.find(c => c.id === selectedCourse);
          if (course) {
            setSelectedCourseName(course.name);
          }

          if (holeCount === 9) {
            setNumHoles(9);
          }

          const courseTees = await golfService.getTees(selectedCourse);
          setTees(courseTees);
          if (courseTees.length > 0) {
            setSelectedTeeId(courseTees[0].id);
          }
        } catch (err) {
          console.error('Error loading course details:', err);
        }
      }
    };

    loadCourseDetails();
  }, [selectedCourse, courses]);

  const loadCourses = async () => {
    try {
      setLoading(true);
      const data = await golfService.getCourses();
      setCourses(data);
      if (data.length > 0) {
        const lastCourseId = safeStorage.getItem('lastSelectedCourse');
        const courseExists = lastCourseId && data.some(c => c.id === lastCourseId);
        setSelectedCourse(courseExists ? lastCourseId : data[0].id);
      }
    } catch (err) {
      setError('Error cargando campos de golf');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const loadActiveRoundsCount = async () => {
    try {
      const activeRounds = await golfService.getActiveRounds();
      setActiveRoundsCount(activeRounds.length);
    } catch (err) {
      console.error('Error cargando contador de partidas:', err);
    }
  };

  const loadCompletedRounds = async () => {
    try {
      if (!currentGroup) {
        const availableRounds = await golfService.getAvailableRoundsForStats(4);
        console.log('📊 Partidas encontradas para estadísticas:', availableRounds);
        setCompletedRounds(availableRounds);
      }
    } catch (err) {
      console.error('Error cargando partidas para estadísticas:', err);
    }
  };

  const handleCreateRound = async () => {
    const isGroupRound = Boolean(currentGroup?.id || currentGroup?.group_code);

    if (!isGroupRound) {
      try {
        setLoading(true);

        const existingRounds = await golfService.getAvailableRoundsForStats(4);

        if (existingRounds.length >= 4) {
          setError('Has alcanzado el límite máximo de 4 partidas del plan Express.');
          setShowUpgradeModal(true);
          setLoading(false);
          return;
        }

        const hasActive = await golfService.hasActiveQuickPlayRound();
        if (hasActive) {
          setError('Tienes una partida en curso. Debes finalizarla o eliminarla antes de crear una nueva.');
          setLoading(false);
          return;
        }

        const hasCompleted = await golfService.hasCompletedQuickPlayRound();
        if (hasCompleted) {
          setError('Tienes una partida finalizada pendiente de archivar. Ve a Mis Partidas para archivarla antes de crear una nueva.');
          setLoading(false);
          return;
        }

      } catch (err) {
        console.error('Error al comprobar el estado de las partidas:', err);
      } finally {
        setLoading(false);
      }
    }

    if (!selectedCourse) {
      setError('Por favor selecciona un campo');
      return;
    }

    if (currentGroup?.group_code === 'DIVEND' && !adminPinUtils.isAuthorized()) {
      setShowAdminPinModal(true);
      setPinError('');
      return;
    }

    await proceedWithRoundCreation();
  };

  const proceedWithRoundCreation = async () => {
    try {
      setLoading(true);
      setError('');
      console.log('🚀 Iniciando creación de partida en golfService...');
      const round = await golfService.createRound(
        selectedCourse,
        numHoles,
        useSlope,
        numHoles === 9 ? holesRange : undefined,
        useSlope ? selectedTeeId || undefined : undefined,
        gameMode
      );

      trackExpressGameCreated(round.id);
      
      safeStorage.setItem('lastSelectedCourse', selectedCourse);
      onRoundCreated(round.id, round.course_id, round.num_holes, round.use_slope);
    } catch (err: any) {
      console.error('Error al crear la partida:', err);
      setError(err.message || 'Error al crear la partida');
    } finally {
      setLoading(false);
    }
  };

  const handleCopyGroupCode = async () => {
    if (!currentGroup) return;

    try {
      await navigator.clipboard.writeText(currentGroup.group_code);
      setCodeCopied(true);
      setTimeout(() => setCodeCopied(false), 2000);
    } catch (err) {
      console.error('Error copying code:', err);
    }
  };

  const handleNumHolesChange = (newNumHoles: 9 | 18) => {
    if (newNumHoles === 9 && selectedCourseHoleCount === 18) {
      const isCostaAzahar = selectedCourseName.includes('Costa Azahar');

      if (isCostaAzahar) {
        setNumHoles(9);
        setHolesRange('1-9');
      } else {
        setPendingNumHoles(newNumHoles);
        setShowHolesRangeModal(true);
      }
    } else {
      setNumHoles(newNumHoles);
      setHolesRange('1-9');
    }
  };

  const handleHolesRangeConfirm = (range: '1-9' | '10-18') => {
    setHolesRange(range);
    if (pendingNumHoles !== null) {
      setNumHoles(pendingNumHoles);
      setPendingNumHoles(null);
    }
    setShowHolesRangeModal(false);
  };

  const handleHolesRangeCancel = () => {
    setPendingNumHoles(null);
    setShowHolesRangeModal(false);
  };

  const handleAdminPinSubmit = (pin: string) => {
    if (adminPinUtils.verifyPin(pin)) {
      adminPinUtils.setAuthorized();
      setShowAdminPinModal(false);
      setPinError('');
      proceedWithRoundCreation();
    } else {
      setPinError('PIN incorrecto. Inténtalo de nuevo.');
    }
  };

  const handleAdminPinCancel = () => {
    setShowAdminPinModal(false);
    setPinError('');
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-900 to-emerald-800 p-4 md:p-8">
      <div className="max-w-2xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center relative">
          {!currentGroup && onBack && (
            <button
              onClick={onBack}
              className="absolute left-0 top-0 text-white hover:text-emerald-200 flex items-center gap-2 transition-colors"
            >
              <ArrowLeft size={24} />
              Atras
            </button>
          )}
          <div className="flex items-center justify-center gap-3 mb-4">
            <h1 className="text-4xl md:text-5xl font-bold text-white">
              {currentGroup?.group_code === 'DIVEND'
                ? 'Partideta dels divendres'
                : (currentGroup?.name || 'La Partideta')}
            </h1>
          </div>
          <p className="text-emerald-100 text-lg">
            {currentGroup ? 'Gestor de Partidas y Puntuación' : 'Partida Rápida'}
          </p>
        </div>

        {/* Banner de Límite para Usuario No Registrado */}
        {!currentGroup && remainingGuestRounds !== null && (
          <div className="bg-amber-500/20 border-2 border-amber-400/40 rounded-xl p-4 text-white flex items-center gap-3 shadow-lg backdrop-blur-sm">
            <Info className="text-amber-300 flex-shrink-0" size={24} />
            <div className="text-sm">
              <p className="font-semibold text-amber-100">
                Modo no registrado
              </p>
              <p className="text-emerald-100">
                Te quedan <span className="font-bold text-amber-300 text-base">{remainingGuestRounds}</span> de {MAX_GUEST_ROUNDS} partidas disponibles en esta modalidad.
              </p>
            </div>
          </div>
        )}

        {/* Código de Grupo */}
        {currentGroup && !hasLimitedAccess && (
          <div className="bg-white rounded-lg shadow-xl p-6">
            <div className="flex items-start justify-between mb-3">
              <h3 className="text-lg font-semibold text-gray-800">Código de Grupo</h3>
              <button
                onClick={onLeaveGroup}
                className="text-red-600 hover:text-red-700 flex items-center gap-1 text-sm font-medium transition-colors"
                title="Salir del grupo"
              >
                <LogOut size={16} />
                Salir
              </button>
            </div>
            <p className="text-sm text-gray-600 mb-3">
              Comparte este código con otros para que puedan participar en las partidas del grupo:
            </p>
            <div className="flex items-center gap-3">
              <div className="flex-1 bg-green-50 border-2 border-green-300 rounded-lg px-4 py-3 text-center">
                <span className="text-2xl font-mono font-bold text-green-700 tracking-wider">
                  {currentGroup.group_code}
                </span>
              </div>
              <button
                onClick={handleCopyGroupCode}
                className="bg-green-600 hover:bg-green-700 text-white p-3 rounded-lg transition-colors"
                title="Copiar código"
              >
                {codeCopied ? <Check size={24} /> : <Copy size={24} />}
              </button>
            </div>
            {currentGroup.name && (
              <p className="text-sm text-gray-500 mt-2">Grupo: {currentGroup.name}</p>
            )}
          </div>
        )}

        {/* Unirse con Código */}
        {currentGroup && !hasLimitedAccess && (
          <div
            onClick={onJoinWithCode}
            className="bg-gradient-to-br from-purple-50 to-purple-100 border-2 border-purple-300 rounded-lg shadow-2xl p-6 md:p-8 cursor-pointer hover:shadow-xl transition-shadow"
          >
            <h2 className="text-2xl font-bold text-purple-900 mb-4">Unirse con Código a una partida</h2>
            <p className="text-gray-700 mb-6">
              ¿Tienes un código de acceso? Úsalo para unirte a una partida existente y editar las puntuaciones.
            </p>
            <button className="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-4 rounded-lg flex items-center justify-center gap-2 transition-colors">
              Introducir Código
              <ChevronRight size={20} />
            </button>
          </div>
        )}

        {/* Salir del Grupo */}
        {currentGroup && hasLimitedAccess && (
          <button
            onClick={onLeaveGroup}
            className="w-full text-left bg-white hover:bg-gray-50 border border-gray-200 rounded-lg p-3 flex items-center justify-between text-sm text-gray-600 hover:text-red-600 transition-colors"
          >
            <span className="flex items-center gap-2">
              <LogOut size={16} />
              Salir del grupo
            </span>
          </button>
        )}

        <div className={`grid grid-cols-1 ${(isGroupCreator && !hasLimitedAccess) ? 'md:grid-cols-2 md:items-stretch' : ''} gap-4`}>
          {/* Nueva Partida */}
          {isGroupCreator && !hasLimitedAccess && (
            <div className="bg-white rounded-lg shadow-2xl p-6 md:p-8">
              <h2 className="text-2xl font-bold text-emerald-900 mb-6">Nueva Partida</h2>

              {error && (
                <div className="bg-red-50 border-l-4 border-red-500 p-3 rounded mb-4">
                  <p className="text-red-700 text-sm">{error}</p>
                </div>
              )}

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Selecciona un Campo
                  </label>
                  <select
                    value={selectedCourse || ''}
                    onChange={(e) => setSelectedCourse(e.target.value)}
                    disabled={loading}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:outline-none focus:border-emerald-600 disabled:bg-gray-100"
                  >
                    <option value="">-- Selecciona un campo --</option>
                    {courses.map((course) => (
                      <option key={course.id} value={course.id}>
                        {course.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-3">
                    Número de Hoyos
                  </label>
                  <div className="flex gap-3">
                    <button
                      onClick={() => handleNumHolesChange(9)}
                      className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                        numHoles === 9
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      9 Hoyos
                    </button>
                    <button
                      onClick={() => handleNumHolesChange(18)}
                      className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                        numHoles === 18
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      18 Hoyos
                    </button>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-3">
                    Cálculo de Handicap
                  </label>
                  <div className="flex gap-3">
                    <button
                      onClick={() => setUseSlope(true)}
                      className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                        useSlope
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Con Slope
                    </button>
                    <button
                      onClick={() => setUseSlope(false)}
                      className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                        !useSlope
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Sin Slope
                    </button>
                  </div>
                </div>

                {useSlope && tees.length > 0 && (
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-3">
                      Selecciona Barras
                    </label>
                    <div className="grid grid-cols-2 gap-3">
                      {tees.map((tee) => (
                        <button
                          key={tee.id}
                          onClick={() => setSelectedTeeId(tee.id)}
                          className={`py-3 px-4 rounded-lg font-bold transition-all flex items-center gap-2 ${
                            selectedTeeId === tee.id
                              ? 'bg-emerald-600 text-white shadow-lg'
                              : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                          }`}
                        >
                          <div
                            className="w-4 h-4 rounded-full border-2 border-current"
                            style={{ backgroundColor: tee.color }}
                          />
                          {tee.name}
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-3">
                    Modalidad de Juego
                  </label>
                  <div className="grid grid-cols-2 gap-3">
                    <button
                      onClick={() => setGameMode('stableford')}
                      className={`py-3 px-4 rounded-lg font-bold transition-all text-sm ${
                        gameMode === 'stableford'
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Stableford
                    </button>
                    <button
                      onClick={() => setGameMode('match')}
                      className={`py-3 px-4 rounded-lg font-bold transition-all text-sm ${
                        gameMode === 'match'
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Match
                    </button>
                    <button
                      onClick={() => setGameMode('sindicato')}
                      className={`py-3 px-4 rounded-lg font-bold transition-all text-sm ${
                        gameMode === 'sindicato'
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Sindicato
                    </button>
                    <button
                      onClick={() => setGameMode('parejas')}
                      className={`py-3 px-4 rounded-lg font-bold transition-all text-sm ${
                        gameMode === 'parejas'
                          ? 'bg-emerald-600 text-white shadow-lg'
                          : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                      }`}
                    >
                      Parejas
                    </button>
                  </div>
                  {gameMode === 'match' && (
                    <p className="text-xs text-gray-500 mt-2">2 jugadores. Se gana por hoyo, no por puntos.</p>
                  )}
                  {gameMode === 'sindicato' && (
                    <p className="text-xs text-gray-500 mt-2">3 jugadores. 6 puntos por hoyo: 4/2/0, 3/3/0 o 4/1/1.</p>
                  )}
                  {gameMode === 'parejas' && (
                    <p className="text-xs text-gray-500 mt-2">2 parejas de 2 jugadores (4 total).</p>
                  )}
                </div>

                <button
                  onClick={handleCreateRound}
                  disabled={!selectedCourse || loading}
                  className="w-full bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-lg flex items-center justify-center gap-2 transition-colors mt-6"
                >
                  Crear Partida
                  <ChevronRight size={20} />
                </button>
              </div>
            </div>
          )}

          {/* Columna derecha: Mi Partida y Estadísticas */}
          <div className="flex flex-col gap-4 h-full">
            {/* Ver Partida Activa */}
            <div
              onClick={onViewActiveRounds}
              className="bg-gradient-to-br from-amber-50 to-amber-100 border-2 border-amber-300 rounded-lg shadow-xl cursor-pointer hover:shadow-2xl transition-shadow flex-[2] flex flex-col"
            >
              <div className="p-5 pb-4 flex-1">
                <div className="flex items-start justify-between mb-3">
                  <h2 className="text-2xl font-bold text-amber-900">
                    {currentGroup ? 'Partida Activas' : 'Mi Partida'}
                  </h2>
                  <div className="bg-amber-600 text-white font-bold rounded-full w-8 h-8 flex items-center justify-center text-base">
                    {activeRoundsCount}
                  </div>
                </div>
                <p className="text-gray-700 text-base leading-relaxed">
                  {currentGroup
                    ? 'Edita las partidas y observa en tiempo real las puntuaciones de todas las partidas activas.'
                    : 'Accede a tus partida rápida activa y continúa donde lo dejaste.'}
                </p>
              </div>
              <button className="w-full bg-amber-600 hover:bg-amber-700 text-white font-bold py-3 px-4 rounded-b-md flex items-center justify-center gap-2 transition-colors text-base">
                Ver Partida
                <ChevronRight size={20} />
              </button>
            </div>

            {/* Sección de Estadísticas para Partida Rápida */}
            {!currentGroup && onViewStatistics && (
              <div
                onClick={completedRounds.length > 0 ? onViewStatistics : undefined}
                className={`bg-gradient-to-br from-blue-50 to-blue-100 border-2 border-blue-300 rounded-lg shadow-xl flex-1 flex flex-col transition-all ${
                  completedRounds.length > 0
                    ? 'cursor-pointer hover:shadow-2xl'
                    : 'opacity-60 cursor-not-allowed'
                }`}
              >
                <div className="p-5 pb-4 flex-1">
                  <div className="flex items-start justify-between mb-3">
                    <h2 className="text-2xl font-bold text-blue-900">Estadísticas</h2>
                    <div className="bg-blue-600 text-white font-bold rounded-full w-8 h-8 flex items-center justify-center text-base shadow-sm">
                      {completedRounds.length}
                    </div>
                  </div>

                  <p className="text-gray-700 text-base leading-relaxed">
                    {completedRounds.length > 0
                      ? 'Ver premios y estadísticas del historial de partidas'
                      : 'No hay partidas completadas o archivadas para mostrar'}
                  </p>
                </div>

                {completedRounds.length > 0 && (
                  <button 
                    onClick={(e) => {
                      e.stopPropagation();
                      onViewStatistics();
                    }}
                    className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-4 rounded-b-md flex items-center justify-center gap-2 transition-colors text-base"
                  >
                    <span>Ver Estadísticas</span>
                    <ChevronRight size={20} />
                  </button>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Puntos de juego */}
        {currentGroup && (
          <div
            onClick={onViewGamePoints}
            className="bg-gradient-to-br from-blue-50 to-blue-100 border-2 border-blue-300 rounded-lg shadow-2xl p-6 md:p-8 cursor-pointer hover:shadow-xl transition-shadow"
          >
            <h2 className="text-2xl font-bold text-blue-900 mb-4">Puntos de Juego</h2>
            <p className="text-gray-700 mb-6">
              Consulta las clasificaciones de partidas completadas en el dia, los jugadores registrados y sus handicaps.
            </p>
            <button className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 rounded-lg flex items-center justify-center gap-2 transition-colors">
              Ver Puntos
              <ChevronRight size={20} />
            </button>
          </div>
        )}

        {/* Estadísticas */}
        {currentGroup && onViewStatistics && (
          <div
            onClick={onViewStatistics}
            className="bg-gradient-to-br from-purple-50 to-purple-100 border-2 border-purple-300 rounded-lg shadow-2xl p-6 md:p-8 cursor-pointer hover:shadow-xl transition-shadow"
          >
            <h2 className="text-2xl font-bold text-purple-900 mb-4">Estadísticas</h2>
            <p className="text-gray-700 mb-6">
              Consulta estadísticas de jugadores, del grupo y de campos. Solo para multipartidetas archivadas.
            </p>
            <button className="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-4 rounded-lg flex items-center justify-center gap-2 transition-colors">
              Ver Estadísticas
              <ChevronRight size={20} />
            </button>
          </div>
        )}
      </div>

      {showHolesRangeModal && (
        <HolesRangeModal
          onConfirm={handleHolesRangeConfirm}
          onCancel={handleHolesRangeCancel}
        />
      )}

      {showAdminPinModal && (
        <AdminPinModal
          onSubmit={handleAdminPinSubmit}
          onCancel={handleAdminPinCancel}
          error={pinError}
        />
      )}

      <ParTeeUpgradeModal
        isOpen={showUpgradeModal}
        onClose={() => setShowUpgradeModal(false)}
      />
    </div>
  );
};