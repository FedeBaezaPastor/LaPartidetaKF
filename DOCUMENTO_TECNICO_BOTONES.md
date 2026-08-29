# Documento Tecnico: Mapa de Interacciones de Botones — La Partideta Golf

## Resumen

- **Archivos analizados:** 27
- **Botones documentados:** ~140+
- **App.tsx** no tiene elementos `<button>` directos — es un router que renderiza componentes hijos y pasa callbacks.

---

## 1. App.tsx (Router Raiz)

No hay elementos `<button>` directamente en el JSX. App.tsx renderiza componentes hijos y pasa handlers. Funciones handler clave:

| Handler | Line | Comportamiento |
|---|---|---|
| `handleAdminLoginAttempt` | 268 | Llama `golfService.leaveGroup()`, limpia estado del grupo, abre `AdminPinModal` |
| `handleAdminPinSubmit` | 278 | Consulta tabla `admin_config`, compara PIN, navega a `admin-dashboard` o `my-groups` |
| `handleConfirmLeaveGroup` | 259 | `golfService.leaveGroup()`, limpia estado, `handleBackToMain()` |
| `handleRoundCreated` | 323 | `golfService.getRoundWithDetails()`, guarda codigo de acceso, navega a `players` |
| `handleJoinRound` | 352 | `golfService.getRoundWithDetails()`, guarda ronda activa, navega a `players` o `scorecard` |
| `handleFinishRound` | 656 | `golfService.updateRoundStatus('completed')`, limpia estado, navega a `setup` o `active-rounds` |
| `handleAccessCodeSubmit` | 596 | `golfService.verifyAccessCode()` o `getRoundByAccessCode()`, luego `handleJoinRound()` |

---

## 2. GroupSetup.tsx

### Modo: `choose`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| GroupSetup - choose | "Crear Partideta Rapida" (Zap) | `onQuickPlay` -> App: `setCurrentView('setup')` | 191 | Navega a RoundSetup (Quick Play) |
| GroupSetup - choose | "Unirse a Partideta Rapida" (LogIn) | `onJoinQuickPlay` -> App: `setShowAccessCodeModal(true)` | 199 | Abre AccessCodeModal |
| GroupSetup - choose | "Crear Multipartideta" (Plus) | `() => setMode('create')` | 207 | Cambia estado a modo create |
| GroupSetup - choose | "Unirse a Multipartideta" (LogIn) | `() => setMode('join')` | 215 | Cambia estado a modo join |
| GroupSetup - choose | "Iniciar Sesion / Crear Cuenta" | `onShowAuth` -> App: `setCurrentView('auth')` | 233 | Navega a pantalla Auth |

### Modo: `create`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| GroupSetup - create | "Generar otro codigo" (RefreshCw) | `handleGenerateNewCode` -> `setAutoCode(generateRandomCode())` | 289 | Cambio de estado: nuevo codigo aleatorio |
| GroupSetup - create | Eye/eyeOff toggle (password) | `() => setShowPassword(!showPassword)` | 376 | Cambio de estado: mostrar/ocultar password |
| GroupSetup - create | Eye/eyeOff toggle (confirm) | `() => setShowConfirmPassword(!showConfirmPassword)` | 399 | Cambio de estado: mostrar/ocultar confirm |
| GroupSetup - create | "inicia sesion aqui" (link) | `onShowAuth` -> App: `setCurrentView('auth')` | 411 | Navega a Auth |
| GroupSetup - create | "Atras" | `() => setMode('choose')` | 430 | Cambia estado a modo choose |
| GroupSetup - create | "Crear Grupo" / "Creando..." | `handleCreateGroup` -> `supabase.auth.signUp()` + `golfService.createGroup()` | 437 | API call (auth + create group) -> `onGroupCreated` callback |

### Modo: `join`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| GroupSetup - join | "Atras" | `() => setMode('choose')` | 492 | Cambia estado a modo choose |
| GroupSetup - join | "Unirse" / "Uniendose..." | `handleJoinGroup` -> `golfService.joinGroup()` or `getRoundByAccessCode()` | 499 | API call -> `onGroupJoined` callback |

---

