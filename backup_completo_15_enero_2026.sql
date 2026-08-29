-- ============================================================
-- LA PARTIDETA GOLF - BACKUP COMPLETO
-- ============================================================
--
-- Fecha: 15 de Enero 2026
-- Versión: v1.0 - PRODUCTION
--
-- Este archivo contiene un backup completo de la aplicación:
-- 1. Instrucciones de uso
-- 2. Referencia a archivo de estructura (01_structure_and_logic_master.sql)
-- 3. Datos actuales de todas las tablas
--
-- ============================================================
-- INSTRUCCIONES DE RESTAURACIÓN
-- ============================================================
--
-- Para restaurar completamente la aplicación desde cero:
--
-- PASO 1: Ejecutar la estructura y lógica maestra
--   Archivo: 01_structure_and_logic_master.sql
--   Este archivo crea todas las tablas, funciones, triggers y RLS
--
-- PASO 2: Ejecutar este archivo de datos
--   Archivo: backup_completo_15_enero_2026.sql
--   Este archivo inserta todos los datos actuales
--
-- ============================================================

-- ============================================================
-- INSERCIÓN DE DATOS
-- ============================================================

-- TABLA: groups
-- Grupo principal de la aplicación
INSERT INTO groups (id, name, group_code, created_at, created_by) VALUES
('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', 'Partideta dels divendres', 'DIVEND', '2025-12-22 21:57:17.190542+00', null);

-- TABLA: golf_courses
-- Campos de golf disponibles
INSERT INTO golf_courses (id, name, description, created_at) VALUES
('72d99c20-8d98-4736-8a08-7250c0dd9d7f', 'Golf Costa Azahar - Verde', 'Campo de 9 hoyos. Salida 1. Diseño técnico con vistas al mar.', '2026-01-15 10:44:22.573397+00'),
('b6629b93-14d0-43d8-8806-d7cb94c92445', 'Golf Costa Azahar - Rojo', 'Campo de 9 hoyos. Salida 10. Recorrido clásico mediterráneo.', '2026-01-15 10:44:22.573397+00'),
('4649cd7e-c97c-47ec-be35-558fd60bd6c1', 'Mediterráneo Golf', 'Campo de 18 hoyos con diseño moderno y desafiante', '2026-01-15 10:44:22.573397+00'),
('abf8619d-23c0-4576-abf5-d0bcecd72c28', 'Panorámica Golf', 'Campo de 18 hoyos con vistas espectaculares', '2026-01-15 10:44:22.573397+00');

-- TABLA: players
-- Jugadores del grupo DIVEND con sus handicaps
INSERT INTO players (id, name, exact_handicap, exact_handicap_18, group_id, created_at, updated_at) VALUES
('b83c753b-2d88-4d52-8a4b-18533cad4403', 'Kike Algora', 10, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 12:51:05.488+00'),
('4c41bddb-7784-473d-92ca-4ccc65e7fc18', 'Antonio Alegre', 14, 14, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('3369080e-8624-4085-99f1-d5698da8bb44', 'Arturo', 14, 14, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('1c7438a7-70bc-4e0d-b3d5-dff2967699f5', 'Carlos Pascual', 13, 13, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('89d0f23f-882e-424c-94a7-4a2712f15788', 'Fede Baeza', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('5f375d1a-6ddc-41f8-810d-32fda1b1715a', 'Fernando', 3, 3, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('df5ebe85-7a4b-4f50-8292-1c89e2ad4a40', 'Juan Bosch', 6, 6, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('11ca0179-cc5f-4c91-b2df-6c3abdcb717d', 'Martincho', 8, 8, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('a1d1d46d-a1de-41f6-bbca-b126b6b3df8f', 'Nacho Bernat', 13, 13, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('fb606c90-c3f9-4a04-b81f-b1903d787790', 'Pablo Armengot', 11, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('7a2c6452-e7a9-48cd-bbb3-1e36dbd17d48', 'Pablo Espinosa', 6, 6, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('6af8367a-2a8a-414e-b580-cc72178a0c82', 'Ángel Arrufat', 12, 11, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 12:51:05.807+00'),
('b4eba18a-9def-4a69-8596-38d7c8a1f988', 'Rafa Salcedo', 10, 10, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('62cafa87-2304-4d0a-ac60-cda603154d53', 'Rebeca Sánchez', 10, 10, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('1d0a8309-104a-4e30-844f-ffa71f9ad63e', 'Salva Martinez', 15, 15, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('eb0b013a-b90f-41d5-bb01-1efcd6ff4a47', 'Saul Viciano', 12, 12, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 10:45:09.552358+00'),
('cc99929b-0d43-4764-b417-82b366992c4c', 'Victor Zeyani', 3, 4, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 12:51:05.647+00'),
('7ce52ab4-71ce-45e8-ab03-96a86d1476ef', 'Alfonso Cardona', 10, 9, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 12:52:20.521+00'),
('803493eb-bafa-486f-afc0-b209a3558c12', 'Guti', 4, 5, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-22 22:50:01.369846+00', '2026-01-15 12:52:20.394+00'),
('91b48d8e-7d4f-4f92-ac93-560eed8e1f47', 'Alberto Usó', 0.0, 0.0, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2025-12-28 00:33:27.133237+00', '2026-01-15 10:45:09.552358+00'),
('0f89e919-afe2-46f3-9755-82109bcd1235', 'Quique Fabregat', 12, 12, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2026-01-06 21:49:24.619544+00', '2026-01-15 10:45:09.552358+00'),
('e8263a13-4831-45fc-8bfd-f849d9cb2647', 'Toni Serra', 9, 9, '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76', '2026-01-09 12:30:45.192183+00', '2026-01-15 10:45:09.552358+00');

-- TABLA: admin_config
-- Configuración de administrador
INSERT INTO admin_config (id, admin_email, admin_pin, created_at, updated_at) VALUES
(gen_random_uuid(), 'admin@partideta.com', '1234', now(), now());

-- ============================================================
-- NOTAS IMPORTANTES
-- ============================================================
--
-- 1. Este backup NO incluye las tablas golf_holes y tees porque
--    estas se crean automáticamente al ejecutar el archivo
--    02_clean_data_seeds.sql que está incluido en el proyecto
--
-- 2. Este backup NO incluye archived_rounds, daily_rankings ni
--    handicap_history ya que están vacías en este momento o
--    son datos históricos que se regeneran desde las partidas archivadas
--
-- 3. Para un backup completo con datos históricos, utiliza el archivo
--    backup_datos_15_enero_2026.sql que contiene las partidas archivadas
--
-- ============================================================
-- FIN DEL BACKUP
-- ============================================================
