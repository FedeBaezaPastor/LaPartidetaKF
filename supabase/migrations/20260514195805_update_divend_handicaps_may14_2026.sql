/*
  # Actualización de handicaps DIVEND - 14 Mayo 2026

  Actualiza exact_handicap y exact_handicap_18 de todos los jugadores DIVEND
  según el listado proporcionado el 14 de mayo de 2026.

  Cambios respecto al listado anterior (mayo 2026):
  - Alberto Usó: 1 → 2
  - Víctor Zeyani: 4 → 3
  - Martincho: 10 → 11
  - Nacho Bernat: 7 → 8
  - Fede Baeza: 9 → 8
  - Carlos Pascual: 13 → 12
*/

UPDATE players SET
  exact_handicap = new_hcp::numeric,
  exact_handicap_18 = new_hcp::numeric
FROM (VALUES
  ('Alberto Usó',     2.0),
  ('Juan Bosch',      4.0),
  ('Fernando',        6.0),
  ('Victor Zeyani',   3.0),
  ('Toni Serra',      9.0),
  ('Alfonso Cardona', 10.0),
  ('Rafa Salcedo',    9.0),
  ('Pablo Espinosa',  6.0),
  ('Ángel Arrufat',   11.0),
  ('Kike Algora',     12.0),
  ('Rebeca Sánchez',  10.0),
  ('Pablo Armengot',  12.0),
  ('Martincho',       11.0),
  ('Guti',            3.0),
  ('Emilio',          8.0),
  ('Javier',          13.0),
  ('Nacho Bernat',    8.0),
  ('Fede Baeza',      8.0),
  ('Saul Viciano',    12.0),
  ('Carlos Pascual',  12.0),
  ('Antonio Alegre',  12.0),
  ('Quique Fabregat', 10.0),
  ('Graciliano',      3.0),
  ('Pablo V',         8.0),
  ('Fede 2',          5.0)
) AS updates(player_name, new_hcp)
WHERE players.name = updates.player_name;

-- Juanjo: actualizar ambos registros
UPDATE players SET
  exact_handicap = 12.0,
  exact_handicap_18 = 12.0
WHERE name = 'Juanjo';
