-- ============================================================
-- LA PARTIDETA GOLF - ESTRUCTURA Y LÓGICA MAESTRA
-- ============================================================
--
-- ARCHIVO 1 DE 2: Estructura de base de datos y lógica de negocio
-- Versión: PRODUCTION v1.0
-- Fecha: Enero 2026
--
-- Este archivo contiene:
-- 1. Eliminación completa de la estructura anterior
-- 2. Esquema de tablas corregido (DDL)
-- 3. Índices para optimización
-- 4. Row Level Security (RLS) con políticas públicas
-- 5. Funciones RPC y Triggers (lógica de negocio)
--
-- IMPORTANTE: Ejecuta este archivo ANTES de 02_clean_data_seeds.sql
--
-- ============================================================

-- ============================================================
-- PASO 1: LIMPIEZA TOTAL DE LA BASE DE DATOS
-- ============================================================

-- Deshabilitar RLS para poder eliminar
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

-- Eliminar todas las funciones existentes
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

-- Eliminar todas las tablas
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

-- ============================================================
-- PASO 2: CREAR ESQUEMA DE TABLAS (DDL)
-- ============================================================

-- Tabla: golf_courses
-- Almacena los campos de golf disponibles
CREATE TABLE golf_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Tabla: golf_holes
-- Define cada hoyo de un campo con su par y stroke index
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

-- Tabla: tees
-- Barras de salida con sus slopes específicos
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

-- Tabla: groups
-- Grupos de jugadores (ej: DIVEND)
CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  group_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by text
);

-- Tabla: players
-- Jugadores registrados con su hándicap actual
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

-- Tabla: golf_rounds
-- Partidas activas en curso
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

-- Tabla: round_players (CORREGIDA)
-- Jugadores participantes en una partida
-- NUEVAS COLUMNAS: initial_handicap, final_handicap, handicap_adjustment
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

-- Tabla: round_scores
-- Scores hoyo por hoyo durante una partida
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
-- Temporadas para agrupar partidas
CREATE TABLE seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  created_at timestamptz DEFAULT now()
);

-- Tabla: archived_rounds
-- Historial de partidas completadas
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

-- Tabla: daily_rankings (CORREGIDA)
-- Rankings diarios con estadísticas de cerveza y skins
-- NUEVAS COLUMNAS: won_skin, total_strokes, total_stableford_net
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

-- Tabla: handicap_history
-- Historial de cambios de hándicap
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
-- Configuración de administrador
CREATE TABLE admin_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  admin_pin text NOT NULL CHECK (length(admin_pin) = 4),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabla: completed_rounds
-- Tracking de rondas completadas por usuario
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
CREATE INDEX idx_daily_rankings_date ON daily_rankings(ranking_date);
CREATE INDEX idx_daily_rankings_player ON daily_rankings(player_name);
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
-- PASO 5: CREAR POLÍTICAS RLS (PÚBLICAS PARA V1)
-- ============================================================

-- Políticas públicas para golf_courses
CREATE POLICY "Public can view courses" ON golf_courses FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert courses" ON golf_courses FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update courses" ON golf_courses FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete courses" ON golf_courses FOR DELETE TO public USING (true);

-- Políticas públicas para golf_holes
CREATE POLICY "Public can view holes" ON golf_holes FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert holes" ON golf_holes FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update holes" ON golf_holes FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete holes" ON golf_holes FOR DELETE TO public USING (true);

-- Políticas públicas para tees
CREATE POLICY "Public can view tees" ON tees FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert tees" ON tees FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update tees" ON tees FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete tees" ON tees FOR DELETE TO public USING (true);

-- Políticas públicas para golf_rounds
CREATE POLICY "Public can view rounds" ON golf_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert rounds" ON golf_rounds FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update rounds" ON golf_rounds FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete rounds" ON golf_rounds FOR DELETE TO public USING (true);

-- Políticas públicas para round_players
CREATE POLICY "Public can view round players" ON round_players FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert round players" ON round_players FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update round players" ON round_players FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete round players" ON round_players FOR DELETE TO public USING (true);

-- Políticas públicas para round_scores
CREATE POLICY "Public can view scores" ON round_scores FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert scores" ON round_scores FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update scores" ON round_scores FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete scores" ON round_scores FOR DELETE TO public USING (true);

-- Políticas públicas para players
CREATE POLICY "Public can view players" ON players FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert players" ON players FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update players" ON players FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete players" ON players FOR DELETE TO public USING (true);

-- Políticas públicas para groups
CREATE POLICY "Public can view groups" ON groups FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert groups" ON groups FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update groups" ON groups FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete groups" ON groups FOR DELETE TO public USING (true);

