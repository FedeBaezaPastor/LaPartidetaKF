# ESTADO TECNICO - DIVEND GOLF APP

**Fecha de Generación:** 18 de Enero de 2026
**Versión:** 1.0.0
**Estado:** Estable y en Producción

---

## 1. ARQUITECTURA DEL SISTEMA

### 1.1 Stack Tecnológico

#### Frontend
- **Framework**: React 18.3.1 con TypeScript 5.5.3
- **Bundler**: Vite 5.4.2
- **Estilos**: Tailwind CSS 3.4.1
- **Iconos**: Lucide React 0.344.0

#### Backend
- **Base de Datos**: Supabase (PostgreSQL)
- **ORM/Cliente**: @supabase/supabase-js 2.57.4
- **Autenticación**: Supabase Auth (Email/Password)

#### Herramientas de Desarrollo
- **Linter**: ESLint 9.9.1
- **Type Checking**: TypeScript con configuración estricta
- **Build**: Vite con optimización de producción

### 1.2 Arquitectura de Componentes

```
src/
├── components/          # Componentes React
│   ├── Auth.tsx        # Sistema de autenticación
│   ├── GroupSetup.tsx  # Configuración de grupos
│   ├── PlayerSetup.tsx # Gestión de jugadores
│   ├── RoundSetup.tsx  # Configuración de partidas
│   ├── Scorecard.tsx   # Tarjeta de puntuación
│   ├── Leaderboard.tsx # Clasificación
│   └── Statistics.tsx  # Estadísticas y premios
├── services/           # Lógica de negocio
│   ├── golfService.ts  # API principal (2445 líneas)
│   └── supabaseClient.ts # Cliente de Supabase
├── utils/              # Utilidades
│   ├── calculations.ts # Matemática de golf
│   ├── storage.ts      # LocalStorage wrapper
│   ├── accessCode.ts   # Generación de códigos
│   └── userId.ts       # Gestión de IDs
├── data/
│   └── defaultCourse.ts # Campos por defecto
└── types.ts            # Definiciones TypeScript
```

### 1.3 Modelo de Datos

#### Base de Datos Supabase (PostgreSQL)

**Tablas Principales:**

1. **golf_courses** - Campos de golf
2. **golf_holes** - Hoyos de cada campo
3. **tees** - Tees/Salidas con slopes
4. **players** - Jugadores registrados
5. **groups** - Grupos/Multipartidetas
6. **golf_rounds** - Partidas activas
7. **round_players** - Jugadores en una partida
8. **round_scores** - Puntuaciones por hoyo
9. **archived_rounds** - Historial de partidas
10. **daily_rankings** - Rankings diarios
11. **seasons** - Temporadas

**Funciones RPC:**
- `calculate_daily_ranking` - Calcula el ranking del día
- `get_*_ranking` - Funciones para cada premio DIVEND
- `get_detailed_player_statistics` - Estadísticas detalladas
- `update_player_name_in_archived_rounds` - Sincronización de nombres

---

## 2. ESTRUCTURA DE DATOS (TYPES)

### 2.1 Interfaces Principales

