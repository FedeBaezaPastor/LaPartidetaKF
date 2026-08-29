-- ============================================================
-- LA PARTIDETA GOLF - ESQUEMA COMPLETO CON DATOS
-- ============================================================
--
-- Script consolidado para recrear la base de datos completa
-- Versión: V1.1 - Enero 2026
-- Incluye: Estructura + Datos de DIVEND
--
-- INSTRUCCIONES:
-- 1. Abre este archivo en Supabase SQL Editor
-- 2. Ejecuta el script completo (puede tardar 1-2 minutos)
-- 3. Verifica que no hay errores
-- 4. Confirma que las tablas y datos se crearon correctamente
--
-- IMPORTANTE:
-- - Este script limpia TODAS las tablas antes de recrearlas
-- - Se perderán TODOS los datos existentes
-- - Solo ejecutar en base de datos limpia o durante migración
--
-- ============================================================

-- ============================================================
-- PASO 1: LIMPIAR BASE DE DATOS
-- ============================================================

-- Deshabilitar temporalmente las políticas RLS para poder borrar
ALTER TABLE IF EXISTS completed_rounds DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS handicap_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS daily_rankings DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS archived_rounds DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS seasons DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS round_scores DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS round_players DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS golf_rounds DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS players DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tees DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS golf_holes DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS golf_courses DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS admin_config DISABLE ROW LEVEL SECURITY;

-- Eliminar tablas en orden inverso de dependencias
DROP TABLE IF EXISTS completed_rounds CASCADE;
DROP TABLE IF EXISTS handicap_history CASCADE;
DROP TABLE IF EXISTS daily_rankings CASCADE;
DROP TABLE IF EXISTS archived_rounds CASCADE;
DROP TABLE IF EXISTS seasons CASCADE;
DROP TABLE IF EXISTS round_scores CASCADE;
DROP TABLE IF EXISTS round_players CASCADE;
DROP TABLE IF EXISTS golf_rounds CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS tees CASCADE;
DROP TABLE IF EXISTS golf_holes CASCADE;
DROP TABLE IF EXISTS golf_courses CASCADE;
DROP TABLE IF EXISTS admin_config CASCADE;

-- Eliminar funciones si existen
DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_detailed_player_statistics(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS get_hoyo_muerte_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_hoyo_gloria_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_best_course_performance(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_worst_course_performance(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_rey_del_bosque_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_mas_birdie_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_mas_par_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_la_paliza_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_beer_statistics(uuid) CASCADE;
DROP FUNCTION IF EXISTS reset_reference_sequence(uuid) CASCADE;

-- ============================================================
-- PASO 2: CREAR TABLAS PRINCIPALES
-- ============================================================

-- Tabla: golf_courses
CREATE TABLE golf_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Tabla: golf_holes
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

-- Tabla: tees (barras con slopes)
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

-- Tabla: groups
CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  group_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by text
);

-- Tabla: players
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

-- Tabla: golf_rounds
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

-- Tabla: round_players
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

-- Tabla: round_scores
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

-- Tabla: seasons
CREATE TABLE seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  created_at timestamptz DEFAULT now()
);

-- Tabla: archived_rounds
CREATE TABLE archived_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  played_at timestamptz NOT NULL,
  archived_at timestamptz DEFAULT now(),
  final_ranking jsonb NOT NULL,
  season_id uuid REFERENCES seasons(id) ON DELETE SET NULL,
  hole_scores jsonb,
  player_stats jsonb,
  created_at timestamptz DEFAULT now()
);

-- Tabla: daily_rankings
CREATE TABLE daily_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  round_id uuid NOT NULL REFERENCES archived_rounds(id) ON DELETE CASCADE,
  played_at timestamptz NOT NULL,
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  player_name text NOT NULL,
  position integer NOT NULL,
  points integer NOT NULL,
  hcp_juego numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(round_id, player_id)
);

-- Tabla: handicap_history
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

-- Tabla: admin_config
CREATE TABLE admin_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  admin_pin text NOT NULL CHECK (length(admin_pin) = 4),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabla: completed_rounds
CREATE TABLE completed_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id text NOT NULL,
  completed_at timestamptz DEFAULT now(),
  UNIQUE(round_id, user_id)
);

-- ============================================================
-- PASO 3: CREAR ÍNDICES
-- ============================================================

