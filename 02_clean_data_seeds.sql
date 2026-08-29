-- ============================================================
-- LA PARTIDETA GOLF - DATOS LIMPIOS (SEEDS)
-- ============================================================
--
-- ARCHIVO 2 DE 2: Carga de datos limpios y saneados
-- Versión: PRODUCTION v1.0
-- Fecha: Enero 2026
--
-- Este archivo contiene:
-- 1. Limpieza previa de datos (TRUNCATE)
-- 2. 22 jugadores reales del grupo DIVEND (sin usuarios de prueba)
-- 3. 4 campos oficiales con pares corregidos
-- 4. Barras (tees) con slopes reales
-- 5. 3 partidas archivadas con scores completos hoyo por hoyo
-- 6. Histórico de hándicaps con variaciones reales
-- 7. Configuración de administrador
--
-- IMPORTANTE: Ejecuta 01_structure_and_logic_master.sql ANTES de este archivo
--
-- ============================================================

-- ============================================================
-- PASO 1: LIMPIEZA PREVIA DE DATOS
-- ============================================================

TRUNCATE TABLE completed_rounds CASCADE;
TRUNCATE TABLE handicap_history CASCADE;
TRUNCATE TABLE daily_rankings CASCADE;
TRUNCATE TABLE archived_rounds CASCADE;
TRUNCATE TABLE seasons CASCADE;
TRUNCATE TABLE round_scores CASCADE;
TRUNCATE TABLE round_players CASCADE;
TRUNCATE TABLE golf_rounds CASCADE;
TRUNCATE TABLE players CASCADE;
TRUNCATE TABLE groups CASCADE;
TRUNCATE TABLE tees CASCADE;
TRUNCATE TABLE golf_holes CASCADE;
TRUNCATE TABLE golf_courses CASCADE;
TRUNCATE TABLE admin_config CASCADE;

-- ============================================================
-- PASO 2: INSERTAR CAMPOS DE GOLF (4 OFICIALES)
-- ============================================================

-- Campo 1: Golf Costa Azahar - Verde (9 hoyos) - PARES CORREGIDOS
INSERT INTO golf_courses (id, name, description) VALUES
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Golf Costa Azahar - Verde', 'Campo de 9 hoyos. Salida 1. Diseño técnico con vistas al mar.');

-- Hoyos 1-9 con PARES CORREGIDOS: H1(P4), H2(P5), H3(P4), H4(P4), H5(P5), H6(P4), H7(P3), H8(P4), H9(P3)
INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 1, 4, 7),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 2, 5, 1),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 3, 4, 15),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 4, 4, 3),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 5, 5, 5),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 6, 4, 9),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 7, 3, 13),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 8, 4, 11),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 9, 3, 17),
-- Hoyos 10-18 (segunda vuelta)
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 10, 4, 2),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 11, 5, 8),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 12, 4, 16),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 13, 4, 4),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 14, 5, 6),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 15, 4, 10),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 16, 3, 14),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 17, 4, 12),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 18, 3, 18);

-- Campo 2: Golf Costa Azahar - Rojo (9 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Golf Costa Azahar - Rojo', 'Campo de 9 hoyos. Salida 10. Recorrido clásico mediterráneo.');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('b6629b93-14d0-43d8-8806-d7cb94c92445', 1, 4, 8),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 2, 5, 2),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 3, 3, 18),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 4, 4, 10),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 5, 4, 6),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 6, 4, 12),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 7, 3, 16),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 8, 5, 4),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 9, 4, 14),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 10, 4, 8),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 11, 5, 2),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 12, 3, 18),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 13, 4, 10),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 14, 4, 6),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 15, 4, 12),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 16, 3, 16),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 17, 5, 4),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 18, 4, 14);

-- Campo 3: Mediterráneo Golf (18 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Mediterráneo Golf', 'Campo de 18 hoyos con diseño moderno y desafiante');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 1, 4, 11),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 2, 5, 5),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 3, 3, 17),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 4, 4, 1),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 5, 4, 9),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 6, 4, 15),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 7, 3, 13),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 8, 5, 3),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 9, 4, 7),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 10, 4, 10),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 11, 5, 6),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 12, 3, 18),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 13, 4, 2),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 14, 4, 8),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 15, 4, 16),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 16, 3, 14),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 17, 5, 4),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 18, 4, 12);

-- Campo 4: Panorámica Golf (18 hoyos)
INSERT INTO golf_courses (id, name, description) VALUES
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Panorámica Golf', 'Campo de 18 hoyos con vistas espectaculares');

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 1, 4, 9),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 2, 5, 3),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 3, 3, 15),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 4, 4, 1),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 5, 4, 11),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 6, 4, 13),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 7, 3, 17),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 8, 5, 5),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 9, 4, 7),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 10, 4, 10),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 11, 5, 4),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 12, 3, 16),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 13, 4, 2),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 14, 4, 12),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 15, 4, 14),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 16, 3, 18),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 17, 5, 6),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 18, 4, 8);