## 3. RoundSetup.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| RoundSetup | "Atras" (ArrowLeft) | `onBack` -> App: `setCurrentView('main')` | 246 | Navega a main (solo si `!currentGroup && onBack`) |
| RoundSetup | "Salir" (LogOut) | `onLeaveGroup` -> App: `handleLeaveGroup` -> `setShowLeaveGroupConfirm(true)` | 272 | Abre ConfirmModal (salir del grupo) |
| RoundSetup | Copy/Check (copiar codigo) | `handleCopyGroupCode` -> `navigator.clipboard.writeText()` | 290 | Copia codigo al portapapeles |
| RoundSetup | "Introducir Codigo" (div clickeable) | div padre (L307) llama `onJoinWithCode` -> App: abre AccessCodeModal | 314 | Abre AccessCodeModal |
| RoundSetup | "Salir del grupo" (limited access) | `onLeaveGroup` -> App: `handleLeaveGroup` | 323 | Abre ConfirmModal |
| RoundSetup | "9 Hoyos" | `() => handleNumHolesChange(9)` -> setNumHoles(9) or abre HolesRangeModal | 371 | Cambio de estado o abre HolesRangeModal |
| RoundSetup | "18 Hoyos" | `() => handleNumHolesChange(18)` -> `setNumHoles(18)` | 381 | Cambio de estado |
| RoundSetup | "Con Slope" | `() => setUseSlope(true)` | 399 | Cambio de estado |
| RoundSetup | "Sin Slope" | `() => setUseSlope(false)` | 409 | Cambio de estado |
| RoundSetup | Tee button (por cada tee) | `() => setSelectedTeeId(tee.id)` | 429 | Cambio de estado: selecciona tee |
| RoundSetup | "Crear Partida" (ChevronRight) | `handleCreateRound` -> check admin PIN -> `proceedWithRoundCreation()` -> `golfService.createRound()` | 449 | API call -> `onRoundCreated`. Puede abrir AdminPinModal si DIVEND |
| RoundSetup | "Ver Partida" (div clickeable) | div padre (L465) llama `onViewActiveRounds` -> App: `setCurrentView('active-rounds')` | 483 | Navega a ActiveRoundsViewer |
| RoundSetup | "Ver Estadisticas" (Quick Play, div) | div padre (L492) llama `onViewStatistics` condicional | 506 | Navega a QuickPlayStatistics |
| RoundSetup | "Ver Puntos" (div clickeable) | div padre (L518) llama `onViewGamePoints` -> App: `setCurrentView('game-points')` | 526 | Navega a GamePoints |
| RoundSetup | "Ver Estadisticas" (grupo, div) | div padre (L535) llama `onViewStatistics` -> App: `setCurrentView('statistics')` | 543 | Navega a Statistics |

---

## 4. PlayerSetup.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| PlayerSetup | "Menu Principal" (ArrowLeft) | `onBack` -> App: `handleBackToMain` | 408 | Limpia estado, navega a main/setup |
| PlayerSetup | Eye/eyeOff (mostrar codigo acceso) | `() => setShowCode(!showCode)` | 435 | Cambio de estado: mostrar/ocultar codigo |
| PlayerSetup | Jugador existente (dropdown) | `() => handleSelectPlayer(player)` -> setea jugador, nombre, handicap | 492 | Cambio de estado: selecciona jugador |
| PlayerSetup | Edit2 (editar nombre jugador) | `(e) => handleEditPlayerClick(player, e)` -> `setShowEditPlayerModal(true)` | 502 | Abre EditPlayerNameModal |
| PlayerSetup | "Crear: {searchTerm}" (nuevo jugador) | `() => setShowDropdown(false)` | 520 | Cambio de estado: cierra dropdown |
| PlayerSetup | "Editar" (slope) | `handleEditSlope` -> `setEditingSlope(true)` | 570 | Cambio de estado: modo edicion slope |
| PlayerSetup | "Restablecer" (slope manual) | `handleResetSlope` -> `golfService.updateRoundSlope(roundId, null)` | 579 | API call: resetea slope a automatico |
| PlayerSetup | "Guardar" (slope) | `handleSaveSlope` -> `golfService.updateRoundSlope(roundId, newSlope)` | 602 | API call: guarda slope manual |
| PlayerSetup | "Cancelar" (slope) | `handleCancelEditSlope` -> `setEditingSlope(false)` | 609 | Cambio de estado: cancela edicion |
| PlayerSetup | "Anadir Jugador" / "Crear y Anadir" (submit) | `handleAddPlayer` -> `golfService.getOrCreatePlayer()` + `addPlayerToRound()` | 632 | API call -> `onPlayersUpdated` callback |
| PlayerSetup | Trash2 (eliminar jugador de ronda) | `() => handleRemovePlayer(player.id)` -> `golfService.removePlayerFromRound()` | 667 | API call -> `onPlayersUpdated` callback |
| PlayerSetup | "Configurar Hoyos" (Settings) | `handleOpenHoleConfigClick` -> `setShowAdminPinModal(true)` | 682 | Abre AdminPinModal (verificacion PIN) |
| PlayerSetup | "Guardar y Volver" / "Comenzar Partida" | `onStartRound` -> App: `handleStartRound` -> `setCurrentView('main')` or `setCurrentView('scorecard')` | 691 | Navega a scorecard o main |

---