```typescript
// Campo de Golf
interface GolfCourse {
  id: string;
  name: string;
  description?: string;
  created_at: string;
}

// Hoyo
interface GolfHole {
  id: string;
  course_id: string;
  hole_number: number;
  par: 3 | 4 | 5;
  stroke_index: number;  // Índice de dificultad (1-18)
  created_at: string;
  updated_at: string;
}

// Tee (Salida con Slope)
interface Tee {
  id: string;
  course_id: string;
  name: string;          // Ej: "Blancas", "Amarillas"
  color: string;
  slope_18: number;      // Slope para 18 hoyos
  slope_9_i: number;     // Slope hoyos 1-9
  slope_9_ii: number;    // Slope hoyos 10-18
  created_at: string;
}

// Jugador
interface Player {
  id: string;
  name: string;
  exact_handicap: number;      // Handicap de 9 hoyos
  exact_handicap_18?: number;  // Handicap de 18 hoyos
  created_at: string;
  updated_at: string;
}

// Jugador en Partida
interface RoundPlayer {
  id: string;
  round_id: string;
  user_id?: string;
  player_id?: string;
  name: string;
  exact_handicap: number;      // Handicap exacto
  exact_handicap_18?: number;  // Handicap 18 hoyos
  playing_handicap: number;    // Handicap de juego (con slope)
  created_at: string;
}

// Puntuación de Hoyo
interface RoundScore {
  id: string;
  round_id: string;
  player_id: string;
  hole_number: number;
  gross_strokes: number;      // Golpes brutos
  strokes_received: number;   // Golpes recibidos
  net_strokes: number;        // Golpes netos
  stableford_points: number;  // Puntos Stableford
  no_paso_rojas: boolean;     // Penalización
  abandoned: boolean;         // Hoyo abandonado
  created_at: string;
  updated_at: string;
}

// Partida
interface GolfRound {
  id: string;
  course_id: string;
  created_by: string;
  user_id: string;
  group_id?: string;
  num_holes: 9 | 18;
  holes_range?: '1-9' | '10-18';
  use_slope: boolean;
  tee_id?: string;
  manual_slope?: number;
  status: 'active' | 'completed' | 'cancelled';
  reference_number: number;
  access_code: string;        // Código de 4 dígitos
  created_at: string;
  updated_at: string;
}

// Grupo/Multipartideta
interface Group {
  id: string;
  name?: string;
  group_code: string;         // Código único del grupo
  created_at: string;
  created_by?: string;
}

// Estadísticas de Jugador
interface PlayerStats {
  playerId: string;
  playerName: string;
  totalPoints: number;
  scoresEntered: number;
  totalHoles: number;
}
```

### 2.2 Tipos Auxiliares

```typescript
type RoundStatus = 'active' | 'completed' | 'cancelled';

interface RoundWithDetails {
  round: GolfRound;
  holes: GolfHole[];
  players: RoundPlayer[];
  scores: RoundScore[];
}

interface CalculatedScore {
  grossStrokes: number;
  strokesReceived: number;
  netStrokes: number;
  stablefordPoints: number;
  no_paso_rojas?: boolean;
  abandoned?: boolean;
}
```

---

## 3. LOGICA MATEMATICA

### 3.1 Sistema de Handicap

#### 3.1.1 Handicap de Juego (Playing Handicap)

**Fórmula con Slope:**
```typescript
playing_handicap = Math.round(exact_handicap × (slope / 113))
```

- **113**: Slope estándar de referencia
- **exact_handicap**: Handicap exacto del jugador (de 9 o 18 hoyos según la partida)
- **slope**: Slope del tee seleccionado (varía por campo y salida)

**Sin Slope:**
```typescript
playing_handicap = Math.round(exact_handicap)
```

#### 3.1.2 Conversión entre 9 y 18 Hoyos

**De 9 a 18 hoyos:**
```typescript
exact_handicap_18 = exact_handicap_9 × 2
```

**De 18 a 9 hoyos:**
```typescript
exact_handicap_9 = exact_handicap_18 / 2
```

### 3.2 Golpes Recibidos por Hoyo

#### 3.2.1 Para Partidas de 18 Hoyos

```typescript
function getStrokesReceived(playingHandicap, strokeIndex) {
  if (playingHandicap <= 0) return 0;

  const fullStrokes = Math.floor(playingHandicap / 18);
  const remainder = playingHandicap % 18;

  if (strokeIndex <= remainder) {
    return fullStrokes + 1;
  }
  return fullStrokes;
}
```

**Explicación:**
- Si el handicap de juego es 23:
  - fullStrokes = 1 (cada hoyo recibe 1 golpe)
  - remainder = 5 (5 hoyos adicionales reciben otro golpe)
  - Hoyos con strokeIndex 1-5: reciben 2 golpes
  - Hoyos con strokeIndex 6-18: reciben 1 golpe