-- Políticas públicas para seasons
CREATE POLICY "Public can view seasons" ON seasons FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert seasons" ON seasons FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update seasons" ON seasons FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete seasons" ON seasons FOR DELETE TO public USING (true);

-- Políticas públicas para archived_rounds
CREATE POLICY "Public can view archived rounds" ON archived_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert archived rounds" ON archived_rounds FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update archived rounds" ON archived_rounds FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete archived rounds" ON archived_rounds FOR DELETE TO public USING (true);

-- Políticas públicas para daily_rankings
CREATE POLICY "Public can view daily rankings" ON daily_rankings FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert daily rankings" ON daily_rankings FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update daily rankings" ON daily_rankings FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete daily rankings" ON daily_rankings FOR DELETE TO public USING (true);

-- Políticas públicas para handicap_history
CREATE POLICY "Public can view handicap history" ON handicap_history FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert handicap history" ON handicap_history FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public can update handicap history" ON handicap_history FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public can delete handicap history" ON handicap_history FOR DELETE TO public USING (true);

-- Políticas para admin_config
CREATE POLICY "Public can read admin config" ON admin_config FOR SELECT TO public USING (true);
CREATE POLICY "Authenticated can update admin config" ON admin_config FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Políticas públicas para completed_rounds
CREATE POLICY "Public can view completed rounds" ON completed_rounds FOR SELECT TO public USING (true);
CREATE POLICY "Public can insert completed rounds" ON completed_rounds FOR INSERT TO public WITH CHECK (true);

-- ============================================================
-- PASO 6: FUNCIONES RPC - LÓGICA DE NEGOCIO
-- ============================================================

-- Función: calculate_daily_ranking
-- Calcula el ranking diario y determina quién paga/recibe cervezas
CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete existing rankings for this date to recalculate
  DELETE FROM daily_rankings
  WHERE group_id = p_group_id
    AND ranking_date = p_date;

  -- Calculate total points per player with handicap for tiebreaking
  WITH player_totals AS (
    SELECT
      p_group_id as group_id,
      p_date as ranking_date,
      (elem->>'player_name')::text as player_name,
      SUM((elem->>'points')::numeric) as total_points,
      MIN((elem->>'hcp_juego')::integer) as hcp_juego,
      SUM(
        COALESCE(
          (SELECT SUM((score->>'gross_strokes')::integer)
           FROM jsonb_array_elements(ar.hole_scores) AS score
           WHERE score->>'player_name' = elem->>'player_name'
          ), 0)
      ) as total_strokes,
      SUM((elem->>'points')::numeric) as total_stableford_net
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND DATE(ar.archived_at) = p_date
    GROUP BY (elem->>'player_name')::text
  ),
  ranked_players AS (
    SELECT
      group_id,
      ranking_date,
      player_name,
      total_points,
      hcp_juego,
      total_strokes,
      total_stableford_net,
      ROW_NUMBER() OVER (
        ORDER BY
          total_points DESC,
          hcp_juego ASC,
          player_name ASC
      ) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
  )
  INSERT INTO daily_rankings (
    group_id,
    ranking_date,
    player_name,
    total_points,
    hcp_juego,
    position,
    receives_beer,
    pays_beer,
    total_strokes,
    total_stableford_net,
    handicap_play
  )
  SELECT
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.hcp_juego,
    rp.position,
    -- Receives beer: top floor(n/2) positions
    rp.position <= FLOOR(pc.total / 2.0) as receives_beer,
    -- Pays beer: bottom floor(n/2) positions
    CASE
      WHEN pc.total % 2 = 0 THEN rp.position > (pc.total / 2)
      ELSE rp.position > FLOOR(pc.total / 2.0) + 1
    END as pays_beer,
    rp.total_strokes,
    rp.total_stableford_net,
    rp.hcp_juego::numeric
  FROM ranked_players rp
  CROSS JOIN player_count pc;
END;
$$;

-- Función: get_patrocinador_ranking (El Patrocinador)
-- Jugador que más cervezas ha pagado
CREATE OR REPLACE FUNCTION get_patrocinador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  total_beers_paid bigint,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    COUNT(*) FILTER (WHERE dr.pays_beer = true) as total_beers_paid,
    COUNT(DISTINCT dr.ranking_date) as total_rounds
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.pays_beer = true) > 0
  ORDER BY total_beers_paid DESC, player_name ASC
  LIMIT 10;
END;
$$;

-- Función: get_barra_libre_ranking (Barra Libre)
-- Jugador que más cervezas ha ganado
CREATE OR REPLACE FUNCTION get_barra_libre_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  total_beers_won bigint,
  total_rounds bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    COUNT(*) FILTER (WHERE dr.receives_beer = true) as total_beers_won,
    COUNT(DISTINCT dr.ranking_date) as total_rounds
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.receives_beer = true) > 0
  ORDER BY total_beers_won DESC, player_name ASC
  LIMIT 10;