## 5. Scorecard.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Scorecard | Home icon (volver menu) | `onResetGame` -> App: `handleBackToMain` | 130 | Limpia round, navega a main/setup |
| Scorecard | "Clasificacion" (Trophy) | `onShowLeaderboard` -> App: `setCurrentView('leaderboard')` | 140 | Navega a Leaderboard |
| Scorecard | "Cambiar" (MapPin, cambiar campo) | `() => setShowCourseChangeModal(true)` | 155 | Abre CourseChangeModal |
| Scorecard | Eye/eyeOff (mostrar codigo) | `() => setShowAccessCode(!showAccessCode)` | 185 | Cambio de estado |
| Scorecard | "Anterior" (ChevronLeft) | `() => onHoleChange(Math.max(1, currentHole - 1))` -> App: `handleHoleChange` | 254 | Cambio de estado: hoyo anterior |
| Scorecard | "Finalizar Partida" (Trophy) | `handleFinishWithConfirm` -> `setShowFinishModal(true)` | 264 | Abre ConfirmModal (finalizar) |
| Scorecard | "Siguiente" (ChevronRight) | `() => onHoleChange(Math.min(playableHoles.length, currentHole + 1))` | 272 | Cambio de estado: hoyo siguiente |

---

## 6. HoleCard.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| HoleCard | Player row (toggle expand) | `() => handleToggleExpanded(player.id, isExpanded)` | 184 | Cambio de estado: expande/colapsa panel. Si hay "1" pendiente, abre HoleInOneModal |
| HoleCard | Number 1-9 (grid de golpes) | `() => handleNumberClick(player.id, num, player)` -> `calculateScore()` + `onScoreChange()` | 236 | API call (via parent): registra score |
| HoleCard | "10" | Inline: `calculateScore(10, ...)` + `onScoreChange()` | 250 | API call: registra score de 10 |
| HoleCard | Minus icon (abandonado/max) | Inline: si QuickPlay -> `onScoreChange({abandoned:true})`, sino -> `calculateScore(maxStrokes)` + `onScoreChange({stableford_points:0})` | 276 | API call: marca abandonado o maximo |
| HoleCard | Trash2 (eliminar score) | Inline: `onScoreChange(player.id, null)` | 315 | API call (via parent): elimina score |
| HoleCard | "Marcar: No paso de rojas" / "check No paso de rojas" | Inline: toggle `no_paso_rojas` -> `onScoreChange()` con flag | 359 | API call: toggle no_paso_rojas (solo DIVEND) |

---

## 7. Leaderboard.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Leaderboard | "Mi Partida" | `() => setShowAllRounds(false)` | 117 | Cambio de estado: vista mi partida |
| Leaderboard | "Todas las Partidas (N)" | Inline: `setShowAllRounds(true)` + `loadAllActiveRounds()` | 127 | Cambio de estado + API call: `golfService.getActiveRounds()` + detalles |
| Leaderboard | "Actualizar" (RefreshCw) | `loadAllActiveRounds` -> `golfService.getActiveRounds()` + `getRoundPlayers()` + `getRoundScores()` | 242 | API call: refresca partidas activas |
| Leaderboard | "Volver a la Tarjeta" (ArrowLeft) | `onBack` -> App: `setCurrentView('scorecard')` | 332 | Navega a Scorecard |

---

## 8. ActiveRoundsViewer.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| ActiveRoundsViewer - Global LB | "Atras" (ArrowLeft) | `() => setShowGlobalLeaderboard(false)` | 406 | Cambio de estado: vuelve a lista |
| ActiveRoundsViewer - List | "Atras" (ArrowLeft) | `onBack` -> App: `setCurrentView(currentGroup ? 'main' : 'setup')` | 498 | Navega a main o setup |
| ActiveRoundsViewer - List | "Clasificacion" (Trophy) | `() => setShowGlobalLeaderboard(true)` | 509 | Cambio de estado: muestra leaderboard global |
| ActiveRoundsViewer - List | "Eliminar Todas" / "Eliminar" (Trash2) | `handleDeleteAllRounds` -> check DIVEND/permisos -> abre ConfirmModal or AdminPinModal | 519 | Abre ConfirmModal o AdminPinModal |
| ActiveRoundsViewer - Round card | Round header (expand/collapse) | `() => setSelectedRound(isExpanded ? null : roundStats.round.id)` | 577 | Cambio de estado: expande/colapsa tarjeta |
| ActiveRoundsViewer - Completed | Archive/Trash (compacto) | `(e) => { e.stopPropagation(); handleDeleteRound(roundStats.round.id); }` | 599 | Abre DeleteRoundModal o AdminPinModal |
| ActiveRoundsViewer - Expanded | UserX (eliminar jugador) | `(e) => { e.stopPropagation(); handleDeletePlayerClick(item.player.id, item.player.name); }` | 674 | Abre modal eliminar jugador o AdminPinModal |
| ActiveRoundsViewer - Expanded | "Ver Partida" / "Comenzar" / "Ver Resultados" | `() => { onJoinRound(roundStats.round.id); setSelectedRound(null); }` -> App: `handleJoinRound` | 691 | API call + navega a scorecard/players |
| ActiveRoundsViewer - Expanded | "Anadir" (UserPlus) | `(e) => { e.stopPropagation(); handleAddPlayerClick(roundStats.round.id); }` -> `golfService.getAllPlayers()` | 706 | API call + abre modal Anadir Jugador |
| ActiveRoundsViewer - Expanded | Trash2 "-" (eliminar partida) | `(e) => { e.stopPropagation(); handleDeleteRound(roundStats.round.id); }` | 718 | Abre DeleteRoundModal o AdminPinModal |
| ActiveRoundsViewer - Completed | "Ver Resultados Completos" | `() => { onJoinRound(roundStats.round.id); setSelectedRound(null); }` | 779 | API call + navega a scorecard |
| ActiveRoundsViewer - Modal | "Cancelar" (eliminar jugador) | `handleCancelDeletePlayer` -> `setPlayerToDelete(null)` | 871 | Cambio de estado: cierra modal |
| ActiveRoundsViewer - Modal | "Eliminar" (confirmar) | `handleConfirmDeletePlayer` -> `golfService.removePlayerFromRound()` | 877 | API call + refresh |
| ActiveRoundsViewer - Modal | "Cancelar" (anadir jugador) | `() => setShowAddPlayerModal(null)` | 951 | Cambio de estado: cierra modal |
| ActiveRoundsViewer - Modal | "Anadir" (confirmar) | `handleConfirmAddPlayer` -> `golfService.getOrCreatePlayer()` / `addPlayerToRound()` | 957 | API call + refresh |