CREATE INDEX idx_golf_holes_course_id ON golf_holes(course_id);
CREATE INDEX idx_tees_course_id ON tees(course_id);
CREATE INDEX idx_golf_rounds_course_id ON golf_rounds(course_id);
CREATE INDEX idx_golf_rounds_created_by ON golf_rounds(created_by);
CREATE INDEX idx_golf_rounds_status ON golf_rounds(status);
CREATE INDEX idx_golf_rounds_group_id ON golf_rounds(group_id);
CREATE INDEX idx_round_players_round_id ON round_players(round_id);
CREATE INDEX idx_round_players_player_id ON round_players(player_id);
CREATE INDEX idx_round_scores_round_id ON round_scores(round_id);
CREATE INDEX idx_round_scores_player_id ON round_scores(player_id);
CREATE INDEX idx_players_name ON players(name);
CREATE INDEX idx_players_group_id ON players(group_id);
CREATE INDEX idx_groups_group_code ON groups(group_code);
CREATE INDEX idx_archived_rounds_group_id ON archived_rounds(group_id);
CREATE INDEX idx_archived_rounds_season_id ON archived_rounds(season_id);
CREATE INDEX idx_archived_rounds_played_at ON archived_rounds(played_at);
CREATE INDEX idx_daily_rankings_group_id ON daily_rankings(group_id);
CREATE INDEX idx_daily_rankings_round_id ON daily_rankings(round_id);
CREATE INDEX idx_daily_rankings_player_id ON daily_rankings(player_id);
CREATE INDEX idx_handicap_history_player_id ON handicap_history(player_id);
CREATE INDEX idx_handicap_history_group_id ON handicap_history(group_id);
CREATE INDEX idx_seasons_group_id ON seasons(group_id);

-- ============================================================
-- PASO 4: HABILITAR ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE golf_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE golf_holes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tees ENABLE ROW LEVEL SECURITY;
ALTER TABLE golf_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE archived_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE handicap_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE completed_rounds ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PASO 5: CREAR POLÍTICAS RLS (PERMISIVAS PARA V1)
-- ============================================================

-- Políticas para golf_courses
CREATE POLICY "Anyone can view golf courses"
  ON golf_courses FOR SELECT
  TO public USING (true);

CREATE POLICY "Authenticated users can insert courses"
  ON golf_courses FOR INSERT
  TO authenticated WITH CHECK (true);

-- Políticas para golf_holes
CREATE POLICY "Anyone can view golf holes"
  ON golf_holes FOR SELECT
  TO public USING (true);

CREATE POLICY "Authenticated users can insert holes"
  ON golf_holes FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update holes"
  ON golf_holes FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

-- Políticas para tees
CREATE POLICY "Anyone can view tees"
  ON tees FOR SELECT
  TO public USING (true);

CREATE POLICY "Authenticated users can insert tees"
  ON tees FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update tees"
  ON tees FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete tees"
  ON tees FOR DELETE
  TO authenticated USING (true);

-- Políticas para golf_rounds
CREATE POLICY "Anyone can view rounds"
  ON golf_rounds FOR SELECT
  TO public USING (true);

CREATE POLICY "Anyone can create rounds"
  ON golf_rounds FOR INSERT
  TO public WITH CHECK (true);

CREATE POLICY "Anyone can update rounds"
  ON golf_rounds FOR UPDATE
  TO public USING (true) WITH CHECK (true);

CREATE POLICY "Anyone can delete rounds"
  ON golf_rounds FOR DELETE
  TO public USING (true);

-- Políticas para round_players
CREATE POLICY "Anyone can view players"
  ON round_players FOR SELECT
  TO public USING (true);

CREATE POLICY "Anyone can add players"
  ON round_players FOR INSERT
  TO public WITH CHECK (true);

CREATE POLICY "Anyone can update players"
  ON round_players FOR UPDATE
  TO public USING (true) WITH CHECK (true);

CREATE POLICY "Anyone can delete players"
  ON round_players FOR DELETE
  TO public USING (true);

-- Políticas para round_scores
CREATE POLICY "Anyone can view scores"
  ON round_scores FOR SELECT
  TO public USING (true);

CREATE POLICY "Anyone can insert scores"
  ON round_scores FOR INSERT
  TO public WITH CHECK (true);