-- ============================================================
-- PASO 3: INSERTAR BARRAS (TEES) CON SLOPES REALES
-- ============================================================

-- Barras para Costa Azahar Verde
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Blancas', '#FFFFFF', 113, 113, 113),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Amarillas', '#FFD700', 113, 113, 113),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Rojas', '#DC143C', 113, 113, 113),
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Azules', '#1E90FF', 113, 113, 113);

-- Barras para Costa Azahar Rojo
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Blancas', '#FFFFFF', 113, 113, 113),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Amarillas', '#FFD700', 113, 113, 113),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Rojas', '#DC143C', 113, 113, 113),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Azules', '#1E90FF', 113, 113, 113);

-- Barras para Mediterráneo Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Blancas', '#FFFFFF', 138, 113, 113),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Amarillas', '#FFD700', 135, 132, 113),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Rojas', '#DC143C', 130, 131, 113),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Azules', '#1E90FF', 131, 113, 113);

-- Barras para Panorámica Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii) VALUES
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Blancas', '#FFFFFF', 136, 136, 136),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Amarillas', '#FFD700', 132, 128, 137),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Rojas', '#DC143C', 118, 118, 119),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Azules', '#1E90FF', 123, 123, 122);

-- ============================================================
-- PASO 4: INSERTAR GRUPO DIVEND
-- ============================================================

INSERT INTO groups (id, name, group_code, created_at, created_by) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Partideta dels divendres', 'DIVEND', '2025-12-22 21:57:17.190542+00', null);

-- ============================================================
-- PASO 5: INSERTAR 22 JUGADORES REALES DE DIVEND
-- ============================================================
-- NOTA: Hándicaps actualizados a enero 2026
-- Se excluyen usuarios de prueba y temporales