---

## 9. GamePoints.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| GamePoints | "Volver" (ArrowLeft) | `onBack` -> App: `setCurrentView('main')` | 299 | Navega a main |
| GamePoints | "Historico de Handicaps" (toggle) | `() => setShowHandicapHistory(!showHandicapHistory)` | 457 | Cambio de estado: expande/colapsa historico |
| GamePoints | "Jugadores Registrados (N)" (toggle) | `() => setShowPlayers(!showPlayers)` | 572 | Cambio de estado: expande/colapsa jugadores |
| GamePoints | User icon (editar nombre) | `() => handleEditNameClick(player)` -> `setShowPinModal(true)` | 614 | Abre AdminPinModal -> luego EditPlayerNameModal |
| GamePoints | UserX (eliminar jugador) | `() => handleDeletePlayerClick(player)` -> `setShowPinModal(true)` | 622 | Abre AdminPinModal -> luego modal confirmacion |
| GamePoints | Save (guardar handicap) | `() => handleSaveHandicap(player.id)` -> `golfService.updatePlayerHandicap()` | 643 | API call + refresh |
| GamePoints | X (cancelar edicion handicap) | `handleCancelEditHandicap` -> `setEditingPlayerId(null)` | 650 | Cambio de estado |
| GamePoints | Edit2 (editar handicap) | `() => handleEditHandicapClick(player)` -> `setShowPinModal(true)` | 663 | Abre AdminPinModal -> entra modo edicion |
| GamePoints - Modal | "Cancelar" (eliminar jugador) | `handleCancelDeletePlayer` -> `setPlayerToDelete(null)` | 722 | Cambio de estado: cierra modal |
| GamePoints - Modal | "Eliminar" (confirmar) | `handleConfirmDeletePlayer` -> `golfService.deletePlayer()` | 728 | API call + refresh |

---

## 10. Statistics.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Statistics - Empty | ArrowLeft (volver) | `onBack` -> App: `setCurrentView('main')` | 432 | Navega a main |
| Statistics - Main | ArrowLeft (volver) | `onBack` -> App: `setCurrentView('main')` | 455 | Navega a main |
| Statistics | "Jugador" (tab) | `() => setActiveTab('player')` | 474 | Cambio de estado: tab jugador |
| Statistics | "Grupo" (tab) | `() => setActiveTab('group')` | 486 | Cambio de estado: tab grupo |
| Statistics | "Campo" (tab) | `() => setActiveTab('course')` | 498 | Cambio de estado: tab campo |
| Statistics - Group | "N partidas archivadas" (boton) | `() => setShowArchivedRoundsModal(true)` | 692 | Abre ArchivedRoundsModal |
| Statistics - Group | ChevronRight "Patrocinador" | `() => openRankingModal('patrocinador')` -> `golfService.getPatrocinadorRanking()` | 714 | API call + abre AwardRankingModal |
| Statistics - Group | ChevronRight "Barra Libre" | `() => openRankingModal('barraLibre')` -> `golfService.getBarraLibreRanking()` | 735 | API call + abre AwardRankingModal |
| Statistics - Group | ChevronRight "Corto" | `() => openRankingModal('corto')` -> `golfService.getCortoRanking()` | 756 | API call + abre AwardRankingModal |
| Statistics - Group | ChevronRight "Driver de Oro" | `() => openRankingModal('driverOro')` -> `golfService.getDriverOroRanking()` | 777 | API call + abre AwardRankingModal |
| Statistics - Group | ChevronRight "Shark" | `() => openRankingModal('shark')` -> usa `phase2Stats.sharkRanking` | 834 | Abre AwardRankingModal (datos cacheados) |
| Statistics - Group | ChevronRight "Viciado" | `() => openRankingModal('viciado')` -> usa `phase2Stats.viciadoRanking` | 856 | Abre AwardRankingModal |
| Statistics - Group | ChevronRight "Francotirador" | `() => openRankingModal('francotirador')` -> usa `phase2Stats.francotiradorRanking` | 878 | Abre AwardRankingModal |
| Statistics - Group | ChevronRight "Maquina" | `() => openRankingModal('maquina')` -> usa `phase2Stats.maquinaRanking` | 900 | Abre AwardRankingModal |
| Statistics - Group | ChevronRight "Amigo del +1" | `() => openRankingModal('amigoDelMasUno')` -> usa `phase2Stats.amigoDelMasUnoRanking` | 922 | Abre AwardRankingModal |
| Statistics - Group | ChevronRight "Rey del Bosque" | `() => openRankingModal('reyDelBosque')` -> usa `phase2Stats.reyDelBosqueRanking` | 944 | Abre AwardRankingModal |

