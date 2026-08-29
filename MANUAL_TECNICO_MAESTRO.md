# MANUAL TÉCNICO MAESTRO - Aplicación de Golf Scoring

**Versión:** 1.0
**Fecha:** 10 de enero de 2026
**Propósito:** Documento maestro para migración, mantenimiento y comprensión completa del sistema

---

## 📋 ÍNDICE

1. [Visión y Lógica](#1-visión-y-lógica)
2. [Arquitectura y Datos](#2-arquitectura-y-datos)
3. [Infraestructura para la Migración](#3-infraestructura-para-la-migración)
4. [Estructura de Archivos](#4-estructura-de-archivos)
5. [Guía de Mantenimiento](#5-guía-de-mantenimiento)
6. [Auditoría de Independencia](#6-auditoría-de-independencia)
7. [Solución de Problemas](#7-solución-de-problemas)

---

## 1. VISIÓN Y LÓGICA

### 1.1 Objetivo del Proyecto

**Problema que Resuelve:**
La aplicación resuelve la complejidad de llevar puntuación en partidas de golf usando el sistema Stableford, calculando automáticamente handicaps de juego, golpes recibidos por hoyo, y puntuaciones netas. Además, gestiona múltiples partidas simultáneas, grupos de jugadores y estadísticas históricas.

**Usuarios Objetivo:**
- **Jugadores Casuales:** Quieren hacer "Quick Play" (partida rápida) sin necesidad de crear grupos
- **Grupos de Amigos:** Necesitan gestionar múltiples partidas, estadísticas acumuladas, rankings y premios especiales
- **Administradores de Grupo:** Personas que crean y gestionan grupos privados con códigos de acceso

### 1.2 Flujos Críticos

#### FLUJO 1: Quick Play (Partida Rápida Individual)

**Objetivo:** Permitir a un usuario jugar una partida rápida sin crear grupos ni autenticarse.

**Pasos:**

1. **Usuario entra a la app**
   - El sistema genera un `userId` único en localStorage
   - Se muestra el menú principal con opción "Quick Play"

2. **Usuario selecciona "Quick Play"**
   - Sistema verifica si existe partida activa (status='active', group_id=null)
   - Si existe: carga la partida activa
   - Si no existe: permite crear nueva partida

3. **Crear nueva partida (RoundSetup)**
   - Usuario selecciona:
     - Campo de golf (de lista precargada)
     - Número de hoyos (9 o 18)
     - Si usar Slope o no
     - Si usar Slope, selecciona Tee (color)
   - Sistema crea registro en `golf_rounds` con status='active'
   - Genera código de acceso único de 4 dígitos

4. **Añadir jugadores (PlayerSetup)**
   - Usuario añade jugadores con nombre y handicap exacto (9 hoyos)
   - Para 18 hoyos, sistema multiplica handicap x2
   - Si usa Slope: calcula handicap de juego con fórmula `(handicap * slope) / 113`
   - Si no usa Slope: handicap de juego = redondeo del handicap exacto
   - Crea registros en `round_players`

5. **Anotar puntuaciones (Scorecard)**
   - Usuario registra golpes brutos por hoyo para cada jugador
   - Sistema calcula automáticamente:
     - Golpes recibidos = según stroke index del hoyo y handicap de juego
     - Golpes netos = golpes brutos - golpes recibidos
     - Puntos Stableford = según tabla (Eagle=4, Birdie=3, Par=2, Bogey=1, +2=0)
   - Permite marcar "No pasó de rojas" (bandera roja)
   - Guarda en `round_scores` con upsert (actualiza si ya existe)

6. **Ver clasificación (Leaderboard)**
   - Muestra ranking en tiempo real ordenado por puntos totales
   - Indica hoyos jugados por cada jugador
   - Botón para "Finalizar Partida"

7. **Finalizar partida**
   - Cambia status a 'completed'
   - Redirige a estadísticas de Quick Play

8. **Ver estadísticas (QuickPlayStatistics)**
   - Muestra pantalla tipo "Game Over" de videojuego
   - Podio con top 3 jugadores
   - Highlights: MVP, Mejor/Peor Hoyo, Birdie King, Montaña Rusa, La Paliza
   - Gráfico de barras comparativo
   - Tabla completa de estadísticas
   - Premios especiales (Rey del Bosque, No Pasó de Rojas, Hoyo en Uno, etc.)
   - Botón para eliminar partida

#### FLUJO 2: Multipartidetas (Grupos con Estadísticas)

**Objetivo:** Gestionar grupos privados con múltiples partidas, estadísticas acumuladas y rankings.

**Pasos:**

1. **Crear o unirse a grupo**
   - **Crear grupo:** Usuario genera código único de 4 letras, opcionalmente nombre
   - **Unirse:** Usuario introduce código de grupo existente
   - Sistema guarda `groupId` en localStorage

2. **Autenticación (opcional pero recomendada)**
   - Usuario puede autenticarse con email/password (Supabase Auth)
   - Vincula grupos creados al `user_auth_id`
   - Permite acceso desde múltiples dispositivos

3. **Gestión de jugadores permanentes**
   - Grupo tiene lista de jugadores en tabla `players` con `group_id`
   - Cada jugador tiene:
     - Nombre
     - Handicap exacto (9 hoyos)
     - Handicap 18 hoyos (mismo valor, para compatibilidad)
   - Jugadores persisten entre partidas

4. **Crear partida en grupo**
   - Similar a Quick Play pero con `group_id` asignado
   - Genera número de referencia secuencial por grupo
   - Puede seleccionar jugadores existentes o crear nuevos

5. **Ver partidas activas del grupo**
   - Lista todas las partidas con status='active' o 'completed' del grupo
   - Muestra número de referencia, campo, fecha, jugadores
   - Permite unirse con código de acceso

6. **Archivar partida (solo creador)**
   - Calcula estadísticas completas (eagles, birdies, pares, bogeys, etc.)
   - Guarda en `archived_rounds` con:
     - Ranking final
     - Estadísticas por jugador
     - Puntuaciones por hoyo
     - Cervezas ganadas/pagadas (top 50% gana, bottom 50% paga)
   - Ajusta handicaps automáticamente:
     - Top 50% → baja 1 punto
     - Bottom 50% → sube 1 punto (máximo 12)
     - Si impar, el del medio no cambia
   - Calcula rankings diarios en tabla `daily_rankings`
   - Elimina la partida activa

7. **Ver estadísticas del grupo**
   - Rankings generales (total puntos, promedio, victorias, podios)
   - Rankings especiales (DIVEND: Patrocinador, Barra Libre, Corto, Driver de Oro)
   - Premios específicos (Killer, Paquete, Shark, Metrónomo, Viciado, etc.)
   - Estadísticas por campo (Hoyo de la Muerte, Hoyo de la Gloria, Mejor Ronda)
   - Historial de handicaps
   - Partidas archivadas con detalle

#### FLUJO 3: Administración de Sistema

**Objetivo:** Permitir al administrador gestionar campos de golf, hoyos y configuraciones globales.

**Pasos:**

1. **Acceso a panel de administración**
   - Usuario introduce PIN de administrador (4 dígitos)
   - Variable de entorno: `VITE_ADMIN_PIN`
   - Solo email autorizado: `VITE_ADMIN_EMAIL`

2. **Gestionar campos de golf**
   - Ver lista de campos existentes
   - Añadir nuevos campos
   - Editar información de campos

3. **Configurar hoyos**
   - Ver hoyos del campo (1-18)
   - Editar par de cada hoyo (3, 4 o 5)
   - Editar stroke index (1-18, indica dificultad)
   - Configurar slopes por Tee (18 hoyos, 9 hoyos primera mitad, 9 hoyos segunda mitad)

4. **Gestionar Tees**
   - Añadir/editar Tees (colores de salida)
   - Configurar slopes para cada Tee

---

## 2. ARQUITECTURA Y DATOS

### 2.1 Stack Tecnológico

#### Frontend

**Framework Principal:**
- **React 18.3.1** - Biblioteca para construir interfaces de usuario
  - Elección: Amplia comunidad, excelente documentación, rico ecosistema
  - Hooks para gestión de estado local
  - No usa Redux ni Context API complejo (estado en componentes)

**Build Tool:**
- **Vite 5.4.2** - Build tool moderno y rápido
  - Elección: Hot Module Replacement instantáneo, builds optimizados
  - Configuración mínima
  - Mejor experiencia de desarrollo que Create React App

**Lenguaje:**
- **TypeScript 5.5.3** - Superset tipado de JavaScript
  - Elección: Seguridad de tipos, mejor autocompletado, menos errores en runtime
  - Interfaces claras para modelos de datos

**Estilos:**
- **Tailwind CSS 3.4.1** - Framework CSS utility-first
  - Elección: Desarrollo rápido, estilos consistentes, bundle pequeño
  - No requiere archivos CSS separados
  - Clases reutilizables

**Iconos:**
- **Lucide React 0.344.0** - Biblioteca de iconos SVG
  - Elección: Iconos modernos y limpios, tree-shakeable
  - No requiere Font Awesome ni Material Icons

#### Backend/Database

**BaaS (Backend as a Service):**
- **Supabase** - Alternativa open source a Firebase
  - Elección: PostgreSQL real, RLS nativo, Auth integrado, Realtime, Edge Functions
  - No vendor lock-in (puedes autoalojarlo)
  - SQL completo (no NoSQL limitado como Firebase)

**Cliente Supabase:**
- **@supabase/supabase-js 2.57.4** - SDK oficial de JavaScript
  - Gestión de autenticación
  - Consultas a base de datos (similar a ORM)
  - Subscripciones en tiempo real
  - Storage (no usado actualmente)

#### Herramientas de Desarrollo

**Linter:**
- **ESLint 9.9.1** - Linter de JavaScript/TypeScript
- **eslint-plugin-react-hooks** - Reglas para hooks de React
- **typescript-eslint** - Reglas para TypeScript

**Otros:**
- **PostCSS 8.4.35** - Procesador CSS (requerido por Tailwind)
- **Autoprefixer 10.4.18** - Añade prefijos de navegador automáticamente

### 2.2 Base de Datos - Esquema Completo

**Motor:** PostgreSQL 15+ (via Supabase)

#### Diagrama de Relaciones

```
┌─────────────────┐
│  golf_courses   │
│  ─────────────  │
│  id (PK)        │
│  name           │
│  description    │
│  created_at     │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼────────┐         ┌─────────────────┐
│   golf_holes    │         │      tees       │
│  ─────────────  │         │  ─────────────  │
│  id (PK)        │         │  id (PK)        │
│  course_id (FK) │         │  course_id (FK) │
│  hole_number    │         │  name           │
│  par            │         │  color          │
│  stroke_index   │         │  slope_18       │
│  created_at     │         │  slope_9_i      │
│  updated_at     │         │  slope_9_ii     │
└─────────────────┘         │  created_at     │
                            └────────┬────────┘
                                     │
                                     │ 1:N
┌─────────────────┐                 │
│     groups      │         ┌───────▼─────────┐
│  ─────────────  │         │  golf_rounds    │
│  id (PK)        │◄────────┤  ─────────────  │
│  name           │  1:N    │  id (PK)        │
│  group_code     │         │  course_id (FK) │
│  created_by     │         │  created_by     │
│  user_auth_id   │         │  user_id        │
│  created_at     │         │  group_id (FK)  │
└─────────────────┘         │  tee_id (FK)    │
         │                  │  num_holes      │
         │ 1:N              │  holes_range    │
         │                  │  use_slope      │
┌────────▼────────┐         │  manual_slope   │
│     players     │         │  status         │
│  ─────────────  │         │  reference_num  │
│  id (PK)        │         │  access_code    │
│  name           │         │  created_at     │
│  exact_hcp      │         │  updated_at     │
│  exact_hcp_18   │         │  completed_at   │
│  group_id (FK)  │         └────────┬────────┘
│  created_at     │                  │
│  updated_at     │                  │ 1:N
└─────────────────┘                  │
                            ┌────────▼────────┐
                            │ round_players   │
                            │  ─────────────  │
                            │  id (PK)        │
                            │  round_id (FK)  │
                            │  player_id (FK) │
                            │  name           │
                            │  exact_hcp      │
                            │  exact_hcp_18   │
                            │  playing_hcp    │
                            │  created_at     │
                            └────────┬────────┘
                                     │
                                     │ 1:N
                                     │
                            ┌────────▼────────┐
                            │  round_scores   │
                            │  ─────────────  │
                            │  id (PK)        │
                            │  round_id (FK)  │
                            │  player_id (FK) │
                            │  hole_number    │
                            │  gross_strokes  │
                            │  strokes_rcvd   │
                            │  net_strokes    │
                            │  stableford_pts │
                            │  no_paso_rojas  │
                            │  created_at     │
                            │  updated_at     │
                            └─────────────────┘

┌─────────────────┐
│ archived_rounds │
│  ─────────────  │
│  id (PK)        │
│  group_id (FK)  │
│  course_name    │
│  played_at      │
│  final_ranking  │ JSONB
│  player_stats   │ JSONB
│  hole_scores    │ JSONB
│  season_id (FK) │
│  archived_at    │
└─────────────────┘

┌─────────────────┐
│ daily_rankings  │
│  ─────────────  │
│  id (PK)        │
│  group_id (FK)  │
│  player_name    │
│  ranking_date   │
│  total_points   │
│  position       │
│  playing_hcp    │
│  receives_beer  │
│  pays_beer      │
│  created_at     │
└─────────────────┘

┌─────────────────┐
│    seasons      │
│  ─────────────  │
│  id (PK)        │
│  group_id (FK)  │
│  name           │
│  start_date     │
│  end_date       │
│  created_at     │
└─────────────────┘

┌─────────────────┐
│   beer_stats    │
│  ─────────────  │
│  id (PK)        │
│  round_id       │
│  player_id      │
│  player_name    │
│  status         │ 'payer'|'receiver'
│  created_at     │
└─────────────────┘

┌─────────────────┐
│ admin_config    │
│  ─────────────  │
│  id (PK)        │
│  key            │
│  value          │
│  created_at     │
│  updated_at     │
└─────────────────┘

┌─────────────────────────┐
│completed_rounds_summary │
│  ─────────────────────  │
│  id (PK)                │
│  round_id               │
│  user_id                │
│  group_id               │
│  course_name            │
│  num_holes              │
│  holes_range            │
│  use_slope              │
│  completed_at           │
│  player_stats (JSONB)   │
│  total_players          │
│  created_at             │
└─────────────────────────┘
```

#### Tablas Principales (Descripción Detallada)

**1. golf_courses**
- Almacena los campos de golf disponibles
- **Campos obligatorios:** `name`
- **Ejemplo:** "Costa Azahar Verde", "Panorámica Golf"

**2. golf_holes**
- Define los hoyos de cada campo (1-18)
- **Campos obligatorios:** `course_id`, `hole_number`, `par`, `stroke_index`
- **stroke_index:** Indica dificultad del hoyo (1=más difícil, 18=más fácil)
- **par:** Solo permite valores 3, 4 o 5
- **Constraint único:** No puede haber dos hoyos con mismo número en un campo

**3. tees**
- Diferentes salidas (colores) de un campo
- **Campos obligatorios:** `course_id`, `name`, `slope_18`, `slope_9_i`, `slope_9_ii`
- **slope_18:** Slope para 18 hoyos
- **slope_9_i:** Slope para hoyos 1-9
- **slope_9_ii:** Slope para hoyos 10-18
- **Ejemplo:** Tee Rojo (slope_18=113), Tee Amarillo (slope_18=120)

**4. golf_rounds**
- Partida de golf activa o completada
- **Campos obligatorios:** `course_id`, `user_id`, `num_holes`, `status`
- **user_id:** ID generado localmente (no auth.users)
- **group_id:** NULL para Quick Play, UUID para Multipartidetas
- **tee_id:** NULL si no usa Slope, UUID si usa Slope
- **manual_slope:** NULL si usa Tee, número si se introduce slope manual
- **num_holes:** Solo permite 9 o 18
- **holes_range:** '1-9' o '10-18' si se juegan 9 hoyos específicos, NULL para 18 o 1-9 por defecto
- **status:** 'active' (en juego), 'completed' (finalizada), 'cancelled' (cancelada)
- **reference_number:** Número secuencial dentro del grupo (calculado automáticamente)
- **access_code:** Código de 4 dígitos generado automáticamente

**5. groups**
- Grupo de jugadores para Multipartidetas
- **Campos obligatorios:** `group_code`
- **group_code:** Código único de 4 letras mayúsculas
- **created_by:** user_id local del creador
- **user_auth_id:** UUID de auth.users si el creador se autentica (permite acceso multi-dispositivo)
- **name:** Nombre opcional del grupo

**6. players**
- Jugadores permanentes de un grupo
- **Campos obligatorios:** `name`, `exact_handicap`, `exact_handicap_18`
- **group_id:** NULL para Quick Play (jugadores temporales), UUID para Multipartidetas
- **exact_handicap:** Handicap de 9 hoyos
- **exact_handicap_18:** Mismo valor que exact_handicap (compatibilidad histórica)
- Los jugadores de Quick Play se eliminan al borrar la partida

**7. round_players**
- Jugadores participantes en una partida específica
- **Campos obligatorios:** `round_id`, `name`, `exact_handicap`, `playing_handicap`
- **player_id:** Referencia a players si es jugador permanente, NULL si es temporal
- **exact_handicap:** Handicap con el que jugó (9 hoyos si partida de 9, 18 hoyos si partida de 18)
- **exact_handicap_18:** Handicap original de 18 hoyos (siempre almacenado)
- **playing_handicap:** Handicap de juego calculado (con o sin Slope)

**8. round_scores**
- Puntuaciones por hoyo de cada jugador
- **Campos obligatorios:** `round_id`, `player_id`, `hole_number`, `gross_strokes`, `net_strokes`, `stableford_points`
- **gross_strokes:** Golpes reales dados (>= 1)
- **strokes_received:** Golpes de ventaja en ese hoyo (calculado según stroke_index y playing_handicap)
- **net_strokes:** gross_strokes - strokes_received
- **stableford_points:** Puntos Stableford (0-4)
- **no_paso_rojas:** Boolean, marca si el jugador no alcanzó las marcas rojas
- **Constraint único:** No puede haber dos puntuaciones para mismo round_id + player_id + hole_number

**9. archived_rounds**
- Partidas archivadas de Multipartidetas
- **Campos JSONB:**
  - **final_ranking:** Array de objetos con position, player_name, points, hcp_juego, handicap
  - **player_stats:** Array con estadísticas detalladas (eagles, birdies, pares, bogeys, beers_won, beers_paid)
  - **hole_scores:** Array con puntuaciones por hoyo de cada jugador
- **season_id:** Vincula la partida a una temporada específica

**10. daily_rankings**
- Ranking calculado por día de juego
- Usado para calcular cervezas (top 50% recibe, bottom 50% paga)
- **Campos obligatorios:** `group_id`, `player_name`, `ranking_date`, `total_points`, `position`

**11. seasons**
- Temporadas de un grupo (ej: "Temporada 2024")
- **Campos obligatorios:** `group_id`, `name`, `start_date`
- **end_date:** NULL si temporada activa, fecha si finalizada

**12. beer_stats**
- Estadísticas de cervezas ganadas/pagadas por partida
- **status:** 'payer' o 'receiver'

**13. admin_config**
- Configuración global del sistema
- **key:** Clave única (ej: "default_slope")
- **value:** Valor JSON

**14. completed_rounds_summary**
- Resumen de partidas completadas (Quick Play)
- Similar a archived_rounds pero para partidas sin grupo
- Permite ver historial de Quick Play sin eliminar datos

#### Funciones de Base de Datos (PostgreSQL)

La aplicación utiliza múltiples funciones SQL para cálculos complejos:

1. **reset_reference_sequence()** - Reinicia el contador de números de referencia
2. **calculate_beer_stats_for_round()** - Calcula cervezas por partida
3. **get_patrocinador_ranking()** - Ranking del que más cervezas paga
4. **get_barra_libre_ranking()** - Ranking del que más cervezas gana
5. **get_corto_ranking()** - Ranking de handicap más bajo promedio
6. **get_driver_oro_ranking()** - Ranking de más eagles
7. **get_detailed_player_statistics()** - Estadísticas detalladas de un jugador
8. **get_killer_ranking()** - Jugador con más victorias
9. **get_paquete_ranking()** - Jugador con más últimos puestos
10. **get_shark_ranking()** - Más birdies en partidas
11. **get_metronomo_ranking()** - Menor variabilidad en puntuaciones
12. **get_viciado_ranking()** - Más partidas jugadas
13. **get_francotirador_ranking()** - Más eagles totales
14. **get_maquina_ranking()** - Más pares conseguidos
15. **get_amigo_del_mas_uno_ranking()** - Más bogeys
16. **get_rey_del_bosque_ranking()** - Más doble bogeys+
17. **get_topo_ranking()** - Más banderas rojas
18. **get_la_paliza()** - Mayor diferencia ganador vs último
19. **get_head_to_head()** - Cara a cara entre dos jugadores
20. **get_hoyo_muerte()** - Hoyo más difícil de un campo
21. **get_hoyo_gloria()** - Hoyo más fácil de un campo
22. **get_mejor_ronda_campo()** - Mejor puntuación en un campo

### 2.3 Autenticación y Sesiones

**Sistema Actual: Dual Track**

La aplicación usa dos sistemas de identificación:

#### 1. Sistema Local (Sin Autenticación)
- **userId:** Generado con `crypto.randomUUID()` o fallback `Date.now() + Math.random()`
- **Almacenamiento:** localStorage con key `golf_user_id`
- **Uso:** Quick Play, identificación básica
- **Limitación:** No sincroniza entre dispositivos

**Código:**
```typescript
// src/utils/userId.ts
export const getUserId = (): string => {
  const storageKey = 'golf_user_id';
  let userId = localStorage.getItem(storageKey);

  if (!userId) {
    userId = crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`;
    localStorage.setItem(storageKey, userId);
  }

  return userId;
};
```

#### 2. Sistema de Autenticación (Supabase Auth)
- **Email/Password:** Autenticación tradicional
- **Almacenamiento:** Supabase gestiona tokens JWT en localStorage
- **Key:** `supabase.auth.token`
- **Uso:** Multipartidetas, sincronización multi-dispositivo
- **Beneficio:** Acceso a grupos desde cualquier dispositivo

**Flujo de Autenticación:**

1. Usuario se registra con email/password
2. Supabase crea registro en `auth.users`
3. Sistema vincula grupos existentes (`created_by` = userId) a `user_auth_id`
4. Usuario puede acceder desde otros dispositivos con mismo email
5. Sistema recupera grupos usando `user_auth_id`

**Gestión de Sesiones:**

```typescript
// Verificación de sesión
const { data: { user } } = await supabase.auth.getUser();

// Listener de cambios
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') {
    // Vincular grupos a usuario autenticado
    golfService.linkGroupsToAuthUser();
  }
  if (event === 'SIGNED_OUT') {
    // Mantener grupos locales
  }
});
```

**Políticas RLS (Row Level Security):**

Todas las tablas tienen RLS habilitado. Ejemplos:

```sql
-- Acceso público a campos de golf
CREATE POLICY "Anyone can view golf courses"
  ON golf_courses FOR SELECT
  TO anon, authenticated
  USING (true);

-- Solo ver partidas propias o de grupo
CREATE POLICY "Users can view rounds they created"
  ON golf_rounds FOR SELECT
  TO authenticated
  USING (created_by = auth.uid() OR group_id IN (
    SELECT id FROM groups WHERE created_by = auth.uid()
  ));
```

**Seguridad de Datos:**

1. **RLS Obligatorio:** Toda tabla tiene RLS activado
2. **Políticas Restrictivas:** Por defecto, nadie accede; se permite explícitamente
3. **Validaciones:**
   - Checks en columnas (ej: `num_holes IN (9,18)`)
   - Foreign keys con CASCADE/SET NULL apropiado
   - Unique constraints para evitar duplicados

---

## 3. INFRAESTRUCTURA PARA LA MIGRACIÓN

### 3.1 Variables de Entorno (.env)

**ARCHIVO REQUERIDO:** `.env` en la raíz del proyecto

**Variables Obligatorias:**

```bash
# ===== SUPABASE =====
# URL del proyecto de Supabase
VITE_SUPABASE_URL=https://[tu-proyecto].supabase.co

# Anon Key de Supabase (pública, segura para el frontend)
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# ===== ADMINISTRACIÓN =====
# Email del administrador que puede acceder al panel admin
VITE_ADMIN_EMAIL=admin@tudominio.com

# PIN de 4 dígitos para acceder al panel de administración
VITE_ADMIN_PIN=1234
```

**Dónde Obtener Estas Claves:**

#### SUPABASE_URL y SUPABASE_ANON_KEY

1. Ve a [supabase.com](https://supabase.com)
2. Crea un nuevo proyecto (o usa uno existente)
3. En el Dashboard → Settings → API
4. Copia:
   - **Project URL** → `VITE_SUPABASE_URL`
   - **anon public** → `VITE_SUPABASE_ANON_KEY`

⚠️ **IMPORTANTE:** La `anon key` es PÚBLICA y segura para usar en el frontend. La seguridad se controla con RLS en la base de datos.

#### ADMIN_EMAIL y ADMIN_PIN

- Define tú mismo estos valores
- El email debe coincidir con un usuario autenticado en Supabase
- El PIN puede ser cualquier número de 4 dígitos

**Ejemplo Completo de .env:**

```bash
VITE_SUPABASE_URL=https://xyzabc123.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5emFiYzEyMyIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE5NzUwMDAwMDB9.AbCdEfGhIjKlMnOpQrStUvWxYz
VITE_ADMIN_EMAIL=tu@email.com
VITE_ADMIN_PIN=2248
```

### 3.2 Configuración de Supabase

#### Paso 1: Crear Proyecto en Supabase

1. Ve a [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click en "New Project"
3. Rellena:
   - **Name:** Nombre de tu proyecto (ej: "golf-scoring")
   - **Database Password:** Genera una segura (guárdala)
   - **Region:** Selecciona la más cercana a tus usuarios
4. Espera 2-3 minutos mientras se crea el proyecto

#### Paso 2: Aplicar Migraciones

Las migraciones están en `/supabase/migrations/` ordenadas por fecha.

**Opción A: Aplicar Manualmente (Recomendado para Primera Vez)**

1. En Supabase Dashboard → SQL Editor
2. Crea nueva query
3. Copia y pega el contenido de cada archivo .sql en orden cronológico:
   - `20251129032653_create_golf_schema.sql` (primero)
   - `20251129033014_seed_default_course.sql`
   - `20251130220101_allow_public_access.sql`
   - ... (todos los demás en orden)
4. Ejecuta cada query con RUN

**Opción B: Supabase CLI (Para Usuarios Avanzados)**

```bash
# Instalar Supabase CLI
npm install -g supabase

# Login
supabase login

# Vincular proyecto
supabase link --project-ref [tu-project-ref]

# Aplicar todas las migraciones
supabase db push
```

⚠️ **ORDEN IMPORTANTE:** Las migraciones deben aplicarse en orden cronológico (nombre de archivo). Cada una depende de las anteriores.

#### Paso 3: Configurar Autenticación (Opcional)

Si quieres habilitar autenticación email/password:

1. Supabase Dashboard → Authentication → Settings
2. **Email Auth:** Activar "Enable Email Signup"
3. **Email Templates:** Personalizar plantillas de confirmación (opcional)
4. **Site URL:** `http://localhost:5173` (desarrollo) o tu dominio (producción)
5. **Redirect URLs:** Añadir:
   - `http://localhost:5173/**`
   - `https://tudominio.com/**`

#### Paso 4: Poblar Campos de Golf Iniciales

Los campos de golf se crean con las migraciones, pero puedes añadir más:

```sql
-- Ejemplo: Añadir nuevo campo
INSERT INTO golf_courses (name, description) VALUES
  ('Nombre del Campo', 'Descripción opcional');

-- Obtener el ID del campo recién creado
SELECT id FROM golf_courses WHERE name = 'Nombre del Campo';

-- Añadir hoyos (ejemplo para 9 hoyos)
INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
  ('[id-del-campo]', 1, 4, 5),
  ('[id-del-campo]', 2, 3, 7),
  ('[id-del-campo]', 3, 5, 1),
  ('[id-del-campo]', 4, 4, 3),
  ('[id-del-campo]', 5, 4, 9),
  ('[id-del-campo]', 6, 3, 11),
  ('[id-del-campo]', 7, 5, 13),
  ('[id-del-campo]', 8, 4, 15),
  ('[id-del-campo]', 9, 4, 17);

-- Añadir Tees (ejemplo)
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
  ('[id-del-campo]', 'Rojo', 'red', 113, 113, 113),
  ('[id-del-campo]', 'Amarillo', 'yellow', 120, 120, 120);
```

### 3.3 Comandos de Despliegue

#### Desarrollo Local

```bash
# 1. Instalar dependencias (primera vez)
npm install

# 2. Configurar variables de entorno
# Crear archivo .env en la raíz con las variables de Supabase

# 3. Iniciar servidor de desarrollo
npm run dev

# La app se abrirá en http://localhost:5173
# Hot reload automático al guardar cambios
```

#### Construcción para Producción

```bash
# 1. Construir la aplicación
npm run build

# Output: Carpeta /dist con archivos optimizados
# - HTML minificado
# - CSS inlineado y minificado
# - JavaScript bundle con code splitting
# - Assets con hash para cache busting

# 2. Preview del build (opcional, para probar antes de desplegar)
npm run preview

# Se abre en http://localhost:4173
```

#### Linter y Type Checking

```bash
# Verificar errores de código
npm run lint

# Verificar tipos de TypeScript (sin compilar)
npm run typecheck
```

#### Despliegue en Diferentes Plataformas

**Netlify:**
```bash
# Build command:
npm run build

# Publish directory:
dist

# Environment variables:
# Añadir todas las variables VITE_* en Netlify Dashboard
```

**Vercel:**
```bash
# Instalar Vercel CLI
npm i -g vercel

# Deploy
vercel

# Configurar variables de entorno en Vercel Dashboard
```

**Servidor Propio (Nginx):**
```bash
# 1. Build
npm run build

# 2. Copiar carpeta dist/ a servidor
scp -r dist/* usuario@servidor:/var/www/golf-scoring/

# 3. Configurar Nginx
# /etc/nginx/sites-available/golf-scoring
server {
    listen 80;
    server_name tudominio.com;
    root /var/www/golf-scoring;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

# 4. Activar sitio
sudo ln -s /etc/nginx/sites-available/golf-scoring /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**Docker:**
```dockerfile
# Dockerfile
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
# Construir imagen
docker build -t golf-scoring .

# Correr contenedor
docker run -d -p 8080:80 golf-scoring
```

### 3.4 Requisitos del Sistema

**Para Desarrollo:**
- Node.js 18+ (LTS recomendado)
- npm 8+ o yarn 1.22+
- 2 GB RAM mínimo
- Navegador moderno (Chrome, Firefox, Safari, Edge)

**Para Producción:**
- Servidor web (Nginx, Apache, Caddy)
- HTTPS habilitado (requerido para PWA en el futuro)
- Certificado SSL (Let's Encrypt gratuito)

**Para Usuarios Finales:**
- Navegador moderno con JavaScript habilitado
- Conexión a internet
- localStorage habilitado (no modo incógnito)

---

## 4. ESTRUCTURA DE ARCHIVOS

```
golf-scoring/
│
├── public/                          # Assets estáticos
│   ├── image.png                    # Logo/imagen del proyecto
│   └── ...                          # Otros assets
│
├── src/                             # Código fuente principal
│   ├── components/                  # Componentes React
│   │   ├── AccessCodeModal.tsx      # Modal para introducir código de acceso
│   │   ├── ActiveRoundsViewer.tsx   # Visor de partidas activas del grupo
│   │   ├── AdminDashboard.tsx       # Panel de administración (campos, hoyos)
│   │   ├── AdminPinModal.tsx        # Modal para PIN de administrador
│   │   ├── ArchivedRoundDetailModal.tsx  # Detalle de partida archivada
│   │   ├── ArchivedRoundsModal.tsx  # Lista de partidas archivadas
│   │   ├── Auth.tsx                 # Componente de autenticación (login/registro)
│   │   ├── AwardRankingModal.tsx    # Modal para rankings de premios especiales
│   │   ├── ConfirmModal.tsx         # Modal de confirmación genérico
│   │   ├── CongratulationsModal.tsx # Modal de felicitaciones (victorias)
│   │   ├── CourseChangeConfirmModal.tsx  # Confirmar cambio de campo
│   │   ├── CourseChangeModal.tsx    # Modal para cambiar campo en partida activa
│   │   ├── DeleteRoundModal.tsx     # Confirmar eliminación de partida
│   │   ├── EditPlayerNameModal.tsx  # Editar nombre de jugador
│   │   ├── ErrorBoundary.tsx        # Captura errores de React
│   │   ├── GamePoints.tsx           # Explicación del sistema de puntos
│   │   ├── GroupSetup.tsx           # Crear o unirse a grupo
│   │   ├── HoleCard.tsx             # Tarjeta individual de hoyo (scorecard)
│   │   ├── HoleConfiguration.tsx    # Configurar par y stroke index de hoyos
│   │   ├── HoleInOneModal.tsx       # Modal especial para hoyo en uno
│   │   ├── HolesRangeModal.tsx      # Seleccionar rango de hoyos (1-9 o 10-18)
│   │   ├── Leaderboard.tsx          # Tabla de clasificación en tiempo real
│   │   ├── MyGroups.tsx             # Gestionar mis grupos (ver, salir)
│   │   ├── PlayerSetup.tsx          # Añadir jugadores a la partida
│   │   ├── QuickPlayStatistics.tsx  # Estadísticas épicas de Quick Play
│   │   ├── RoundSetup.tsx           # Configurar nueva partida (campo, hoyos, slope)
│   │   ├── RoundStatistics.tsx      # Estadísticas al finalizar partida de grupo
│   │   ├── Scorecard.tsx            # Tarjeta de puntuación (anotar golpes)
│   │   ├── ScoreSymbol.tsx          # Símbolos visuales (eagle, birdie, etc.)
│   │   └── Statistics.tsx           # Estadísticas generales del grupo
│   │
│   ├── data/                        # Datos estáticos
│   │   └── defaultCourse.ts         # Configuración de campo por defecto
│   │
│   ├── services/                    # Lógica de negocio y comunicación con Supabase
│   │   ├── golfService.ts           # Servicio principal (CRUD, cálculos)
│   │   └── supabaseClient.ts        # Cliente de Supabase configurado
│   │
│   ├── utils/                       # Utilidades y helpers
│   │   ├── accessCode.ts            # Generación y validación de códigos de acceso
│   │   ├── adminPin.ts              # Validación de PIN de administrador
│   │   ├── calculations.ts          # Cálculos de golf (handicap, puntos Stableford)
│   │   ├── safeStorage.ts           # Wrapper seguro de localStorage (modo incógnito)
│   │   ├── storage.ts               # Gestión de localStorage (grupos, partidas)
│   │   └── userId.ts                # Generación y gestión de userId local
│   │
│   ├── App.tsx                      # Componente principal de la aplicación
│   ├── index.css                    # Estilos globales (Tailwind base)
│   ├── main.tsx                     # Punto de entrada de React
│   ├── types.ts                     # Tipos e interfaces de TypeScript
│   └── vite-env.d.ts                # Tipos de Vite
│
├── supabase/                        # Configuración de Supabase
│   └── migrations/                  # Migraciones de base de datos (SQL)
│       ├── 20251129032653_create_golf_schema.sql
│       ├── 20251129033014_seed_default_course.sql
│       ├── 20251130220101_allow_public_access.sql
│       └── ... (90+ archivos más)
│
├── .env                             # Variables de entorno (NO COMMITEAR)
├── .gitignore                       # Archivos ignorados por Git
├── eslint.config.js                 # Configuración de ESLint
├── index.html                       # HTML principal (punto de entrada)
├── package.json                     # Dependencias y scripts
├── package-lock.json                # Lockfile de dependencias
├── postcss.config.js                # Configuración de PostCSS (Tailwind)
├── README.md                        # Documentación básica
├── tailwind.config.js               # Configuración de Tailwind CSS
├── tsconfig.json                    # Configuración de TypeScript
├── tsconfig.app.json                # Configuración de TypeScript para la app
├── tsconfig.node.json               # Configuración de TypeScript para Vite
└── vite.config.ts                   # Configuración de Vite
```

### Descripción de Directorios Clave

#### `/src/components/`
**Propósito:** Componentes visuales de React. Cada archivo es un componente independiente.

**Convenciones:**
- Nombre en PascalCase (ej: `PlayerSetup.tsx`)
- Un componente principal por archivo
- Componentes auxiliares pequeños pueden estar en el mismo archivo
- Props definidas con TypeScript interface

**Componentes Más Importantes:**
- **App.tsx** - Orquestador principal, gestiona navegación entre vistas
- **RoundSetup.tsx** - Primer paso (seleccionar campo, hoyos, slope)
- **PlayerSetup.tsx** - Segundo paso (añadir jugadores)
- **Scorecard.tsx** - Vista principal durante la partida
- **Leaderboard.tsx** - Clasificación en tiempo real
- **Statistics.tsx** - Estadísticas del grupo
- **QuickPlayStatistics.tsx** - Estadísticas épicas de Quick Play

#### `/src/services/`
**Propósito:** Lógica de negocio, comunicación con Supabase.

**Archivos:**
- **golfService.ts** - Servicio PRINCIPAL (2400+ líneas)
  - CRUD de partidas, jugadores, puntuaciones
  - Cálculos de handicaps y puntos
  - Gestión de grupos
  - Archivado de partidas
  - Estadísticas y rankings
- **supabaseClient.ts** - Cliente de Supabase configurado
  - Singleton del cliente
  - Configuración de autenticación

#### `/src/utils/`
**Propósito:** Funciones auxiliares reutilizables.

**Archivos:**
- **calculations.ts** - Fórmulas de golf
  - `calculatePlayingHandicap()` - Convierte handicap exacto a handicap de juego con slope
  - `calculateScore()` - Calcula golpes recibidos, netos y puntos Stableford
- **storage.ts** - Gestión de localStorage
  - Guardar/recuperar grupo actual
  - Guardar/recuperar partida activa
- **userId.ts** - Generación de ID único de usuario
- **accessCode.ts** - Generación y validación de códigos
- **safeStorage.ts** - Wrapper de localStorage que no falla en modo incógnito

#### `/supabase/migrations/`
**Propósito:** Cambios incrementales en el esquema de base de datos.

**Convenciones:**
- Nombre: `YYYYMMDDHHMMSS_descripcion.sql`
- Orden cronológico por timestamp
- Cada archivo es idempotente (puede ejecutarse múltiples veces)
- Incluye comentarios detallados

**Migraciones Críticas:**
1. `20251129032653_create_golf_schema.sql` - Crea todas las tablas base
2. `20251129033014_seed_default_course.sql` - Inserta campo por defecto
3. `20260101163153_add_tees_table_and_slope_support.sql` - Añade tabla de Tees
4. `20260102232534_create_statistics_tables.sql` - Tablas de estadísticas
5. `20260106230033_create_daily_rankings_table.sql` - Rankings diarios

---

## 5. GUÍA DE MANTENIMIENTO

### 5.1 Para No Programadores

#### Cambiar Textos de la Interfaz

**Ejemplo: Cambiar "Quick Play" por "Partida Rápida"**

1. Buscar en VS Code (Ctrl+Shift+F o Cmd+Shift+F):
   - Texto a buscar: `Quick Play`
   - Reemplazar por: `Partida Rápida`
2. Review de cambios: Verificar que no sea código
3. Guardar todos los archivos
4. Build: `npm run build`
5. Deploy: Subir carpeta `dist/`

⚠️ **CUIDADO:** No cambiar textos entre comillas en archivos que terminen en `.ts` o `.sql` (a menos que sepas qué haces)

#### Cambiar Imágenes o Logo

**Ubicación:** `/public/`

1. Prepara tu imagen (formato PNG, JPG o SVG)
2. Renombra para reemplazar imagen existente (ej: `image.png`)
3. O añade nueva imagen y actualiza referencia en código:
   ```tsx
   // Buscar en archivos .tsx:
   <img src="/image.png" />
   // Cambiar por:
   <img src="/tu-nueva-imagen.png" />
   ```
4. Build y deploy

#### Cambiar Colores Principales

Los colores están definidos con Tailwind CSS. Buscar y reemplazar:

**Verde Esmeralda (color principal):**
- Buscar: `emerald-` (ej: `bg-emerald-900`, `text-emerald-700`)
- Reemplazar por otro color de Tailwind: `blue-`, `green-`, `teal-`, `cyan-`, etc.

**Ejemplo:**
```tsx
// Antes
className="bg-emerald-900 text-white"

// Después (azul)
className="bg-blue-900 text-white"
```

**Colores Disponibles en Tailwind:**
- slate, gray, zinc, neutral, stone
- red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose

**Intensidades:** 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950

### 5.2 Añadir Nuevo Campo de Golf (Para Administradores)

#### Opción A: Desde el Panel de Administración

1. Autenticarse en la app con email/password
2. Ir a "Administración" en el menú
3. Introducir PIN de administrador (definido en .env)
4. Click en "Añadir Nuevo Campo"
5. Rellenar:
   - Nombre del campo
   - Descripción (opcional)
6. Configurar cada hoyo:
   - Par (3, 4 o 5)
   - Stroke Index (1-18, orden de dificultad)
7. Añadir Tees (opcional, para slopes):
   - Nombre (ej: "Rojo", "Amarillo")
   - Color
   - Slope 18 hoyos
   - Slope 9 hoyos (1-9)
   - Slope 9 hoyos (10-18)
8. Guardar

#### Opción B: Directamente en Supabase

1. Ve a Supabase Dashboard → SQL Editor
2. Ejecuta query:

```sql
-- 1. Crear campo
INSERT INTO golf_courses (name, description)
VALUES ('Nombre del Campo', 'Descripción opcional')
RETURNING id;

-- Copiar el ID devuelto

-- 2. Crear hoyos (repetir 18 veces)
INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
  ('[id-copiado]', 1, 4, 5),   -- Hoyo 1: Par 4, Stroke Index 5
  ('[id-copiado]', 2, 3, 7),   -- Hoyo 2: Par 3, Stroke Index 7
  -- ... hasta hoyo 18
  ('[id-copiado]', 18, 5, 2);  -- Hoyo 18: Par 5, Stroke Index 2

-- 3. Crear Tees (opcional)
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
  ('[id-copiado]', 'Rojo', 'red', 113, 113, 113),
  ('[id-copiado]', 'Amarillo', 'yellow', 120, 120, 120);
```

### 5.3 Añadir Nueva Métrica o Estadística

**Ejemplo: Añadir "Total de Eagles" a estadísticas de jugador**

#### Paso 1: Modificar Consulta SQL

Archivo: Crear nueva migración en `/supabase/migrations/`

```sql
-- 20260110000000_add_eagles_to_player_stats.sql
/*
  # Añadir Eagles a Estadísticas de Jugador

  1. Modificaciones
    - Añadir eagles al JSON de archived_rounds.player_stats

  2. Notas
    - Los eagles ya se calculan en el frontend, solo añadirlos a la query
*/

-- No se necesita cambio en esquema, solo en lógica de cálculo
-- Los eagles ya están en hole_results.eagles dentro de player_stats
```

#### Paso 2: Modificar Frontend (golfService.ts)

Ubicación: `/src/services/golfService.ts`

Buscar función: `archiveRound`

```typescript
// Línea ~1436
const eagles = playerScores.filter((s) => {
  const hole = holes.find((h) => h.hole_number === s.hole_number);
  return hole && s.net_strokes <= hole.par - 2;
}).length;

// Los eagles YA se guardan en player_stats.hole_results.eagles
```

#### Paso 3: Mostrar en Componente

Ubicación: `/src/components/Statistics.tsx`

```typescript
// Añadir en la sección de estadísticas:
<div className="stat-card">
  <p className="stat-label">Eagles</p>
  <p className="stat-value">{playerStats.eagles || 0}</p>
</div>
```

#### Paso 4: Testing

1. Jugar una partida de prueba
2. Archivar la partida
3. Verificar en estadísticas que aparezca el valor
4. Verificar en Supabase Dashboard que el JSON incluye eagles

### 5.4 Modificar Cálculo de Handicaps

**Ubicación:** `/src/utils/calculations.ts`

**Función Actual:**
```typescript
export function calculatePlayingHandicap(exactHandicap: number, slope: number): number {
  // Fórmula estándar: (Handicap * Slope) / 113
  return Math.round((exactHandicap * slope) / 113);
}
```

**Ejemplo: Cambiar a multiplicar por 0.9 en lugar de usar slope**

```typescript
export function calculatePlayingHandicap(exactHandicap: number, slope: number): number {
  // Nueva fórmula: 90% del handicap
  return Math.round(exactHandicap * 0.9);
}
```

⚠️ **IMPACTO:** Esto afecta a TODAS las partidas nuevas. Las partidas existentes mantienen sus handicaps calculados.

### 5.5 Cambiar Reglas de Cervezas

**Ubicación:** `/src/services/golfService.ts` → función `archiveRound`

**Regla Actual: Top 50% recibe, Bottom 50% paga**

```typescript
// Línea ~1467
const totalPlayers = sortedPlayers.length;
const receiverCount = Math.floor(totalPlayers / 2);
const payerStart = totalPlayers % 2 === 0 ? receiverCount + 1 : receiverCount + 2;

const playerStatsForArchive = sortedPlayers.map((player, index) => {
  const position = index + 1;
  const beersWon = position <= receiverCount ? 1 : 0;
  const beersPaid = position >= payerStart ? 1 : 0;
  // ...
});
```

**Cambiar a: Top 3 reciben, Último paga**

```typescript
const playerStatsForArchive = sortedPlayers.map((player, index) => {
  const position = index + 1;
  const beersWon = position <= 3 ? 1 : 0;
  const beersPaid = position === sortedPlayers.length ? 1 : 0;
  // ...
});
```

### 5.6 Backup y Restauración

#### Backup Completo de Base de Datos

**Opción A: Desde Supabase Dashboard**

1. Ve a Database → Backups
2. Click "Backup Now"
3. Se crea backup automático
4. Descargar con "Download Backup"

**Opción B: Con pg_dump (Avanzado)**

```bash
# Obtener DATABASE_URL desde Supabase Dashboard → Settings → Database
DATABASE_URL="postgresql://postgres:[password]@[host]:5432/postgres"

# Crear backup
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql

# Comprimir
gzip backup_$(date +%Y%m%d).sql
```

#### Restauración de Backup

```bash
# Descomprimir
gunzip backup_20260110.sql.gz

# Restaurar
psql $DATABASE_URL < backup_20260110.sql
```

#### Backup de Código

```bash
# Crear archivo comprimido
tar -czf golf-scoring-backup.tar.gz \
  --exclude=node_modules \
  --exclude=dist \
  --exclude=.git \
  .

# O usar Git (recomendado)
git add .
git commit -m "Backup antes de cambios importantes"
git push origin main
```

---

## 6. AUDITORÍA DE INDEPENDENCIA

### 6.1 Valores Hardcodeados a Revisar

#### 🔴 CRÍTICOS (Deben convertirse en variables)

**1. PIN de Administrador en Validación**

**Ubicación:** `/src/utils/adminPin.ts`

```typescript
// ACTUAL (hardcoded)
export const ADMIN_PIN = import.meta.env.VITE_ADMIN_PIN || '2248';

// ✅ YA ES VARIABLE DE ENTORNO
```

**Status:** ✅ Correcto

**2. Slope por Defecto**

**Ubicación:** `/src/services/golfService.ts`

```typescript
// Línea ~225
return { slope: 113, isManual: false };
```

**Recomendación:** Mover a variable de entorno o configuración en base de datos

```typescript
// Mejor:
const DEFAULT_SLOPE = parseInt(import.meta.env.VITE_DEFAULT_SLOPE || '113');
return { slope: DEFAULT_SLOPE, isManual: false };
```

**3. Límites de Handicap**

**Ubicación:** `/src/services/golfService.ts`

```typescript
// Línea ~1367
newHandicap = currentHandicap < 12 ? currentHandicap + 1 : currentHandicap;
```

**Recomendación:** Crear tabla `admin_config`:

```sql
INSERT INTO admin_config (key, value) VALUES
  ('max_handicap_increase', '12'),
  ('handicap_increase_amount', '1'),
  ('handicap_decrease_amount', '1');
```

**4. Distribución de Cervezas**

**Ubicación:** `/src/services/golfService.ts`

```typescript
// Línea ~1468
const receiverCount = Math.floor(totalPlayers / 2);
const payerStart = totalPlayers % 2 === 0 ? receiverCount + 1 : receiverCount + 2;
```

**Recomendación:** Configurar en `admin_config`:

```sql
INSERT INTO admin_config (key, value) VALUES
  ('beer_distribution_rule', 'half_split'),
  ('beer_distribution_config', '{"receivers_percent": 50, "payers_percent": 50}');
```

#### 🟡 MEDIOS (Pueden ser variables)

**5. Formato de Códigos de Acceso**

**Ubicación:** `/src/utils/accessCode.ts`

```typescript
// Longitud hardcoded a 4 dígitos
const code = Math.floor(1000 + Math.random() * 9000).toString();
```

**Recomendación:**

```typescript
const CODE_LENGTH = parseInt(import.meta.env.VITE_ACCESS_CODE_LENGTH || '4');
const min = Math.pow(10, CODE_LENGTH - 1);
const max = Math.pow(10, CODE_LENGTH) - 1;
const code = Math.floor(min + Math.random() * (max - min)).toString();
```

**6. Nombres de Premios Especiales**

**Ubicación:** Múltiples componentes (Statistics.tsx, QuickPlayStatistics.tsx)

```typescript
// Hardcoded
<h4>Rey del Bosque</h4>
<h4>No Pasó de Rojas</h4>
<h4>La Paliza</h4>
```

**Recomendación:** Crear archivo de internacionalización:

```typescript
// src/i18n/es.ts
export const AWARDS = {
  reyDelBosque: 'Rey del Bosque',
  noPasoRojas: 'No Pasó de Rojas',
  laPaliza: 'La Paliza',
  // ...
};
```

#### 🟢 BAJOS (Aceptables como están)

**7. Colores de Tailwind**

```typescript
className="bg-emerald-900 text-white"
```

**Status:** ✅ Aceptable. Los colores son parte del diseño, no configuración.

**8. Límites de Par**

```sql
CHECK (par >= 3 AND par <= 5)
```

**Status:** ✅ Correcto. Los pares en golf son siempre 3, 4 o 5.

### 6.2 Dependencias de Servicios Externos

#### Supabase (BaaS)

**Dependencia:** CRÍTICA - Toda la app depende de Supabase

**Puntos de Vinculación:**
1. Autenticación (Supabase Auth)
2. Base de datos (PostgreSQL via Supabase)
3. Realtime (Subscripciones)

**Plan de Migración a Propio Backend:**

**Paso 1: Exportar Datos**
```bash
# Exportar esquema
pg_dump --schema-only $DATABASE_URL > schema.sql

# Exportar datos
pg_dump --data-only $DATABASE_URL > data.sql
```

**Paso 2: Configurar PostgreSQL Propio**
```bash
# Instalar PostgreSQL 15+
sudo apt install postgresql-15

# Crear base de datos
createdb golf_scoring

# Importar esquema y datos
psql golf_scoring < schema.sql
psql golf_scoring < data.sql
```

**Paso 3: Reemplazar Cliente Supabase**

```typescript
// Antes: /src/services/supabaseClient.ts
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(url, key);

// Después: /src/services/apiClient.ts
import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Implementar mismas funciones pero con llamadas HTTP
export const apiClient = {
  from: (table: string) => ({
    select: (columns: string) => api.get(`/${table}?select=${columns}`),
    insert: (data: any) => api.post(`/${table}`, data),
    // ...
  }),
  auth: {
    signUp: (email: string, password: string) =>
      api.post('/auth/signup', { email, password }),
    // ...
  }
};
```

**Paso 4: Implementar Backend (Node.js + Express)**

```javascript
// server.js
const express = require('express');
const { Pool } = require('pg');

const app = express();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// Endpoints
app.get('/golf_courses', async (req, res) => {
  const result = await pool.query('SELECT * FROM golf_courses');
  res.json(result.rows);
});

app.post('/golf_rounds', async (req, res) => {
  const { course_id, user_id, num_holes } = req.body;
  const result = await pool.query(
    'INSERT INTO golf_rounds (course_id, user_id, num_holes) VALUES ($1, $2, $3) RETURNING *',
    [course_id, user_id, num_holes]
  );
  res.json(result.rows[0]);
});

// ... resto de endpoints

app.listen(3000);
```

**Estimación de Esfuerzo:** 40-60 horas de desarrollo

#### Lucide React (Iconos)

**Dependencia:** BAJA - Solo librería de iconos

**Plan de Migración:**
- Opción A: Reemplazar con Font Awesome, Material Icons, Heroicons
- Opción B: Usar SVGs propios
- **Esfuerzo:** 2-4 horas (búsqueda y reemplazo)

#### Tailwind CSS (Estilos)

**Dependencia:** MEDIA - Framework CSS

**Plan de Migración:**
- Opción A: Migrar a CSS Modules + SCSS
- Opción B: Migrar a Styled Components
- Opción C: Usar CSS vanilla con BEM
- **Esfuerzo:** 60-80 horas (reescribir todos los estilos)

**Recomendación:** NO migrar. Tailwind no tiene vendor lock-in, se compila a CSS estático.

### 6.3 Checklist de Independencia Total

- [x] Variables de entorno para URLs y keys
- [x] Código en repositorio Git
- [x] Esquema de base de datos documentado
- [x] Migraciones SQL separadas
- [ ] Configuraciones en base de datos (no hardcoded)
- [ ] Backend abstracto (puede reemplazar Supabase)
- [x] Sin dependencias de CDN externos
- [x] Sin llamadas a APIs propietarias (excepto Supabase)
- [x] Documentación completa de arquitectura

**Puntuación:** 6.5/8 (81% independiente)

### 6.4 Pasos para Conectar a Supabase Propio y Vacío

#### Requisitos Previos
- Cuenta en Supabase (gratuita funciona)
- Node.js 18+ instalado
- Git instalado

#### Paso a Paso

**1. Crear Proyecto en Supabase**

1. Ve a [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click "New Project"
3. Rellena:
   - Organization: Selecciona o crea nueva
   - Name: `golf-scoring`
   - Database Password: Genera una fuerte y guárdala
   - Region: Selecciona cercana a ti
   - Pricing Plan: Free (hasta 500MB DB, 50,000 MAU)
4. Click "Create new project"
5. Espera 2 minutos mientras se provisiona

**2. Obtener Credenciales**

1. En el Dashboard del proyecto → Settings → API
2. Copia:
   - **URL:** `https://xyzabc123.supabase.co`
   - **anon public key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

**3. Configurar Variables de Entorno**

Crea archivo `.env` en la raíz del proyecto:

```bash
VITE_SUPABASE_URL=https://[tu-proyecto].supabase.co
VITE_SUPABASE_ANON_KEY=[tu-anon-key]
VITE_ADMIN_EMAIL=tu@email.com
VITE_ADMIN_PIN=2248
```

**4. Aplicar Migraciones**

**Opción A: Manual (Recomendado para Primera Vez)**

1. Ve a Database → SQL Editor en Supabase Dashboard
2. Abre cada archivo de `/supabase/migrations/` en orden:
   ```
   20251129032653_create_golf_schema.sql
   20251129033014_seed_default_course.sql
   20251130220101_allow_public_access.sql
   20251130220318_make_created_by_nullable.sql
   ... (todos los demás en orden cronológico)
   ```
3. Copia contenido de cada archivo
4. Pega en SQL Editor
5. Click "RUN"
6. Verifica que no haya errores
7. Repite para todos los archivos

⚠️ **MUY IMPORTANTE:** Aplicar en orden cronológico. Cada migración depende de las anteriores.

**Opción B: Supabase CLI (Avanzado)**

```bash
# 1. Instalar CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Obtener Project Ref (desde Dashboard → Settings → General → Reference ID)
PROJECT_REF="xyzabc123"

# 4. Vincular proyecto
supabase link --project-ref $PROJECT_REF

# 5. Aplicar todas las migraciones
supabase db push

# 6. Verificar
supabase db diff
```

**5. Verificar Instalación**

1. Ve a Database → Tables en Supabase Dashboard
2. Deberías ver:
   - golf_courses
   - golf_holes
   - golf_rounds
   - round_players
   - round_scores
   - groups
   - players
   - archived_rounds
   - daily_rankings
   - seasons
   - tees
   - beer_stats
   - admin_config
   - completed_rounds_summary

3. Ve a Database → SQL Editor y ejecuta:
```sql
SELECT * FROM golf_courses;
-- Deberías ver al menos 1 campo (Costa Azahar Verde)

SELECT * FROM golf_holes WHERE course_id = (SELECT id FROM golf_courses LIMIT 1);
-- Deberías ver 9 o 18 hoyos

SELECT * FROM tees;
-- Deberías ver tees configurados para los campos
```

**6. Configurar Autenticación (Opcional)**

Si quieres usar autenticación email/password:

1. Authentication → Providers
2. Activar "Email"
3. Settings → Auth → Email Auth:
   - Enable Email Signup: ON
   - Confirm Email: OFF (para desarrollo, ON para producción)
4. Settings → Auth → Site URL:
   - Development: `http://localhost:5173`
   - Production: `https://tudominio.com`
5. Settings → Auth → Redirect URLs:
   - Añadir: `http://localhost:5173/**`
   - Añadir: `https://tudominio.com/**` (si tienes)

**7. Instalar y Ejecutar Aplicación**

```bash
# 1. Clonar o descomprimir proyecto
cd golf-scoring

# 2. Instalar dependencias
npm install

# 3. Verificar .env
cat .env
# Debe contener las 4 variables de Supabase

# 4. Iniciar servidor de desarrollo
npm run dev

# 5. Abrir navegador en http://localhost:5173
```

**8. Prueba Inicial**

1. Click en "Quick Play"
2. Selecciona campo (debería aparecer Costa Azahar u otro)
3. Configura partida (9 hoyos, sin slope)
4. Añade 2 jugadores con handicaps
5. Anota algunas puntuaciones
6. Verifica en Supabase Dashboard → Database → Table Editor:
   - `golf_rounds`: Debería haber 1 registro con status='active'
   - `round_players`: Deberían estar tus 2 jugadores
   - `round_scores`: Deberían estar las puntuaciones anotadas

**9. Verificar Realtime (Opcional)**

1. Abre la app en 2 pestañas del navegador
2. En una pestaña, anota puntuaciones
3. En la otra, verifica que se actualizan en tiempo real (Leaderboard)

**10. Troubleshooting Común**

**Error: "Supabase URL and Anon Key are required"**
- Solución: Verifica que `.env` existe y tiene variables correctas
- Reinicia servidor de desarrollo: `npm run dev`

**Error: "relation 'golf_courses' does not exist"**
- Solución: No se aplicaron las migraciones
- Vuelve a Paso 4 y aplica todas las migraciones

**Error: "Failed to fetch"**
- Solución: Verifica que Supabase URL es correcto
- Verifica que proyecto Supabase está "Active" (no "Paused")

**Las puntuaciones no se actualizan en tiempo real**
- Solución: Ve a Supabase Dashboard → Database → Replication
- Verifica que `realtime` está habilitado
- Habilita en la tabla `round_scores`

**No puedo autenticarme**
- Solución: Verifica configuración de Authentication
- Verifica que Email provider está activo
- Verifica Redirect URLs

---

## 7. SOLUCIÓN DE PROBLEMAS

### 7.1 Errores Comunes y Soluciones

#### Error: "localStorage is not defined" o "Cannot read property 'setItem' of null"

**Causa:** Navegador en modo incógnito o localStorage deshabilitado

**Solución:**
- La app ya tiene `safeStorage.ts` que maneja esto
- Mensaje al usuario: "Por favor, sal del modo incógnito para usar la app"

**Código de detección:**
```typescript
// src/utils/safeStorage.ts ya implementa esto
try {
  localStorage.setItem('test', 'test');
  localStorage.removeItem('test');
} catch {
  // Modo incógnito detectado
}
```

#### Error: "Round not found" al intentar unirse con código

**Causa:** Código incorrecto o partida no existe

**Verificación en Supabase:**
```sql
SELECT * FROM golf_rounds
WHERE access_code = 'XXXX'
AND status = 'active';
```

**Soluciones:**
1. Verificar que código es correcto (4 dígitos, sin espacios)
2. Verificar que partida está activa
3. Regenerar código si es necesario

#### Error: "Failed to insert player: duplicate key value"

**Causa:** Intento de crear jugador con mismo nombre en mismo grupo

**Solución:**
```typescript
// En PlayerSetup.tsx, antes de crear:
const existingPlayer = await golfService.getOrCreatePlayer(name, handicap);
// Esta función ya maneja duplicados
```

#### Error: Handicaps Incorrectos Después de Cambiar Número de Hoyos

**Causa:** No se recalcularon los handicaps al cambiar de 9 a 18 o viceversa

**Verificación:**
```typescript
// golfService.ts línea ~482
if (oldNumHoles !== numHoles) {
  // Debería entrar aquí y recalcular
}
```

**Solución Manual (SQL):**
```sql
-- Si partida cambió de 9 a 18 hoyos
UPDATE round_players
SET exact_handicap = exact_handicap * 2,
    playing_handicap = ROUND((exact_handicap * 2 * [slope]) / 113)
WHERE round_id = '[id-de-la-partida]';

-- Si cambió de 18 a 9
UPDATE round_players
SET exact_handicap = exact_handicap / 2,
    playing_handicap = ROUND((exact_handicap / 2 * [slope]) / 113)
WHERE round_id = '[id-de-la-partida]';
```

#### Error: "Cannot calculate score: hole not found"

**Causa:** Intentando anotar puntuación en hoyo que no existe en el campo

**Verificación:**
```sql
SELECT hole_number FROM golf_holes
WHERE course_id = '[id-del-campo]'
ORDER BY hole_number;
```

**Solución:**
1. Verificar que el campo tiene todos los hoyos configurados
2. Si faltan hoyos, añadirlos manualmente en admin panel

#### Error: Realtime no Funciona (Puntuaciones no se Actualizan)

**Causa:** Subscripción Realtime no configurada o deshabilitada

**Verificación:**
1. Supabase Dashboard → Database → Replication
2. Verificar que tabla `round_scores` tiene Realtime habilitado

**Solución:**
```sql
-- Habilitar realtime
ALTER PUBLICATION supabase_realtime ADD TABLE round_scores;
```

**En Frontend (Scorecard.tsx):**
```typescript
useEffect(() => {
  const channel = golfService.subscribeToRound(roundId, (payload) => {
    console.log('Realtime update:', payload);
    // Recargar puntuaciones
  });

  return () => {
    channel.unsubscribe();
  };
}, [roundId]);
```

### 7.2 Performance

#### Problema: La App Carga Lento

**Causas Comunes:**
1. Demasiados datos cargados a la vez
2. Queries sin índices
3. Bundle de JavaScript muy grande

**Soluciones:**

**1. Paginación:**
```typescript
// Antes: Cargar todas las partidas archivadas
const rounds = await golfService.getArchivedRounds(groupId);

// Después: Cargar solo últimas 20
const rounds = await supabase
  .from('archived_rounds')
  .select('*')
  .eq('group_id', groupId)
  .order('played_at', { ascending: false })
  .limit(20);
```

**2. Verificar Índices:**
```sql
-- Ver índices existentes
SELECT * FROM pg_indexes WHERE tablename = 'round_scores';

-- Añadir índice si falta
CREATE INDEX idx_round_scores_round_player
ON round_scores(round_id, player_id);
```

**3. Code Splitting (React Lazy):**
```typescript
// Antes
import { Statistics } from './components/Statistics';

// Después
const Statistics = lazy(() => import('./components/Statistics'));

// En render
<Suspense fallback={<div>Cargando...</div>}>
  <Statistics />
</Suspense>
```

#### Problema: Base de Datos Crece Demasiado

**Solución: Limpieza Automática de Partidas Viejas**

```sql
-- Crear función de limpieza
CREATE OR REPLACE FUNCTION cleanup_old_rounds()
RETURNS void AS $$
BEGIN
  -- Eliminar partidas Quick Play completadas > 30 días
  DELETE FROM golf_rounds
  WHERE group_id IS NULL
    AND status = 'completed'
    AND completed_at < NOW() - INTERVAL '30 days';

  -- Archivar partidas de grupo completadas > 7 días
  -- (o implementar tu lógica)
END;
$$ LANGUAGE plpgsql;

-- Ejecutar manualmente
SELECT cleanup_old_rounds();

-- O configurar cron job en Supabase (plan Pro)
```

### 7.3 Debugging

#### Habilitar Logs Detallados

**Frontend:**
```typescript
// Añadir en supabaseClient.ts
export const supabase = createClient(url, key, {
  auth: { ...},
  global: {
    headers: {
      'x-my-custom-header': 'debug'
    }
  },
  db: {
    schema: 'public'
  },
  // Habilitar logs
  log: {
    level: 'debug'
  }
});
```

**Browser Console:**
```javascript
// Ver todas las peticiones a Supabase
localStorage.setItem('supabase.log', 'debug');
// Recargar página
```

#### Inspeccionar Estado de Partida

**Console del Navegador:**
```javascript
// Ver estado actual de localStorage
console.log({
  userId: localStorage.getItem('golf_user_id'),
  currentGroup: localStorage.getItem('golf_current_group'),
  groupCode: localStorage.getItem('golf_group_code'),
  isCreator: localStorage.getItem('golf_is_creator'),
  authToken: localStorage.getItem('supabase.auth.token')
});
```

**SQL en Supabase:**
```sql
-- Ver partida activa de un usuario
SELECT r.*, c.name as course_name
FROM golf_rounds r
JOIN golf_courses c ON r.course_id = c.id
WHERE r.user_id = '[user-id]'
  AND r.status = 'active';

-- Ver jugadores y puntuaciones
SELECT
  rp.name,
  rp.playing_handicap,
  COUNT(rs.id) as holes_played,
  SUM(rs.stableford_points) as total_points
FROM round_players rp
LEFT JOIN round_scores rs ON rs.player_id = rp.id
WHERE rp.round_id = '[round-id]'
GROUP BY rp.id, rp.name, rp.playing_handicap;
```

### 7.4 Seguridad

#### Verificar RLS (Row Level Security)

**Test: ¿Puede un usuario ver partidas de otro?**

```sql
-- Ejecutar como usuario específico
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "[otro-user-id]"}';

-- Intentar ver partidas de otro usuario
SELECT * FROM golf_rounds WHERE user_id != '[otro-user-id]';

-- NO debería devolver nada (protegido por RLS)
```

#### Verificar Políticas

```sql
-- Ver todas las políticas de una tabla
SELECT * FROM pg_policies WHERE tablename = 'golf_rounds';

-- Probar política específica
EXPLAIN (ANALYZE, VERBOSE, BUFFERS)
SELECT * FROM golf_rounds WHERE created_by = auth.uid();
```

#### Proteger Datos Sensibles

**Nunca exponer:**
- Database password de Supabase
- Service Role Key (solo para backend)
- Secrets de terceros

**Solo exponer:**
- anon public key (segura para frontend)
- Project URL
- Admin PIN (en .env, no en código)

---

## 📝 NOTAS FINALES

### Contacto y Soporte

**Documentación Oficial:**
- Supabase: [supabase.com/docs](https://supabase.com/docs)
- React: [react.dev](https://react.dev)
- Tailwind CSS: [tailwindcss.com/docs](https://tailwindcss.com/docs)
- TypeScript: [typescriptlang.org/docs](https://www.typescriptlang.org/docs)

### Próximos Pasos Recomendados

1. **Configurar CI/CD:** Despliegue automático con cada push
2. **Añadir Tests:** Jest + React Testing Library
3. **PWA:** Hacer la app instalable en móviles
4. **Modo Offline:** Cache de partidas con Service Workers
5. **Internacionalización:** Soporte multiidioma (i18n)
6. **Temas:** Modo oscuro/claro
7. **Analytics:** Seguimiento de uso con PostHog o similar
8. **Notificaciones:** Push notifications para partidas del grupo

### Licencia y Uso

Este proyecto es de código cerrado. Todos los derechos reservados.

### Historial de Cambios

**v1.0 - 10 Enero 2026**
- Versión inicial del manual técnico
- Documentación completa de arquitectura
- Guías de migración y mantenimiento
- Auditoría de independencia

---

**Fin del Manual Técnico Maestro**

*Este documento debe actualizarse con cada cambio significativo en la arquitectura o funcionalidades del sistema.*