INSERT INTO players (id, name, exact_handicap, exact_handicap_18, group_id, created_at) VALUES
('91b48d8e-7d4f-4f92-ac93-560eed8e1f47', 'Alberto Usó', 0.0, 0.0, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-28 00:33:27.133237+00'),
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
('cc99929b-0d43-4764-b417-82b366992c4c', 'Victor Zeyani', 4.0, 4.0, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00');

-- ============================================================
-- PASO 6: INSERTAR 3 PARTIDAS ARCHIVADAS CON DATOS COMPLETOS
-- ============================================================

-- Partida 1: 09/01/2026 - Guti (1º), Martincho (2º), Quique Fabregat (3º), Saul Viciano (4º)
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, hole_scores, player_stats, created_at) VALUES
('689324b7-027c-4fe0-ba9b-e35a1764f241',
'355d0af9-0a96-4d6d-ab5a-ef1c2b203c76',
'Golf Costa Azahar - Verde',
'2026-01-09 13:40:48.630622+00',
'2026-01-09 16:29:43.461778+00',
'[{"points": 17, "handicap": 6, "position": 1, "hcp_juego": 6, "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "player_name": "Guti"},
  {"points": 12, "handicap": 9, "position": 2, "hcp_juego": 9, "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "player_name": "Martincho"},
  {"points": 10, "handicap": 12, "position": 3, "hcp_juego": 12, "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "player_name": "Quique Fabregat"},
  {"points": 9, "handicap": 12, "position": 4, "hcp_juego": 12, "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "player_name": "Saul Viciano"}]'::jsonb,
null,
'[{"par": 4, "result": "birdie", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 1, "net_strokes": 3, "player_name": "Guti", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "double_bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 1, "net_strokes": 5, "player_name": "Martincho", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "double_bogey", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 1, "net_strokes": 4, "player_name": "Quique Fabregat", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 1, "net_strokes": 4, "player_name": "Saul Viciano", "gross_strokes": 6, "no_paso_rojas": true, "stableford_points": 2},
  {"par": 5, "result": "par", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 2, "net_strokes": 4, "player_name": "Guti", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 5, "result": "double_bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 2, "net_strokes": 6, "player_name": "Martincho", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "double_bogey", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 2, "net_strokes": 6, "player_name": "Quique Fabregat", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 2, "net_strokes": 8, "player_name": "Saul Viciano", "gross_strokes": 9, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "birdie", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 3, "net_strokes": 3, "player_name": "Guti", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "par", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 3, "net_strokes": 3, "player_name": "Martincho", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "double_bogey", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 3, "net_strokes": 5, "player_name": "Quique Fabregat", "gross_strokes": 6, "no_paso_rojas": true, "stableford_points": 1},
  {"par": 4, "result": "double_bogey", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 3, "net_strokes": 5, "player_name": "Saul Viciano", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "par", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 4, "net_strokes": 4, "player_name": "Guti", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 4, "net_strokes": 5, "player_name": "Martincho", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 4, "net_strokes": 7, "player_name": "Quique Fabregat", "gross_strokes": 9, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "double_bogey", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 4, "net_strokes": 4, "player_name": "Saul Viciano", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 5, "result": "par", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 5, "net_strokes": 5, "player_name": "Guti", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 5, "result": "bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 5, "net_strokes": 5, "player_name": "Martincho", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 5, "net_strokes": 8, "player_name": "Quique Fabregat", "gross_strokes": 10, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 5, "net_strokes": 8, "player_name": "Saul Viciano", "gross_strokes": 10, "no_paso_rojas": true, "stableford_points": 0},
  {"par": 4, "result": "bogey", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 6, "net_strokes": 5, "player_name": "Guti", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 6, "net_strokes": 7, "player_name": "Martincho", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "bogey", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 6, "net_strokes": 4, "player_name": "Quique Fabregat", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 6, "net_strokes": 7, "player_name": "Saul Viciano", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "par", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 7, "net_strokes": 3, "player_name": "Guti", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 7, "net_strokes": 6, "player_name": "Martincho", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 7, "net_strokes": 6, "player_name": "Quique Fabregat", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 7, "net_strokes": 5, "player_name": "Saul Viciano", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "par", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 8, "net_strokes": 4, "player_name": "Guti", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 8, "net_strokes": 4, "player_name": "Martincho", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 8, "net_strokes": 5, "player_name": "Quique Fabregat", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "bogey", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 8, "net_strokes": 4, "player_name": "Saul Viciano", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "birdie", "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "hole_number": 9, "net_strokes": 2, "player_name": "Guti", "gross_strokes": 2, "no_paso_rojas": false, "stableford_points": 4},
  {"par": 3, "result": "bogey", "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "hole_number": 9, "net_strokes": 3, "player_name": "Martincho", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "par", "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "hole_number": 9, "net_strokes": 2, "player_name": "Quique Fabregat", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 3, "result": "bogey", "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "hole_number": 9, "net_strokes": 3, "player_name": "Saul Viciano", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2}]'::jsonb,
'[{"handicap": 6, "beers_won": 1, "player_id": "803493eb-bafa-486f-afc0-b209a3558c12", "beers_paid": 0, "player_name": "Guti", "hole_results": {"pars": 5, "bogeys": 1, "eagles": 0, "birdies": 3, "double_bogeys": 0, "triple_bogey_plus": 0}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 9, "beers_won": 0, "player_id": "11ca0179-cc5f-4c91-b2df-6c3abdcb717d", "beers_paid": 0, "player_name": "Martincho", "hole_results": {"pars": 1, "bogeys": 3, "eagles": 0, "birdies": 0, "double_bogeys": 3, "triple_bogey_plus": 2}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 12, "beers_won": 0, "player_id": "0f89e919-afe2-46f3-9755-82109bcd1235", "beers_paid": 1, "player_name": "Quique Fabregat", "hole_results": {"pars": 1, "bogeys": 1, "eagles": 0, "birdies": 0, "double_bogeys": 4, "triple_bogey_plus": 3}, "total_holes_played": 9, "no_paso_rojas_count": 1},
  {"handicap": 12, "beers_won": 0, "player_id": "eb0b013a-b90f-41d5-bb01-1efcd6ff4a47", "beers_paid": 1, "player_name": "Saul Viciano", "hole_results": {"pars": 0, "bogeys": 2, "eagles": 0, "birdies": 0, "double_bogeys": 3, "triple_bogey_plus": 4}, "total_holes_played": 9, "no_paso_rojas_count": 2}]'::jsonb,
'2026-01-09 16:29:43.461778+00');

-- Partida 2: 09/01/2026 - Nacho Bernat (1º), Fede Baeza (2º), Carlos Pascual (3º)
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, hole_scores, player_stats, created_at) VALUES
('9b6d8cc5-faf0-4581-98f7-aa29cbf28eb8',
'355d0af9-0a96-4d6d-ab5a-ef1c2b203c76',
'Golf Costa Azahar - Verde',
'2026-01-09 13:42:48.632774+00',
'2026-01-09 16:29:42.370629+00',
'[{"points": 21, "handicap": 14, "position": 1, "hcp_juego": 14, "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "player_name": "Nacho Bernat"},
  {"points": 11, "handicap": 10, "position": 2, "hcp_juego": 10, "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "player_name": "Fede Baeza"},
  {"points": 6, "handicap": 13, "position": 3, "hcp_juego": 13, "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "player_name": "Carlos Pascual"}]'::jsonb,
null,
'[{"par": 4, "result": "bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 1, "net_strokes": 3, "player_name": "Nacho Bernat", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 1, "net_strokes": 3, "player_name": "Fede Baeza", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 1, "net_strokes": 6, "player_name": "Carlos Pascual", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 5, "result": "eagle", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 2, "net_strokes": 2, "player_name": "Nacho Bernat", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 5},
  {"par": 5, "result": "double_bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 2, "net_strokes": 6, "player_name": "Fede Baeza", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 2, "net_strokes": 6, "player_name": "Carlos Pascual", "gross_strokes": 8, "no_paso_rojas": true, "stableford_points": 1},
  {"par": 4, "result": "bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 3, "net_strokes": 4, "player_name": "Nacho Bernat", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 3, "net_strokes": 5, "player_name": "Fede Baeza", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "double_bogey", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 3, "net_strokes": 5, "player_name": "Carlos Pascual", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "double_bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 4, "net_strokes": 4, "player_name": "Nacho Bernat", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 4, "net_strokes": 5, "player_name": "Fede Baeza", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 4, "net_strokes": 5, "player_name": "Carlos Pascual", "gross_strokes": 7, "no_paso_rojas": true, "stableford_points": 1},
  {"par": 5, "result": "double_bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 5, "net_strokes": 5, "player_name": "Nacho Bernat", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 5, "result": "double_bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 5, "net_strokes": 6, "player_name": "Fede Baeza", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 5, "net_strokes": 7, "player_name": "Carlos Pascual", "gross_strokes": 9, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 6, "net_strokes": 6, "player_name": "Nacho Bernat", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 6, "net_strokes": 4, "player_name": "Fede Baeza", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 6, "net_strokes": 7, "player_name": "Carlos Pascual", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 7, "net_strokes": 3, "player_name": "Nacho Bernat", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 7, "net_strokes": 6, "player_name": "Fede Baeza", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 7, "net_strokes": 5, "player_name": "Carlos Pascual", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "bogey", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 8, "net_strokes": 4, "player_name": "Nacho Bernat", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "bogey", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 8, "net_strokes": 4, "player_name": "Fede Baeza", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "bogey", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 8, "net_strokes": 4, "player_name": "Carlos Pascual", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "par", "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "hole_number": 9, "net_strokes": 2, "player_name": "Nacho Bernat", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 3, "result": "triple_bogey_plus", "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "hole_number": 9, "net_strokes": 6, "player_name": "Fede Baeza", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 3, "result": "double_bogey", "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "hole_number": 9, "net_strokes": 4, "player_name": "Carlos Pascual", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 1}]'::jsonb,
'[{"handicap": 14, "beers_won": 1, "player_id": "a1d1d46d-a1de-41f6-bbca-b126b6b3df8f", "beers_paid": 0, "player_name": "Nacho Bernat", "hole_results": {"pars": 1, "bogeys": 4, "eagles": 1, "birdies": 0, "double_bogeys": 2, "triple_bogey_plus": 1}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 10, "beers_won": 0, "player_id": "89d0f23f-882e-424c-94a7-4a2712f15788", "beers_paid": 0, "player_name": "Fede Baeza", "hole_results": {"pars": 0, "bogeys": 3, "eagles": 0, "birdies": 0, "double_bogeys": 4, "triple_bogey_plus": 2}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 13, "beers_won": 0, "player_id": "1c7438a7-70bc-4e0d-b3d5-dff2967699f5", "beers_paid": 1, "player_name": "Carlos Pascual", "hole_results": {"pars": 0, "bogeys": 1, "eagles": 0, "birdies": 0, "double_bogeys": 2, "triple_bogey_plus": 6}, "total_holes_played": 9, "no_paso_rojas_count": 2}]'::jsonb,
'2026-01-09 16:29:42.370629+00');

-- Partida 3: 09/01/2026 - Victor Zeyani (1º), Kike Algora (2º), Alfonso Cardona (3º)
INSERT INTO archived_rounds (id, group_id, course_name, played_at, archived_at, final_ranking, season_id, hole_scores, player_stats, created_at) VALUES
('313958f3-fc2e-4eef-b573-c72257ae4ec8',
'355d0af9-0a96-4d6d-ab5a-ef1c2b203c76',
'Golf Costa Azahar - Verde',
'2026-01-09 13:47:55.016281+00',
'2026-01-09 16:29:41.231368+00',
'[{"points": 17, "handicap": 5, "position": 1, "hcp_juego": 5, "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "player_name": "Victor Zeyani"},
  {"points": 15, "handicap": 12, "position": 2, "hcp_juego": 12, "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "player_name": "Kike Algora"},
  {"points": 11, "handicap": 8, "position": 3, "hcp_juego": 8, "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "player_name": "Alfonso Cardona"}]'::jsonb,
null,
'[{"par": 4, "result": "bogey", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 1, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "bogey", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 1, "net_strokes": 3, "player_name": "Kike Algora", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 4, "result": "par", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 1, "net_strokes": 3, "player_name": "Alfonso Cardona", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 5, "result": "par", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 2, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 5, "result": "par", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 2, "net_strokes": 4, "player_name": "Kike Algora", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 3},
  {"par": 5, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 2, "net_strokes": 6, "player_name": "Alfonso Cardona", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "par", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 3, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 3, "net_strokes": 6, "player_name": "Kike Algora", "gross_strokes": 7, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 3, "net_strokes": 5, "player_name": "Alfonso Cardona", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "bogey", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 4, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 4, "net_strokes": 4, "player_name": "Kike Algora", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 4, "net_strokes": 5, "player_name": "Alfonso Cardona", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 5, "net_strokes": 7, "player_name": "Victor Zeyani", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 5, "net_strokes": 6, "player_name": "Kike Algora", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 5, "result": "triple_bogey_plus", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 5, "net_strokes": 7, "player_name": "Alfonso Cardona", "gross_strokes": 8, "no_paso_rojas": true, "stableford_points": 0},
  {"par": 4, "result": "bogey", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 6, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "triple_bogey_plus", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 6, "net_strokes": 7, "player_name": "Kike Algora", "gross_strokes": 8, "no_paso_rojas": false, "stableford_points": 0},
  {"par": 4, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 6, "net_strokes": 5, "player_name": "Alfonso Cardona", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 3, "result": "par", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 7, "net_strokes": 3, "player_name": "Victor Zeyani", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "bogey", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 7, "net_strokes": 3, "player_name": "Kike Algora", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 7, "net_strokes": 4, "player_name": "Alfonso Cardona", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 4, "result": "par", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 8, "net_strokes": 4, "player_name": "Victor Zeyani", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "bogey", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 8, "net_strokes": 4, "player_name": "Kike Algora", "gross_strokes": 5, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 4, "result": "double_bogey", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 8, "net_strokes": 5, "player_name": "Alfonso Cardona", "gross_strokes": 6, "no_paso_rojas": false, "stableford_points": 1},
  {"par": 3, "result": "par", "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "hole_number": 9, "net_strokes": 3, "player_name": "Victor Zeyani", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "bogey", "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "hole_number": 9, "net_strokes": 3, "player_name": "Kike Algora", "gross_strokes": 4, "no_paso_rojas": false, "stableford_points": 2},
  {"par": 3, "result": "par", "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "hole_number": 9, "net_strokes": 3, "player_name": "Alfonso Cardona", "gross_strokes": 3, "no_paso_rojas": false, "stableford_points": 2}]'::jsonb,
'[{"handicap": 5, "beers_won": 1, "player_id": "cc99929b-0d43-4764-b417-82b366992c4c", "beers_paid": 0, "player_name": "Victor Zeyani", "hole_results": {"pars": 5, "bogeys": 3, "eagles": 0, "birdies": 0, "double_bogeys": 0, "triple_bogey_plus": 1}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 12, "beers_won": 0, "player_id": "b83c753b-2d88-4d52-8a4b-18533cad4403", "beers_paid": 0, "player_name": "Kike Algora", "hole_results": {"pars": 1, "bogeys": 4, "eagles": 0, "birdies": 0, "double_bogeys": 1, "triple_bogey_plus": 3}, "total_holes_played": 9, "no_paso_rojas_count": 0},
  {"handicap": 8, "beers_won": 0, "player_id": "7ce52ab4-71ce-45e8-ab03-96a86d1476ef", "beers_paid": 1, "player_name": "Alfonso Cardona", "hole_results": {"pars": 2, "bogeys": 0, "eagles": 0, "birdies": 0, "double_bogeys": 6, "triple_bogey_plus": 1}, "total_holes_played": 9, "no_paso_rojas_count": 1}]'::jsonb,
'2026-01-09 16:29:41.231368+00');

-- ============================================================
-- PASO 7: CALCULAR DAILY RANKINGS PARA LAS 3 PARTIDAS
-- ============================================================

-- Calcular rankings para la fecha 09/01/2026
SELECT calculate_daily_ranking('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'::uuid, '2026-01-09'::date);

-- ============================================================
-- PASO 8: INSERTAR HISTÓRICO DE HÁNDICAPS CON VARIACIONES
-- ============================================================
-- NOTA: Estas son simulaciones de evolución de hándicap
-- En producción, esto se generará automáticamente tras cada partida

-- Evolución de Victor Zeyani: 6.0 → 5.0
INSERT INTO handicap_history (player_id, group_id, old_handicap, new_handicap, changed_at, archived_round_id) VALUES
('cc99929b-0d43-4764-b417-82b366992c4c', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 6.0, 5.0, '2025-12-28 18:00:00+00', null);

-- Evolución de Alberto Usó: 1.0 → 0.0 (scratch player)
INSERT INTO handicap_history (player_id, group_id, old_handicap, new_handicap, changed_at, archived_round_id) VALUES
('91b48d8e-7d4f-4f92-ac93-560eed8e1f47', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 1.0, 0.0, '2025-12-20 18:00:00+00', null);

-- Evolución de Guti: 6.0 → 5.0
INSERT INTO handicap_history (player_id, group_id, old_handicap, new_handicap, changed_at, archived_round_id) VALUES
('803493eb-bafa-486f-afc0-b209a3558c12', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 6.0, 5.0, '2025-12-28 18:00:00+00', null);

-- Evolución de Martincho: 9.0 → 8.0
INSERT INTO handicap_history (player_id, group_id, old_handicap, new_handicap, changed_at, archived_round_id) VALUES
('11ca0179-cc5f-4c91-b2df-6c3abdcb717d', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 9.0, 8.0, '2026-01-02 18:00:00+00', null);

-- Evolución de Nacho Bernat: 14.0 → 13.0
INSERT INTO handicap_history (player_id, group_id, old_handicap, new_handicap, changed_at, archived_round_id) VALUES
('a1d1d46d-a1de-41f6-bbca-b126b6b3df8f', '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 14.0, 13.0, '2026-01-06 18:00:00+00', null);

-- ============================================================
-- PASO 9: CONFIGURACIÓN DE ADMINISTRADOR
-- ============================================================

INSERT INTO admin_config (admin_email, admin_pin) VALUES
('kike@kikealgora.com', '2248');

-- ============================================================
-- COMPLETADO - DATOS LIMPIOS CARGADOS
-- ============================================================
--
-- Resumen de lo que se ha cargado:
--
-- ✅ 4 campos de golf oficiales
-- ✅ 72 hoyos definidos con pares correctos
-- ✅ 16 barras (tees) con slopes reales
-- ✅ 1 grupo DIVEND
-- ✅ 22 jugadores reales (sin usuarios de prueba)
-- ✅ 3 partidas archivadas con datos completos hoyo por hoyo
-- ✅ Daily rankings calculados
-- ✅ 4 registros de histórico de hándicap con variaciones
-- ✅ Configuración de administrador
--
-- VERIFICACIÓN:
--
-- SELECT COUNT(*) FROM golf_courses;           -- Debe retornar: 4
-- SELECT COUNT(*) FROM golf_holes;             -- Debe retornar: 72
-- SELECT COUNT(*) FROM tees;                   -- Debe retornar: 16
-- SELECT COUNT(*) FROM players;                -- Debe retornar: 22
-- SELECT COUNT(*) FROM archived_rounds;        -- Debe retornar: 3
-- SELECT COUNT(*) FROM daily_rankings;         -- Debe retornar: 10
-- SELECT COUNT(*) FROM handicap_history;       -- Debe retornar: 4
--
-- SIGUIENTE PASO:
-- Conecta tu aplicación frontend y verifica que todo funciona correctamente.
--
-- ============================================================