END;
$$;

-- Función: get_corto_ranking (El Corto)
-- Jugador con el hándicap más bajo
CREATE OR REPLACE FUNCTION get_corto_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  current_handicap numeric,
  rounds_played bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.name as player_name,
    p.exact_handicap as current_handicap,
    COUNT(DISTINCT dr.ranking_date) as rounds_played
  FROM players p
  LEFT JOIN daily_rankings dr ON dr.player_name = p.name AND dr.group_id = p.group_id
  WHERE p.group_id = p_group_id
  GROUP BY p.id, p.name, p.exact_handicap
  ORDER BY p.exact_handicap ASC, rounds_played DESC
  LIMIT 10;
END;
$$;

-- Función: get_driver_oro_ranking (Driver de Oro)
-- Jugador con mejor promedio de puntos por ronda
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  avg_points numeric,
  total_rounds bigint,
  total_points numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dr.player_name,
    ROUND(AVG(dr.total_points), 2) as avg_points,
    COUNT(DISTINCT dr.ranking_date) as total_rounds,
    SUM(dr.total_points) as total_points
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(DISTINCT dr.ranking_date) >= 3
  ORDER BY avg_points DESC, total_rounds DESC
  LIMIT 10;
END;
$$;

-- Función: get_francotirador_ranking (El Francotirador - más eagles)
CREATE OR REPLACE FUNCTION get_francotirador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_eagles bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_eagles AS (
    SELECT
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'eagles')::integer, 0) as eagles,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
      AND player_stat->'hole_results' IS NOT NULL
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(eagles) as total_eagles,
      COUNT(*) as total_rounds,
      MAX(eagles) as best_day_eagles
    FROM player_eagles
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.eagles,
      pe.played_at,
      pe.course_name
    FROM player_eagles pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.eagles = pt.best_day_eagles
    ORDER BY pe.pid, pe.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_eagles,
    COALESCE(bd.eagles::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_eagles > 0
  ORDER BY pt.total_eagles DESC, bd.eagles DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: get_maquina_ranking (La Máquina - más birdies)
CREATE OR REPLACE FUNCTION get_maquina_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_birdies bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_birdies AS (
    SELECT
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'birdies')::integer, 0) as birdies,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
      AND player_stat->'hole_results' IS NOT NULL
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(birdies) as total_birdies,
      COUNT(*) as total_rounds,
      MAX(birdies) as best_day_birdies
    FROM player_birdies
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.birdies,
      pe.played_at,
      pe.course_name
    FROM player_birdies pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.birdies = pt.best_day_birdies
    ORDER BY pe.pid, pe.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_birdies,
    COALESCE(bd.birdies::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_birdies > 0
  ORDER BY pt.total_birdies DESC, bd.birdies DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: get_amigo_del_mas_uno_ranking (Amigo del +1 - más bogeys)
CREATE OR REPLACE FUNCTION get_amigo_del_mas_uno_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_bogeys bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_bogeys AS (
    SELECT
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'bogeys')::integer, 0) as bogeys,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
      AND player_stat->'hole_results' IS NOT NULL
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(bogeys) as total_bogeys,
      COUNT(*) as total_rounds,
      MAX(bogeys) as best_day_bogeys
    FROM player_bogeys
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.bogeys,
      pe.played_at,
      pe.course_name
    FROM player_bogeys pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.bogeys = pt.best_day_bogeys
    ORDER BY pe.pid, pe.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_bogeys,
    COALESCE(bd.bogeys::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_bogeys > 0
  ORDER BY pt.total_bogeys DESC, bd.bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: get_rey_del_bosque_ranking (Rey del Bosque - más doble bogeys)
CREATE OR REPLACE FUNCTION get_rey_del_bosque_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_double_bogeys bigint,
  best_single_day bigint,
  best_single_day_date timestamptz,
  best_single_day_course text,
  total_rounds bigint
) AS $$
BEGIN
  RETURN QUERY
  WITH player_double_bogeys AS (
    SELECT
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid,
      COALESCE((player_stat->'hole_results'->>'double_bogeys')::integer, 0) as double_bogeys,
      ar.played_at,
      ar.course_name
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
      AND player_stat->'hole_results' IS NOT NULL
  ),
  player_totals AS (
    SELECT
      pname,
      pid,
      SUM(double_bogeys) as total_double_bogeys,
      COUNT(*) as total_rounds,
      MAX(double_bogeys) as best_day_double_bogeys
    FROM player_double_bogeys
    GROUP BY pname, pid
  ),
  best_days AS (
    SELECT DISTINCT ON (pe.pid)
      pe.pid,
      pe.double_bogeys,
      pe.played_at,
      pe.course_name
    FROM player_double_bogeys pe
    INNER JOIN player_totals pt ON pe.pid = pt.pid AND pe.double_bogeys = pt.best_day_double_bogeys
    ORDER BY pe.pid, pe.played_at ASC
  )
  SELECT
    pt.pname,
    pt.pid,
    pt.total_double_bogeys,
    COALESCE(bd.double_bogeys::bigint, 0),
    bd.played_at,
    bd.course_name,
    pt.total_rounds
  FROM player_totals pt
  LEFT JOIN best_days bd ON pt.pid = bd.pid
  WHERE pt.total_double_bogeys > 0
  ORDER BY pt.total_double_bogeys DESC, bd.double_bogeys DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: get_detailed_player_statistics
