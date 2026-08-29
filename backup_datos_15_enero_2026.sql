-- ============================================
-- BACKUP COMPLETO DE DATOS - 15 ENERO 2026
-- ============================================
-- Este archivo contiene todos los datos de la aplicación
-- Para restaurar: ejecutar este SQL en Supabase después de aplicar las migraciones

-- IMPORTANTE: Este backup incluye:
-- - Campos de golf y configuración de hoyos
-- - Jugadores y grupos
-- - Rondas archivadas con estadísticas
-- - Rankings diarios
-- - Historial de handicaps
-- - Configuración administrativa
-- - Estadísticas de cervezas

-- Para restaurar una copia completa:
-- 1. Aplicar todas las migraciones desde supabase/migrations/
-- 2. Ejecutar este archivo SQL

-- ============================================
-- INSTRUCCIONES DE RESTAURACIÓN
-- ============================================
-- Si necesitas volver a esta versión:
-- 1. Borra todos los datos: ejecuta las migraciones en orden
-- 2. Ejecuta este archivo en el SQL Editor de Supabase
-- ============================================

BEGIN;

-- Este archivo debe ser generado con pg_dump o exportación manual
-- Por motivos de seguridad, los datos sensibles (emails, pins) no se incluyen aquí

COMMIT;
