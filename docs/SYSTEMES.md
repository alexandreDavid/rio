# Systèmes de gameplay — état réel (2026-07-21)

Architecture transversale : tout passe par `EventBus` (`scripts/core/EventBus.gd`).
Deux patterns dominent : le **launcher additif** (prop monde `Interactable` →
instancie la scène de mini-jeu, masque World+UI, écoute `match_ended`) et la
**récompense en deux canaux** (launcher + autoload `ActivityRewards`).

## 1. Joueur & déplacement (`scripts/player/PlayerController.gd`)

- `WALK_SPEED=80`, `RUN_SPEED=140`. Sprint draine 7/s, marche récupère 14/s
  (`scripts/player/Stamina.gd`, max 100). À sec → essoufflé, marche forcée
  jusqu'à 25 % (`WINDED_RECOVER_RATIO`). Seul ressort de tension des courses.
- Interactions : liste `_active_interactables`, le plus récent gagne, `E`.
  Freeze total pendant dialogue/cutscene.
- **Rideable** (`scripts/world/Rideable.gd`) : monter/descendre à `E`, le
  véhicule porte la physique (accel/friction/drift SUP/`rotate_visual` voiture,
  `stamina_drain` optionnel). Bike `max_speed=180`. Retour à `_home_position` à
  chaque `district_changed`.
- Tactile : `MobileControls.gd` (bouton E, bouton ⚽ altinha, joystick) ;
  `VirtualJoystick.gd` déclenche `run` à **0.85 de déflexion**.

Frictions : pas de bouton sprint dédié en tactile (sprint incompatible avec une
direction fine — pénalise cobrador/PM/ciclovia) ; stamina sans aucune
progression sur toute la partie ; altinha lancée par un chemin spécial
(`altinha_requested` → PlayerController) au lieu du pattern launcher ; `print()`
de debug encore actifs.

## 2. Mini-jeux (`scripts/minigames/`, 16 mécaniques réelles)

Tous émettent `minigame_started/ended(id, result)`. `ActivityRewards.gd` mappe
l'id → axe de réputation + affinité NPC + flag `mestre_<id>` au 3e succès.
Tips crédités par les launchers (`inv.add_money`).

**Profonds** : Beach-volley (timing frappe Perfeito/Boa/Mole, saut, IA
progressive, pari ×2, 1er à 5), Altinha (roda de 3, placement + fenêtre +
visée + combo cap 20, parceiro quente = técnico +40, 3 chutes = fin, qualif
≥ 400, jamais d'argent), Surf (séries lisibles, pic, fenêtre take-off,
équilibre curseur, kick-out, 90 s, qualif ≥ 250), SUP Cagarras (courant à
compenser, 4 îlots), Valet (410 l., restituer la voiture réclamée, tip à la
rapidité), Padaria (531 l., assemblage + fenêtre de cuisson 4-8 s), Racha
Atlântica (course 3 tours vs 3 IA, payout 600/200/60/0), DJ (4 lanes, combo
×1→×3), Carnaval Samba (pattern fixe, ≥ 240 clôt `act4_carnaval_desfile`),
Maracanã Torcida (réactif 5 commandes), Lagoa (contre-la-montre vélo + vent).

**Superficiels (1-2 boutons)** : Basket (jauge oscillante), Bike (scroller
esquive 30 s), Fishing (barre de timing, 3 rounds), Exercise (mash). Les deux
derniers sont les plus pauvres — candidats à approfondir.

### Bugs/frictions récompenses
- **Double canal non plafonné** : launcher (gain_capped par source) +
  `ActivityRewards.modify` (**aucun cap**) → réputation grindable en rejouant
  (valet, basket, bike…).
- **Exercise** : affiche « +1 Charisma » (`ExerciseGame.gd:91`) mais
  `ActivityRewards["exercise"]` donne STREET + affinité ramos — gain caché.
- **Kite = Surf.tscn** (`scenes/props/KiteStation.tscn` pointe
  `match_scene = Surf.tscn`) : la session émet les signaux `surf` →
  récompenses surf (TOURIST, affinité lucas) + STREET du KiteLauncher, et un
  objectif MINIJEU `surf` s'auto-complèterait depuis une session de kite.

## 3. Systèmes de résistance

- **CobradorChase** (`scripts/world/CobradorChase.gd`, spawn en code, pas de
  .tscn) : 126 px/s frais / 96 fatigué après 22 s ; abandonne à 560 px ou 40 s ;
  capture à 26 px = −15 % du cash (min 20) ; semé = STREET +1, rattrapé les
  poches vides = STREET −2. Sert le cobrador ET le verbe `start_chase` (PM
  Tráfico), filtré `chaser_id`. Debug `Ctrl+F6`.
- **StakeoutZone** (`scripts/world/StakeoutZone.gd`) : bande 70-240 px du
  suspect ; trop près 3× ou perdu > 5 s = échec (retente au spot) ; anneaux
  dessinés pour lisibilité sans tuto.
