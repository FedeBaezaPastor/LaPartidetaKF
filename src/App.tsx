import React, { useState, useEffect } from 'react';
import { AlertTriangle } from 'lucide-react';
import { GolfRound, GolfHole, GolfCourse, RoundPlayer, RoundScore, Group, GameMode } from './types';
import { golfService } from './services/golfService';
import { calculateModePoints, ModeScoreInput } from './utils/calculations';
import { accessCodeStorage } from './utils/accessCode';
import { storageUtils } from './utils/storage';
import { RoundSetup } from './components/RoundSetup';
import { PlayerSetup } from './components/PlayerSetup';
import { Scorecard } from './components/Scorecard';
import { Leaderboard } from './components/Leaderboard';
import { ActiveRoundsViewer } from './components/ActiveRoundsViewer';
import { HoleConfiguration } from './components/HoleConfiguration';
import { GamePoints } from './components/GamePoints';
import { Statistics } from './components/Statistics';
import { QuickPlayStatistics } from './components/QuickPlayStatistics';
import { AccessCodeModal } from './components/AccessCodeModal';
import { ConfirmModal } from './components/ConfirmModal';
import { AdminPinModal } from './components/AdminPinModal';
import GroupSetup from './components/GroupSetup';
import Auth from './components/Auth';
import MyGroups from './components/MyGroups';
import AdminDashboard from './components/AdminDashboard';
import ProfileScreen from './components/ProfileScreen';
import { PremiumModal } from './components/PremiumModal';

type ViewType = 'main' | 'setup' | 'players' | 'scorecard' | 'leaderboard' | 'active-rounds' | 'viewer' | 'game-points' | 'statistics' | 'quickplay-statistics' | 'auth' | 'my-groups' | 'admin-dashboard' | 'profile';

interface RoundState {
  round: GolfRound | null;
  holes: GolfHole[];
  players: RoundPlayer[];
  scores: RoundScore[];
  currentHole: number;
  isCreator: boolean;
  hasEditAccess: boolean;
  courseName: string;
  course?: GolfCourse;
}