---

## 11. QuickPlayStatistics.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| QuickPlayStats - No data | ArrowLeft (volver) | `onBack` -> App: `setCurrentView('setup')` | 156 | Navega a setup |
| QuickPlayStats - Main | "Volver" (ArrowLeft) | `onBack` -> App: `setCurrentView('setup')` | 196 | Navega a setup |
| QuickPlayStats - Main | "Eliminar" (Trash2) | `() => setShowDeleteConfirm(true)` | 215 | Abre ConfirmModal (eliminar partida) |

---

## 12. AdminDashboard.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| AdminDashboard | "Volver" (ArrowLeft) | `onBack` -> App: `setCurrentView('main')` | 433 | Navega a main |
| AdminDashboard | "Estadisticas" (tab) | `() => setActiveTab('stats')` | 452 | Cambio de estado: tab stats |
| AdminDashboard | "Configuracion" (tab) | `() => setActiveTab('config')` | 465 | Cambio de estado: tab config |
| AdminDashboard - Config | "Actualizar Correo" (Save) | `handleChangeEmail` -> `supabase.auth.updateUser({email})` + DB update | 510 | API call: actualiza email admin |
| AdminDashboard - Config | Eye/eyeOff (password) | `() => setShowPassword(!showPassword)` | 531 | Cambio de estado |
| AdminDashboard - Config | "Actualizar Contrasena" (Save) | `handleChangePassword` -> `supabase.auth.updateUser({password})` | 545 | API call: actualiza password |
| AdminDashboard - Config | "Mostrar PIN" / "Ocultar PIN" | `() => setShowPin(!showPin)` | 558 | Cambio de estado |
| AdminDashboard - Config | "Actualizar PIN" (Save) | `handleChangePin` -> `supabase.from('admin_config').update()` | 581 | API call: actualiza PIN en BD |

---

## 13. Auth.tsx

### Modo: `login`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Auth - login | "Volver" (ArrowLeft) | `onBack` -> App: `setCurrentView('main')` | 169 | Navega a main |
| Auth - login | Eye/eyeOff (password) | `() => setShowPassword(!showPassword)` | 217 | Cambio de estado |
| Auth - login | "Iniciar Sesion" (submit) | `handleLogin` -> `supabase.auth.signInWithPassword()` | 234 | API call -> `onAuthSuccess` o `onAdminLoginAttempt` |
| Auth - login | "Olvidaste tu contrasena?" | `() => setMode('forgot-password')` | 243 | Cambio de estado: modo forgot-password |
| Auth - login | "Registrate" | `() => setMode('register')` | 252 | Cambio de estado: modo register |

### Modo: `register`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Auth - register | "Volver al inicio de sesion" | `() => setMode('login')` | 271 | Cambio de estado: modo login |
| Auth - register | Eye/eyeOff (password) | `() => setShowPassword(!showPassword)` | 319 | Cambio de estado |
| Auth - register | Eye/eyeOff (confirm) | `() => setShowConfirmPassword(!showConfirmPassword)` | 343 | Cambio de estado |
| Auth - register | "Crear Cuenta" (submit) | `handleRegister` -> `supabase.auth.signUp()` + `golfService.linkGroupsToAuthUser()` | 366 | API call -> `onAuthSuccess` (con delay 1.5s) |
| Auth - register | "Inicia sesion" | `() => setMode('login')` | 377 | Cambio de estado: modo login |

### Modo: `reset-password`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Auth - reset | Eye/eyeOff (password) | `() => setShowPassword(!showPassword)` | 417 | Cambio de estado |
| Auth - reset | Eye/eyeOff (confirm) | `() => setShowConfirmPassword(!showConfirmPassword)` | 441 | Cambio de estado |
| Auth - reset | "Actualizar Contrasena" (submit) | `handleResetPassword` -> `supabase.auth.updateUser({password})` | 464 | API call -> vuelve a modo login (2s delay) |

### Modo: `forgot-password`

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| Auth - forgot | "Volver al inicio de sesion" | `() => setMode('login')` | 480 | Cambio de estado: modo login |
| Auth - forgot | "Enviar Enlace de Recuperacion" | `handleForgotPassword` -> `supabase.auth.resetPasswordForEmail()` | 527 | API call: envia email de recuperacion |

---

