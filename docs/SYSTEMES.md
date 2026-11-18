# Systèmes de gameplay — état réel (2026-07-21)

Architecture transversale : tout passe par `EventBus` (`scripts/core/EventBus.gd`).
Deux patterns dominent : le **launcher additif** (prop monde `Interactable` →
instancie la scène de mini-jeu, masque World+UI, écoute `match_ended`) et la
**récompense séparée** (argent au launcher, réputation/affinité/mestre à
l'autoload `ActivityRewards`).

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

Corrigé le 2026-07-21 : bouton 🏃 Correr à bascule (`RunButton` +
`external_run_hold` du joystick — sprint compatible direction fine, seuil
0.85 en alternative) ; `print()` de debug retirés. Frictions restantes :
stamina sans progression sur toute la partie ; altinha lancée par un chemin
spécial (`altinha_requested` → PlayerController) au lieu du pattern launcher.

## 2. Mini-jeux (`scripts/minigames/`, 18 scènes + kite)

Tous émettent `minigame_started/ended(id, result)`. `ActivityRewards.gd` mappe
l'id → axe de réputation + affinité NPC + flag `mestre_<id>` au 3e succès.
Tips crédités par les launchers (`inv.add_money`).

**Socle commun `MinigameBase`** (2026-11-18, `scripts/minigames/MinigameBase.gd`,
toutes les scènes en héritent) : bouton « ✕ Sair » posé d'office (≥ 44 pt,
SafeArea, B manette / Échap ; les HUD du coin haut-droit s'écartent),
abandon = `forfeited` → `final_qualifies()` ne qualifie jamais ; fonds pleine
largeur étirés aux bords réels (plus de bandes grises en 19,5:9) ;
`sfx(clé)` (SFX `mg_perfect/good/miss/hit/drop`, `checkpoint`, `splash`,
`fish_bite`, `oven_ding`, `torcida_cheer`, pads `dj_*` / `samba_*`, synthétisés
par `tools/audio/synth_audio.py`) et `pulse()` (vibration) ; `char_sprite()`
= le joueur en pixel-art. Le bouton Action tactile émet appui ET relâché
(`interact` restait coincé : Surf/Padaria/Valet/Treino/Pesca injouables au doigt).

**Profonds** : Beach-volley (volley de blobs, vue de côté : ◀ ▶ + saut, la
balle rebondit sur la tête du joueur — l'angle dépend du point d'impact, légère aide vers l'avant —, smash en l'air
au-dessus du filet, personnages pixel-art de profil, 3 touches par camp, service alterné, ombre du point de
chute ; physique codée à la main, IA qui prédit la trajectoire ; 1er à 5,
abandon = défaite),
Altinha (roda de 3, placement + fenêtre + visée + combo cap 20, parceiro quente
= técnico +40, 3 chutes = fin, qualif ≥ 400, jamais d'argent), Surf (séries
lisibles, pic, fenêtre take-off, équilibre curseur, kick-out, 90 s, qualif
≥ 250 ; surfeur sur la planche), **Kite** (même mer, autre geste : stick ↑
borde l'aile, saut sur le front avec l'aile dans la zone verte — molle = pas
de décollage, trop bordée = arrachée ; la puissance multiplie le saut), SUP
Cagarras (2 tours de 4 îlots, courant qui tourne toutes les 5-8 s ; max
120 R$), Valet (8 clients max, arrivées qui se resserrent 11→5 s, klaxon à
l'entrée −10 R$, client réclamant non servi en 22 s = parti fâché ; qualif
4 servis / ≤ 1 perdu), Padaria (assemblage + four qui sonne no ponto, fila qui
s'impatiente 32→20 s ; qualif 3 fournées dont 1 parfaite, ≤ 1 fila perdue),
Racha Atlântica (3 tours vs 3 IA, inertie + dérapage, hors bitume ×0,45,
turbo, IA en trajectoire + élastique, compte à rebours, tour compté sur la
ligne ; payout 220/100/40/0 pour 50 d'inscription), DJ (4 lanes qui sonnent,
combo ×1→×3, tap à vide = combo cassé ; qualif ≥ 500, ~200-250 R$), Carnaval
Samba (motif base/base/virada/breque, frappe hors temps pénalisée, qualif ≥ 480
clôt `act4_carnaval_desfile`), Maracanã Torcida (5 ordres = 5 gestes au doigt :
glisser ↑ ← → ↓, taper = OLA ; fenêtre 1,6→1,0 s ; qualif ≥ 170), Lagoa
(course pseudo-3D vue de derrière façon F1 rétro autour de la Lagoa : route
dessinée par segments, virages et bosses, force centrifuge, FREIO, hors piste
×0,3, cyclistes à doubler, 2 tours, temps de départ 22 s + 13 s par checkpoint ;
max 100 R$).

**Courts** : Basket (jauge qui accélère et zones qui rétrécissent au fil des
10 tirs, 6 R$/pt, moitié si non qualifié), Bike (rue qui défile en 4 voies,
rangées qui laissent toujours un passage, piétons, colis à ramasser — qualif
≥ 5 entregas avec la commande intacte), Desembarque (les passagers sortent un par un
et s'arrêtent devant toi ; plaque à pastilles de couleur ; « É ELE ! » ou laisser
passer — appel tôt = Perfeito, mauvais appel −1 ; A manette = appeler ; qualif
≥ 14), Pesca da
Colônia (lancer visé 3 bandes, ferrage, combat à la tension — quai, pêcheur et
morros de Niterói), Treino da academia (appui-relâché dans la zone de forme,
gás anti-mash — l'athlète sous la barre), Milho (rush de service, navigable
à la croix + A).

### Récompenses (canal unique depuis le 2026-11-18)
- La réputation ne passe plus que par `ActivityRewards` (`gain_capped`, cap =
  3× la signature — le compteur mestre continue au-delà) ; les launchers ne
  gèrent plus que l'argent et les objectifs de quête.
- Exercise crédite CHARISMA (l'axe affiché) + affinité ramos.
- Le kite a son identité : `SurfGame.minigame_id` (exporté, défaut `surf`),
  surchargé `kitesurf` par `KiteLauncher` — signature ActivityRewards propre,
  plus d'auto-complétion d'objectifs MINIJEU `surf` depuis le kite.

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

Corrigé le 2026-07-21 : plancher 180 s sur les missions dont la cible est à
un offset de district (> 3000 px) — le taxi est instantané et le téléphone
pause le jeu. Friction restante : cobrador/visites créancières limités à
copacabana/zona_sul/favela_morro — pression dette absente ailleurs.

## 4. Économie

Sources : milho (`CornCart.gd` — acte 1 : tournée à pied, stock 3, 5/15 R$ ;
dès l'acte 2 : « Hora do rush » `MilhoGame`, ~100-150 R$ par rush réussi +
affinité des fregueses — voir ci-dessous),
missions dynamiques (moteur principal), tips launchers, `money_reward` de
quêtes, payouts fishing/bike/racha, pari volley ×2, achievements.

Dette : `DEBT_TOTAL=50 000`, seuils 500/2 000/6 000 = jalons de rythme.
**`debt_credit` crédite la dette sans ponctionner le cash** (versements
scénarisés des 4 chaînes, ~2 500/voie). Cash de poche ≠ dette payée : il faut
payer au Consórcio (Nilton) pour convertir — expliqué dans l'app Saúde
depuis le 2026-07-21.

`CreditorVisitManager` : check 60 s, cooldown 480 s, chance 30 → 85 % avec les
jours ; scénarios soft/ultimatum/raid ; shakedown police si
`commissaire_alerted` ; cobrador si dette ≥ 500 (45 %). Depuis le
2026-07-21, `BuildingManager.is_inside` (posé par les portes, remis à false
par tout voyage) bloque les visites en lieu privé.

Dépenses : água de coco (5 R$, recover stamina instantané), bribes, taxi,
paris, paiement de dette.

## 5. Réputation & affinité

`ReputationSystem` : 5 axes CIVIC/POLICE/STREET/TOURIST/CHARISMA, −100..100 ;
`modify` libre vs `gain_capped(axis, delta, source, cap)`. Sert au gating
(`Quest.required_reputation`, `missing_reputation`) et aux verrous de dialogue.

`NPCAffinity` : tiers stranger / acquaintance (≥2) / familiar (≥5) sur
`dialogue_ended` ; `bump(npc)` hors dialogue ; `knot_for_tier` varie les
salutations. Carburant du jeitinho.

Effets mécaniques (livrés le 2026-07-21) : preço de amigo chez les
StreetVendor (tier d'affinité `vendor_<id>` → −1/−2 R$, l'achat nourrit la
relation), `CobradorChase.adjusted_config` (STREET ≥ 50 : abandon −25 %,
fatigue du poursuivant −20 %), `PMPatrol.waves_through` (POLICE ≥ 40 : la
patrouille salue au lieu de racketter). L'usage négatif passe par les
carrefours de voie. Reste sans décroissance passive (choix assumé).

## 6. HUD & guidage

`HUD.gd` : flash `+R$` en vert et `−R$` en rouge (les ponctions se sentent,
depuis le 2026-07-21), stamina, milho, jour/acte/phase, dette affichée comme
progression vers le **prochain seuil** (pas les 50 000), toasts (max 4),
chrono le plus urgent + suffixe « (+N ⏱) » si d'autres tournent,
`MAIN_NEXT_HINT` (toast doré jalon — dictionnaire à maintenir à la main).

`NavigationDirector` (32 KB) : source de vérité « quoi/où maintenant » —
`STEP` par (quest_id, obj_id), `PATRONS` pour l'acte 2. UI : `ObjectiveBanner`
(acte + quoi + où, teinte de voie, tap → journal), `Compass` (flèche de bord +
distance, bannière 🚕 si autre district), `QuestLog` (História ✦ / Atividades •).

Téléphone (`Phone.gd`, 40 KB) : apps Taxi, Saúde, Diário, Missões
(`MissionBoardUI`), Photos, Notícias, Conquistas, Mapa, Ajustes ; badges rouges.

Bouton ⚽ altinha : sable de Copa (`Cfg.shore_y`) + plages d'Ipanema et
d'Icaraí (`BEACH_BANDS`) depuis le 2026-07-21.

## Frictions restantes (entrée pour JOUABILITE.md)

Les bugs B1-B9 sont tous corrigés au 2026-07-21 (voir la table de
JOUABILITE.md — sprint 🏃 à bascule, plancher inter-districts, flag
`is_inside`, deltas négatifs + multi-chronos au HUD, Fotos sans chemin OS,
prints retirés). Restent :

1. ~~Milho anecdotique passé l'acte 1~~ — résolu le 2026-10-07 : la carrocinha
   lance la « Hora do rush » (`scripts/minigames/milho/MilhoGame.gd`, signature
   ActivityRewards `milho`). Panela de 3 épis (cru / no ponto / passado /
   desmanchou), garnitures 🧈🧂🧀, file de 3 clients à patience. Les 6 fregueses
   (Jorge, Ramos, le concierge, Diego, Roberto Maia, Seu Tonio) disent leur
   commande tant qu'on ne les connaît pas (flag `milho_conhece_<id>`, 2 Perfeitos),
   puis seulement « o de sempre » ; chaque Perfeito d'habitué = +1 affinité par
   rush → le milho nourrit le jeitinho.
2. `MAIN_NEXT_HINT` toujours à maintenir à la main.
3. Fishing/Exercise très en retrait des standards volley/surf/altinha (axe F).
4. Stamina sans progression sur toute la partie.
5. Altinha lancée hors pattern launcher (chemin spécial PlayerController).