-- Estadísticas detalladas de un jugador específico
CREATE OR REPLACE FUNCTION get_detailed_player_statistics(p_group_id uuid, p_player_id uuid)
RETURNS TABLE (
  total_rounds bigint,
  total_holes bigint,
  avg_score numeric,
  best_score integer,
  worst_score integer,
  total_birdies bigint,
  total_pars bigint,
  total_bogeys bigint,
  total_double_bogeys bigint,
  total_beers_won bigint,
  total_beers_paid bigint,
  current_handicap numeric,
  handicap_trend text
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_player_name text;
BEGIN
  -- Obtener nombre del jugador
  SELECT name INTO v_player_name
  FROM players
  WHERE id = p_player_id AND group_id = p_group_id;

  RETURN QUERY
  WITH round_stats AS (
    SELECT
      COALESCE((stat->>'total_holes_played')::integer, 0) as holes,
      COALESCE((stat->'hole_results'->>'birdies')::integer, 0) as birdies,
      COALESCE((stat->'hole_results'->>'pars')::integer, 0) as pars,
      COALESCE((stat->'hole_results'->>'bogeys')::integer, 0) as bogeys,
      COALESCE((stat->'hole_results'->>'double_bogeys')::integer, 0) as double_bogeys
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS stat
    WHERE ar.group_id = p_group_id
      AND (stat->>'player_name')::text = v_player_name
  ),
  beer_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE receives_beer = true) as beers_won,
      COUNT(*) FILTER (WHERE pays_beer = true) as beers_paid
    FROM daily_rankings
    WHERE group_id = p_group_id
      AND player_name = v_player_name
  ),
  score_stats AS (
    SELECT
      COUNT(DISTINCT ranking_date) as rounds,
      AVG(total_points) as avg_pts,
      MAX(total_points::integer) as best_pts,
      MIN(total_points::integer) as worst_pts
    FROM daily_rankings
    WHERE group_id = p_group_id
      AND player_name = v_player_name
  ),
  player_info AS (
    SELECT exact_handicap
    FROM players
    WHERE id = p_player_id
  )
  SELECT
    COALESCE(ss.rounds, 0) as total_rounds,
    COALESCE(SUM(rs.holes), 0) as total_holes,
    COALESCE(ROUND(ss.avg_pts, 2), 0) as avg_score,
    COALESCE(ss.best_pts, 0) as best_score,
    COALESCE(ss.worst_pts, 0) as worst_score,
    COALESCE(SUM(rs.birdies), 0) as total_birdies,
    COALESCE(SUM(rs.pars), 0) as total_pars,
    COALESCE(SUM(rs.bogeys), 0) as total_bogeys,
    COALESCE(SUM(rs.double_bogeys), 0) as total_double_bogeys,
    COALESCE(bs.beers_won, 0) as total_beers_won,
    COALESCE(bs.beers_paid, 0) as total_beers_paid,
    COALESCE(pi.exact_handicap, 0) as current_handicap,
    'stable'::text as handicap_trend
  FROM round_stats rs
  CROSS JOIN beer_stats bs
  CROSS JOIN score_stats ss
  CROSS JOIN player_info pi
  GROUP BY ss.rounds, ss.avg_pts, ss.best_pts, ss.worst_pts, bs.beers_won, bs.beers_paid, pi.exact_handicap;
END;
$$;

-- Función: reset_reference_sequence
-- Reinicia la secuencia de números de referencia para un grupo
CREATE OR REPLACE FUNCTION reset_reference_sequence(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Esta función puede ser expandida en el futuro si se necesita lógica adicional
  -- Por ahora simplemente retorna
  RETURN;
END;
$$;

-- ============================================================
-- COMPLETADO - ESTRUCTURA Y LÓGICA MAESTRA
-- ============================================================
--
-- La estructura de la base de datos está lista.
-- Todas las funciones RPC están creadas.
-- Las políticas RLS están configuradas como públicas.
--
-- SIGUIENTE PASO: Ejecuta 02_clean_data_seeds.sql para cargar los datos limpios
--
-- ============================================================