#### 3.2.2 Para Partidas de 9 Hoyos

```typescript
function getStrokesReceived9Holes(playingHandicap, strokeIndex, holeStrokeIndexes) {
  if (playingHandicap <= 0) return 0;

  // Normalizar el strokeIndex según los 9 hoyos jugados
  const sortedIndexes = [...holeStrokeIndexes].sort((a, b) => a - b);
  const normalizedStrokeIndex = sortedIndexes.findIndex(si => si === strokeIndex) + 1;

  const fullStrokes = Math.floor(playingHandicap / 9);
  const remainder = playingHandicap % 9;

  return normalizedStrokeIndex <= remainder ? fullStrokes + 1 : fullStrokes;
}
```

**Ejemplo:**
- 9 hoyos con strokeIndexes: [2, 4, 6, 8, 10, 12, 14, 16, 18]
- Handicap de juego: 7
- Normalización:
  - strokeIndex 2 → posición 1 → recibe 1 golpe
  - strokeIndex 4 → posición 2 → recibe 1 golpe
  - ...
  - strokeIndex 14 → posición 7 → recibe 1 golpe
  - strokeIndex 16 → posición 8 → recibe 0 golpes

### 3.3 Sistema Stableford

#### 3.3.1 Cálculo de Golpes Netos

```typescript
net_strokes = gross_strokes - strokes_received
```

#### 3.3.2 Puntos Stableford

```typescript
function calculateStablefordPoints(netStrokes, par) {
  const difference = netStrokes - par;

  if (difference >= 2)  return 0;  // Doble bogey o peor
  if (difference === 1)  return 1;  // Bogey
  if (difference === 0)  return 2;  // Par
  if (difference === -1) return 3;  // Birdie
  if (difference === -2) return 4;  // Eagle
  if (difference <= -3)  return 5;  // Albatros o mejor
}
```

**Tabla de Puntos:**

| Resultado          | Diferencia | Puntos |
|--------------------|------------|--------|
| Albatros o mejor   | -3 o menos | 5      |
| Eagle              | -2         | 4      |
| Birdie             | -1         | 3      |
| Par                | 0          | 2      |
| Bogey              | +1         | 1      |
| Doble bogey o peor | +2 o más   | 0      |

### 3.4 Score To Par Personal

```typescript
function calculateScoreToPar(totalGrossStrokes, coursePar, playerHandicap, numHoles) {
  const personalPar = coursePar + playerHandicap;
  const scoreToPar = totalGrossStrokes - personalPar;

  let display;
  if (scoreToPar === 0) {
    display = 'PAR';
  } else if (scoreToPar > 0) {
    display = `+${scoreToPar}`;
  } else {
    display = `${scoreToPar}`;
  }

  return { value: scoreToPar, display };
}
```

### 3.5 Sistema de Ajuste de Handicap DIVEND

**Reglas:**
1. Ordenar jugadores por puntos Stableford (mayor a menor)
2. Desempate por handicap más bajo
3. Dividir en dos mitades

**Para número PAR de jugadores:**
```
Primera mitad (ganadores): handicap - 1 (mínimo 0)
Segunda mitad (perdedores): handicap + 1 (máximo +1 si handicap < 12)
```

**Para número IMPAR de jugadores:**
```
Primera mitad: handicap - 1 (mínimo 0)
Jugador del medio: sin cambio
Segunda mitad: handicap + 1 (máximo +1 si handicap < 12)
```

### 3.6 Sistema de Cervezas

**Reglas:**
1. Primera mitad recibe 1 cerveza
2. Segunda mitad paga 1 cerveza
3. Jugador del medio (si impar): no paga ni recibe

**Ejemplo con 5 jugadores:**
```
Posición 1: +1 cerveza (recibe)
Posición 2: +1 cerveza (recibe)
Posición 3: 0 cervezas (medio)
Posición 4: -1 cerveza (paga)
Posición 5: -1 cerveza (paga)
```

