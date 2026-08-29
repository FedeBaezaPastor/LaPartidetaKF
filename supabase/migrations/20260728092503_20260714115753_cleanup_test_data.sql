-- 1. Delete test archived rounds (played today - all are from test sessions)
DELETE FROM archived_rounds
WHERE group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  AND DATE(played_at) = '2026-07-14';

-- 2. Delete daily rankings generated from test rounds today
DELETE FROM daily_rankings
WHERE group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  AND ranking_date = '2026-07-14';

-- 3. Delete handicap adjustments generated from test rounds today
DELETE FROM handicap_adjustments
WHERE group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  AND adjustment_date = '2026-07-14';

-- 4. Restore player handicaps to the correct values from migration 20260714094527
UPDATE players SET exact_handicap = 6.0,  exact_handicap_18 = 6.0,  playing_handicap = 6  WHERE id = '5f375d1a-6ddc-41f8-810d-32fda1b1715a'; -- Fernando
UPDATE players SET exact_handicap = 6.0,  exact_handicap_18 = 6.0,  playing_handicap = 6  WHERE id = '7ce52ab4-71ce-45e8-ab03-96a86d1476ef'; -- Alfonso
UPDATE players SET exact_handicap = 12.0, exact_handicap_18 = 12.0, playing_handicap = 12 WHERE id = 'b83c753b-2d88-4d52-8a4b-18533cad4403'; -- Kike
UPDATE players SET exact_handicap = 6.0,  exact_handicap_18 = 6.0,  playing_handicap = 6  WHERE id = 'a1d1d46d-a1de-41f6-bbca-b126b6b3df8f'; -- Nacho
UPDATE players SET exact_handicap = 8.0,  exact_handicap_18 = 8.0,  playing_handicap = 8  WHERE id = '0f89e919-afe2-46f3-9755-82109bcd1235'; -- Quique
UPDATE players SET exact_handicap = 12.0, exact_handicap_18 = 12.0, playing_handicap = 12 WHERE id = '1c7438a7-70bc-4e0d-b3d5-dff2967699f5'; -- Carlos
UPDATE players SET exact_handicap = 0.0,  exact_handicap_18 = 0.0,  playing_handicap = 0  WHERE id = 'bf3d9415-33a1-451b-b63c-a544f1a0cc71'; -- Fede2