## 14. MyGroups.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| MyGroups | "Volver" (ArrowLeft) | `onBack` -> App: `setCurrentView('main')` | 127 | Navega a main |
| MyGroups | "Cerrar Sesion" (LogOut) | `handleLogout` -> `supabase.auth.signOut()` + `onLogout()` | 133 | API call -> navega a main |
| MyGroups - Empty | "Crear tu primer grupo" | `onBack` -> App: `setCurrentView('main')` | 159 | Navega a main |
| MyGroups - Card | Trash2 (eliminar grupo) | `() => handleDeleteGroup(group.id)` -> `setGroupToDelete(groupId)` | 175 | Abre ConfirmModal (eliminar grupo) |
| MyGroups - Card | "Copiar" / "Copiado" (Copy/Check) | `() => handleCopyCode(group.group_code)` -> `navigator.clipboard.writeText()` | 191 | Copia codigo al portapapeles |
| MyGroups - Card | "Seleccionar Grupo" | `() => handleSelectGroup(group)` -> `onGroupSelected(group)` -> App: `handleGroupJoined` | 210 | Navega a main con grupo seleccionado |

---

## 15. AccessCodeModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| AccessCodeModal | X (cerrar) | `onCancel` -> App: `handleAccessCodeCancel` -> cierra modal | 45 | Cierra modal |
| AccessCodeModal | "Cancelar" | `onCancel` -> App: `handleAccessCodeCancel` | 84 | Cierra modal |
| AccessCodeModal | "Acceder" / "Verificando..." (submit) | `handleSubmit` -> `onSubmit(code)` -> App: `handleAccessCodeSubmit` -> `golfService.verifyAccessCode()` / `getRoundByAccessCode()` | 92 | API call -> `handleJoinRound()` o muestra error |

---

## 16. AdminPinModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| AdminPinModal | X (cerrar) | `onCancel` -> Parent: cierra modal | 43 | Cierra modal |
| AdminPinModal | "Cancelar" | `onCancel` -> Parent: cierra modal | 82 | Cierra modal |
| AdminPinModal | "Verificar" (submit) | `handleSubmit` -> `onSubmit(pin)` -> Parent: `adminPinUtils.verifyPin(pin)` | 89 | Verifica PIN -> ejecuta accion pendiente o muestra error |

---

## 17. ConfirmModal.tsx (Generico - reutilizado en toda la app)

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| ConfirmModal | "Cancelar" | `handleCancel` -> `onCancel()` -> Parent handler | 52 | Ejecuta callback de cancelacion del parent |
| ConfirmModal | "Aceptar" | `handleConfirm` -> `onConfirm()` -> Parent handler | 59 | Ejecuta callback de confirmacion del parent |

**Usado por:** App.tsx (salir grupo, finalizar ronda), Scorecard (finalizar ronda), ActiveRoundsViewer (eliminar todas), QuickPlayStatistics (eliminar ronda), MyGroups (eliminar grupo).

---

## 18. HolesRangeModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| HolesRangeModal | X (cerrar) | `onCancel` -> Parent: `handleHolesRangeCancel` | 21 | Cierra modal |
| HolesRangeModal | "Hoyos 1-9 (Front Nine)" | `() => setSelectedRange('1-9')` | 34 | Cambio de estado: selecciona 1-9 |
| HolesRangeModal | "Hoyos 10-18 (Back Nine)" | `() => setSelectedRange('10-18')` | 44 | Cambio de estado: selecciona 10-18 |
| HolesRangeModal | "Cancelar" | `onCancel` -> Parent: `handleHolesRangeCancel` | 57 | Cierra modal |
| HolesRangeModal | "Confirmar" | `handleConfirm` -> `onConfirm(selectedRange)` -> Parent: `handleHolesRangeConfirm` | 63 | Cambio de estado: setea holesRange + numHoles |

---

## 19. CourseChangeModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| CourseChangeModal | X (cerrar) | `onClose` -> Parent: `setShowCourseChangeModal(false)` | 55 | Cierra modal |
| CourseChangeModal | Course item (por cada campo) | `() => !isCurrentCourse && onSelectCourse(course)` -> Parent: `handleSelectCourse` | 80 | Cierra este modal + abre CourseChangeConfirmModal |
| CourseChangeModal | "Cancelar" | `onClose` -> Parent: `setShowCourseChangeModal(false)` | 104 | Cierra modal |

---

## 20. CourseChangeConfirmModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| CourseChangeConfirm | "9 Hoyos" | `() => setSelectedHoles(9)` | 56 | Cambio de estado |
| CourseChangeConfirm | "18 Hoyos" | `() => setSelectedHoles(18)` | 66 | Cambio de estado |
| CourseChangeConfirm | "Cancelar" | `onCancel` -> Parent: cierra modal + limpia selectedCourse | 80 | Cierra modal |
| CourseChangeConfirm | "Confirmar Cambio" | `() => onConfirm(selectedHoles)` -> Parent: `handleConfirmCourseChange` -> `golfService.changeCourse()` | 86 | API call -> `onCourseChanged` callback |

