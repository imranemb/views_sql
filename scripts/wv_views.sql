-- Création des vues modifiables pour chaque table : v_{nom_table}
-- Ces vues permettent d'effectuer des SELECT mais aussi des INSERT via des triggers INSTEAD OF

-- =============================
-- Vue pour la table parties
-- =============================
CREATE VIEW v_parties AS
SELECT * FROM parties;  -- Crée une vue qui expose toutes les colonnes de la table parties pour les rendre accessibles en lecture

-- Fonction de trigger pour gérer les INSERT sur la vue v_parties
CREATE OR REPLACE FUNCTION v_parties_insert() RETURNS trigger AS $$
BEGIN
  -- Cette fonction est déclenchée lorsqu'on tente un INSERT sur la vue v_parties
  INSERT INTO parties(id_party, title_party)  -- Insère les données dans la table réelle 'parties' à partir de la ligne NEW
  VALUES (NEW.id_party, NEW.title_party);
  RETURN NEW;  -- Retourne la ligne insérée pour que la vue affiche la donnée comme si l'INSERT était natif
END;
$$ LANGUAGE plpgsql;  -- Le langage PL/pgSQL est utilisé pour écrire la fonction

-- Trigger qui utilise la fonction précédente
CREATE TRIGGER trg_v_parties_insert
INSTEAD OF INSERT ON v_parties  -- Ce trigger remplace (INSTEAD OF) le comportement par défaut de l'INSERT sur la vue
FOR EACH ROW EXECUTE FUNCTION v_parties_insert();  -- À chaque ligne insérée, appelle la fonction v_parties_insert()

-- =============================
-- Vue pour la table players
-- =============================
CREATE VIEW v_players AS
SELECT * FROM players;  -- Rend toutes les données de la table players disponibles en lecture via la vue

-- Fonction de trigger pour gérer les INSERT sur la vue v_players
CREATE OR REPLACE FUNCTION v_players_insert() RETURNS trigger AS $$
BEGIN
  -- Lors d’un INSERT sur la vue v_players, redirige l’opération vers la vraie table players
  INSERT INTO players(id_player, pseudo)
  VALUES (NEW.id_player, NEW.pseudo);
  RETURN NEW;  -- Retourne la ligne insérée dans la vue
END;
$$ LANGUAGE plpgsql;

-- Trigger d'insertion sur la vue v_players
CREATE TRIGGER trg_v_players_insert
INSTEAD OF INSERT ON v_players  -- Intercepte les INSERT sur la vue
FOR EACH ROW EXECUTE FUNCTION v_players_insert();  -- Utilise la fonction définie ci-dessus pour insérer dans la table réelle

-- ========================================
-- 1. ALL_PLAYERS : Vue des joueurs actifs
-- ========================================
CREATE VIEW ALL_PLAYERS AS
SELECT
  p.pseudo AS nom_du_joueur,  -- Affiche le pseudo du joueur
  COUNT(DISTINCT pip.id_party) AS nombre_de_parties_jouees,  -- Compte le nombre de parties uniques jouées
  COUNT(pp.id_turn) AS nombre_de_tours_joues,  -- Nombre total d’actions du joueur (tours)
  MIN(pp.start_time) AS date_premiere_participation,  -- Date de sa toute première action enregistrée
  MAX(pp.end_time) AS date_derniere_action  -- Date de sa dernière action enregistrée
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player  -- Lien entre les joueurs et les parties jouées
JOIN players_play pp ON pip.id_players_in_parties = pp.id_players_in_parties  -- Lien avec les actions jouées
GROUP BY p.pseudo  -- On regroupe par joueur pour agréger les données
ORDER BY nombre_de_parties_jouees DESC, date_premiere_participation, date_derniere_action, nom_du_joueur;  -- Tri selon les consignes