---

## 4. PREMIOS DIVEND

### 4.1 Premios Regulares

#### Patrocinador
El jugador que más cervezas ha pagado en total.

#### Barra Libre
El jugador que más cervezas ha recibido en total.

#### El Corto
El jugador con más "No pasó rojas" acumulados.

#### Driver de Oro
El jugador con más birdies (netos) acumulados.

### 4.2 Rankings Estadísticos

#### La Máquina
Mayor número de birdies (netos) totales.

#### El Topo
Mayor número de eagles (netos) totales.

#### Rey del Bosque
Mayor número de dobles bogeys o peor.

#### Francotirador
Mayor número de pares conseguidos.

#### El Viciado
Jugador con más partidas jugadas.

#### Metrónomo
Mayor porcentaje de pares sobre hoyos totales jugados.

#### Shark
Mayor porcentaje de birdies sobre hoyos totales jugados.

#### Amigo del +1
Mayor número de bogeys totales.

### 4.3 Premios Especiales

#### La Paliza
Mayor diferencia de puntos entre el 1º y el último en una misma partida.

#### Hoyo Muerte
Hoyo con menor promedio de puntos Stableford (por campo).

#### Hoyo Gloria
Hoyo con mayor promedio de puntos Stableford (por campo).

#### Mejor Ronda Campo
Mayor puntuación Stableford en un campo específico.

---

## 5. FLUJOS DE NEGOCIO

### 5.1 Flujo de Partida Rápida (Quick Play)

1. Usuario sin grupo accede a la app
2. Selecciona campo y número de hoyos
3. Añade jugadores con handicaps
4. Configura slope (opcional)
5. Sistema calcula handicaps de juego
6. Jugadores introducen puntuaciones hoyo a hoyo
7. Sistema calcula automáticamente:
   - Golpes recibidos
   - Golpes netos
   - Puntos Stableford
8. Finaliza partida y muestra resumen con premios

### 5.2 Flujo de Multipartideta (Grupo)

1. Creador genera grupo con código único
2. Jugadores se unen con el código
3. Cualquier miembro puede crear partidas
4. Sistema genera código de acceso de 4 dígitos
5. Jugadores se unen a la partida con el código
6. Al finalizar, la partida se archiva
7. Sistema calcula:
   - Ranking diario
   - Ajustes de handicap
   - Cervezas pagadas/recibidas
   - Estadísticas acumuladas
8. Actualiza todos los premios DIVEND

### 5.3 Cambio de Campo Durante Partida

1. Usuario solicita cambio de campo
2. Sistema detecta cambio de 9↔18 hoyos
3. Recalcula handicaps:
   - 9→18: multiplica por 2
   - 18→9: divide por 2
4. Recalcula handicaps de juego con nuevo slope
5. Recalcula todas las puntuaciones existentes
6. Actualiza golpes recibidos por hoyo

---

## 6. LIBRERIAS EXTERNAS

### 6.1 Dependencias de Producción

```json
{
  "@supabase/supabase-js": "^2.57.4",    // Cliente de Supabase
  "lucide-react": "^0.344.0",            // Iconos SVG
  "react": "^18.3.1",                    // Framework UI
  "react-dom": "^18.3.1"                 // React DOM
}
```

### 6.2 Dependencias de Desarrollo

```json
{
  "@eslint/js": "^9.9.1",                      // Core ESLint
  "@types/react": "^18.3.5",                   // Tipos React
  "@types/react-dom": "^18.3.0",               // Tipos React DOM
  "@vitejs/plugin-react": "^4.3.1",            // Plugin Vite
  "autoprefixer": "^10.4.18",                  // PostCSS
  "eslint": "^9.9.1",                          // Linter
  "eslint-plugin-react-hooks": "^5.1.0-rc.0",  // Reglas hooks
  "eslint-plugin-react-refresh": "^0.4.11",    // HMR React
  "globals": "^15.9.0",                        // Globals JS
  "postcss": "^8.4.35",                        // CSS processor
  "tailwindcss": "^3.4.1",                     // Framework CSS
  "typescript": "^5.5.3",                      // TypeScript
  "typescript-eslint": "^8.3.0",               // ESLint TS
  "vite": "^5.4.2"                             // Bundler
}
```

