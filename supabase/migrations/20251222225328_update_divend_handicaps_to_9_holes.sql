/*
  # Actualizar handicaps de DIVEND a 9 hoyos

  1. Descripción
    - Las partidas de DIVEND son casi siempre de 9 hoyos
    - Se actualizan los handicaps para que sean de 9 hoyos por defecto
    - Cuando se juegue a 18 hoyos, el sistema los multiplicará automáticamente por 2

  2. Cambios
    - Se dividen todos los handicaps de jugadores DIVEND por 2
    - exact_handicap y exact_handicap_18 se actualizan a los valores de 9 hoyos

  3. Jugadores actualizados
    - Alberto Usó: 14.0 → 7.0
    - Alfonso Cardona: 28.0 → 14.0
    - Ángel Arrufat: 36.0 → 18.0
    - Antonio Alegre: 14.0 → 7.0
    - Arturo: 28.0 → 14.0
    - Carlos Pascual: 30.0 → 15.0
    - Cuqui Sanchez: 24.0 → 12.0
    - Fede Baeza: 16.0 → 8.0
    - Fer: 18.0 → 9.0
    - José Luis - Guti: 14.0 → 7.0
    - Juan Bosch: 14.0 → 7.0
    - Kike Algora: 22.0 → 11.0
    - Martincho: 26.0 → 13.0
    - Nacho Bernat: 30.0 → 15.0
    - Orasion: 16.0 → 8.0
    - Pablo Armengot: 28.0 → 14.0
    - Pablo Espinosa: 14.0 → 7.0
    - Rafa Salcedo: 24.0 → 12.0
    - Rebeca Sánchez: 26.0 → 13.0
    - Salva Martinez: 30.0 → 15.0
    - Saul Viciano: 24.0 → 12.0
    - Victor Zeyani: 12.0 → 6.0
*/

DO $$
DECLARE
  divend_group_id uuid;
BEGIN
  -- Get DIVEND group ID
  SELECT id INTO divend_group_id
  FROM groups
  WHERE group_code = 'DIVEND'
  LIMIT 1;

  -- Update all DIVEND players' handicaps to 9-hole values
  IF divend_group_id IS NOT NULL THEN
    UPDATE players
    SET 
      exact_handicap = exact_handicap / 2,
      exact_handicap_18 = exact_handicap_18 / 2
    WHERE group_id = divend_group_id
    AND exact_handicap > 0;
  END IF;
END $$;