---

## 21. HoleConfiguration.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| HoleConfiguration | ChevronDown (par -1, por hoyo) | `() => handleParChange(hole.id, -1)` -> `setEditingPars` | 133 | Cambio de estado: decrementa par |
| HoleConfiguration | ChevronUp (par +1, por hoyo) | `() => handleParChange(hole.id, 1)` -> `setEditingPars` | 154 | Cambio de estado: incrementa par |
| HoleConfiguration | ChevronDown (stroke index -1) | `() => handleStrokeIndexChange(hole.id, -1)` -> `setEditingHoles` | 176 | Cambio de estado: decrementa SI |
| HoleConfiguration | ChevronUp (stroke index +1) | `() => handleStrokeIndexChange(hole.id, 1)` -> `setEditingHoles` | 197 | Cambio de estado: incrementa SI |
| HoleConfiguration | "Cancelar" (editable mode) | `onClose` -> Parent: `setShowHoleConfig(false)` | 220 | Cierra modal |
| HoleConfiguration | "Guardar Cambios" / "Sin cambios" | `handleSave` -> `golfService.updateHole()` (multiples) -> `onHolesUpdated()` + `onClose()` | 226 | API call (batch) -> callback + auto-close en 1.5s |
| HoleConfiguration | "Cerrar" (readonly mode) | `onClose` -> Parent: `setShowHoleConfig(false)` | 238 | Cierra modal |

---

## 22. DeleteRoundModal.tsx

### Variante simple (no group round O no completada)

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| DeleteRoundModal - Simple | "Cancelar" | `onCancel` -> Parent: `setShowDeleteRoundModal(null)` | 44 | Cierra modal |
| DeleteRoundModal - Simple | "Eliminar" | `onDeleteWithoutSaving` -> Parent: `handleDeleteWithoutSaving` -> `golfService.deleteRound()` | 50 | API call + refresh |

### Variante ronda completada de grupo

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| DeleteRoundModal - Completed | X (cerrar) | `onCancel` -> Parent: `setShowDeleteRoundModal(null)` | 75 | Cierra modal |
| DeleteRoundModal - Completed | "Archivar y Eliminar" (Archive) | `onArchiveAndDelete` -> Parent: `handleArchiveAndDelete` -> `golfService.archiveRound()` | 96 | API call: archiva + elimina + refresh |
| DeleteRoundModal - Completed | "Eliminar sin Guardar" (Trash2) | `onDeleteWithoutSaving` -> Parent: `handleDeleteWithoutSaving` -> `golfService.deleteRound()` | 109 | API call: elimina sin archivar |
| DeleteRoundModal - Completed | "Cancelar" | `onCancel` -> Parent: `setShowDeleteRoundModal(null)` | 127 | Cierra modal |

---

## 23. HoleInOneModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| HoleInOneModal | "No, corregir" | `onCancel` -> Parent: `handleCancelHoleInOne` -> cierra modal, resetea firstDigit | 30 | Cierra modal, mantiene panel abierto |
| HoleInOneModal | "Si, hole-in-one!" (Trophy) | `onConfirm` -> Parent: `handleConfirmHoleInOne` -> `calculateScore(1)` + `onScoreChange()` + abre CongratulationsModal | 36 | API call (via parent) + abre CongratulationsModal |

---

## 24. CongratulationsModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| CongratulationsModal | "Gracias!" | `onClose` -> Parent: `setShowCongratulationsModal(false)` | 42 | Cierra modal |

---

## 25. ArchivedRoundsModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| ArchivedRoundsModal | X (cerrar) | `onClose` -> Parent: `setShowArchivedRoundsModal(false)` | 51 | Cierra modal |
| ArchivedRoundsModal | Date card (por cada dia) | `() => onSelectRound(dayRounds[0])` -> Parent: `setSelectedArchivedRound(round)` | 87 | Abre ArchivedRoundDetailModal |
| ArchivedRoundsModal | "Cerrar" | `onClose` -> Parent: `setShowArchivedRoundsModal(false)` | 138 | Cierra modal |

---

## 26. ArchivedRoundDetailModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| ArchivedRoundDetail | ArrowLeft (volver, header) | `onBack` -> Parent: `setSelectedArchivedRound(null)` | 133 | Vuelve a ArchivedRoundsModal |
| ArchivedRoundDetail | X (cerrar, header) | `onClose` -> Parent: `setSelectedArchivedRound(null)` + `setShowArchivedRoundsModal(false)` | 144 | Cierra ambos modales |
| ArchivedRoundDetail | "Volver a lista" | `onBack` -> Parent: `setSelectedArchivedRound(null)` | 383 | Vuelve a ArchivedRoundsModal |
| ArchivedRoundDetail | "Cerrar" | `onClose` -> Parent: cierra ambos modales | 389 | Cierra ambos modales |

---

## 27. AwardRankingModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| AwardRankingModal | X (cerrar) | `onClose` -> Parent: `closeRankingModal` -> `setRankingModal({isOpen:false, type:null, data:[]})` | 47 | Cierra modal |

