/*
  # Añadir jugadores DIVEND

  1. Descripción
    - Inserta 22 jugadores para el grupo DIVEND
    - Los handicaps proporcionados son para 9 hoyos
    - Se multiplican por 2 para guardarlos como handicaps de 18 hoyos (exact_handicap_18)
    - Cuando se juegue a 9 hoyos, el sistema los dividirá automáticamente por 2

  2. Jugadores
    - Alberto Usó: 7.0 → 14.0 (18 hoyos)
    - Alfonso Cardona: 14.0 → 28.0 (18 hoyos)
    - Ángel Arrufat: 18.0 → 36.0 (18 hoyos)
    - Antonio Alegre: 7.0 → 14.0 (18 hoyos)
    - Arturo: 14.0 → 28.0 (18 hoyos)
    - Carlos Pascual: 15.0 → 30.0 (18 hoyos)
    - Cuqui Sanchez: 12.0 → 24.0 (18 hoyos)
    - Fede Baeza: 8.0 → 16.0 (18 hoyos)
    - Fer: 9.0 → 18.0 (18 hoyos)
    - José Luis - Guti: 7.0 → 14.0 (18 hoyos)
    - Juan Bosch: 7.0 → 14.0 (18 hoyos)
    - Kike Algora: 11.0 → 22.0 (18 hoyos)
    - Martincho: 13.0 → 26.0 (18 hoyos)
    - Nacho Bernat: 15.0 → 30.0 (18 hoyos)
    - Orasion: 8.0 → 16.0 (18 hoyos)
    - Pablo Armengot: 14.0 → 28.0 (18 hoyos)
    - Pablo Espinosa: 7.0 → 14.0 (18 hoyos)
    - Rafa Salcedo: 12.0 → 24.0 (18 hoyos)
    - Rebeca Sánchez: 13.0 → 26.0 (18 hoyos)
    - Salva Martinez: 15.0 → 30.0 (18 hoyos)
    - Saul Viciano: 12.0 → 24.0 (18 hoyos)
    - Victor Zeyani: 6.0 → 12.0 (18 hoyos)

  3. Notas
    - Solo se insertan si no existen ya
    - Se asignan al grupo DIVEND
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

  -- Only proceed if DIVEND group exists
  IF divend_group_id IS NOT NULL THEN
    -- Insert players if they don't exist
    INSERT INTO players (name, exact_handicap, exact_handicap_18, group_id)
    SELECT * FROM (VALUES
      ('Alberto Usó', 14.0, 14.0, divend_group_id),
      ('Alfonso Cardona', 28.0, 28.0, divend_group_id),
      ('Ángel Arrufat', 36.0, 36.0, divend_group_id),
      ('Antonio Alegre', 14.0, 14.0, divend_group_id),
      ('Arturo', 28.0, 28.0, divend_group_id),
      ('Carlos Pascual', 30.0, 30.0, divend_group_id),
      ('Cuqui Sanchez', 24.0, 24.0, divend_group_id),
      ('Fede Baeza', 16.0, 16.0, divend_group_id),
      ('Fer', 18.0, 18.0, divend_group_id),
      ('José Luis - Guti', 14.0, 14.0, divend_group_id),
      ('Juan Bosch', 14.0, 14.0, divend_group_id),
      ('Kike Algora', 22.0, 22.0, divend_group_id),
      ('Martincho', 26.0, 26.0, divend_group_id),
      ('Nacho Bernat', 30.0, 30.0, divend_group_id),
      ('Orasion', 16.0, 16.0, divend_group_id),
      ('Pablo Armengot', 28.0, 28.0, divend_group_id),
      ('Pablo Espinosa', 14.0, 14.0, divend_group_id),
      ('Rafa Salcedo', 24.0, 24.0, divend_group_id),
      ('Rebeca Sánchez', 26.0, 26.0, divend_group_id),
      ('Salva Martinez', 30.0, 30.0, divend_group_id),
      ('Saul Viciano', 24.0, 24.0, divend_group_id),
      ('Victor Zeyani', 12.0, 12.0, divend_group_id)
    ) AS new_players(name, exact_handicap, exact_handicap_18, group_id)
    WHERE NOT EXISTS (
      SELECT 1 FROM players 
      WHERE players.name = new_players.name 
      AND players.group_id = divend_group_id
    );
  END IF;
END $$;
