-- ============================================================
-- LA PARTIDETA GOLF - ESTRUCTURA Y LÓGICA MAESTRA
-- ============================================================

-- PASO 1: LIMPIEZA TOTAL DE LA BASE DE DATOS
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

DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date) CASCADE;
DROP FUNCTION IF EXISTS trigger_calculate_daily_ranking() CASCADE;
DROP FUNCTION IF EXISTS get_detailed_player_statistics(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS get_patrocinador_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_barra_libre_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_corto_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_driver_oro_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_francotirador_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_maquina_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_amigo_del_mas_uno_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_rey_del_bosque_ranking(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_hoyo_muerte(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_hoyo_gloria(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_mejor_ronda_campo(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_la_paliza(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_divend_statistics(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_divend_beer_statistics(uuid) CASCADE;
DROP FUNCTION IF EXISTS calculate_beer_stats_for_round(uuid, date) CASCADE;
DROP FUNCTION IF EXISTS reset_reference_sequence(uuid) CASCADE;
DROP FUNCTION IF EXISTS update_player_name_in_archived_rounds() CASCADE;
DROP FUNCTION IF EXISTS recalculate_archived_round_stats(uuid) CASCADE;

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

-- PASO 2: CREAR ESQUEMA DE TABLAS
CREATE TABLE golf_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamptz DEFAULT now()
);

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

CREATE TABLE tees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text NOT NULL,
  slope_18 integer NOT NULL DEFAULT 113,
  slope_9_i integer NOT NULL DEFAULT 113,
  slope_9_ii integer NOT NULL DEFAULT 113,
  created_at timestamptz DEFAULT now(),
  UNIQUE(course_id, name)
);

CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  group_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by text
);

CREATE TABLE players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  exact_handicap numeric NOT NULL DEFAULT 0,
  exact_handicap_18 numeric DEFAULT 0,
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(name, group_id)
);

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

CREATE TABLE round_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  name text NOT NULL,
  exact_handicap numeric NOT NULL,
  exact_handicap_18 numeric,
  playing_handicap integer NOT NULL,
  initial_handicap numeric,
  final_handicap numeric,
  handicap_adjustment numeric DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

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

CREATE TABLE seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  created_at timestamptz DEFAULT now()
);

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

CREATE TABLE daily_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  ranking_date date NOT NULL,
  player_name text NOT NULL,
  total_points numeric NOT NULL,
  position integer NOT NULL,
  receives_beer boolean NOT NULL DEFAULT false,
  pays_beer boolean NOT NULL DEFAULT false,
  won_skin boolean DEFAULT false,
  total_strokes integer DEFAULT 0,
  total_stableford_net integer DEFAULT 0,
  hcp_juego integer,
  handicap_play numeric,
  created_at timestamptz DEFAULT now(),
  UNIQUE(group_id, ranking_date, player_name)
);

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

CREATE TABLE admin_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  admin_pin text NOT NULL CHECK (length(admin_pin) = 4),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE completed_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id text NOT NULL,
  completed_at timestamptz DEFAULT now(),
  UNIQUE(round_id, user_id)
);

-- PASO 3: CREAR ÍNDICES
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
CREATE INDEX idx_daily_rankings_date ON daily_rankings(ranking_date);
CREATE INDEX idx_daily_rankings_player ON daily_rankings(player_name);
CREATE INDEX idx_handicap_history_player_id ON handicap_history(player_id);
CREATE INDEX idx_handicap_history_group_id ON handicap_history(group_id);
CREATE INDEX idx_seasons_group_id ON seasons(group_id);

-- PASO 4: HABILITAR ROW LEVEL SECURITY
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

-- PASO 5: CREAR POLÍTICAS RLS
CREATE POLICY "Public can view courses" ON golf_courses FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert courses" ON golf_courses FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update courses" ON golf_courses FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete courses" ON golf_courses FOR DELETE TO public USING (true);

CREATE POLICY "Public can view holes" ON golf_holes FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert holes" ON golf_holes FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update holes" ON golf_holes FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete holes" ON golf_holes FOR DELETE TO public USING (true);

CREATE POLICY "Public can view tees" ON tees FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert tees" ON tees FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update tees" ON tees FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete tees" ON tees FOR DELETE TO public USING (true);

CREATE POLICY "Public can view rounds" ON golf_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert rounds" ON golf_rounds FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update rounds" ON golf_rounds FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete rounds" ON golf_rounds FOR DELETE TO public USING (true);

CREATE POLICY "Public can view round players" ON round_players FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert round players" ON round_players FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update round players" ON round_players FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete round players" ON round_players FOR DELETE TO public USING (true);

CREATE POLICY "Public can view scores" ON round_scores FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert scores" ON round_scores FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update scores" ON round_scores FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete scores" ON round_scores FOR DELETE TO public USING (true);

CREATE POLICY "Public can view players" ON players FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert players" ON players FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update players" ON players FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete players" ON players FOR DELETE TO public USING (true);

CREATE POLICY "Public can view groups" ON groups FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert groups" ON groups FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update groups" ON groups FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete groups" ON groups FOR DELETE TO public USING (true);

CREATE POLICY "Public can view seasons" ON seasons FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert seasons" ON seasons FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update seasons" ON seasons FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete seasons" ON seasons FOR DELETE TO public USING (true);

CREATE POLICY "Public can view archived rounds" ON archived_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert archived rounds" ON archived_rounds FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update archived rounds" ON archived_rounds FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete archived rounds" ON archived_rounds FOR DELETE TO public USING (true);

CREATE POLICY "Public can view daily rankings" ON daily_rankings FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert daily rankings" ON daily_rankings FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update daily rankings" ON daily_rankings FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete daily rankings" ON daily_rankings FOR DELETE TO public USING (true);

CREATE POLICY "Public can view handicap history" ON handicap_history FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert handicap history" ON handicap_history FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update handicap history" ON handicap_history FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete handicap history" ON handicap_history FOR DELETE TO public USING (true);

CREATE POLICY "Public can read admin config" ON admin_config FOR SELECT TO public USING (true);
CREATE POLICY "Authenticated can update admin config" ON admin_config FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Public can view completed rounds" ON completed_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert completed rounds" ON completed_rounds FOR INSERT TO public WITH CHECK (true);