-- ===================================================
-- 2. ALL_PLAYERS_ELAPSED_GAME : Durée par partie/joueur
-- ===================================================
CREATE VIEW ALL_PLAYERS_ELAPSED_GAME AS
SELECT
  p.pseudo AS nom_du_joueur,  -- Nom du joueur
  pa.title_party AS nom_de_la_partie,  -- Nom de la partie à laquelle il a participé
  COUNT(DISTINCT pip2.id_player) AS nombre_de_participants,  -- Nombre total de joueurs dans cette partie
  MIN(pp.start_time) AS premiere_action,  -- Moment de la première action du joueur dans cette partie
  MAX(pp.end_time) AS derniere_action,  -- Moment de sa dernière action
  EXTRACT(EPOCH FROM MAX(pp.end_time) - MIN(pp.start_time)) AS nb_secondes_passees  -- Temps total en secondes passé dans cette partie
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player  -- Association joueur/partie
JOIN parties pa ON pip.id_party = pa.id_party  -- Nom de la partie
JOIN players_play pp ON pip.id_players_in_parties = pp.id_players_in_parties  -- Actions du joueur
JOIN players_in_parties pip2 ON pip2.id_party = pa.id_party  -- Tous les joueurs de la même partie pour le compte
GROUP BY p.pseudo, pa.title_party;  -- Un résultat par joueur et par partie

-- ======================================================
-- 3. ALL_PLAYERS_ELAPSED_TOUR : Temps de réaction par tour
-- ======================================================
CREATE VIEW ALL_PLAYERS_ELAPSED_TOUR AS
SELECT
  p.pseudo AS nom_du_joueur,  -- Nom du joueur
  pa.title_party AS nom_de_la_partie,  -- Partie concernée
  t.id_turn AS numero_du_tour,  -- Identifiant du tour
  t.start_time AS debut_tour,  -- Début du tour
  pp.end_time AS prise_decision,  -- Fin de l'action du joueur
  EXTRACT(EPOCH FROM pp.end_time - t.start_time) AS nb_secondes_passees_dans_le_tour  -- Temps écoulé depuis le début du tour
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player  -- On relie les joueurs aux parties jouées
JOIN parties pa ON pip.id_party = pa.id_party  -- On récupère le titre de la partie
JOIN players_play pp ON pip.id_players_in_parties = pp.id_players_in_parties  -- On relie aux actions
JOIN turns t ON pp.id_turn = t.id_turn;  -- On relie aux tours pour connaître les débuts de chaque tour

-- ======================================================
-- 4. ALL_PLAYERS_STATS : Statistiques générales du joueur
-- ======================================================
CREATE VIEW ALL_PLAYERS_STATS AS
SELECT
  p.pseudo AS nom_du_joueur,  -- Nom du joueur
  r.description_role AS role,  -- Rôle dans la partie (ex: loup, villageois)
  pa.title_party AS nom_de_la_partie,  -- Nom de la partie
  COUNT(DISTINCT pp.id_turn) AS nb_tours_joues,  -- Nombre total de tours auxquels le joueur a participé
  (SELECT COUNT(*) FROM turns t2 WHERE t2.id_party = pa.id_party) AS nb_total_tours,  -- Nombre total de tours dans la partie (même sans le joueur)
  'inconnu' AS vainqueur,  -- Champ statique à remplacer selon le vainqueur réel (nécessite une autre table non fournie)
  ROUND(AVG(EXTRACT(EPOCH FROM (pp.end_time - pp.start_time)))) AS temps_moyen_prise_decision  -- Moyenne du temps de prise de décision en secondes
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player  -- Lien joueur/partie/role
JOIN parties pa ON pip.id_party = pa.id_party  -- Lien vers la partie
JOIN roles r ON pip.id_role = r.id_role  -- Récupération du rôle du joueur
JOIN players_play pp ON pip.id_players_in_parties = pp.id_players_in_parties  -- Actions du joueur
GROUP BY p.pseudo, r.description_role, pa.title_party;  -- Regroupement par joueur, rôle, et partie