function App() {
  const [isIncognito, setIsIncognito] = useState(false);
  const [authUser, setAuthUser] = useState<any>(null);
  const [currentGroup, setCurrentGroup] = useState<Group | null>(null);
  const [isGroupCreator, setIsGroupCreator] = useState(false);
  const [hasLimitedAccess, setHasLimitedAccess] = useState(false);
  const [groupLoading, setGroupLoading] = useState(true);
  const [currentView, setCurrentView] = useState<ViewType>('main');
  const [roundState, setRoundState] = useState<RoundState>({
    round: null,
    holes: [],
    players: [],
    scores: [],
    currentHole: 1,
    isCreator: false,
    hasEditAccess: false,
    courseName: '',
  });
  const [showHoleConfig, setShowHoleConfig] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showAccessCodeModal, setShowAccessCodeModal] = useState(false);
  const [pendingRoundId, setPendingRoundId] = useState<string | null>(null);
  const [accessCodeError, setAccessCodeError] = useState('');
  const [showLeaveGroupConfirm, setShowLeaveGroupConfirm] = useState(false);
  const [showAdminPinModal, setShowAdminPinModal] = useState(false);
  const [adminPinError, setAdminPinError] = useState('');
  const [adminPinAttempts, setAdminPinAttempts] = useState(0);

  useEffect(() => {
    const checkIncognito = () => {
      try {
        const testKey = '__test__';
        localStorage.setItem(testKey, 'test');
        localStorage.removeItem(testKey);
        console.log('✅ localStorage disponible');
        setIsIncognito(false);
      } catch {
        console.log('⚠️ Modo incógnito detectado');
        setIsIncognito(true);
      }
    };
    checkIncognito();
  }, []);

  useEffect(() => {
    const handleOpenProfileScreen = () => {
      if (authUser) {
        setCurrentView('profile');
      }
    };

    window.addEventListener('open-profile-screen', handleOpenProfileScreen);

    return () => {
      window.removeEventListener('open-profile-screen', handleOpenProfileScreen);
    };
  }, [authUser]);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        console.log('🔐 Checking auth...');
        const { supabase } = await import('./services/supabaseClient');
        console.log('✅ Supabase client imported');

        const {
          data: { user },
        } = await supabase.auth.getUser();

        if (!user) {
          console.log('No user authenticated');
          setAuthUser(null);
        } else {
          console.log('✅ User authenticated:', user.email);
          setAuthUser(user);
        }

        const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
          console.log('🔄 Auth state change:', event);
          if (event === 'PASSWORD_RECOVERY') {
            setCurrentView('auth');
          } else if (event === 'SIGNED_IN') {
            setAuthUser(session?.user || null);
          } else if (event === 'SIGNED_OUT') {
            setAuthUser(null);
          }
        });

        return () => {
          authListener.subscription.unsubscribe();
        };
      } catch (error) {
        console.error('❌ Error in checkAuth:', error);
      }
    };
    checkAuth();
  }, []);

  useEffect(() => {
    const checkGroup = async () => {
      try {
        console.log('👥 Checking group...');
        const group = await golfService.getCurrentGroup();

        if (group) {
          console.log('✅ Group found:', group.group_code);
          const { getUserId } = await import('./utils/userId');
          const currentUserId = getUserId();
          const isCreator = group.group_code === 'DIVEND' || currentUserId === group.created_by;
          const limitedAccess = storageUtils.hasLimitedAccess();
          storageUtils.saveCurrentGroup(group.id, group.group_code, isCreator, limitedAccess);
          setIsGroupCreator(isCreator);
          setHasLimitedAccess(limitedAccess);
        } else {
          console.log('ℹ️ No group found');
        }

        setCurrentGroup(group);
      } catch (err) {
        console.error('❌ Error checking group:', err);
      } finally {
        console.log('✅ Group loading complete');
        setGroupLoading(false);
      }
    };
    checkGroup();
  }, []);

  useEffect(() => {
    const restoreActiveRound = async () => {
      if (groupLoading) return;

      const activeRoundId = storageUtils.getActiveRoundId();
      if (activeRoundId && !roundState.round) {
        try {
          setLoading(true);
          const roundData = await golfService.getRoundWithDetails(activeRoundId);
          if (roundData) {
            const { getUserId } = await import('./utils/userId');
            const currentUserId = getUserId();

            const isCreator = currentUserId === roundData.round.user_id;
            const storedCode = accessCodeStorage.getAccessCode(activeRoundId);
            const hasEditAccess = isCreator || storedCode === roundData.round.access_code;

            const course = await golfService.getCourse(roundData.round.course_id);

            setRoundState({
              round: roundData.round,
              holes: roundData.holes,
              players: roundData.players,
              scores: roundData.scores,
              currentHole: 1,
              isCreator,
              hasEditAccess,
              courseName: course?.name || '',
            });

            if (roundData.players.length === 0) {
              setCurrentView('players');
            } else {
              setCurrentView('scorecard');
            }
          }
        } catch (err) {
          console.error('Error restoring active round:', err);
          storageUtils.clearActiveRound();
        } finally {
          setLoading(false);
        }
      }
    };
    restoreActiveRound();
  }, [groupLoading]);

  useEffect(() => {
    if (!roundState.round || (currentView !== 'scorecard' && currentView !== 'leaderboard' && currentView !== 'players')) {
      return;
    }

    const scoresSubscription = golfService.subscribeToRoundScores(roundState.round.id, async () => {
      try {
        const scores = await golfService.getRoundScores(roundState.round!.id);
        setRoundState((prev) => ({
          ...prev,
          scores,
        }));
      } catch (err) {
        console.error('Error updating scores:', err);
      }
    });

    const playersSubscription = golfService.subscribeToRoundPlayers(roundState.round.id, async () => {
      try {
        const players = await golfService.getRoundPlayers(roundState.round!.id);
        setRoundState((prev) => ({
          ...prev,
          players,
        }));
      } catch (err) {
        console.error('Error updating players:', err);
      }
    });

    return () => {
      scoresSubscription.unsubscribe();
      playersSubscription.unsubscribe();
    };
  }, [roundState.round?.id, currentView]);

  const handleGroupCreated = async (group: Group) => {
    setCurrentGroup(group);
    setIsGroupCreator(true);
    setHasLimitedAccess(false);
    storageUtils.saveCurrentGroup(group.id, group.group_code, true, false);
  };

  const handleGroupJoined = async (group: Group) => {
    const { supabase } = await import('./services/supabaseClient');
    const { data: { user } } = await supabase.auth.getUser();

    let isCreator = false;
    if (user) {
      isCreator = group.group_code === 'DIVEND' || user.id === group.created_by;
    } else {
      const { getUserId } = await import('./utils/userId');
      const currentUserId = getUserId();
      isCreator = group.group_code === 'DIVEND' || currentUserId === group.created_by;
    }

    const limitedAccess = storageUtils.hasLimitedAccess();
    storageUtils.saveCurrentGroup(group.id, group.group_code, isCreator, limitedAccess);
    setCurrentGroup(group);
    setIsGroupCreator(isCreator);
    setHasLimitedAccess(limitedAccess);
    setCurrentView('main');
  };

  const handleLeaveGroup = () => {
    setShowLeaveGroupConfirm(true);
  };

  const handleConfirmLeaveGroup = () => {
    golfService.leaveGroup();
    setCurrentGroup(null);
    setIsGroupCreator(false);
    setHasLimitedAccess(false);
    setShowLeaveGroupConfirm(false);
    handleBackToMain();
  };

  const handleAdminLoginAttempt = () => {
    golfService.leaveGroup();
    setCurrentGroup(null);
    setIsGroupCreator(false);
    setHasLimitedAccess(false);
    setShowAdminPinModal(true);
    setAdminPinError('');
    setAdminPinAttempts(0);
  };

  const handleAdminPinSubmit = async (pin: string) => {
    try {
      const { supabase } = await import('./services/supabaseClient');
      const { data: config } = await supabase
        .from('admin_config')
        .select('admin_pin')
        .single();

      const correctPin = config?.admin_pin || import.meta.env.VITE_ADMIN_PIN;

      if (pin === correctPin) {
        setShowAdminPinModal(false);
        setAdminPinError('');
        setAdminPinAttempts(0);
        setCurrentView('admin-dashboard');
      } else {
        const newAttempts = adminPinAttempts + 1;
        setAdminPinAttempts(newAttempts);

        if (newAttempts >= 3) {
          setShowAdminPinModal(false);
          setAdminPinError('');
          setAdminPinAttempts(0);
          setCurrentView('my-groups');
        } else {
          setAdminPinError(`Código incorrecto. Intento ${newAttempts} de 3.`);
        }
      }
    } catch (err) {
      console.error('Error validating PIN:', err);
      setAdminPinError('Error al validar el PIN');
    }
  };

  const handleAdminPinCancel = () => {
    setShowAdminPinModal(false);
    setAdminPinError('');
    setAdminPinAttempts(0);
    setCurrentView('my-groups');
  };

  const handleCancelLeaveGroup = () => {
    setShowLeaveGroupConfirm(false);
  };

  const handleRoundCreated = async (roundId: string, courseId: string, numHoles: 9 | 18, useSlope: boolean) => {
    try {
      setLoading(true);
      const roundData = await golfService.getRoundWithDetails(roundId);
      if (roundData) {
        accessCodeStorage.saveAccessCode(roundId, roundData.round.access_code);

        const course = await golfService.getCourse(courseId);

        setRoundState({
          round: roundData.round,
          holes: roundData.holes,
          players: roundData.players,
          scores: roundData.scores,
          currentHole: 1,
          isCreator: true,
          hasEditAccess: true,
          courseName: course?.name || '',
        });
        setCurrentView('players');
      }
    } catch (err) {
      setError('Error creando partida');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleJoinRound = async (roundId: string) => {
    try {
      setLoading(true);
      const roundData = await golfService.getRoundWithDetails(roundId);
      if (roundData) {
        const { getUserId } = await import('./utils/userId');
        const currentUserId = getUserId();

        const isCreator = currentUserId === roundData.round.user_id;
        const storedCode = accessCodeStorage.getAccessCode(roundId);
        const hasEditAccess = isCreator || storedCode === roundData.round.access_code;

        const course = await golfService.getCourse(roundData.round.course_id);

        setRoundState({
          round: roundData.round,
          holes: roundData.holes,
          players: roundData.players,
          scores: roundData.scores,
          currentHole: 1,
          isCreator,
          hasEditAccess,
          courseName: course?.name || '',
        });

        storageUtils.saveActiveRound(roundId);

        if (roundData.players.length === 0) {
          setCurrentView('players');
        } else {
          setCurrentView('scorecard');
        }
      }
    } catch (err) {
      setError('Error cargando partida');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handlePlayersUpdated = (players: RoundPlayer[]) => {
    setRoundState((prev) => ({ ...prev, players }));
  };

  const handleStartRound = () => {
    if (currentGroup) {
      setCurrentView('main');
    } else {
      setCurrentView('scorecard');
    }
  };

  const handleHoleChange = (holeNumber: number) => {
    setRoundState((prev) => ({ ...prev, currentHole: holeNumber }));
  };

  const handleScoreChange = async (playerId: string, holeNumber: number, score: any) => {
    console.log('=== handleScoreChange llamado ===');
    console.log('playerId:', playerId);
    console.log('holeNumber:', holeNumber);
    console.log('score recibido:', score);

    if (!roundState.round) {
      console.log('No hay round activo');
      return;
    }

    try {
      if (score === null) {
        console.log('Eliminando score de la BD');
        await golfService.deleteScore(roundState.round.id, playerId, holeNumber);

        console.log('Score eliminado, actualizando estado local');
        setRoundState((prev) => ({
          ...prev,
          scores: prev.scores.filter((s) => !(s.player_id === playerId && s.hole_number === holeNumber)),
        }));

        console.log('Estado actualizado');
        return;
      }

      const grossStrokes = score.grossStrokes ?? score.gross_strokes;
      const strokesReceived = score.strokesReceived ?? score.strokes_received;
      const netStrokes = score.netStrokes ?? score.net_strokes;
      const stablefordPoints = score.stablefordPoints ?? score.stableford_points;
      const noPasoRojas = score.no_paso_rojas ?? false;
      const spanishHands = score.spanish_hands ?? false;
      const abandoned = score.abandoned ?? false;
      const modePoints = score.mode_points ?? 0;

      console.log('Grabando en BD:', {
        roundId: roundState.round.id,
        playerId,
        holeNumber,
        grossStrokes,
        strokesReceived,
        netStrokes,
        stablefordPoints,
        noPasoRojas,
        abandoned
      });

      await golfService.recordScore(
        roundState.round.id,
        playerId,
        holeNumber,
        grossStrokes,
        strokesReceived,
        netStrokes,
        stablefordPoints,
        noPasoRojas,
        spanishHands,
        abandoned,
        modePoints
      );

      const gameMode = (roundState.round.game_mode || 'stableford') as GameMode;
      const isModeScoring = gameMode !== 'stableford';

      const teamAssignments: Record<string, 0 | 1> | undefined = gameMode === 'parejas' && roundState.players.length === 4
        ? Object.fromEntries(roundState.players.map((p, i) => [p.id, i < 2 ? 0 as const : 1 as const]))
        : undefined;

      const otherScores = roundState.scores.filter(
        (s) => s.hole_number === holeNumber && s.player_id !== playerId
      );

      const updatedOtherScores: RoundScore[] = [];
      if (isModeScoring && otherScores.length > 0) {
        const allInputs: ModeScoreInput[] = roundState.players.map((p) => {
          if (p.id === playerId) {
            return {
              playerId: p.id,
              netStrokes: abandoned ? 999 : netStrokes,
              abandoned,
              entered: true,
            };
          }
          const existing = otherScores.find((s) => s.player_id === p.id);
          if (!existing) {
            return { playerId: p.id, netStrokes: 999, abandoned: true, entered: false };
          }
          return { playerId: p.id, netStrokes: existing.abandoned ? 999 : existing.net_strokes, abandoned: existing.abandoned, entered: true };
        });

        for (const existing of otherScores) {
          const newModePoints = calculateModePoints(gameMode, existing.player_id, allInputs, teamAssignments);
          if (newModePoints !== existing.mode_points) {
            await golfService.recordScore(
              roundState.round.id,
              existing.player_id,
              holeNumber,
              existing.gross_strokes,
              existing.strokes_received,
              existing.net_strokes,
              existing.stableford_points,
              existing.no_paso_rojas,
              existing.spanish_hands ?? false,
              existing.abandoned,
              newModePoints
            );
            updatedOtherScores.push({
              ...existing,
              mode_points: newModePoints,
              updated_at: new Date().toISOString(),
            });
          }
        }
      }

      setRoundState((prev) => ({
        ...prev,
        scores: [
          ...prev.scores.filter((s) => !(s.hole_number === holeNumber && s.player_id === playerId)),
          ...updatedOtherScores,
          {
            id: `score_${Date.now()}`,
            round_id: roundState.round!.id,
            player_id: playerId,
            hole_number: holeNumber,
            gross_strokes: grossStrokes,
            strokes_received: strokesReceived,
            net_strokes: netStrokes,
            stableford_points: stablefordPoints,
            no_paso_rojas: noPasoRojas,
            spanish_hands: spanishHands,
            abandoned: abandoned,
            mode_points: modePoints,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        ],
      }));
    } catch (err) {
      console.error('Error recording score:', err);
    }
  };

  const handleHolesUpdated = (updatedHoles: GolfHole[]) => {
    setRoundState((prev) => ({ ...prev, holes: updatedHoles }));
  };

  const handleHolesChanged = async (numHoles: 9 | 18, holes: GolfHole[]) => {
    console.log('🟢 APP: handleHolesChanged iniciado con numHoles:', numHoles);
    console.log('🟢 APP: Tiene round?', !!roundState.round);

    if (!roundState.round) {
      console.log('🔴 APP: No hay round, abortando');
      return;
    }

    const oldHandicaps = roundState.players.map(p => ({ name: p.name, handicap: p.playing_handicap }));
    console.log('🟢 APP: Handicaps ANTES:', oldHandicaps);

    try {
      await new Promise(resolve => setTimeout(resolve, 100));

      console.log('🟢 APP: Llamando getRoundPlayers...');
      const updatedPlayers = await golfService.getRoundPlayers(roundState.round.id);
      console.log('🟢 APP: updatedPlayers recibidos:', updatedPlayers.length);

      const newHandicaps = updatedPlayers.map(p => ({ name: p.name, handicap: p.playing_handicap }));
      console.log('🟢 APP: Handicaps DESPUÉS:', newHandicaps);

      console.log('🟢 APP: Actualizando roundState...');
      setRoundState((prev) => {
        const newState = {
          ...prev,
          holes,
          players: updatedPlayers,
          round: prev.round ? { ...prev.round, num_holes: numHoles } : null,
        };
        console.log('🟢 APP: Nuevo estado:', {
          numHoles: newState.round?.num_holes,
          holesLength: newState.holes.length
        });
        return newState;
      });
      console.log('✅ APP: roundState actualizado');
    } catch (error) {
      console.error('🔴 APP: Error reloading players:', error);
      setRoundState((prev) => ({
        ...prev,
        holes,
        round: prev.round ? { ...prev.round, num_holes: numHoles } : null,
      }));
    }
  };

  const handleCourseChanged = async (courseId: string, numHoles: 9 | 18, holes: GolfHole[], updatedPlayers?: RoundPlayer[]) => {
    if (!roundState.round) return;

    try {
      console.log('🔄 APP: handleCourseChanged - Using players:', !!updatedPlayers ? 'from changeCourse' : 'fetching from DB');

      // Use the players passed from changeCourse if available, otherwise fetch from DB
      const players = updatedPlayers || await golfService.getRoundPlayers(roundState.round.id);
      const updatedScores = await golfService.getRoundScores(roundState.round.id);
      const course = await golfService.getCourse(courseId);

      console.log('🔄 APP: Course changed - Updated players:', players.map(p => ({ name: p.name, exact18: p.exact_handicap_18, playing: p.playing_handicap })));
      console.log('🔄 APP: Course changed - New course:', course?.name, 'Holes:', numHoles);

      // Force React to recognize the change by creating new player objects
      const newPlayers = players.map(p => ({ ...p }));

      setRoundState((prev) => ({
        ...prev,
        holes,
        players: newPlayers,
        scores: updatedScores,
        round: prev.round ? {
          ...prev.round,
          course_id: courseId,
          num_holes: numHoles,
        } : null,
        course: course || prev.course,
        courseName: course?.name || prev.courseName,
      }));
    } catch (error) {
      console.error('Error reloading after course change:', error);
      setRoundState((prev) => ({
        ...prev,
        holes,
        round: prev.round ? {
          ...prev.round,
          course_id: courseId,
          num_holes: numHoles,
        } : null,
      }));
    }
  };

  const handleRequestAccess = (roundId: string) => {
    setPendingRoundId(roundId);
    setShowAccessCodeModal(true);
    setAccessCodeError('');
  };

  const handleAccessCodeSubmit = async (code: string) => {
    try {
      setLoading(true);
      setAccessCodeError('');

      if (pendingRoundId) {
        const isValid = await golfService.verifyAccessCode(pendingRoundId, code);

        if (isValid) {
          accessCodeStorage.saveAccessCode(pendingRoundId, code);
          setShowAccessCodeModal(false);
          setPendingRoundId(null);
          await handleJoinRound(pendingRoundId);
        } else {
          setAccessCodeError('Código de acceso incorrecto');
        }
      } else {
        const round = await golfService.getRoundByAccessCode(code, currentGroup?.id);

        if (round) {
          accessCodeStorage.saveAccessCode(round.id, code);
          setShowAccessCodeModal(false);
          await handleJoinRound(round.id);
        } else {
          setAccessCodeError('No se encontró una partida con ese código');
        }
      }
    } catch (err) {
      setAccessCodeError('Error verificando código');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleAccessCodeCancel = () => {
    setShowAccessCodeModal(false);
    setPendingRoundId(null);
    setAccessCodeError('');
  };

  const handleBackToMain = () => {
    storageUtils.clearActiveRound();
    setRoundState({
      round: null,
      holes: [],
      players: [],
      scores: [],
      currentHole: 1,
      isCreator: false,
      hasEditAccess: false,
      courseName: '',
    });
    if (currentGroup) {
      setCurrentView('main');
    } else {
      setCurrentView('setup');
    }
  };

  /*const handleFinishRound = async () => {
    if (!roundState.round) {
      return;
    }

    try {
      await golfService.updateRoundStatus(roundState.round.id, 'completed');

      const isQuickPlay = !roundState.round.group_id;

      handleBackToMain();
      if (!isQuickPlay) {
        setCurrentView('active-rounds');
      }
    } catch (err) {
      console.error('Error finishing round:', err);
      setError('Error al finalizar la partida');
    }
  };*/
const handleFinishRound = async () => {
    if (!roundState.round) {
      return;
    }
  
    try {
      setLoading(true);
      // 1. Guardamos como 'completed' o 'finished' en Supabase
      await golfService.updateRoundStatus(roundState.round.id, 'completed');
  
      // 2. Limpiamos la ronda activa en localStorage para romper el bucle al volver
      storageUtils.clearActiveRound();

      const isQuickPlay = !roundState.round.group_id;

      // 3. Redirigimos directamente a las estadísticas según el modo
      if (isQuickPlay) {
        setCurrentView('quickplay-statistics');
      } else if (currentGroup) {
        setCurrentView('statistics');
      } else {
        setCurrentView('setup');
      }
    } catch (err) {
      console.error('Error al finalizar la partida:', err);
      setError('Error al finalizar la partida');
    } finally {
      setLoading(false);
    }
  };
  
  const IncognitoWarning = () => (
    isIncognito ? (
      <div className="fixed top-0 left-0 right-0 z-50 bg-amber-500 text-white px-4 py-2 text-center text-sm font-medium shadow-lg">
        <div className="flex items-center justify-center gap-2">
          <AlertTriangle size={16} />
          <span>Modo incógnito: No recargues la página o perderás todos los datos</span>
        </div>
      </div>
    ) : null
  );

  if (groupLoading) {
    return (
      <>
        <IncognitoWarning />
        <div className={`min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 flex items-center justify-center ${isIncognito ? 'pt-10' : ''}`}>
          <div className="text-center">
            <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-green-600 mx-auto mb-4"></div>
            <p className="text-gray-600">Cargando...</p>
          </div>
        </div>
      </>
    );
  }

  if (currentView === 'auth') {
    return (
      <>
        <IncognitoWarning />
        <div className={isIncognito ? 'pt-10' : ''}>
          <Auth
            onAuthSuccess={() => setCurrentView('my-groups')}
            onAdminLoginAttempt={handleAdminLoginAttempt}
            onBack={() => setCurrentView('main')}
          />
          {showAdminPinModal && (
            <AdminPinModal
              onSubmit={handleAdminPinSubmit}
              onCancel={handleAdminPinCancel}
              error={adminPinError}
            />
          )}
        </div>
      </>
    );
  }

  if (currentView === 'my-groups') {
    return (
      <>
        <IncognitoWarning />
        <div className={isIncognito ? 'pt-10' : ''}>
          <MyGroups
            onBack={() => setCurrentView('main')}
            onGroupSelected={handleGroupJoined}
            onLogout={() => setCurrentView('main')}
          />
        </div>
      </>
    );
  }

  if (currentView === 'profile') {
    return (
      <>
        <IncognitoWarning />
        <div className={isIncognito ? 'pt-10' : ''}>
          <ProfileScreen
            authUser={authUser}
            onBack={() => setCurrentView('main')}
            onUserUpdated={(user) => setAuthUser(user)}
            onLogout={async () => {
              const { supabase } = await import('./services/supabaseClient');
              await supabase.auth.signOut();
              setAuthUser(null);
              setCurrentView('main');
            }}
          />
        </div>
      </>
    );
  }

  if (!currentGroup && currentView === 'main') {
    return (
      <>
        <IncognitoWarning />
        <div className={isIncognito ? 'pt-10' : ''}>
          <GroupSetup
            onGroupCreated={handleGroupCreated}
            onGroupJoined={handleGroupJoined}
            onQuickPlay={() => setCurrentView('setup')}
            onJoinQuickPlay={() => {
              setPendingRoundId(null);
              setShowAccessCodeModal(true);
              setAccessCodeError('');
            }}
            onShowAuth={() => setCurrentView('auth')}
            onJoinRound={handleJoinRound}
            authUser={authUser}
            onLogout={async () => {
              const { supabase } = await import('./services/supabaseClient');
              await supabase.auth.signOut();
              setAuthUser(null);
            }}
          />
          {showAccessCodeModal && (
            <AccessCodeModal
              onSubmit={handleAccessCodeSubmit}
              onCancel={handleAccessCodeCancel}
              error={accessCodeError}
              loading={loading}
            />
          )}
        </div>
      </>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-50 to-emerald-100">
      <IncognitoWarning />
      <div className={isIncognito ? 'pt-10' : ''}>
      {currentView === 'main' && currentGroup && (
        <RoundSetup
          onRoundCreated={handleRoundCreated}
          onViewActiveRounds={() => setCurrentView('active-rounds')}
          onViewGamePoints={() => setCurrentView('game-points')}
          onViewStatistics={() => setCurrentView('statistics')}
          onJoinWithCode={() => {
            setPendingRoundId(null);
            setShowAccessCodeModal(true);
            setAccessCodeError('');
          }}
          onLeaveGroup={handleLeaveGroup}
          currentGroup={currentGroup}
          isGroupCreator={isGroupCreator}
          hasLimitedAccess={hasLimitedAccess}
        />
      )}

      {currentView === 'setup' && !currentGroup && (
        <RoundSetup
          onRoundCreated={handleRoundCreated}
          onViewActiveRounds={() => setCurrentView('active-rounds')}
          onViewGamePoints={() => setCurrentView('game-points')}
          onViewStatistics={() => setCurrentView('quickplay-statistics')}
          onJoinWithCode={() => {
            setPendingRoundId(null);
            setShowAccessCodeModal(true);
            setAccessCodeError('');
          }}
          onLeaveGroup={() => {}}
          onBack={() => setCurrentView('main')}
          currentGroup={null}
        />
      )}

      {currentView === 'players' && roundState.round && (
        <>
          {showHoleConfig && (
            <HoleConfiguration
              holes={roundState.holes}
              onHolesUpdated={handleHolesUpdated}
              onClose={() => setShowHoleConfig(false)}
              editable={roundState.isCreator}
            />
          )}
          <PlayerSetup
            roundId={roundState.round.id}
            players={roundState.players}
            useSlope={roundState.round.use_slope}
            numHoles={roundState.round.num_holes}
            courseId={roundState.round.course_id}
            accessCode={roundState.round.access_code}
            hasEditAccess={roundState.hasEditAccess}
            currentGroup={currentGroup}
            gameMode={roundState.round.game_mode}
            onPlayersUpdated={handlePlayersUpdated}
            onStartRound={handleStartRound}
            onOpenHoleConfig={() => setShowHoleConfig(true)}
            onHolesChanged={handleHolesChanged}
            onBack={handleBackToMain}
            loading={loading}
          />
        </>
      )}

      {currentView === 'scorecard' && roundState.round && (
        <Scorecard
          holes={roundState.holes}
          players={roundState.players}
          rounds={roundState.players.map((player) => ({
            playerId: player.id,
            scores: Object.fromEntries(
              roundState.scores
                .filter((s) => s.player_id === player.id)
                .map((s) => [s.hole_number, s])
            ),
            totalStablefordPoints: roundState.scores
              .filter((s) => s.player_id === player.id)
              .reduce((sum, s) => sum + s.stableford_points, 0),
          }))}
          currentHole={roundState.currentHole}
          numHoles={roundState.round.num_holes}
          roundId={roundState.round.id}
          courseId={roundState.round.course_id}
          accessCode={roundState.round.access_code}
          hasEditAccess={roundState.hasEditAccess}
          courseName={roundState.courseName}
          groupCode={currentGroup?.group_code}
          gameMode={roundState.round.game_mode}
          onHoleChange={handleHoleChange}
          onScoreChange={handleScoreChange}
          onShowLeaderboard={() => setCurrentView('leaderboard')}
          onResetGame={handleBackToMain}
          onFinishRound={handleFinishRound}
          onCourseChanged={handleCourseChanged}
        />
      )}

      {currentView === 'leaderboard' && roundState.round && (
        <Leaderboard
          players={roundState.players}
          rounds={roundState.players.map((player) => ({
            playerId: player.id,
            scores: Object.fromEntries(
              roundState.scores
                .filter((s) => s.player_id === player.id)
                .map((s) => [s.hole_number, s])
            ),
            totalStablefordPoints: roundState.scores
              .filter((s) => s.player_id === player.id)
              .reduce((sum, s) => sum + s.stableford_points, 0),
          }))}
          currentHole={roundState.currentHole}
          onBack={() => setCurrentView('scorecard')}
          hasGroup={!!currentGroup}
          gameMode={roundState.round.game_mode}
        />
      )}

      {currentView === 'active-rounds' && (
        <ActiveRoundsViewer
          onBack={() => setCurrentView(currentGroup ? 'main' : 'setup')}
          onJoinRound={handleJoinRound}
          currentGroup={currentGroup}
        />
      )}

      {currentView === 'game-points' && (
        <GamePoints onBack={() => setCurrentView('main')} />
      )}

      {currentView === 'statistics' && currentGroup && (
        <Statistics
          onBack={() => setCurrentView('main')}
          currentGroup={currentGroup}
        />
      )}

      {currentView === 'quickplay-statistics' && !currentGroup && (
        <QuickPlayStatistics
          roundId={roundState.round?.id}
          onBack={() => setCurrentView('setup')}
          //onBack={handleBackToMain}
        />
      )}

      {currentView === 'admin-dashboard' && (
        <AdminDashboard
          onBack={() => setCurrentView('main')}
        />
      )}

      {showAccessCodeModal && (
        <AccessCodeModal
          onSubmit={handleAccessCodeSubmit}
          onCancel={handleAccessCodeCancel}
          error={accessCodeError}
          loading={loading}
        />
      )}

      {showLeaveGroupConfirm && (
        <ConfirmModal
          message="¿Seguro que deseas salir del grupo? Tendrás que volver a unirte con el código del grupo."
          onConfirm={handleConfirmLeaveGroup}
          onCancel={handleCancelLeaveGroup}
        />
      )}

      {currentView === 'viewer' && roundState.round && !roundState.isCreator && (
        <div className="min-h-screen bg-gradient-to-b from-emerald-900 to-emerald-800 p-4 md:p-8">
          <div className="max-w-2xl mx-auto">
            <div className="bg-white rounded-lg shadow-2xl p-6 md:p-8 text-center">
              <h1 className="text-3xl font-bold text-emerald-900 mb-4">Observando Partida</h1>
              <p className="text-gray-600 mb-6">
                Estás viendo esta partida como observador. Solo el creador puede editar puntuaciones.
              </p>
              <Leaderboard
                players={roundState.players}
                rounds={roundState.players.map((player) => ({
                  playerId: player.id,
                  scores: Object.fromEntries(
                    roundState.scores
                      .filter((s) => s.player_id === player.id)
                      .map((s) => [s.hole_number, s])
                  ),
                  totalStablefordPoints: roundState.scores
                    .filter((s) => s.player_id === player.id)
                    .reduce((sum, s) => sum + s.stableford_points, 0),
                }))}
                currentHole={roundState.currentHole}
                onBack={handleBackToMain}
                hasGroup={!!currentGroup}
                gameMode={roundState.round.game_mode}
              />
            </div>
          </div>
        </div>
      )}
      </div>
    </div>
  );
}

export default App;
