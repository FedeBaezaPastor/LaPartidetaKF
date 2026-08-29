# 🏌️ La Partideta Golf

**Sistema completo de gestión de partidas de golf con puntuación Stableford, handicaps dinámicos y estadísticas avanzadas.**

[![Estado](https://img.shields.io/badge/Estado-Producción-success)](https://github.com)
[![Licencia](https://img.shields.io/badge/Licencia-Privada-blue)](https://github.com)
[![Tecnología](https://img.shields.io/badge/Stack-React%20%2B%20Supabase-informational)](https://github.com)

---

## 📋 Tabla de Contenidos

- [Descripción](#-descripción)
- [Características](#-características)
- [Modalidades de Juego](#-modalidades-de-juego)
- [Pantallas de la Aplicación](#-pantallas-de-la-aplicación)
- [Tecnologías](#-tecnologías)
- [Inicio Rápido](#-inicio-rápido)
- [Base de Datos](#-base-de-datos)
- [Funciones y Triggers](#-funciones-y-triggers)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Despliegue](#-despliegue)
- [Seguridad](#-seguridad)
- [Notas de Versión](#-notas-de-versión)

---

## 🎯 Descripción

**La Partideta Golf** es una Progressive Web App (PWA) diseñada para digitalizar y mejorar la experiencia de jugar golf con amigos. Elimina el papel, automatiza cálculos complejos de Stableford con handicaps variables, y mantiene un histórico completo de estadísticas.

**Casos de uso:**
- 🎮 Partidas rápidas entre amigos (sin registro)
- 👥 Grupos permanentes con rankings históricos
- 📊 Seguimiento de evolución de jugadores
- 🏆 Sistema de premios y reconocimientos especiales
- 📱 Acceso multiplataforma (móvil, tablet, desktop)

---

## ✨ Características

### Partidas

- ✅ **Partidetas Rápidas**: Juego instantáneo sin necesidad de cuenta
- ✅ **Multipartidetas**: Grupos permanentes con código de acceso
- ✅ **4 Modalidades de Juego**: Stableford, Match (1v1), Sindicato (3 jugadores), Parejas (2v2 fourball)
- ✅ **Tarjeta de Puntuación Digital**: Interfaz intuitiva para ingreso de golpes
- ✅ **Cálculo Automático**: Stableford points con soporte para handicaps y slopes
- ✅ **Marcador en Tiempo Real**: Clasificación actualizada hoyo a hoyo según la modalidad
- ✅ **Acceso Compartido**: Únete con código de 4 dígitos

### Campos y Configuración

- 🏌️ **5 Campos Pre-configurados**: Costa Azahar (Rojo/Verde), Mediterráneo, Panorámica, y más
- 🎯 **Sistema de Barras (Tees)**: Blancas, Amarillas, Rojas, Azules con slopes
- ⚙️ **Configuración Flexible**: 9 o 18 hoyos, personalización de stroke index y rango de hoyos
- 🔄 **Cambio de Campo**: Durante setup con confirmación

### Estadísticas y Rankings

- 📈 **Estadísticas Detalladas**: Por jugador, por campo, por temporada
- 🏆 **Rankings Especiales**: Rey del Bosque, La Paliza, Hoyo de la Muerte, Máquina, Driver Oro, Corto, Topo
- 🍺 **Sistema de Cervezas**: Contabilización automática (grupo DIVEND)
- 📚 **Archivo Histórico**: Todas las rondas completadas
- 🎯 **Métricas Avanzadas**: Fairways, GIR, putts, etc.

### Premios Especiales

- 🎉 **Hole in One**: Modal celebratorio
- 🔴 **No Pasó de Rojas**: Marca especial
- 👑 **Premio al Mejor de la Jornada**
- 🏅 **Rankings Múltiples**: Varios criterios de clasificación

### Administración

- 🔒 **Panel Admin**: Protegido con PIN
- 📊 **Gestión de Handicaps**: Actualización manual y automática tras cada partida
- 👥 **Gestión de Jugadores**: CRUD completo
- 📋 **Vista de Rondas Archivadas**: Histórico completo

---

## 🎮 Modalidades de Juego

Al crear una partida se elige una de cuatro modalidades. La modalidad determina cómo se puntúa cada hoyo y cómo se muestra el marcador.

### Stableford (por defecto)
- **Jugadores:** 1 a 4 (sin límite estricto)
- **Puntuación:** Puntos Stableford clásicos por hoyo según el resultado neto frente al par:
  - 0 puntos — doble bogey o peor
  - 1 punto — bogey
  - 2 puntos — par
  - 3 puntos — birdie
  - 4 puntos — eagle o mejor
- **Marcador:** Cada jugador acumula sus propios puntos. El leaderboard ordena por total Stableford.
- **Sin puntuación por pareja ni enfrentamiento directo.**

### Match (Match Play 1 vs 1)
- **Jugadores:** Exactamente 2
- **Puntuación por hoyo:** Compara los golpes netos de ambos jugadores:
  - Gana el hoyo → 1 punto
  - Empate → 0.5 puntos
  - Pierde → 0 puntos
- **Marcador:** Se muestra como ventaja acumulada (`3UP`, `AS`, etc.) en lugar de puntos totales.
- **Gana quien gane más hoyos, no quien sume más puntos.**

### Sindicato (3 jugadores)
- **Jugadores:** Exactamente 3
- **Puntuación por hoyo:** Se reparten 6 puntos según los golpes netos ordenados de menor a mayor:
  - Sin empates: **4 / 2 / 0** (mejor / medio / peor)
  - Empate a dos en el mejor: **3 / 3 / 0**
  - Empate a dos en el peor: **4 / 1 / 1**
  - Empate total (los tres iguales): **2 / 2 / 2**
- **Marcador:** Cada jugador acumula sus puntos. El leaderboard muestra el total y el nombre del líder.

### Parejas (Fourball 2 vs 2)
- **Jugadores:** Exactamente 4, agrupados en 2 parejas (P1 = jugadores 1-2, P2 = jugadores 3-4)
- **Puntuación por hoyo:** Compara la **mejor bola** y la **peor bola** de cada pareja por separado:
  - Mejor bola de la pareja gana a la mejor bola rival → 1 punto para la pareja
  - Peor bola de la pareja gana a la peor bola rival → 1 punto para la pareja
  - Empate en mejor o peor bola → 0.5 puntos
  - Total posible por hoyo: 2 / 1.5 / 1 / 0.5 / 0 puntos por pareja
- **Cálculo:** Los puntos se calculan automáticamente cuando los 4 jugadores tienen resultado en el hoyo. Ambos miembros de la pareja reciben los mismos puntos.
- **Marcador:** Se muestra como `P1 fede/kike 2-0 Otro/Otro mas P2`, sumando los puntos de un jugador por pareja (no se duplican).

---

## 📱 Pantallas de la Aplicación

### Pantallas Conectadas (14)

Estas son las vistas que están activas y accesibles desde la navegación principal:

| # | Pantalla | Componente | Descripción | Acceso |
|---|---------|-----------|-------------|--------|
| 1 | Inicio / Selección de Grupo | `GroupSetup` | Pantalla principal donde se elige entre partida rápida o grupo | Al abrir la app |
| 2 | Autenticación | `Auth` | Pantalla de inicio de sesión y registro | Desde el menú principal |
| 3 | Mis Grupos | `MyGroups` | Lista de grupos permanentes del usuario | Desde el menú principal |
| 4 | Configuración de Partida | `RoundSetup` | Selección de campo, barras, número de hoyos y slope | Desde el menú principal |
| 5 | Configuración de Jugadores | `PlayerSetup` | Añadir y configurar jugadores con sus handicaps | Tras configurar la partida |
| 6 | Tarjeta de Puntuaciones | `Scorecard` | Ingreso de golpes por hoyo con cálculo automático Stableford | Tras configurar jugadores |
| 7 | Clasificación en Vivo | `Leaderboard` | Tabla de posiciones actualizada en tiempo real | Desde la tarjeta de puntuaciones |
| 8 | Partidas Activas | `ActiveRoundsViewer` | Lista de partidas en curso a las que unirse | Desde el menú principal |
| 9 | Puntos de Juego | `GamePoints` | Visualización de puntos de juego por jugador | Desde la tarjeta de puntuaciones |
| 10 | Estadísticas de Grupo | `Statistics` | Estadísticas detalladas del grupo permanente | Desde el menú del grupo |
| 11 | Estadísticas de Partida Rápida | `QuickPlayStatistics` | Estadísticas de partidas rápidas sin grupo | Desde el menú principal |
| 12 | Panel de Administración | `AdminDashboard` | Gestión de jugadores, handicaps y rondas archivadas | Con PIN de administrador |
| 13 | Vista de Observador | (viewer) | Vista de solo lectura para seguir una partida | Con código de acceso |
| 14 | Configuración de Hoyos | `HoleConfiguration` | Personalización de hoyos, par y stroke index | Desde la configuración de partida |

### Componentes Existentes No Conectados (18)

Estos componentes existen en el código pero no forman parte de la navegación principal. Son modales, componentes auxiliares o funcionalidades en preparación:

| Componente | Tipo | Descripción |
|-----------|------|-------------|
| `AccessCodeModal` | Modal | Introducir código de acceso de 4 dígitos para unirse a partida |
| `AdminPinModal` | Modal | Introducir PIN de administrador |
| `ArchivedRoundDetailModal` | Modal | Ver detalle de una partida archivada |
| `ArchivedRoundsModal` | Modal | Listar partidas archivadas |
| `AwardRankingModal` | Modal | Mostrar rankings de premios especiales |
| `ComingSoonModal` | Modal | Funcionalidad próximamente |
| `ConfirmModal` | Modal | Confirmación genérica de acciones |
| `CongratulationsModal` | Modal | Felicitación al ganador |
| `CourseChangeConfirmModal` | Modal | Confirmar cambio de campo |
| `CourseChangeModal` | Modal | Seleccionar nuevo campo |
| `CreateGroupComingSoonModal` | Modal | Crear grupo (próximamente) |
| `EditPlayerNameModal` | Modal | Editar nombre de jugador |
| `ErrorBoundary` | Utilidad | Captura de errores de React |
| `HandicapUpdateModal` | Modal | Actualizar handicap de jugador |
| `HoleCard` | Componente | Tarjeta visual de un hoyo |
| `HoleInOneModal` | Modal | Celebración de hole in one |
| `HolesRangeModal` | Modal | Seleccionar rango de hoyos (9, 18, personalizado) |
| `ParTeeUpgradeModal` | Modal | Upgrade de par/tee |
| `RoundStatistics` | Componente | Estadísticas de una partida concreta |
| `ShareModal` | Modal | Compartir resultados |
| `ScoreSymbol` | Componente | Símbolo visual de puntuación (birdie, eagle, etc.) |

---

## 🛠 Tecnologías

### Frontend
- **React 18** - Librería UI
- **TypeScript** - Tipado estático
- **Vite** - Build tool y dev server
- **Tailwind CSS** - Framework de estilos
- **Lucide React** - Sistema de iconos
- **html2canvas** - Captura de imágenes para compartir
- **qrcode.react** - Generación de códigos QR

### Backend
- **Supabase** - Backend as a Service
  - PostgreSQL - Base de datos relacional
  - Row Level Security - Seguridad a nivel de fila
  - Realtime - Actualizaciones en tiempo real
  - Auth - Autenticación

### Herramientas
- **ESLint** - Linting
- **PostCSS** - Procesamiento CSS

---

## 🚀 Inicio Rápido

### Prerrequisitos

- Node.js >= 18.0.0
- npm >= 9.0.0
- Cuenta en Supabase (gratis)

### Instalación Local

```bash
# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env
# Edita .env con tus credenciales de Supabase

# Iniciar servidor de desarrollo
npm run dev
```

Abre [http://localhost:5173](http://localhost:5173) para ver la aplicación.

### Comandos Disponibles

```bash
npm run dev       # Desarrollo (puerto 5173)
npm run build     # Build para producción
npm run preview   # Preview del build (puerto 4173)
npm run lint      # Linting
npm run typecheck  # Verificación de tipos
```

---

## 🗄 Base de Datos

### Tablas (14)

El sistema utiliza 14 tablas en PostgreSQL gestionadas mediante 223 migraciones:

#### `golf_courses`
Campos de golf disponibles.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `name` | text | Nombre del campo |
| `description` | text | Descripción del campo |
| `created_at` | timestamptz | Fecha de creación |

#### `golf_holes`
Hoyos de cada campo de golf.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `course_id` | uuid (FK → golf_courses) | Campo al que pertenece |
| `hole_number` | integer | Número de hoyo (1-18) |
| `par` | integer | Par del hoyo |
| `stroke_index` | integer | Índice de stroke (handicap) |
| `distance` | integer | Distancia en metros |

#### `tees`
Barras de salida con slopes por campo.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `course_id` | uuid (FK → golf_courses) | Campo al que pertenece |
| `name` | text | Nombre (Blancas, Amarillas, Rojas, Azules) |
| `color` | text | Código de color para UI |
| `slope_18` | integer | Slope para 18 hoyos |
| `slope_9_i` | integer | Slope para hoyos 1-9 |
| `slope_9_ii` | integer | Slope para hoyos 10-18 |
| `created_at` | timestamptz | Fecha de creación |

#### `golf_rounds`
Partidas de golf (activas o completadas).
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `course_id` | uuid (FK → golf_courses) | Campo donde se juega |
| `user_id` | text | ID del creador |
| `group_id` | uuid (FK → groups) | Grupo asociado (nullable) |
| `num_holes` | integer | Número de hoyos (9 o 18) |
| `holes_range` | integer[] | Rango de hoyos seleccionado |
| `use_slope` | boolean | Usar slope para cálculos |
| `tee_id` | uuid (FK → tees) | Barra seleccionada |
| `manual_slope` | integer | Slope manual (sobrescribe tee) |
| `status` | text | Estado de la partida |
| `game_mode` | text | Modalidad: `stableford`, `match`, `sindicato` o `parejas` |
| `reference_number` | integer | Número de referencia por grupo |
| `access_code` | text | Código de acceso de 4 dígitos |
| `completed_at` | timestamptz | Fecha de finalización |
| `created_at` | timestamptz | Fecha de creación |

#### `round_players`
Jugadores participantes en cada partida.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `round_id` | uuid (FK → golf_rounds) | Partida asociada |
| `user_id` | text | ID del usuario |
| `player_id` | uuid (FK → players) | Jugador registrado |
| `name` | text | Nombre del jugador |
| `exact_handicap` | numeric | Handicap exacto |
| `exact_handicap_18` | numeric | Handicap exacto para 18 hoyos |
| `playing_handicap` | integer | Handicap de juego |
| `created_at` | timestamptz | Fecha de creación |

#### `round_scores`
Puntuaciones por hoyo de cada jugador.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `round_id` | uuid (FK → golf_rounds) | Partida asociada |
| `player_id` | uuid (FK → round_players) | Jugador |
| `hole_number` | integer | Número de hoyo |
| `gross_strokes` | integer | Golpes brutos |
| `strokes_received` | numeric | Golpes recibidos por handicap |
| `net_strokes` | numeric | Golpes netos |
| `stableford_points` | numeric | Puntos Stableford |
| `mode_points` | numeric | Puntos de la modalidad (match, sindicato o parejas) |
| `no_paso_rojas` | boolean | Marcador especial "no pasó de rojas" |
| `abandoned` | boolean | El jugador abandonó el hoyo |
| `created_at` | timestamptz | Fecha de creación |

#### `groups`
Grupos permanentes de jugadores.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `name` | text | Nombre del grupo |
| `group_code` | text (unique) | Código de 6 dígitos para unirse |
| `created_by` | text | ID del creador |
| `created_at` | timestamptz | Fecha de creación |

#### `players`
Jugadores registrados en el sistema.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `name` | text (unique) | Nombre del jugador |
| `exact_handicap` | numeric | Handicap exacto |
| `exact_handicap_18` | numeric | Handicap exacto para 18 hoyos |
| `playing_handicap` | integer | Handicap de juego |
| `group_id` | uuid (FK → groups) | Grupo al que pertenece |
| `created_at` | timestamptz | Fecha de creación |
| `updated_at` | timestamptz | Última actualización |

#### `seasons`
Temporadas de juego por grupo.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `group_id` | uuid (FK → groups) | Grupo asociado |
| `name` | text | Nombre de la temporada |
| `start_date` | date | Fecha de inicio |
| `end_date` | date | Fecha de fin (null si activa) |
| `created_at` | timestamptz | Fecha de creación |

#### `archived_rounds`
Partidas completadas y archivadas (solo multipartidetas).
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `group_id` | uuid (FK → groups) | Grupo que jugó la partida |
| `course_name` | text | Nombre del campo |
| `played_at` | timestamptz | Fecha de juego |
| `archived_at` | timestamptz | Fecha de archivo |
| `final_ranking` | jsonb | Ranking final: `[{position, player_name, points, hcp_juego}]` |
| `player_stats` | jsonb | Estadísticas por jugador |
| `hole_scores` | jsonb | Puntuaciones por hoyo |
| `no_paso_rojas` | jsonb | Marcadores especiales |
| `season_id` | uuid (FK → seasons) | Temporada asociada |
| `handicap_adjusted` | boolean | Si los handicaps ya fueron ajustados |
| `created_at` | timestamptz | Fecha de creación |

#### `daily_rankings`
Clasificaciones diarias por grupo (base del sistema de cervezas).
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `group_id` | uuid (FK → groups) | Grupo asociado |
| `ranking_date` | date | Fecha del ranking |
| `player_name` | text | Nombre del jugador |
| `total_points` | numeric | Puntos totales del día |
| `position` | integer | Posición final (1, 2, 3...) |
| `receives_beer` | boolean | Si recibe cerveza |
| `pays_beer` | boolean | Si paga cerveza |
| `hcp_juego` | numeric | Handicap de juego usado |
| `created_at` | timestamptz | Fecha de creación |

**Constraint único:** `(group_id, ranking_date, player_name)`

#### `handicap_history`
Histórico de cambios de handicap.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `player_id` | uuid (FK → players) | Jugador |
| `group_id` | uuid (FK → groups) | Grupo |
| `old_handicap` | numeric | Handicap anterior |
| `new_handicap` | numeric | Handicap nuevo |
| `changed_at` | timestamptz | Fecha del cambio |
| `archived_round_id` | uuid (FK → archived_rounds) | Partida que causó el cambio |
| `created_at` | timestamptz | Fecha de creación |

#### `handicap_adjustments`
Ajustes de handicap por partida (sistema per-round).
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `group_id` | uuid (FK → groups) | Grupo asociado |
| `player_id` | uuid (FK → players) | Jugador ajustado |
| `player_name` | text | Nombre del jugador |
| `adjustment_date` | date | Fecha del ajuste |
| `ranking_position` | integer | Posición en el ranking |
| `hcp_before` | numeric | Handicap antes del ajuste |
| `hcp_after` | numeric | Handicap después del ajuste |
| `adjustment` | numeric | Diferencia aplicada |
| `playing_handicap_before` | numeric | Playing handicap antes |
| `archived_round_id` | uuid (FK → archived_rounds) | Partida que originó el ajuste |
| `created_at` | timestamptz | Fecha de creación |

**Constraint único:** `(group_id, player_id, archived_round_id)`

#### `admin_config`
Configuración del administrador.
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid (PK) | Identificador único |
| `admin_email` | text | Email del administrador |
| `admin_pin` | text | PIN de acceso (4 dígitos) |
| `created_at` | timestamptz | Fecha de creación |
| `updated_at` | timestamptz | Última actualización |

### Diagrama de Relaciones

```
golf_courses ──┬──< golf_holes
               └──< tees
                     │
groups ──┬──< players          ┌──< round_scores
         │         │            │
         ├──< seasons            │
         │         │            │
         ├──< archived_rounds ──┤
         │         │            │
         ├──< daily_rankings    │
         │                      │
         └──< handicap_history ─┘
                │
                └──< handicap_adjustments

golf_rounds ──< round_players ──< round_scores
     │
     ├──> golf_courses
     ├──> tees
     ├──> groups
     └──> user_id (text)
```

---

## ⚙️ Funciones y Triggers

### Funciones RPC Principales

| Función | Descripción |
|---------|-------------|
| `calculate_daily_ranking(group_id, date)` | Calcula la clasificación diaria de un grupo: suma puntos de todas las partidas del día, asigna posiciones y determina quién recibe/paga cervezas |
| `apply_handicap_adjustments_for_round(round_id)` | Ajusta handicaps de los jugadores tras archivar una partida: la mitad superior baja el handicap, la inferior lo sube |
| `reset_reference_sequence(group_id)` | Reinicia la secuencia de números de referencia de partidas por grupo |

### Triggers

| Trigger | Función | Descripción |
|---------|---------|-------------|
| `auto_calculate_daily_ranking` | `auto_calculate_daily_ranking()` | Se ejecuta automáticamente al insertar en `archived_rounds`: recalcula el ranking diario y aplica ajustes de handicap |

### Funciones de Rankings Especiales

El sistema incluye funciones RPC para los rankings especiales del grupo DIVEND:

| Función | Descripción |
|---------|-------------|
| **Rey del Bosque** | Mayor número de dobles bogeys o peor |
| **La Paliza** | Mayor diferencia de puntos entre primera y última partida del día |
| **Hoyo de la Muerte** | Hoyo con más bogeys acumulados |
| **Máquina** | Mayor número de birdies netos exactos |
| **Driver Oro** | Mejor driver del día |
| **Corto** | Jugador con menos distancia |
| **Topo** | Peor rendimiento relativo al handicap |

---

## 📁 Estructura del Proyecto

```
la-partideta-golf/
├── src/
│   ├── components/              # 34 componentes React
│   │   ├── AccessCodeModal.tsx
│   │   ├── ActiveRoundsViewer.tsx
│   │   ├── AdminDashboard.tsx
│   │   ├── AdminPinModal.tsx
│   │   ├── ArchivedRoundDetailModal.tsx
│   │   ├── ArchivedRoundsModal.tsx
│   │   ├── Auth.tsx
│   │   ├── AwardRankingModal.tsx
│   │   ├── ComingSoonModal.tsx
│   │   ├── ConfirmModal.tsx
│   │   ├── CongratulationsModal.tsx
│   │   ├── CourseChangeConfirmModal.tsx
│   │   ├── CourseChangeModal.tsx
│   │   ├── CreateGroupComingSoonModal.tsx
│   │   ├── EditPlayerNameModal.tsx
│   │   ├── ErrorBoundary.tsx
│   │   ├── GamePoints.tsx
│   │   ├── GroupSetup.tsx
│   │   ├── HandicapUpdateModal.tsx
│   │   ├── HoleCard.tsx
│   │   ├── HoleConfiguration.tsx
│   │   ├── HoleInOneModal.tsx
│   │   ├── HolesRangeModal.tsx
│   │   ├── Leaderboard.tsx
│   │   ├── MyGroups.tsx
│   │   ├── ParTeeUpgradeModal.tsx
│   │   ├── PlayerSetup.tsx
│   │   ├── QuickPlayStatistics.tsx
│   │   ├── RoundSetup.tsx
│   │   ├── RoundStatistics.tsx
│   │   ├── Scorecard.tsx
│   │   ├── ScoreSymbol.tsx
│   │   ├── ShareModal.tsx
│   │   └── Statistics.tsx
│   ├── services/                # Lógica de negocio
│   │   ├── golfService.ts        # Servicio principal (CRUD, realtime, archivado)
│   │   ├── supabaseClient.ts    # Cliente de Supabase
│   │   └── expressTierGuard.ts  # Control de niveles de acceso
│   ├── utils/                   # Utilidades
│   │   ├── accessCode.ts        # Gestión de códigos de acceso
│   │   ├── adminPin.ts          # PIN de administrador
│   │   ├── calculations.ts      # Cálculos de golf (Stableford, handicaps)
│   │   ├── safeStorage.ts       # Almacenamiento seguro (incógnito-safe)
│   │   ├── storage.ts           # LocalStorage helpers
│   │   └── userId.ts            # Generación de ID de usuario
│   ├── data/
│   │   └── defaultCourse.ts     # Campo por defecto
│   ├── types.ts                 # Tipos de TypeScript
│   └── App.tsx                  # Componente principal (navegación)
├── supabase/
│   └── migrations/             # 223 migraciones SQL
├── public/                      # Assets estáticos
├── batches/                     # Scripts SQL de importación de datos
├── data/                        # Exports de datos JSON
├── .env.example                 # Plantilla de variables de entorno
├── package.json
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
└── eslint.config.js
```

---

## 🌐 Despliegue

### Variables de Entorno Requeridas

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=tu_clave_anon
VITE_ADMIN_EMAIL=tu@email.com
VITE_ADMIN_PIN=2248
```

### Opción 1: Vercel

1. Conecta tu repositorio GitHub
2. Configura variables de entorno
3. Deploy

### Opción 2: Netlify

1. Conecta tu repositorio GitHub
2. Build command: `npm run build`
3. Publish directory: `dist`

---

## 🔒 Seguridad

- ✅ Row Level Security (RLS) habilitado en todas las tablas
- ✅ Variables de entorno para secretos
- ✅ PIN de administrador con límite de intentos (3)
- ✅ Validación de inputs en frontend
- ⚠️ Las políticas RLS son permisivas (acceso público) para permitir el uso sin autenticación completa
- 🔄 V2 endurecerá la seguridad con autenticación completa de Supabase Auth

---

## 📝 Notas de Versión

### V1 (Agosto 2026) - Estado Actual

**Funcionalidades Activas:**
- ✅ Partidetas Rápidas completas
- ✅ Multipartidetas (unirse y jugar)
- ✅ 4 modalidades de juego: Stableford, Match, Sindicato y Parejas (fourball 2v2)
- ✅ 5 campos de golf configurados con barras y slopes
- ✅ Sistema de estadísticas avanzado con rankings especiales
- ✅ Panel de administración con PIN
- ✅ Archivo histórico de partidas
- ✅ Sistema de handicaps dinámicos per-round
- ✅ Sistema de cervezas automático (DIVEND)
- ✅ Clasificaciones diarias automáticas
- ✅ Autenticación con Supabase Auth

**Funcionalidades Bloqueadas:**
- ❌ Crear Multipartidetas (muestra modal)
- ❌ Sincronización multi-dispositivo
- ❌ Notificaciones push

### Roadmap V2

- 🔄 Creación libre de Multipartidetas
- 🔄 Gestión de múltiples grupos por usuario
- 🔄 PWA con modo offline avanzado
- 🔄 Notificaciones en tiempo real
- 🔄 Endurecimiento de políticas RLS

---

## 📄 Licencia

Copyright © 2026 La Partideta Golf. Todos los derechos reservados.

Este es un proyecto privado y el código no está disponible para uso público.

---

**¡Disfruta del golf! 🏌️⛳**

*Última actualización: Agosto 2026*