- **Objectifs typés** (`QuestObjective.kind`, hooks `QuestManager`) : MANUEL /
  MINIJEU (auto, `minigame_id`) / CHRONO (expiration = fail) / FUITE (auto sur
  `chase_ended` escaped). Chronos au HUD via `chrono_updated/cleared`.
- **DynamicMissionManager** (329 l.) : 3 missions permanentes (VOYOU/POLICE/
  MAIRE), régénérées à la complétion. `REWARD_TABLE = [80…1300]`, budget temps
  distance-based (~90 px/s + 30 s + 15 s/point, clamp 45-420 s), **Rapidinho
  +25 %** si ≥ 25 % de marge. C'est le vrai moteur de cash entre jalons.

Frictions : missions dynamiques inter-districts au chrono qui court pendant le
trajet taxi (ex. VOYOU « Course pour Ipanema » à (-11700,-2770)) — risque
d'intenable ; cobrador/visites créancières limités à copacabana/zona_sul/
favela_morro (`CreditorVisitManager` L90-93) — pression dette absente ailleurs.

## 4. Économie

Sources : milho (`CornCart.gd`, stock 3, 5/15 R$, paiement immédiat — appoint),
missions dynamiques (moteur principal), tips launchers, `money_reward` de
quêtes, payouts fishing/bike/racha, pari volley ×2, achievements.

Dette : `DEBT_TOTAL=50 000`, seuils 500/2 000/6 000 = jalons de rythme.
**`debt_credit` crédite la dette sans ponctionner le cash** (versements
scénarisés des 4 chaînes, ~2 500/voie). Cash de poche ≠ dette payée : il faut
payer au Consórcio (Nilton) pour convertir — jamais expliqué à l'écran.

`CreditorVisitManager` : check 60 s, cooldown 480 s, chance 30 → 85 % avec les
jours ; scénarios soft/ultimatum/raid ; shakedown police si
`commissaire_alerted` ; cobrador si dette ≥ 500 (45 %). La détection « joueur
en intérieur » est un proxy inerte (L85-89, « à raffiner ») — visite possible
en lieu privé.

Dépenses : água de coco (5 R$, recover stamina instantané), bribes, taxi,
paris, paiement de dette.

## 5. Réputation & affinité

`ReputationSystem` : 5 axes CIVIC/POLICE/STREET/TOURIST/CHARISMA, −100..100 ;
`modify` libre vs `gain_capped(axis, delta, source, cap)`. Sert au gating
(`Quest.required_reputation`, `missing_reputation`) et aux verrous de dialogue.

`NPCAffinity` : tiers stranger / acquaintance (≥2) / familiar (≥5) sur
`dialogue_ended` ; `bump(npc)` hors dialogue ; `knot_for_tier` varie les
salutations. Carburant du jeitinho.

Frictions : la part `ActivityRewards.modify` sans cap rend les axes farmables ;
aucune décroissance ni usage négatif (les axes ne montent que) ; l'affinité ne
débloque que des variantes de dialogue + flags mestre — pas d'effet mécanique
fort (prix, accès) : le jeitinho reste surtout cosmétique côté systèmes.

## 6. HUD & guidage

`HUD.gd` (777 l.) : flash `+R$` (delta positif seulement — les ponctions ne se
« sentent » pas), stamina, milho, jour/acte/phase, dette affichée comme
progression vers le **prochain seuil** (pas les 50 000), toasts (max 4), chrono
**le plus urgent seulement** (les autres deviennent invisibles),
`MAIN_NEXT_HINT` (toast doré jalon — dictionnaire à maintenir à la main).

`NavigationDirector` (32 KB) : source de vérité « quoi/où maintenant » —
`STEP` par (quest_id, obj_id), `PATRONS` pour l'acte 2. UI : `ObjectiveBanner`
(acte + quoi + où, teinte de voie, tap → journal), `Compass` (flèche de bord +
distance, bannière 🚕 si autre district), `QuestLog` (História ✦ / Atividades •).

Téléphone (`Phone.gd`, 40 KB) : apps Taxi, Saúde, Diário, Missões
(`MissionBoardUI`), Photos, Notícias, Conquistas, Mapa, Ajustes ; badges rouges.

Bouton ⚽ altinha : **sable de Copacabana uniquement** (TODO backlog : autres
plages).

## Frictions prioritaires (entrée pour JOUABILITE.md)

1. Sprint tactile au seuil 0.85 — inutilisable en dirigeant finement.
2. Double canal de réputation non plafonné + gains cachés (Exercise).
3. Kite = Surf.tscn : mislabel, double récompense, fuite de complétion de quête.
4. Cash ≠ dette jamais explicité ; milho inutile passé l'acte 1.
5. Missions chronométrées inter-districts vs temps de trajet.
6. Guidage fragile : `MAIN_NEXT_HINT` manuel, un seul chrono affiché.
7. Visites créancières possibles en intérieur (détection inerte).
8. Fishing/Exercise très en retrait des standards volley/surf/altinha.