### 6.3 Configuraciones Importantes

#### TypeScript (tsconfig.json)
- **target**: ES2020
- **module**: ESNext
- **strict**: true
- **skipLibCheck**: true

#### Vite (vite.config.ts)
- **port**: 3000 (dev)
- **open**: true (auto-abrir navegador)
- **React plugin** con Fast Refresh

#### Tailwind CSS
- Configuración completa en `tailwind.config.js`
- PostCSS con autoprefixer
- JIT mode habilitado

---

## 7. VARIABLES DE ENTORNO

### 7.1 Variables Requeridas (.env)

```bash
# Supabase
VITE_SUPABASE_URL=https://[PROJECT_ID].supabase.co
VITE_SUPABASE_ANON_KEY=[ANON_KEY]

# Opcional
VITE_ADMIN_PIN=[PIN_DE_4_DIGITOS]
```

### 7.2 Acceso en el Código

```typescript
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
```

---

## 8. SEGURIDAD

### 8.1 Row Level Security (RLS)

**Todas las tablas tienen RLS habilitado.**

Políticas principales:
- Usuarios autenticados pueden leer/escribir sus propios datos
- Grupos: solo miembros pueden ver/modificar
- Partidas: públicas con código de acceso
- Estadísticas: solo lectura para miembros del grupo

### 8.2 Autenticación

- Sistema email/password de Supabase
- Sin confirmación de email (desarrollo)
- Sesiones persistentes en localStorage
- Auto-login al abrir la app

---

## 9. CONSIDERACIONES TECNICAS

### 9.1 LocalStorage

Se usa para:
- ID de usuario anónimo (sin auth)
- Grupo actual
- Cache temporal de partidas activas

### 9.2 Realtime

Supabase Realtime activado para:
- `round_scores` - Actualización de puntuaciones en vivo
- `golf_rounds` - Estado de partidas
- `round_players` - Jugadores en partida

### 9.3 Códigos de Acceso

**Formato:** 4 dígitos mayúsculas y números
**Ejemplo:** AB1C, XY9Z, 1234

Generación:
```typescript
function generateAccessCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
```

### 9.4 Números de Referencia

