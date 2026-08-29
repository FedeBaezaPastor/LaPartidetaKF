/*
  # Añadir políticas de escritura para handicap_adjustments

  ## Descripción
  Añade las políticas RLS faltantes para permitir INSERT, UPDATE y DELETE
  en la tabla `handicap_adjustments`. Esto soluciona el error que impedía
  archivar partidas correctamente.

  ## Problema
  La tabla solo tenía política SELECT, causando error:
  "new row violates row-level security policy for table handicap_adjustments"

  ## Solución
  Se añaden políticas públicas para:
  - INSERT: Permitir crear registros de ajustes de handicap
  - UPDATE: Permitir actualizar registros existentes
  - DELETE: Permitir eliminar registros si es necesario

  ## Seguridad
  Las políticas son públicas para mantener consistencia con la app
  que no usa autenticación de Supabase Auth
*/

-- Política para INSERT
CREATE POLICY "Anyone can insert handicap adjustments"
  ON handicap_adjustments
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Política para UPDATE
CREATE POLICY "Anyone can update handicap adjustments"
  ON handicap_adjustments
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Política para DELETE
CREATE POLICY "Anyone can delete handicap adjustments"
  ON handicap_adjustments
  FOR DELETE
  TO public
  USING (true);
