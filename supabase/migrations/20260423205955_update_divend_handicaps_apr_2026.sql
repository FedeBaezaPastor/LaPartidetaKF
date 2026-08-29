/*
  # Actualización de handicaps DIVEND - Abril 2026

  Actualiza exact_handicap y exact_handicap_18 de todos los jugadores DIVEND
  según el listado proporcionado el 23 de abril de 2026.

  Cambios principales respecto al listado anterior:
  - Alberto Usó: 0 → 1
  - Fernando: 3 → 6
  - Víctor Zeyani: 6 → 4
  - Rafa Salcedo: 11 → 9
  - Fede Baeza: 5 → 8
  - Nacho Bernat: 12 → 9
  - Graciliano: 0 → 3
  - Juanjo: → 12
  - Pablo V: 12 → 9
  - Quique Fabregat: 9 → 10
*/

UPDATE players SET
  exact_handicap = new_hcp::numeric,
  exact_handicap_18 = new_hcp::numeric
FROM (VALUES
  ('Alberto Usó',    1.0),
  ('Juan Bosch',     4.0),
  ('Fernando',       6.0),
  ('Victor Zeyani',  4.0),
  ('Toni Serra',     9.0),
  ('Alfonso Cardona',10.0),
  ('Rafa Salcedo',   9.0),
  ('Pablo Espinosa', 5.0),
  ('Ángel Arrufat',  12.0),
  ('Kike Algora',    12.0),
  ('Rebeca Sánchez', 10.0),
  ('Pablo Armengot', 12.0),
  ('Martincho',      10.0),
  ('Guti',           3.0),
  ('Emilio',         8.0),
  ('Javier',         13.0),
  ('Nacho Bernat',   9.0),
  ('Fede Baeza',     8.0),
  ('Saul Viciano',   12.0),
  ('Carlos Pascual', 13.0),
  ('Antonio Alegre', 12.0),
  ('Quique Fabregat',10.0),
  ('Graciliano',     3.0),
  ('Pablo V',        9.0)
) AS updates(player_name, new_hcp)
WHERE players.name = updates.player_name;

-- Juanjo: actualizar ambos registros (hay dos con ese nombre)
UPDATE players SET
  exact_handicap = 12.0,
  exact_handicap_18 = 12.0
WHERE name = 'Juanjo';
