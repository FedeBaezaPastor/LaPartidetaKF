/*
  # Corrección de Handicaps después de la partida del 13/02/2026
  
  ## Lógica Correcta de Ajuste de Handicaps
  
  Para una clasificación con N jugadores:
  - **Posiciones 1 a FLOOR(N/2)**: MITAD SUPERIOR → baja 1 punto
  - **Posición CEIL(N/2) cuando N es impar**: MITAD DE TABLA → se queda igual
  - **Posiciones superiores a CEIL(N/2)**: MITAD INFERIOR → sube 1 punto (solo si HCP < 12, tope máximo)
  
  ## Partida del 13/02/2026: 9 jugadores
  
  - Posiciones 1-4: GANAN (bajan 1)
  - Posición 5: MITAD DE TABLA (se queda igual)
  - Posiciones 6-9: PIERDEN (suben 1 si HCP < 12)
  
  ## Correcciones aplicadas:
  
  1. **Pablo Espinosa** (Pos 1, ganó):
     - HCP de juego: 8 → 7
     - HCP actual incorrecto: 4.0
     - HCP correcto: 7.0
  
  2. **Juan Bosch** (Pos 2, ganó):
     - HCP de juego: 5 → 4
     - HCP actual incorrecto: 2.0
     - HCP correcto: 4.0
  
  3. **Saul Viciano** (Pos 4, ganó):
     - HCP de juego: 12 → 11
     - HCP actual incorrecto: 10.0
     - HCP correcto: 11.0
  
  4. **Nacho Bernat** (Pos 5, MITAD DE TABLA):
     - HCP de juego: 10 → 10 (se queda igual)
     - HCP actual incorrecto: 12.0
     - HCP correcto: 10.0
  
  5. **Victor Zeyani** (Pos 7, perdió):
     - HCP de juego: 4 → 5
     - HCP actual incorrecto: 4.0
     - HCP correcto: 5.0
  
  6. **Alfonso Cardona** (Pos 8, perdió):
     - HCP de juego: 10 → 11
     - HCP actual incorrecto: 12.0
     - HCP correcto: 11.0
*/

-- Actualizar Pablo Espinosa (ganó, baja 1)
UPDATE players 
SET exact_handicap_18 = 7.0,
    exact_handicap = 3.5
WHERE name = 'Pablo Espinosa';

-- Actualizar Juan Bosch (ganó, baja 1)
UPDATE players 
SET exact_handicap_18 = 4.0,
    exact_handicap = 2.0
WHERE name = 'Juan Bosch';

-- Actualizar Saul Viciano (ganó, baja 1)
UPDATE players 
SET exact_handicap_18 = 11.0,
    exact_handicap = 5.5
WHERE name = 'Saul Viciano';

-- Actualizar Nacho Bernat (mitad de tabla, se queda igual)
UPDATE players 
SET exact_handicap_18 = 10.0,
    exact_handicap = 5.0
WHERE name = 'Nacho Bernat';

-- Actualizar Victor Zeyani (perdió, sube 1)
UPDATE players 
SET exact_handicap_18 = 5.0,
    exact_handicap = 2.5
WHERE name = 'Victor Zeyani';

-- Actualizar Alfonso Cardona (perdió, sube 1)
UPDATE players 
SET exact_handicap_18 = 11.0,
    exact_handicap = 5.5
WHERE name = 'Alfonso Cardona';