CREATE POLICY "Anyone can update scores"
  ON round_scores FOR UPDATE
  TO public USING (true) WITH CHECK (true);

CREATE POLICY "Anyone can delete scores"
  ON round_scores FOR DELETE
  TO public USING (true);

-- Políticas para players
CREATE POLICY "Public can view players"
  ON players FOR SELECT
  TO public USING (true);

CREATE POLICY "Public can create players"
  ON players FOR INSERT
  TO public WITH CHECK (true);

CREATE POLICY "Public can update players"
  ON players FOR UPDATE
  TO public USING (true) WITH CHECK (true);

CREATE POLICY "Public can delete players"
  ON players FOR DELETE
  TO public USING (true);

-- Políticas para groups
CREATE POLICY "Anyone can create groups"
  ON groups FOR INSERT
  TO public WITH CHECK (true);

CREATE POLICY "Anyone can read groups"
  ON groups FOR SELECT
  TO public USING (true);

CREATE POLICY "Anyone can update groups"
  ON groups FOR UPDATE
  TO public USING (true) WITH CHECK (true);

-- Políticas para seasons, archived_rounds, daily_rankings, handicap_history
CREATE POLICY "Anyone can view seasons"
  ON seasons FOR SELECT TO public USING (true);
CREATE POLICY "Anyone can insert seasons"
  ON seasons FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Anyone can update seasons"
  ON seasons FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Anyone can delete seasons"
  ON seasons FOR DELETE TO public USING (true);

CREATE POLICY "Anyone can view archived rounds"
  ON archived_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Anyone can insert archived rounds"
  ON archived_rounds FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Anyone can update archived rounds"
  ON archived_rounds FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Anyone can delete archived rounds"
  ON archived_rounds FOR DELETE TO public USING (true);

CREATE POLICY "Anyone can view daily rankings"
  ON daily_rankings FOR SELECT TO public USING (true);
CREATE POLICY "Anyone can insert daily rankings"
  ON daily_rankings FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Anyone can update daily rankings"
  ON daily_rankings FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Anyone can delete daily rankings"
  ON daily_rankings FOR DELETE TO public USING (true);

CREATE POLICY "Anyone can view handicap history"
  ON handicap_history FOR SELECT TO public USING (true);
CREATE POLICY "Anyone can insert handicap history"
  ON handicap_history FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Anyone can update handicap history"
  ON handicap_history FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Anyone can delete handicap history"
  ON handicap_history FOR DELETE TO public USING (true);

CREATE POLICY "Authenticated can read admin config"
  ON admin_config FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can update admin config"
  ON admin_config FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Anyone can view completed rounds"
  ON completed_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Anyone can insert completed rounds"
  ON completed_rounds FOR INSERT TO public WITH CHECK (true);

-- ============================================================
-- PASO 6: INSERTAR DATOS - CAMPOS DE GOLF
-- ============================================================

-- Campo 1: Club de Golf Campestre (Genérico)
INSERT INTO golf_courses (id, name, description) VALUES
('00000000-0000-0000-0000-000000000001', 'Club de Golf Campestre', 'Campo de golf estándar de 18 hoyos con dificultad media');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('00000000-0000-0000-0000-000000000001', 1, 4, 5),
('00000000-0000-0000-0000-000000000001', 2, 3, 17),
('00000000-0000-0000-0000-000000000001', 3, 5, 1),
('00000000-0000-0000-0000-000000000001', 4, 4, 7),
('00000000-0000-0000-0000-000000000001', 5, 4, 11),
('00000000-0000-0000-0000-000000000001', 6, 3, 15),
('00000000-0000-0000-0000-000000000001', 7, 5, 3),
('00000000-0000-0000-0000-000000000001', 8, 4, 9),
('00000000-0000-0000-0000-000000000001', 9, 4, 13),
('00000000-0000-0000-0000-000000000001', 10, 4, 6),
('00000000-0000-0000-0000-000000000001', 11, 5, 2),
('00000000-0000-0000-0000-000000000001', 12, 3, 18),
('00000000-0000-0000-0000-000000000001', 13, 4, 8),
('00000000-0000-0000-0000-000000000001', 14, 4, 12),
('00000000-0000-0000-0000-000000000001', 15, 5, 4),
('00000000-0000-0000-0000-000000000001', 16, 3, 16),
('00000000-0000-0000-0000-000000000001', 17, 4, 10),
('00000000-0000-0000-0000-000000000001', 18, 4, 14);

