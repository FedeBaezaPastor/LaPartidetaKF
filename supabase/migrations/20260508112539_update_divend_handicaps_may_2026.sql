/*
  # Actualización de handicaps DIVEND - Mayo 2026

  Actualiza exact_handicap y exact_handicap_18 de todos los jugadores DIVEND
  según el listado proporcionado el 8 de mayo de 2026.

  Cambios respecto al listado anterior (abril 2026):
  - Pablo Espinosa: 5 → 6
  - Ángel Arrufat: 12 → 11
  - Nacho Bernat: 9 → 7
  - Fede Baeza: 8 → 9
  - Pablo V: 9 → 8
*/

UPDATE players SET
  exact_handicap = new_hcp::numeric,
  exact_handicap_18 = new_hcp::numeric
FROM (VALUES
  ('Alberto Usó',     1.0),
  ('Juan Bosch',      4.0),
  ('Fernando',        6.0),
  ('Victor Zeyani',   4.0),
  ('Toni Serra',      9.0),
  ('Alfonso Cardona', 10.0),
  ('Rafa Salcedo',    9.0),
  ('Pablo Espinosa',  6.0),
  ('Ángel Arrufat',   11.0),
  ('Kike Algora',     12.0),
  ('Rebeca Sánchez',  10.0),
  ('Pablo Armengot',  12.0),
  ('Martincho',       10.0),
  ('Guti',            3.0),
  ('Emilio',          8.0),
  ('Javier',          13.0),
  ('Nacho Bernat',    7.0),
  ('Fede Baeza',      9.0),
  ('Saul Viciano',    12.0),
  ('Carlos Pascual',  13.0),
  ('Antonio Alegre',  12.0),
  ('Quique Fabregat', 10.0),
  ('Graciliano',      3.0),
  ('Pablo V',         8.0)
) AS updates(player_name, new_hcp)
WHERE players.name = updates.player_name;

-- Juanjo: actualizar ambos registros
UPDATE players SET
  exact_handicap = 12.0,
  exact_handicap_18 = 12.0
WHERE name = 'Juanjo';
