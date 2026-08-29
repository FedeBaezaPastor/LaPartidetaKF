# Guía de Migración - La Partideta Golf V1

**Documento Técnico de Migración y Despliegue Independiente**

Fecha de generación: Enero 2026
Versión del proyecto: V1 (MVP)

---

## Índice

1. [Estado del Proyecto (V1)](#1-estado-del-proyecto-v1)
2. [Arquitectura de Datos](#2-arquitectura-de-datos-crítico)
3. [Variables de Entorno y Secretos](#3-variables-de-entorno-y-secretos)
4. [Dependencias y Build](#4-dependencias-y-build)
5. [Guía de Independencia](#5-guía-de-independencia)
6. [Configuración de Supabase](#6-configuración-de-supabase)
7. [Despliegue en Vercel/Netlify](#7-despliegue-en-vercelnetlify)
8. [Valores Hardcoded](#8-valores-hardcoded-detectados)
9. [Testing Post-Migración](#9-testing-post-migración)

---

## 1. Estado del Proyecto (V1)

### 1.1 Resumen Rápido

**La Partideta Golf** es una aplicación web progresiva (PWA) para gestionar partidas de golf con sistema de puntuación Stableford, seguimiento de handicaps, estadísticas avanzadas y rankings competitivos.

**Problema que resuelve:**
- Eliminación del papel y cálculos manuales durante partidas de golf
- Seguimiento automático de puntos Stableford con handicaps variables
- Gestión de grupos de amigos con rankings y estadísticas históricas
- Accesibilidad desde cualquier dispositivo (móvil, tablet, ordenador)

### 1.2 Funcionalidades Clave (✅ ACTIVAS)

#### Partidas Rápidas
- ✅ **Crear Partideta Rápida**: Partida instantánea sin grupo (local)
- ✅ **Unirse a Partideta Rápida**: Unión mediante código de acceso de 4 dígitos
- ✅ **Tarjeta de Puntuación Interactiva**: Ingreso rápido de golpes por hoyo
- ✅ **Cálculo Automático Stableford**: Con soporte para handicaps y slope
- ✅ **Leaderboard en Tiempo Real**: Clasificación actualizada automáticamente
- ✅ **Gestión de Hoyos**: Configuración de 9 o 18 hoyos, personalización de stroke index
- ✅ **Estadísticas de Partida**: Métricas individuales post-partida

#### Multipartidetas (Grupos)
- ✅ **Unirse a Multipartideta**: Ingreso mediante código de grupo
- ✅ **Unirse con Código de Partida**: Acceso directo a partida mediante código de 4 dígitos
- ✅ **Acceso Limitado**: Distingue entre miembro completo vs. invitado temporal
- ✅ **Visualización de Partidas Activas**: Ver todas las partidas del grupo
- ✅ **Salir del Grupo**: Abandono voluntario del grupo

#### Campos de Golf
- ✅ **5 Campos Pre-configurados**:
  - Club de Golf Campestre (campo genérico)
  - Costa Azahar Golf - Verde (9 hoyos)
  - Costa Azahar Golf - Rojo (9 hoyos)
  - Mediterráneo Golf (18 hoyos)
  - Panorámica Golf (18 hoyos)
- ✅ **Sistema de Barras (Tees)**: Blancas, Amarillas, Rojas, Azules con slopes específicos
- ✅ **Cambio de Campo Durante Partida**: Con confirmación

#### Sistema de Premios Especiales (DIVEND)
- ✅ **"No Pasó de Rojas"**: Marca cuando un jugador no supera las barras rojas
- ✅ **"Hole in One"**: Modal celebratorio para hoyo en uno
- ✅ **Rankings Especiales**: "Rey del Bosque", "La Paliza", "Hoyo de la Muerte", etc.
- ✅ **Sistema de Cervezas**: Contabilización automática de cervezas ganadas/pagadas

#### Estadísticas Avanzadas
- ✅ **Estadísticas por Jugador**: Histórico completo con métricas detalladas
- ✅ **Rankings de Grupo**: Ordenación por múltiples criterios
- ✅ **Archivo de Rondas**: Historial permanente de partidas completadas
- ✅ **Gráficos de Rendimiento**: Visualización de tendencias

#### Panel de Administración (Grupo DIVEND)
- ✅ **Acceso mediante PIN**: Protección de funciones administrativas
- ✅ **Gestión de Handicaps**: Actualización manual de handicaps de jugadores
- ✅ **Vista de Rondas Completadas**: Listado de todas las partidas archivadas

### 1.3 Funcionalidades Bloqueadas (❌ DESHABILITADAS en V1)

Estas funcionalidades muestran modales de "Próximamente..." y NO están implementadas:

- ❌ **Crear Multipartideta**: Bloqueado con modal explicativo
- ❌ **Iniciar Sesión / Crear Cuenta**: Bloqueado con modal de expectativas
- ❌ **Gestión Multi-Grupo para Usuarios**: Sistema de autenticación deshabilitado
- ❌ **Sincronización Multi-Dispositivo**: Requiere autenticación
- ❌ **Notificaciones Push**: No implementadas
- ❌ **Modo Offline Avanzado**: Sin service worker

**Nota Importante**: La funcionalidad de crear grupos existe en el código pero está bloqueada a nivel de UI. La infraestructura de base de datos SÍ está lista para soportarlo.

---

## 2. Arquitectura de Datos (CRÍTICO)

### 2.1 Tipo de Base de Datos

**🔴 IMPORTANTE**: Esta aplicación usa **Supabase (PostgreSQL)** como base de datos principal.

- **Backend**: Supabase (servicio gestionado de PostgreSQL + API REST)
- **Cliente**: `@supabase/supabase-js` (v2.57.4)
- **Autenticación**: Supabase Auth (parcialmente configurado)
- **Storage**: NO se usa Supabase Storage en V1
- **Edge Functions**: NO se usan en V1

### 2.2 Esquema SQL Completo

Para recrear la base de datos COMPLETA en tu propio proyecto de Supabase, necesitas ejecutar las **98 migraciones** en orden cronológico. A continuación se detallan las tablas principales y sus relaciones:

#### Estructura de Tablas Principales

```sql
-- ============================================================
-- CAMPOS DE GOLF
-- ============================================================

-- Cursos de golf
CREATE TABLE golf_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Hoyos de los cursos
CREATE TABLE golf_holes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  hole_number integer NOT NULL CHECK (hole_number >= 1 AND hole_number <= 18),
  par integer NOT NULL CHECK (par >= 3 AND par <= 5),
  stroke_index integer NOT NULL CHECK (stroke_index >= 1 AND stroke_index <= 18),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(course_id, hole_number)
);

-- Barras (tees) con slopes
CREATE TABLE tees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text NOT NULL,
  slope_18 integer NOT NULL DEFAULT 113,
  slope_9_i integer NOT NULL DEFAULT 113,
  slope_9_ii integer NOT NULL DEFAULT 113,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- JUGADORES Y GRUPOS
-- ============================================================

-- Grupos (multipartidetas)
CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  group_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by text
);

-- Jugadores permanentes
CREATE TABLE players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  exact_handicap numeric NOT NULL DEFAULT 0,
  exact_handicap_18 numeric,
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(name, group_id)
);

-- ============================================================
-- RONDAS DE GOLF
-- ============================================================

-- Rondas (partidas)
CREATE TABLE golf_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  num_holes integer NOT NULL CHECK (num_holes IN (9, 18)),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  use_slope boolean DEFAULT false,
  access_code text NOT NULL,
  user_id text,
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  reference_number integer,
  holes_range text CHECK (holes_range IN ('1-9', '10-18')),
  tee_id uuid REFERENCES tees(id) ON DELETE SET NULL,
  manual_slope integer,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Jugadores en cada ronda
CREATE TABLE round_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  player_id uuid REFERENCES players(id),
  name text NOT NULL,
  exact_handicap numeric NOT NULL,
  exact_handicap_18 numeric,
  playing_handicap integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Puntuaciones por hoyo
CREATE TABLE round_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES round_players(id) ON DELETE CASCADE,
  hole_number integer NOT NULL,
  gross_strokes integer NOT NULL CHECK (gross_strokes >= 0),
  strokes_received integer NOT NULL DEFAULT 0,
  net_strokes integer NOT NULL,
  stableford_points integer NOT NULL DEFAULT 0,
  no_paso_rojas boolean DEFAULT false,
  abandoned boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(round_id, player_id, hole_number)
);

-- ============================================================
-- ESTADÍSTICAS Y ARCHIVO
-- ============================================================

-- Temporadas
CREATE TABLE seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  created_at timestamptz DEFAULT now()
);

-- Rondas archivadas
CREATE TABLE archived_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  played_at timestamptz NOT NULL,
  archived_at timestamptz DEFAULT now(),
  final_ranking jsonb NOT NULL,
  season_id uuid REFERENCES seasons(id) ON DELETE SET NULL,
  no_paso_rojas jsonb,
  hole_scores jsonb,
  player_stats jsonb,
  created_at timestamptz DEFAULT now()
);

-- Rankings diarios precalculados
CREATE TABLE daily_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  archived_round_id uuid NOT NULL REFERENCES archived_rounds(id) ON DELETE CASCADE,
  played_at timestamptz NOT NULL,
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  player_name text NOT NULL,
  position integer NOT NULL,
  points integer NOT NULL,
  hcp_juego numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(archived_round_id, player_id)
);

-- Historial de cambios de handicap
CREATE TABLE handicap_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  old_handicap numeric NOT NULL,
  new_handicap numeric NOT NULL,
  changed_at timestamptz DEFAULT now(),
  archived_round_id uuid REFERENCES archived_rounds(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Configuración de administrador
CREATE TABLE admin_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  admin_pin text NOT NULL CHECK (length(admin_pin) = 4),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Seguimiento de rondas completadas
CREATE TABLE completed_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id text NOT NULL,
  completed_at timestamptz DEFAULT now(),
  UNIQUE(round_id, user_id)
);
```

### 2.3 Obtención del Esquema Completo

**Opción 1: Ejecutar Migraciones Individualmente** (RECOMENDADO)

En tu proyecto de Supabase:

1. Ve a la sección **SQL Editor**
2. Ejecuta cada archivo SQL de la carpeta `supabase/migrations/` en orden cronológico
3. Los archivos están numerados por fecha: `YYYYMMDDHHMMSS_descripcion.sql`
4. Ejecuta en orden desde el más antiguo al más reciente

**Opción 2: Script de Consolidación**

Puedes crear un script que concatene todas las migraciones:

```bash
# Desde la raíz del proyecto
cd supabase/migrations
cat $(ls -1 *.sql | sort) > ../../schema_completo.sql
```

Luego ejecuta `schema_completo.sql` en tu proyecto de Supabase.

### 2.4 Datos Iniciales Críticos

#### Campos de Golf

Los campos están definidos en estas migraciones:
- `20251129033014_seed_default_course.sql` - Club de Golf Campestre
- `20251205225002_add_second_golf_course.sql` - Costa Azahar Verde
- `20251205225002_add_second_golf_course.sql` - Costa Azahar Rojo
- `20251210230857_add_mediterraneo_golf.sql` - Mediterráneo Golf
- `20251210231241_add_panoramica_golf.sql` - Panorámica Golf

#### Barras (Tees)

Las barras con slopes están en:
- `20260101165256_seed_default_tees_for_courses.sql` - Barras para todos los cursos
- `20260101171409_update_mediterraneo_golf_slopes.sql` - Slopes Mediterráneo
- `20260101213321_update_panoramica_golf_slopes.sql` - Slopes Panorámica

#### Grupo DIVEND

Si necesitas el grupo DIVEND con sus 22 jugadores:
- `20251222224959_add_divend_players.sql` - Jugadores DIVEND

**⚠️ NOTA**: El grupo DIVEND debe ser creado ANTES de ejecutar esta migración. Puedes hacerlo manualmente:

```sql
INSERT INTO groups (name, group_code, created_by)
VALUES ('DIVEND', 'DIVEND', 'admin')
ON CONFLICT (group_code) DO NOTHING;
```

#### Configuración de Administrador

```sql
INSERT INTO admin_config (admin_email, admin_pin)
VALUES ('tu_email@ejemplo.com', '2248');
```

### 2.5 Funciones y Triggers

La aplicación incluye múltiples funciones PostgreSQL para:
- Cálculo automático de rankings diarios
- Estadísticas de jugadores
- Funciones especiales de premios (Rey del Bosque, La Paliza, etc.)
- Actualización automática de nombres de jugadores en rondas archivadas

Estas funciones están distribuidas en varias migraciones (prefijo `create_*` y `fix_*`).

### 2.6 Row Level Security (RLS)

**Estado Actual**: RLS está HABILITADO pero con políticas PERMISIVAS para V1.

La mayoría de las tablas tienen políticas que permiten acceso público (`TO public USING (true)`). Esto es intencional para V1 ya que la autenticación está deshabilitada.

**Para V2**: Deberás revisar y endurecer las políticas RLS cuando actives la autenticación.

---

## 3. Variables de Entorno y Secretos

### 3.1 Variables Requeridas

Crea un archivo `.env` en la raíz del proyecto con las siguientes variables:

```env
# Supabase Configuration (OBLIGATORIO)
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=tu_clave_publica_anon

# Admin Configuration (OBLIGATORIO)
VITE_ADMIN_EMAIL=tu_email@ejemplo.com
VITE_ADMIN_PIN=2248
```

### 3.2 Cómo Obtener las Credenciales de Supabase

1. Ve a [https://supabase.com](https://supabase.com)
2. Crea un nuevo proyecto (o usa uno existente)
3. Ve a **Settings** → **API**
4. Copia:
   - **Project URL** → `VITE_SUPABASE_URL`
   - **anon/public key** → `VITE_SUPABASE_ANON_KEY`

### 3.3 Variables en Vercel/Netlify

Al desplegar en Vercel o Netlify, añade las mismas variables en la configuración del proyecto:

**Vercel**:
1. Ve a **Settings** → **Environment Variables**
2. Añade cada variable con su valor
3. Asegúrate de que estén disponibles para **Production**, **Preview** y **Development**

**Netlify**:
1. Ve a **Site settings** → **Environment variables**
2. Añade cada variable con su valor

### 3.4 Seguridad de Secretos

- ✅ **VITE_SUPABASE_URL**: Puede ser pública
- ✅ **VITE_SUPABASE_ANON_KEY**: Puede ser pública (clave anónima)
- ⚠️ **VITE_ADMIN_PIN**: Sensible pero necesario en frontend
- 🔴 **service_role_key**: NUNCA expongas esta clave en frontend

**Nota**: El prefijo `VITE_` hace que estas variables sean accesibles en el código del navegador. Esto es intencional para este tipo de aplicación.

---

## 4. Dependencias y Build

### 4.1 Dependencias Principales

```json
{
  "dependencies": {
    "@supabase/supabase-js": "^2.57.4",  // Cliente Supabase
    "lucide-react": "^0.344.0",          // Iconos
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",    // Plugin Vite para React
    "autoprefixer": "^10.4.18",          // PostCSS
    "tailwindcss": "^3.4.1",             // Framework CSS
    "typescript": "^5.5.3",              // TypeScript
    "vite": "^5.4.2"                     // Build tool
  }
}
```

### 4.2 Compatibilidad

- **Node.js**: >= 18.0.0 (recomendado 20.x LTS)
- **npm**: >= 9.0.0
- **Navegadores soportados**:
  - Chrome/Edge >= 90
  - Firefox >= 88
  - Safari >= 14
  - Mobile browsers (iOS Safari, Chrome Android)

### 4.3 Comandos de Build

```bash
# Instalar dependencias
npm install

# Desarrollo local (puerto 5173 por defecto)
npm run dev

# Type checking (sin compilar)
npm run typecheck

# Build para producción
npm run build

# Preview del build (puerto 4173 por defecto)
npm run preview

# Linting
npm run lint
```

### 4.4 Salida del Build

El comando `npm run build` genera:
- **Directorio**: `dist/`
- **index.html**: Punto de entrada
- **assets/**: JS, CSS e imágenes optimizadas
- **Tamaño aproximado**: ~600KB (JS) + ~60KB (CSS)

**Nota**: Los nombres de archivo incluyen timestamps para cache-busting.

### 4.5 Problemas Conocidos

#### Warning: Chunks grandes

```
(!) Some chunks are larger than 500 kB after minification
```

**Solución**: Ignorar por ahora. Para V2 considera:
- Code splitting con `React.lazy()`
- Importaciones dinámicas
- Configurar `build.rollupOptions.output.manualChunks`

#### Warning: Dynamic imports

```
(!) /src/services/supabaseClient.ts is dynamically imported but also statically imported
```

**Solución**: Ignorar. No afecta funcionalidad. Optimización para V2.

---

## 5. Guía de Independencia

### 5.1 Pasos para Conectar a GitHub

1. **Crea un nuevo repositorio en GitHub** (vacío, sin README)

2. **Desde la raíz del proyecto**, inicializa Git y conecta:

```bash
# Inicializar repositorio (si no existe)
git init

# Añadir todos los archivos
git add .

# Primer commit
git commit -m "feat: Initial commit - La Partideta Golf V1"

# Conectar con GitHub
git remote add origin https://github.com/TU_USUARIO/TU_REPO.git

# Subir código
git branch -M main
git push -u origin main
```

3. **Verifica que `.env` NO se suba** (ya está en `.gitignore`)

### 5.2 Configuración de .gitignore

Verifica que tu `.gitignore` incluya:

```
# Dependencias
node_modules/

# Build
dist/
dist-ssr/

# Entorno
.env
.env.local
.env.production

# IDE
.vscode/
.idea/

# Logs
*.log

# Sistema operativo
.DS_Store
Thumbs.db
```

### 5.3 Despliegue Continuo (CI/CD)

#### Vercel (RECOMENDADO)

1. Ve a [vercel.com](https://vercel.com) e inicia sesión con GitHub
2. Click **Add New Project**
3. Importa tu repositorio
4. Configura:
   - **Framework Preset**: Vite
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
   - **Install Command**: `npm install`
5. Añade las variables de entorno (sección 3.3)
6. Click **Deploy**

Vercel detectará automáticamente nuevos commits y desplegará.

#### Netlify

1. Ve a [netlify.com](https://netlify.com) e inicia sesión con GitHub
2. Click **Add new site** → **Import an existing project**
3. Selecciona tu repositorio
4. Configura:
   - **Build command**: `npm run build`
   - **Publish directory**: `dist`
5. Añade las variables de entorno (sección 3.3)
6. Click **Deploy site**

### 5.4 Configuración de SPA Routing

Ambas plataformas necesitan configuración para Single Page Applications:

**Vercel**: Crear `vercel.json` en la raíz:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/" }
  ]
}
```

**Netlify**: Crear `netlify.toml` en la raíz:

```toml
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

**Nota**: Actualmente la app no usa routing, pero es buena práctica para el futuro.

---

## 6. Configuración de Supabase

### 6.1 Crear Proyecto Nuevo

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Click **New Project**
3. Completa:
   - **Name**: La Partideta Golf
   - **Database Password**: Guárdala en un lugar seguro
   - **Region**: Elige la más cercana a tus usuarios
4. Espera ~2 minutos mientras se crea el proyecto

### 6.2 Ejecutar Migraciones

Opción A - **SQL Editor** (Manual pero seguro):

1. Ve a **SQL Editor** en el panel de Supabase
2. Abre cada archivo de `supabase/migrations/` en orden
3. Copia el contenido y ejecútalo
4. Verifica que no hay errores antes de continuar

Opción B - **Supabase CLI** (Automático):

```bash
# Instalar Supabase CLI
npm install -g supabase

# Login
supabase login

# Link a tu proyecto
supabase link --project-ref TU_PROJECT_REF

# Ejecutar todas las migraciones
supabase db push
```

**⚠️ IMPORTANTE**: Las migraciones deben ejecutarse en orden cronológico.

### 6.3 Verificación de Datos

Después de ejecutar las migraciones, verifica:

1. **Cursos de golf**:
```sql
SELECT name FROM golf_courses;
```
Deberías ver 5 cursos.

2. **Barras (tees)**:
```sql
SELECT course_id, name, slope_18 FROM tees;
```
Cada curso debe tener 2-4 barras.

3. **Grupo DIVEND** (si lo necesitas):
```sql
SELECT * FROM groups WHERE group_code = 'DIVEND';
SELECT COUNT(*) FROM players WHERE group_id IN (
  SELECT id FROM groups WHERE group_code = 'DIVEND'
);
```
Deberías ver el grupo y 22 jugadores.

### 6.4 Configuración de Autenticación

Aunque la autenticación está deshabilitada en V1, Supabase Auth debe estar activo:

1. Ve a **Authentication** → **Providers**
2. Asegúrate de que **Email** esté habilitado
3. **Email Confirmation**: DESHABILITADO (para V1)
4. **Autoconfirm**: HABILITADO

### 6.5 Configuración de API

1. Ve a **Settings** → **API**
2. **API Settings**:
   - ✅ Enable RLS: Activado
   - ✅ Enable Realtime: Opcional (no usado en V1)
3. **JWT Settings**: Dejar valores por defecto

---

## 7. Despliegue en Vercel/Netlify

### 7.1 Pre-despliegue Checklist

Antes de desplegar, verifica:

- [ ] Todas las migraciones están ejecutadas en Supabase
- [ ] Variables de entorno están configuradas
- [ ] `npm run build` funciona localmente sin errores
- [ ] `.env` NO está en el repositorio
- [ ] `.gitignore` está correctamente configurado
- [ ] Has testeado con `npm run preview` localmente

### 7.2 Configuración en Vercel

#### Método 1: Dashboard Web

1. Importa proyecto desde GitHub (sección 5.3)
2. Variables de entorno (sección 3.3)
3. Deploy

#### Método 2: Vercel CLI

```bash
# Instalar Vercel CLI
npm install -g vercel

# Login
vercel login

# Desplegar (primera vez)
vercel

# Seguir prompts:
# - Vincular a proyecto existente o crear nuevo
# - Configurar framework preset: Vite
# - Configurar directorio de build: dist

# Desplegar a producción
vercel --prod
```

### 7.3 Configuración en Netlify

#### Método 1: Dashboard Web

1. Importa proyecto desde GitHub (sección 5.3)
2. Configuración de build (sección 5.3)
3. Variables de entorno (sección 3.3)
4. Deploy

#### Método 2: Netlify CLI

```bash
# Instalar Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Inicializar proyecto
netlify init

# Deploy manual
netlify deploy --prod

# O configurar despliegue automático
netlify link
```

### 7.4 Dominios Personalizados

**Vercel**:
1. Ve a **Settings** → **Domains**
2. Add → Ingresa tu dominio
3. Configura DNS según instrucciones

**Netlify**:
1. Ve a **Domain settings** → **Add custom domain**
2. Ingresa tu dominio
3. Configura DNS según instrucciones

### 7.5 Performance y Optimización

**Headers recomendados**:

Para Vercel, añade a `vercel.json`:

```json
{
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

Para Netlify, añade a `netlify.toml`:

```toml
[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"
```

---

## 8. Valores Hardcoded Detectados

### 8.1 Código Administrativo

**Archivo**: `src/utils/adminPin.ts`

```typescript
const ADMIN_PIN = '2248';
```

**Acción**: Este valor está sincronizado con la variable de entorno `VITE_ADMIN_PIN`. Considera cambiarlo después del despliegue.

**Solución para V2**: Mover verificación al backend y usar Supabase Functions.

### 8.2 Grupo DIVEND

**Archivos afectados**:
- `supabase/migrations/*_divend_*.sql` (múltiples)
- `src/components/Statistics.tsx`
- `src/components/AdminDashboard.tsx`
- `src/services/golfService.ts`

**Referencias hardcoded**:
```typescript
const DIVEND_GROUP_CODE = 'DIVEND';
```

**Notas**:
- El grupo DIVEND tiene lógica especial para premios y estadísticas
- Si despliegas para otro grupo, puedes:
  1. Eliminar referencias a DIVEND
  2. Cambiar el código 'DIVEND' por el de tu grupo
  3. Crear un sistema configurable de "grupos especiales"

### 8.3 Códigos de Acceso

**Archivo**: `src/utils/accessCode.ts`

```typescript
export const generateAccessCode = (): string => {
  return Math.floor(1000 + Math.random() * 9000).toString();
};
```

Genera códigos de 4 dígitos aleatorios (1000-9999).

**No requiere cambios**: Funciona correctamente como está.

### 8.4 Emails en Base de Datos

**Archivo**: `supabase/migrations/20260109121041_create_admin_config_table.sql`

```sql
INSERT INTO admin_config (admin_email, admin_pin)
VALUES ('kike@kikealgora.com', '2248');
```

**Acción REQUERIDA**: Cambia este email al tuyo antes de ejecutar la migración.

### 8.5 Slopes por Defecto

**Archivo**: Múltiples migraciones de tees

```sql
slope_18 integer NOT NULL DEFAULT 113,
```

**Nota**: 113 es el slope estándar neutral. Los campos reales tienen sus propios valores definidos en migraciones específicas.

### 8.6 Configuración de Vite

**Archivo**: `vite.config.ts`

```typescript
entryFileNames: `assets/[name]-v${Date.now()}-[hash].js`,
```

Añade timestamp a los archivos para cache-busting.

**No requiere cambios**: Funciona correctamente.

---

## 9. Testing Post-Migración

### 9.1 Tests Críticos

Después de desplegar, verifica estas funcionalidades:

#### ✅ Funcionalidad Básica

1. **Crear Partideta Rápida**:
   - [ ] Seleccionar campo de golf
   - [ ] Añadir jugadores (mínimo 2)
   - [ ] Configurar handicaps
   - [ ] Iniciar partida

2. **Tarjeta de Puntuación**:
   - [ ] Ingresar golpes por hoyo
   - [ ] Ver cálculo automático de Stableford
   - [ ] Navegar entre hoyos
   - [ ] Ver leaderboard actualizado

3. **Unirse a Partida**:
   - [ ] Copiar código de acceso
   - [ ] Unirse desde otro navegador/dispositivo
   - [ ] Ver puntuaciones sincronizadas

#### ✅ Multipartidetas

1. **Unirse con Código de Grupo**:
   - [ ] Ingresar código DIVEND (si lo configuraste)
   - [ ] Ver partidas activas del grupo
   - [ ] Crear nueva partida en el grupo

2. **Estadísticas**:
   - [ ] Ver ranking histórico
   - [ ] Ver estadísticas individuales
   - [ ] Ver rondas archivadas

#### ✅ Funciones Avanzadas

1. **Cambio de Campo**:
   - [ ] Cambiar campo durante setup
   - [ ] Confirmación de cambio
   - [ ] Handicaps se recalculan

2. **Premios Especiales**:
   - [ ] Marcar "No Pasó de Rojas"
   - [ ] Modal de Hole in One
   - [ ] Sistema de cervezas (DIVEND)

3. **Panel Admin**:
   - [ ] Ingresar PIN correcto
   - [ ] Actualizar handicaps
   - [ ] Ver rondas completadas

### 9.2 Tests de Integración

```bash
# Test manual de variables de entorno
console.log(import.meta.env.VITE_SUPABASE_URL);
console.log(import.meta.env.VITE_SUPABASE_ANON_KEY);

# Debe mostrar tus URLs, NO 'undefined'
```

### 9.3 Tests de Base de Datos

Desde Supabase SQL Editor:

```sql
-- Verificar campos
SELECT COUNT(*) as total_cursos FROM golf_courses;
-- Esperado: 5

-- Verificar hoyos
SELECT COUNT(*) as total_hoyos FROM golf_holes;
-- Esperado: ~80 (depende de configuración)

-- Verificar barras
SELECT COUNT(*) as total_barras FROM tees;
-- Esperado: ~15-20

-- Test de RLS (debe funcionar)
SELECT * FROM golf_courses;
```

### 9.4 Tests de Rendimiento

1. **Lighthouse Score** (objetivo):
   - Performance: > 90
   - Accessibility: > 95
   - Best Practices: > 90
   - SEO: > 90

2. **Tiempo de carga**:
   - First Contentful Paint: < 1.5s
   - Time to Interactive: < 3.5s

3. **Mobile Performance**:
   - Probar en dispositivos reales
   - Chrome DevTools → Device mode

### 9.5 Checklist Final

Antes de marcar la migración como completada:

- [ ] La aplicación carga sin errores en consola
- [ ] Todas las variables de entorno están configuradas
- [ ] Puedes crear y unirte a partidas
- [ ] Las puntuaciones se guardan correctamente
- [ ] Supabase muestra datos en las tablas
- [ ] El dominio personalizado funciona (si aplica)
- [ ] SSL/HTTPS está activo
- [ ] Modales de "Próximamente" funcionan para features bloqueadas
- [ ] La app funciona en móvil
- [ ] Has cambiado el PIN de admin y el email

---

## 10. Soporte y Contacto

### 10.1 Recursos Útiles

- **Documentación Supabase**: [https://supabase.com/docs](https://supabase.com/docs)
- **Documentación Vite**: [https://vitejs.dev](https://vitejs.dev)
- **Documentación Vercel**: [https://vercel.com/docs](https://vercel.com/docs)
- **Documentación Netlify**: [https://docs.netlify.com](https://docs.netlify.com)

### 10.2 Problemas Comunes

#### "Missing environment variables"

**Síntoma**: La app muestra error al cargar.

**Solución**:
1. Verifica que `.env` existe y tiene las variables correctas
2. En producción, verifica que las variables están en Vercel/Netlify
3. Las variables deben tener el prefijo `VITE_`

#### "Failed to fetch" en Supabase

**Síntoma**: Errores de red al intentar acceder a datos.

**Solución**:
1. Verifica que `VITE_SUPABASE_URL` es correcta
2. Verifica que el proyecto de Supabase está activo
3. Revisa las políticas RLS en Supabase

#### Build falla en Vercel/Netlify

**Síntoma**: El deploy falla durante el build.

**Solución**:
1. Corre `npm run build` localmente
2. Revisa los logs del error
3. Asegúrate de que `node_modules` no está en Git
4. Verifica que la versión de Node.js es compatible

---

## Resumen Ejecutivo

**Para migrar La Partideta Golf V1 a un entorno independiente:**

1. ✅ **Crea un proyecto en Supabase** y ejecuta las 98 migraciones SQL
2. ✅ **Obtén las credenciales** (URL + anon key) y configúralas en `.env`
3. ✅ **Sube el código a GitHub** (sin `.env`)
4. ✅ **Despliega en Vercel o Netlify** con las variables de entorno configuradas
5. ✅ **Verifica funcionalidades críticas** según checklist de testing
6. ✅ **Cambia valores hardcoded** (PIN, email admin)

**Tiempo estimado**: 2-3 horas para un desarrollador experimentado.

**Costo mensual estimado**:
- Supabase Free Tier: $0 (hasta 500MB DB + 2GB bandwidth)
- Vercel Hobby: $0 (límites generosos)
- **Total: $0/mes** para uso personal o pequeños grupos

---

*Documento generado automáticamente el 12 de enero de 2026*
*La Partideta Golf V1 - Sistema de Gestión de Partidas de Golf*