-- Campo 2: Costa Azahar Golf - Verde (9 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('00000000-0000-0000-0000-000000000002', 'Costa Azahar Golf - Verde', 'Campo de 9 hoyos. Salida 1. Diseño técnico con vistas al mar.');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('00000000-0000-0000-0000-000000000002', 1, 4, 7),
('00000000-0000-0000-0000-000000000002', 2, 5, 1),
('00000000-0000-0000-0000-000000000002', 3, 3, 17),
('00000000-0000-0000-0000-000000000002', 4, 4, 9),
('00000000-0000-0000-0000-000000000002', 5, 4, 5),
('00000000-0000-0000-0000-000000000002', 6, 4, 11),
('00000000-0000-0000-0000-000000000002', 7, 3, 15),
('00000000-0000-0000-0000-000000000002', 8, 5, 3),
('00000000-0000-0000-0000-000000000002', 9, 4, 13),
('00000000-0000-0000-0000-000000000002', 10, 4, 8),
('00000000-0000-0000-0000-000000000002', 11, 5, 2),
('00000000-0000-0000-0000-000000000002', 12, 3, 18),
('00000000-0000-0000-0000-000000000002', 13, 4, 10),
('00000000-0000-0000-0000-000000000002', 14, 4, 6),
('00000000-0000-0000-0000-000000000002', 15, 4, 12),
('00000000-0000-0000-0000-000000000002', 16, 3, 16),
('00000000-0000-0000-0000-000000000002', 17, 5, 4),
('00000000-0000-0000-0000-000000000002', 18, 4, 14);

-- Campo 3: Costa Azahar Golf - Rojo (9 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('00000000-0000-0000-0000-000000000003', 'Costa Azahar Golf - Rojo', 'Campo de 9 hoyos. Salida 10. Recorrido clásico mediterráneo.');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('00000000-0000-0000-0000-000000000003', 1, 4, 8),
('00000000-0000-0000-0000-000000000003', 2, 5, 2),
('00000000-0000-0000-0000-000000000003', 3, 3, 18),
('00000000-0000-0000-0000-000000000003', 4, 4, 10),
('00000000-0000-0000-0000-000000000003', 5, 4, 6),
('00000000-0000-0000-0000-000000000003', 6, 4, 12),
('00000000-0000-0000-0000-000000000003', 7, 3, 16),
('00000000-0000-0000-0000-000000000003', 8, 5, 4),
('00000000-0000-0000-0000-000000000003', 9, 4, 14),
('00000000-0000-0000-0000-000000000003', 10, 4, 8),
('00000000-0000-0000-0000-000000000003', 11, 5, 2),
('00000000-0000-0000-0000-000000000003', 12, 3, 18),
('00000000-0000-0000-0000-000000000003', 13, 4, 10),
('00000000-0000-0000-0000-000000000003', 14, 4, 6),
('00000000-0000-0000-0000-000000000003', 15, 4, 12),
('00000000-0000-0000-0000-000000000003', 16, 3, 16),
('00000000-0000-0000-0000-000000000003', 17, 5, 4),
('00000000-0000-0000-0000-000000000003', 18, 4, 14);

-- Campo 4: Mediterráneo Golf (18 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('00000000-0000-0000-0000-000000000004', 'Mediterráneo Golf', 'Campo de 18 hoyos con diseño moderno y desafiante');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('00000000-0000-0000-0000-000000000004', 1, 4, 11),
('00000000-0000-0000-0000-000000000004', 2, 5, 5),
('00000000-0000-0000-0000-000000000004', 3, 3, 17),
('00000000-0000-0000-0000-000000000004', 4, 4, 1),
('00000000-0000-0000-0000-000000000004', 5, 4, 9),
('00000000-0000-0000-0000-000000000004', 6, 4, 15),
('00000000-0000-0000-0000-000000000004', 7, 3, 13),
('00000000-0000-0000-0000-000000000004', 8, 5, 3),
('00000000-0000-0000-0000-000000000004', 9, 4, 7),
('00000000-0000-0000-0000-000000000004', 10, 4, 10),
('00000000-0000-0000-0000-000000000004', 11, 5, 6),
('00000000-0000-0000-0000-000000000004', 12, 3, 18),
('00000000-0000-0000-0000-000000000004', 13, 4, 2),
('00000000-0000-0000-0000-000000000004', 14, 4, 8),
('00000000-0000-0000-0000-000000000004', 15, 4, 16),
('00000000-0000-0000-0000-000000000004', 16, 3, 14),
('00000000-0000-0000-0000-000000000004', 17, 5, 4),
('00000000-0000-0000-0000-000000000004', 18, 4, 12);

-- Campo 5: Panorámica Golf (18 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('00000000-0000-0000-0000-000000000005', 'Panorámica Golf', 'Campo de 18 hoyos con vistas espectaculares');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('00000000-0000-0000-0000-000000000005', 1, 4, 9),
('00000000-0000-0000-0000-000000000005', 2, 5, 3),
('00000000-0000-0000-0000-000000000005', 3, 3, 15),
('00000000-0000-0000-0000-000000000005', 4, 4, 1),
('00000000-0000-0000-0000-000000000005', 5, 4, 11),
('00000000-0000-0000-0000-000000000005', 6, 4, 13),
('00000000-0000-0000-0000-000000000005', 7, 3, 17),
('00000000-0000-0000-0000-000000000005', 8, 5, 5),
('00000000-0000-0000-0000-000000000005', 9, 4, 7),
('00000000-0000-0000-0000-000000000005', 10, 4, 10),
('00000000-0000-0000-0000-000000000005', 11, 5, 4),
('00000000-0000-0000-0000-000000000005', 12, 3, 16),
('00000000-0000-0000-0000-000000000005', 13, 4, 2),
('00000000-0000-0000-0000-000000000005', 14, 4, 12),
('00000000-0000-0000-0000-000000000005', 15, 4, 14),
('00000000-0000-0000-0000-000000000005', 16, 3, 18),
('00000000-0000-0000-0000-000000000005', 17, 5, 6),
('00000000-0000-0000-0000-000000000005', 18, 4, 8);

-- ============================================================
-- PASO 7: INSERTAR BARRAS (TEES) CON SLOPES
-- ============================================================

-- Barras para Club de Golf Campestre
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('00000000-0000-0000-0000-000000000001', 'Blancas', '#FFFFFF', 113, 113, 113),
('00000000-0000-0000-0000-000000000001', 'Amarillas', '#FCD34D', 113, 113, 113),
('00000000-0000-0000-0000-000000000001', 'Rojas', '#EF4444', 113, 113, 113);

-- Barras para Costa Azahar Verde
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('00000000-0000-0000-0000-000000000002', 'Blancas', '#FFFFFF', 122, 119, 125),
('00000000-0000-0000-0000-000000000002', 'Amarillas', '#FCD34D', 118, 115, 121),
('00000000-0000-0000-0000-000000000002', 'Rojas', '#EF4444', 127, 124, 130),
('00000000-0000-0000-0000-000000000002', 'Azules', '#3B82F6', 126, 123, 129);

-- Barras para Costa Azahar Rojo
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('00000000-0000-0000-0000-000000000003', 'Blancas', '#FFFFFF', 122, 125, 119),
('00000000-0000-0000-0000-000000000003', 'Amarillas', '#FCD34D', 118, 121, 115),
('00000000-0000-0000-0000-000000000003', 'Rojas', '#EF4444', 127, 130, 124),
('00000000-0000-0000-0000-000000000003', 'Azules', '#3B82F6', 126, 129, 123);

-- Barras para Mediterráneo Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('00000000-0000-0000-0000-000000000004', 'Blancas', '#FFFFFF', 129, 128, 130),
('00000000-0000-0000-0000-000000000004', 'Amarillas', '#FCD34D', 125, 124, 126),
('00000000-0000-0000-0000-000000000004', 'Rojas', '#EF4444', 134, 133, 135),
('00000000-0000-0000-0000-000000000004', 'Azules', '#3B82F6', 133, 132, 134);

-- Barras para Panorámica Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('00000000-0000-0000-0000-000000000005', 'Blancas', '#FFFFFF', 131, 130, 132),
('00000000-0000-0000-0000-000000000005', 'Amarillas', '#FCD34D', 127, 126, 128),
('00000000-0000-0000-0000-000000000005', 'Rojas', '#EF4444', 136, 135, 137),
('00000000-0000-0000-0000-000000000005', 'Azules', '#3B82F6', 135, 134, 136);

-- ============================================================
-- PASO 8: INSERTAR DATOS - GRUPO DIVEND
-- ============================================================

-- Grupo: Partideta dels divendres (DIVEND)
INSERT INTO groups (id, name, group_code, created_at, created_by) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Partideta dels divendres', 'DIVEND', '2025-12-22 21:57:17.190542+00', null);

-- ============================================================
-- PASO 9: INSERTAR DATOS - JUGADORES DIVEND (22 jugadores)
-- ============================================================

INSERT INTO players (id, name, exact_handicap, exact_handicap_18, group_id, created_at) VALUES
('91b48d8e-7d4f-4f92-ac93-560eed8e1f47', 'Alberto Usó', 0, 0, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-28 00:33:27.133237+00'),
('7ce52ab4-71ce-45e8-ab03-96a86d1476ef', 'Alfonso Cardona', 9, 9, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('6af8367a-2a8a-414e-b580-cc72178a0c82', 'Ángel Arrufat', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('4c41bddb-7784-473d-92ca-4ccc65e7fc18', 'Antonio Alegre', 14, 14, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('3369080e-8624-4085-99f1-d5698da8bb44', 'Arturo', 14, 14, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('1c7438a7-70bc-4e0d-b3d5-dff2967699f5', 'Carlos Pascual', 13, 13, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('89d0f23f-882e-424c-94a7-4a2712f15788', 'Fede Baeza', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('5f375d1a-6ddc-41f8-810d-32fda1b1715a', 'Fernando', 3, 3, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('803493eb-bafa-486f-afc0-b209a3558c12', 'Guti', 5, 5, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('df5ebe85-7a4b-4f50-8292-1c89e2ad4a40', 'Juan Bosch', 6, 6, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('b83c753b-2d88-4d52-8a4b-18533cad4403', 'Kike Algora', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('11ca0179-cc5f-4c91-b2df-6c3abdcb717d', 'Martincho', 8, 8, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('a1d1d46d-a1de-41f6-bbca-b126b6b3df8f', 'Nacho Bernat', 13, 13, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('fb606c90-c3f9-4a04-b81f-b1903d787790', 'Pablo Armengot', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('7a2c6452-e7a9-48cd-bbb3-1e36dbd17d48', 'Pablo Espinosa', 6, 6, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('0f89e919-afe2-46f3-9755-82109bcd1235', 'Quique Fabregat', 12, 12, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2026-01-06 21:49:24.619544+00'),
('b4eba18a-9def-4a69-8596-38d7c8a1f988', 'Rafa Salcedo', 10, 10, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('62cafa87-2304-4d0a-ac60-cda603154d53', 'Rebeca Sánchez', 10, 10, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('1d0a8309-104a-4e30-844f-ffa71f9ad63e', 'Salva Martinez', 15, 15, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('eb0b013a-b90f-41d5-bb01-1efcd6ff4a47', 'Saul Viciano', 12, 12, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00'),
('e8263a13-4831-45fc-8bfd-f849d9cb2647', 'Toni Serra', 9, 9, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2026-01-09 12:30:45.192183+00'),
('cc99929b-0d43-4764-b417-82b366992c4c', 'Victor Zeyani', 4, 4, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00');

-- ============================================================
-- PASO 10: INSERTAR DATOS - PARTIDAS ARCHIVADAS (3 rondas)
-- ============================================================

-- Partida 1: 09/01/2026 13:40 - Guti, Martincho, Quique Fabregat, Saul Viciano
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, created_at) VALUES
('689324b7-027c-4fe0-ba9b-e35a1764f241', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Golf Costa Azahar - Verde', '2026-01-09 13:40:48.630622+00', '2026-01-09 16:29:43.461778+00', 
'[{"points":17,"handicap":6,"position":1,"hcp_juego":6,"player_id":"803493eb-bafa-486f-afc0-b209a3558c12","player_name":"Guti"},{"points":12,"handicap":9,"position":2,"hcp_juego":9,"player_id":"77df31f3-a61a-4efb-a8f1-71ee28d602a7","player_name":"Martincho"},{"points":10,"handicap":12,"position":3,"hcp_juego":12,"player_id":"de1e775f-e711-4b87-ba3d-38700b6428f8","player_name":"Quique Fabregat"},{"points":9,"handicap":12,"position":4,"hcp_juego":12,"player_id":"ae2d8383-5c72-4611-aab9-9a43a1ae5341","player_name":"Saul Viciano"}]'::jsonb, 
null, '2026-01-09 16:29:43.461778+00');

-- Partida 2: 09/01/2026 13:42 - Nacho Bernat, Fede Baeza, Carlos Pascual
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, created_at) VALUES
('9b6d8cc5-faf0-4581-98f7-aa29cbf28eb8', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Golf Costa Azahar - Verde', '2026-01-09 13:42:48.632774+00', '2026-01-09 16:29:42.370629+00',
'[{"points":21,"handicap":14,"position":1,"hcp_juego":14,"player_id":"25fec838-37c8-4d97-a209-694354c69b50","player_name":"Nacho Bernat"},{"points":11,"handicap":10,"position":2,"hcp_juego":10,"player_id":"2c710da6-d394-4b45-8a61-af136b926cba","player_name":"Fede Baeza"},{"points":6,"handicap":13,"position":3,"hcp_juego":13,"player_id":"4b03a78b-10ae-4648-80e3-2401a7d696f8","player_name":"Carlos Pascual"}]'::jsonb,
null, '2026-01-09 16:29:42.370629+00');

-- Partida 3: 09/01/2026 13:47 - Victor Zeyani, Kike Algora, Alfonso Cardona
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, created_at) VALUES
('313958f3-fc2e-4eef-b573-c72257ae4ec8', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Golf Costa Azahar - Verde', '2026-01-09 13:47:55.016281+00', '2026-01-09 16:29:41.231368+00',
'[{"points":17,"handicap":5,"position":1,"hcp_juego":5,"player_id":"9903ec2c-c0f3-4e63-95f0-38c0914dc0d9","player_name":"Victor Zeyani"},{"points":15,"handicap":12,"position":2,"hcp_juego":12,"player_id":"08bc44a5-deb3-4ed5-a5e3-0c78458fd186","player_name":"Kike Algora"},{"points":11,"handicap":8,"position":3,"hcp_juego":8,"player_id":"07d2112c-9651-408e-afc5-1e03fce49eed","player_name":"Alfonso Cardona"}]'::jsonb,
null, '2026-01-09 16:29:41.231368+00');

-- ============================================================
-- PASO 11: INSERTAR DAILY RANKINGS DE LAS PARTIDAS
-- ============================================================

-- Rankings partida 1
INSERT INTO daily_rankings (group_id, round_id, played_at, player_id, player_name, position, points, hcp_juego) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '689324b7-027c-4fe0-ba9b-e35a1764f241', '2026-01-09 13:40:48.630622+00', '803493eb-bafa-486f-afc0-b209a3558c12', 'Guti', 1, 17, 6),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '689324b7-027c-4fe0-ba9b-e35a1764f241', '2026-01-09 13:40:48.630622+00', '11ca0179-cc5f-4c91-b2df-6c3abdcb717d', 'Martincho', 2, 12, 9),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '689324b7-027c-4fe0-ba9b-e35a1764f241', '2026-01-09 13:40:48.630622+00', '0f89e919-afe2-46f3-9755-82109bcd1235', 'Quique Fabregat', 3, 10, 12),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '689324b7-027c-4fe0-ba9b-e35a1764f241', '2026-01-09 13:40:48.630622+00', 'eb0b013a-b90f-41d5-bb01-1efcd6ff4a47', 'Saul Viciano', 4, 9, 12);

-- Rankings partida 2
INSERT INTO daily_rankings (group_id, round_id, played_at, player_id, player_name, position, points, hcp_juego) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '9b6d8cc5-faf0-4581-98f7-aa29cbf28eb8', '2026-01-09 13:42:48.632774+00', 'a1d1d46d-a1de-41f6-bbca-b126b6b3df8f', 'Nacho Bernat', 1, 21, 14),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '9b6d8cc5-faf0-4581-98f7-aa29cbf28eb8', '2026-01-09 13:42:48.632774+00', '89d0f23f-882e-424c-94a7-4a2712f15788', 'Fede Baeza', 2, 11, 10),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '9b6d8cc5-faf0-4581-98f7-aa29cbf28eb8', '2026-01-09 13:42:48.632774+00', '1c7438a7-70bc-4e0d-b3d5-dff2967699f5', 'Carlos Pascual', 3, 6, 13);

-- Rankings partida 3
INSERT INTO daily_rankings (group_id, round_id, played_at, player_id, player_name, position, points, hcp_juego) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '313958f3-fc2e-4eef-b573-c72257ae4ec8', '2026-01-09 13:47:55.016281+00', 'cc99929b-0d43-4764-b417-82b366992c4c', 'Victor Zeyani', 1, 17, 5),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '313958f3-fc2e-4eef-b573-c72257ae4ec8', '2026-01-09 13:47:55.016281+00', 'b83c753b-2d88-4d52-8a4b-18533cad4403', 'Kike Algora', 2, 15, 12),
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '313958f3-fc2e-4eef-b573-c72257ae4ec8', '2026-01-09 13:47:55.016281+00', '7ce52ab4-71ce-45e8-ab03-96a86d1476ef', 'Alfonso Cardona', 3, 11, 8);

-- ============================================================
-- PASO 12: INSERTAR CONFIGURACIÓN DE ADMINISTRADOR
-- ============================================================

INSERT INTO admin_config (admin_email, admin_pin) VALUES
('kike@kikealgora.com', '2248');

-- ============================================================
-- PASO 13: CREAR FUNCIÓN DE RESET DE SECUENCIAS
-- ============================================================

CREATE OR REPLACE FUNCTION reset_reference_sequence(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Esta función resetea las secuencias de referencia para un grupo
  -- No necesita hacer nada en esta versión simplificada
  RETURN;
END;
$$;

-- ============================================================
-- PASO 14: CREAR FUNCIÓN DE CÁLCULO DE RANKING DIARIO
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_archived_round_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_group_id uuid;
  v_played_at timestamptz;
  v_ranking jsonb;
  v_player jsonb;
BEGIN
  -- Obtener group_id y played_at de la ronda archivada
  SELECT group_id, played_at, final_ranking
  INTO v_group_id, v_played_at, v_ranking
  FROM archived_rounds
  WHERE id = p_archived_round_id;

  -- Borrar rankings existentes para esta ronda
  DELETE FROM daily_rankings WHERE round_id = p_archived_round_id;

  -- Insertar nuevos rankings
  FOR v_player IN SELECT * FROM jsonb_array_elements(v_ranking)
  LOOP
    INSERT INTO daily_rankings (
      group_id,
      round_id,
      played_at,
      player_id,
      player_name,
      position,
      points,
      hcp_juego
    )
    SELECT
      v_group_id,
      p_archived_round_id,
      v_played_at,
      p.id,
      v_player->>'player_name',
      (v_player->>'position')::integer,
      (v_player->>'points')::integer,
      (v_player->>'hcp_juego')::numeric
    FROM players p
    WHERE p.name = v_player->>'player_name'
      AND p.group_id = v_group_id
    LIMIT 1;
  END LOOP;
END;
$$;

-- ============================================================
-- COMPLETADO
-- ============================================================
--
-- El esquema se ha creado exitosamente con todos los datos de DIVEND.
--
-- Próximos pasos:
-- 1. Verifica que no hay errores en la ejecución
-- 2. Confirma que las tablas se crearon:
--    SELECT table_name FROM information_schema.tables
--    WHERE table_schema = 'public' ORDER BY table_name;
-- 3. Verifica los datos iniciales:
--    SELECT name FROM golf_courses;
--    SELECT COUNT(*) FROM golf_holes;
--    SELECT COUNT(*) FROM tees;
-- 4. Verifica los datos de DIVEND:
--    SELECT name FROM groups WHERE group_code = 'DIVEND';
--    SELECT COUNT(*) FROM players WHERE group_id IN (SELECT id FROM groups WHERE group_code = 'DIVEND');
--    SELECT COUNT(*) FROM archived_rounds WHERE group_id IN (SELECT id FROM groups WHERE group_code = 'DIVEND');
--
-- ============================================================