---

## 28. EditPlayerNameModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| EditPlayerNameModal | X (cerrar) | `onCancel` -> Parent: cierra modal | 21 | Cierra modal |
| EditPlayerNameModal | "Cancelar" (submit button) | `onCancel` -> Parent: cierra modal | 47 | Cierra modal |
| EditPlayerNameModal | "Guardar" (submit) | `handleSubmit` -> `onConfirm(newName.trim())` -> Parent: `golfService.updatePlayerName()` | 54 | API call + refresh |

---

## 29. DangerousDeleteConfirmModal.tsx

| Pantalla | Boton | Codigo que ejecuta | Linea | Destino |
|---|---|---|---|---|
| DangerousDeleteConfirm | X (cerrar) | `onCancel` -> Parent: `setShowDangerousDeleteModal(false)` | 34 | Cierra modal |
| DangerousDeleteConfirm | "Cancelar" | `onCancel` -> Parent: `setShowDangerousDeleteModal(false)` | 56 | Cierra modal |
| DangerousDeleteConfirm | "Eliminar Todo" | `onConfirm` -> Parent: `handleConfirmDangerousDelete` -> `golfService.deleteAllRounds()` | 63 | API call: elimina todas las rondas |

---

## Referencia Cruzada: Resumen de Flujo de Navegacion

```
GroupSetup (choose)
  +- "Crear Partideta Rapida" -> RoundSetup (quick play)
  +- "Unirse a Partideta Rapida" -> AccessCodeModal -> Scorecard/PlayerSetup
  +- "Crear Multipartideta" -> GroupSetup (create) -> RoundSetup (with group)
  +- "Unirse a Multipartideta" -> GroupSetup (join) -> RoundSetup (with group)
  +- "Iniciar Sesion" -> Auth -> MyGroups -> RoundSetup (with group)

RoundSetup
  +- "Crear Partida" -> PlayerSetup -> Scorecard
  +- "Ver Partida" -> ActiveRoundsViewer -> Scorecard
  +- "Ver Puntos" -> GamePoints
  +- "Ver Estadisticas" -> Statistics / QuickPlayStatistics
  +- "Salir" -> ConfirmModal -> GroupSetup

Scorecard
  +- "Clasificacion" -> Leaderboard -> Scorecard
  +- "Finalizar Partida" -> ConfirmModal -> handleFinishRound -> ActiveRoundsViewer/Setup
  +- "Cambiar" (campo) -> CourseChangeModal -> CourseChangeConfirmModal -> API
  +- HoleCard -> (scores) -> HoleInOneModal -> CongratulationsModal

ActiveRoundsViewer
  +- "Ver Partida" -> Scorecard
  +- "Clasificacion" -> Global Leaderboard view
  +- "Eliminar" -> DeleteRoundModal -> archive/delete API
  +- "Anadir" -> AddPlayerModal -> API
```

---

## Referencia Cruzada: Mapa de Disparo de Modales

| Modal | Disparado Desde | Accion de Disparo |
|---|---|---|
| AccessCodeModal | GroupSetup, RoundSetup | `setShowAccessCodeModal(true)` |
| AdminPinModal | App (admin login), RoundSetup, PlayerSetup, ActiveRoundsViewer, GamePoints | `setShowAdminPinModal(true)` / `setShowPinModal(true)` |
| ConfirmModal | App (leave group), Scorecard (finish), ActiveRoundsViewer (delete all), QuickPlayStats (delete), MyGroups (delete group) | `setShow*Confirm(true)` |
| HolesRangeModal | RoundSetup, PlayerSetup | `setShowHolesRangeModal(true)` |
| CourseChangeModal | Scorecard | `setShowCourseChangeModal(true)` |
| CourseChangeConfirmModal | Scorecard (via handleSelectCourse) | `setShowCourseConfirmModal(true)` |
| HoleConfiguration | App (via PlayerSetup PIN flow) | `setShowHoleConfig(true)` |
| DeleteRoundModal | ActiveRoundsViewer | `setShowDeleteRoundModal(roundId)` |
| HoleInOneModal | HoleCard | `setShowHoleInOneModal(true)` |
| CongratulationsModal | HoleCard (via handleConfirmHoleInOne) | `setShowCongratulationsModal(true)` |
| ArchivedRoundsModal | Statistics | `setShowArchivedRoundsModal(true)` |
| ArchivedRoundDetailModal | Statistics (via onSelectRound) | `setSelectedArchivedRound(round)` |
| AwardRankingModal | Statistics | `setRankingModal({isOpen:true, ...})` |
| EditPlayerNameModal | PlayerSetup, GamePoints | `setShowEditPlayerModal(true)` / `setShowEditNameModal(true)` |
| DangerousDeleteConfirmModal | ActiveRoundsViewer | `setShowDangerousDeleteModal(true)` |

---

*Documento generado automaticamente. Cubre todos los elementos `<button>` en los 27 componentes analizados.*