Cada partida tiene un `reference_number` único y secuencial por grupo.
Se usa para identificar partidas de forma amigable (Partida #1, #2, etc.).

---

## 10. DEPLOYMENT

### 10.1 Build de Producción

```bash
npm run build
```

Genera carpeta `dist/` con:
- HTML minificado
- CSS optimizado con Tailwind purge
- JS bundled y tree-shaken
- Assets optimizados

### 10.2 Netlify

Archivo `_redirects` en `/public`:
```
/*    /index.html   200
```

Para manejar el routing de SPA.

---

## 11. TESTING Y CALIDAD

### 11.1 Scripts NPM

```json
{
  "dev": "vite",                  // Servidor desarrollo
  "build": "vite build",          // Build producción
  "lint": "eslint .",             // Linting
  "preview": "vite preview",      // Preview build
  "typecheck": "tsc --noEmit"     // Verificación tipos
}
```

### 11.2 Buenas Prácticas Implementadas

- TypeScript estricto en todo el código
- Componentes funcionales con hooks
- Separación de lógica de negocio (services)
- Utilidades reutilizables (utils)
- Interfaces bien definidas
- Manejo de errores consistente
- Loading states en todas las operaciones async

---

## 12. MIGRACIONES DE BASE DE DATOS

### 12.1 Sistema de Migraciones

Todas las migraciones en `supabase/migrations/`

**Formato:** `YYYYMMDDHHMMSS_descripcion.sql`

**Último estado:**
- 151 migraciones aplicadas
- Sistema de handicap v3 con playing_handicap
- Sistema de rankings diarios
- Sistema de premios DIVEND completo
- Sistema de temporadas (seasons)

### 12.2 Funciones RPC Principales

1. **calculate_daily_ranking** - Calcula ranking del día
2. **get_patrocinador_ranking** - Ranking de cervezas pagadas
3. **get_barra_libre_ranking** - Ranking de cervezas recibidas
4. **get_corto_ranking** - Ranking de "no pasó rojas"
5. **get_driver_oro_ranking** - Ranking de birdies
6. **get_killer_ranking** - Más victorias
7. **get_maquina_ranking** - Más birdies totales
8. **get_topo_ranking** - Más eagles
9. **get_rey_del_bosque_ranking** - Más dobles bogeys
10. **get_detailed_player_statistics** - Estadísticas completas

---

## 13. PROXIMOS PASOS Y MEJORAS FUTURAS

### 13.1 Funcionalidades Pendientes

- Sistema de notificaciones push
- Export de estadísticas a PDF
- Gráficos de evolución de handicap
- Comparativas entre jugadores
- Sistema de torneos
- Integración con APIs de campos reales

### 13.2 Optimizaciones Técnicas

- Implementar cache con React Query
- Lazy loading de componentes pesados
- Optimización de imágenes
- Service Worker para PWA
- Tests unitarios y E2E

---

## 14. CONTACTO Y MANTENIMIENTO

### 14.1 Responsables

- **Desarrollo**: Equipo DIVEND
- **Base de Datos**: Supabase (alojado)
- **Frontend**: React + Vite

### 14.2 Recursos

- **Repositorio**: [URL del repo]
- **Documentación Supabase**: https://supabase.com/docs
- **Documentación React**: https://react.dev
- **Documentación Vite**: https://vitejs.dev

---

## APENDICE A: CAMPOS DE GOLF CONFIGURADOS

### Costa Azahar Golf - Tee Verde (9 hoyos)
- **Slope 1-9:** 103
- **Slope 10-18:** 106
- **Par Total:** 34 (9 hoyos)

### Costa Azahar Golf - Tee Rojo (9 hoyos)
- **Slope 1-9:** 93
- **Slope 10-18:** 96
- **Par Total:** 34 (9 hoyos)

### Mediterráneo Golf (18 hoyos)
- **Slope 18 hoyos:** 130
- **Slope 1-9:** 65
- **Slope 10-18:** 65
- **Par Total:** 72

### Panorámica Golf (18 hoyos)
- **Slope 18 hoyos:** 134
- **Slope 1-9:** 67
- **Slope 10-18:** 67
- **Par Total:** 72

---

## APENDICE B: EJEMPLO DE CALCULO COMPLETO

### Escenario
- **Jugador**: Juan (Handicap exacto 9 hoyos: 6)
- **Campo**: Costa Azahar Verde
- **Partida**: 9 hoyos
- **Slope**: 103

### Paso 1: Calcular Handicap de Juego
```
playing_handicap = 6 × (103 / 113) = 6 × 0.9115 = 5.47 → 5
```

### Paso 2: Golpes por Hoyo (Ejemplo Hoyo 1, strokeIndex: 2)
```
fullStrokes = floor(5 / 9) = 0
remainder = 5 % 9 = 5
strokeIndex = 2 (normalizado)

Golpes recibidos = 2 <= 5 ? 0 + 1 : 0 = 1
```

### Paso 3: Calcular Puntos (Par 4, 5 golpes brutos)
```
net_strokes = 5 - 1 = 4
difference = 4 - 4 = 0
stableford_points = 2 (par)
```

---

**FIN DEL DOCUMENTO**

Este documento es una referencia técnica completa del sistema DIVEND Golf App.
Mantener actualizado con cada cambio mayor en la arquitectura o lógica de negocio.
