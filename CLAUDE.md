# Rio — Copacabana (Godot 4.6)

Vertical slice d'un jeu 2D top-down situé sur la plage de Copacabana à Rio. Quête principale autour du milho (maïs grillé), mini-jeux (volley, padaria, valet, surf…), système de réputation multi-axes, dialogues à choix structurés.

Langue de travail : **français** (code, commentaires, dialogues, UI).

Docs de contexte (état réel vérifié dans le code, 2026-07-21) : `docs/SYSTEMES.md` (gameplay, mini-jeux, économie, HUD), `docs/NARRATIF.md` (actes, quêtes, dialogues, choix), `docs/MONDE.md` (districts, NPCs, vie ambiante, tests), `docs/JOUABILITE.md` (diagnostic croisé + axes d'amélioration priorisés). À lire avant un chantier jouabilité ; `docs/BACKLOG.md` reste la trace des besoins de design.

## Stack
- Godot **4.6** Forward+ (`project.godot` line `config/features`)
- Scripts GDScript statiquement typés — préférer `Node2D` explicite aux `Variant` non typés
- Dialogues : knots structurés (dicts `const KNOTS`) dans `scripts/dialogues/Act1..4Dialogues.gd` + `Side{Plage,Services,Baia}Dialogues.gd` (SIDE re-splités par domaine), fusionnés au runtime par `DialogueBridge._merge_external_dialogues()`. `DialogueBridge` expose un contrat de signaux (`line_shown` / `choices_presented` / `dialogue_finished`) indépendant du moteur : `InkStoryLoader.gd` reste branché comme backend interchangeable, mais **le plugin inkgd n'est pas installé** et `ink/milho.ink` est un vestige non chargé — tout le contenu réel vit dans les dicts ci-dessus

## Autoloads (singletons)
Ordre important dans `project.godot` — ne pas changer sans raison :
- **EventBus** (`scripts/core/EventBus.gd`) — bus global de signaux. Les systèmes ne se référencent jamais directement, ils émettent/écoutent ici.
- **GameManager**, **ReputationSystem**, **TimeOfDay**, **QuestManager**, **DialogueBridge**, **SaveSystem**, **AudioManager**, **SelfCheck**, **BuildingManager**
- **CarnavalCalendar** (jours PT via `TimeOfDay.day_count`, `hud_label()` J-x Carnaval, jogo du Domingo soir → flags `jogo_vitoria|jogo_derrota` le lendemain ; après le desfile : flag `pos_carnaval`, ellipse au mercredi des Cendres `cinzas_hoje` à la fermeture de l'épilogue, feijoada du samedi), **ActivityRewards** (mini-jeu qualifiant → réputation ciblée + `NPCAffinity.bump(npc)` + flag `mestre_<id>` au 3e succès — récompenses non fongibles)

## Layout de la map (`scripts/world/CopacabanaGenerator.gd`)
Map horizontale orientée ouest→est. **LEME à l'est (x haut), FORTE à l'ouest (x bas).** 6 postos (comme en vrai) : Posto 6 côté forte, Posto 1 côté Leme.

Zones par bande Y (du nord au sud) :
```
y < -200         Favelas (Morro à l'ouest, Leme à l'est)
y = -192..-128   2ème rangée d'immeubles + police + bar flic + academia
y = -128..-64    Nossa Senhora de Copacabana (route intérieure)
y = -64..0       1ère rangée d'immeubles + palace + commerces
y = 0..64        Av. Atlântica (route front de mer ; ciclovia terracotta y=48..64)
y = 64..128      Calçadão (motif vague noir/blanc)
y = 128..~400    Sable (le rivage suit la courbe de la baie : `Cfg.shore_y(x)`)
y = ~372..600    Mer (arc parabolique — 372 au centre x=1450, 435 aux pointes Forte/Leme)
```
Constantes clés (dans `scripts/world/CopacabanaConfig.gd`, préchargé `Cfg` par le générateur) : `BUILDING_Y=-32`, `SECOND_ROW_Y=-160`, `POSTO_Y=168`, `PALACE_X=1700`, `POLICE_X=1200`, `ACADEMIA_X=700`, `COP_BAR_X=1380`. Rues transversales réelles (`Cfg.CROSS_STREETS`, trouées dans les deux rangées d'immeubles) : R. Santa Clara x=600, R. Siqueira Campos x=1111 (alignée Túnel Velho), Av. Princesa Isabel x=2150 (alignée Túnel Novo). Entrées de métro décoratives (`Cfg.METRO_STATIONS`) : Cantagalo, Siqueira Campos, Cardeal Arcoverde.

Limite de la zone jouable (bâtiments NPC) : `map_start_x=160`, `map_end_x=2200`. Les strips de tiles (sable, calçadão, route, mer) couvrent toute la map décorée : `Cfg.MAP_LEFT=-300` → `Cfg.MAP_RIGHT=3200`, soit `Cfg.MAP_TOTAL_W=3500` (inclut Forte à l'ouest et Leme à l'est).

Autres sprites : `assets/sprites/props_ai.png` = 12 icônes d'objets (vraie transparence), régions dans `scripts/ui/ItemIcons.gd` (`ItemIcons.texture("agua_de_coco")`) — encore inutilisées par l'UI. **`props_ai_clean.png` a un damier incrusté, ne pas l'utiliser.** `grass.png` (Kenney) sert de tuile d'herbe aux districts.

## Z-index convention
```
-10  Background (ciel bleu ColorRect)
 -6  Sols trottoir (sous les rangées d'immeubles)
 -5  Tuiles de sol (sable, calçadão, route, eau)
 -4  Écume plage/mer
 -3  Lignes décoratives ColorRect (Nossa Senhora, Av. Atlântica)
  0  Bâtiments, NPCs, props, joueur (défaut)
```

## Tileset `assets/sprites/tileset_ai.png` (1536×1024, RGBA)
Atlas 7 colonnes × 5 rangées. **Chaque tuile a un cadre décoratif de ~20 px qui ne tile pas proprement** : toujours cropper *à l'intérieur* du cadre (`position + 20, size - 40`).

Bandes Y des tuiles opaques (scannées par alpha > 128) :
- `y=72..207`   — sable (tile 0 = sable plein ; tile 6 = sable/mer transition, large)
- `y=226..361`  — calçadão (tile 0 = sable ; tiles 1-5 = vagues noir/blanc)
- `y=381..513`  — routes (asphalte, ligne jaune, pavé, calçadão-like)
- `y=536..655`  — trottoirs (curb blanc en haut ~y=542-570, béton en dessous)
- `y=660..920`  — décors : 2 palmiers (`PALM_TREE_REGION`, `PALM_TREE_B_REGION`), 3 parasols, 2 serviettes (`TOWEL_*_REGION`), carrocinha de plage (`BEACH_CART_REGION`) — tous inventoriés dans `CopacabanaConfig.gd`

Colonnes (début de chaque tile) : `108, 266, 425, 584, 744, 903, 1062`. Largeur tile ≈ 143 px, hauteur ≈ 136 px.

Régions utilisées (`scripts/world/CopacabanaConfig.gd`) :
| Constante | Rect2 |
|---|---|
| `SAND_TILE_REGION` | `(128, 92, 103, 96)` |
| `CALCADAO_TILE_REGION` | `(286, 246, 104, 96)` |
| `ROAD_TILE_REGION` | `(128, 401, 103, 93)` |
| `WATER_TILE_REGION` | `(1165, 145, 130, 50)` |
| `SIDEWALK_TILE_REGION` | `(128, 582, 103, 60)` |
| `FOAM_TILE_REGION` | `(1100, 88, 180, 60)` |
| `UMBRELLA_YELLOW/RED/BLUE_REGION` | `(460/614/1031, 660, ...)` |
| `PALM_TREE_REGION` | `(296, 660, 122, 252)` |
| `PALM_TREE_B_REGION` | `(108, 680, 165, 229)` |
| `TOWEL_STRIPED/LOUNGER_REGION` | `(785, 696, 211, 99)` / `(778, 825, 217, 82)` |
| `BEACH_CART_REGION` | `(1198, 660, 224, 260)` |

Helper : `_spawn_tile_strip(name, y_top, y_bot, region, z_idx=-5)` pour remplir une bande rectangulaire. `_spawn_prop_sprite(parent, region, pos, target_h)` pour un décor ponctuel (ancrage par la base).

## Jouabilité (systèmes de résistance)
- **Objectifs typés** : `QuestObjective.kind` = MANUEL (défaut, complété par dialogue/script) / MINIJEU (auto via `minigame_ended` + `minigame_id`, ex. `camila_ipanema_volley`) / CHRONO (`time_limit_sec` après acceptation, expiration = échec de quête) / FUITE (auto quand `chase_ended` escaped). Hooks dans `QuestManager`, chronos affichés au HUD via `EventBus.chrono_updated/cleared` (sources `quest:<id>`, `mission:<cat>`, `chase:cobrador`).
- **Sprint sous stamina** (`PlayerController`) : courir draine, marcher récupère, à sec = essoufflé (marche forcée) jusqu'à 25 %. Déflexion complète du joystick virtuel = sprint (tactile). L'água de coco des StreetVendor recover instantanément.
- **Cobrador** (`CobradorChase.gd`, spawné en code par `CreditorVisitManager` si dette ≥ 500) : course-poursuite réelle ; semer = STREET +1, rattrapé = −15 % du cash. Debug : `Ctrl+F6`.
- **Altinha** (`scripts/minigames/altinha/`, scène `Altinha.tscn`) : vrai mini-jeu type volley (roda de 3, timing Perfeito/Boa/Mole, visée, parceiro « chaud »). Lancé par le bouton ⚽ de `MobileControls` (visible sur le sable de Copa) → `EventBus.altinha_requested` → `PlayerController` l'instancie en additif (pattern launcher, sans prop monde). Récompense via `ActivityRewards` (« altinha ») — jamais d'argent. NB : une v1 « jonglage libre dans le monde » a été retirée (retour design : pas assez fun) ; préférer des mini-jeux structurés.
- **Missions dynamiques chronométrées** : budget temps distance-based à l'acceptation (`DynamicMissionManager`), bonus « Rapidinho! » si ≥ 25 % de marge, expiration = mission perdue + régénérée. C'est le moteur de cash entre deux jalons (le milho = appoint).
- **Un verbe par voie** (actes 3-4) : Tráfico = livraisons + poursuites PM (`start_chase`, objectifs FUITE filtrés par `chaser_id` ; rattrapé = amende, on relance depuis le spot), Polícia = filatures (`start_stakeout` → `StakeoutZone.gd` : rester dans la bande 70-240 px), Consórcio = négociations à tell lisible (mauvais choix = caution `pay_bribe` perdue, variante rejouable), Prefeito = mutirão multi-objectifs. Motif spot en 3 temps : déclenche → relance (objective_done+objective_pending) → clôture (quest_completed → accept_quest + debt_credit).
- **Verbes DialogueBridge composables** (utilisables dans les `actions` des spots) : `debt_credit` (crédite la dette SANS ponctionner le cash — canal des versements scénarisés qui font franchir les seuils d'acte en jouant), `start_chase` (config `CobradorChase.spawn`), `start_stakeout`. `ReactiveDialogueSpot` accepte aussi `choice_actions` ({index: actions}) pour des choix à conséquences distinctes.
- **Objectifs mécaniques et audit** : tout objectif complété hors dialogue doit être déclaré dans `SCRIPT_COMPLETED_OBJECTIVES` (`IntegrationTestBase.gd`) — l'audit de complétude de `TestGroupWorld` échoue sinon. Chaque objectif MAIN exige aussi une entrée `STEP` dans `NavigationDirector.gd`, et les e2e de voie (`TestGroupNarrative`) marchent par stations — les insérer dans l'ordre.
- **Gabarit « enquête Pedrinho »** (pivots tio Zé + gros coups A8/B8/D8) : préparation par témoins chaînés (le 1er nomme le 2e) → lieu-clé « retenu » (variante d'esquive tant que la préparation n'est pas faite) → climax au verbe de la voie (fuite A8, planque 28 s B8, cortège escorté D8, lembrança tioze). `DialogueTriggerZone.gd` = « le donneur vient à toi » (Area2D une-seule-fois via `fired_flag`) ; `EscortFollower.gd` = suiveur générique flag-driven (`follow_flag`/`done_flag`) pour les cortèges/escortes.

## NPCs & quêtes
- 1 scène `.tscn` par NPC dans `scenes/npcs/` — la scène de base `NPC.tscn` définit le comportement commun
- Quêtes = ressources `.tres` dans `resources/quests/` (schéma `Quest.gd` + `QuestObjective.gd`)
- Dialogues en Ink dans `ink/`, chargés par `DialogueBridge` qui relie au NPC via un `npc_id`
- Instancier un NPC dans `scenes/world/Copacabana.tscn` avec `ExtResource` + `position`

## Intérieurs
Instanciés **une seule fois** loin du monde joué (x=~900..3000, y=-3000) via `_spawn_interiors()`. On y téléporte le joueur via les portes (`BuildingDoor.tscn`) qui portent un `destination: Vector2` et un `prompt_text`. Les positions cibles sont les `SpawnPoint` dans chaque intérieur.

## Conventions
- **Âme carioca** : avant d'écrire du contenu (dialogues, quêtes, événements), lire le skill `.claude/skills/ame-carioca` ; les besoins de design se tracent dans `docs/BACKLOG.md` (skill `backlog`). Le time de coração du joueur = flags `time_flamengo|time_vasco|time_fluminense|time_botafogo` (posés à l'intro) ; placeholder `{time}` substitué par `DialogueBridge._sub_placeholders`. Les événements de `RandomEventManager` peuvent être restreints par phase (`"phases": [2]`) ou par flag (`"flag": "jogo_vitoria"`), et `CopacabanaGenerator._spawn_evening_life()` n'apparaît qu'en phase EVENING ; `_spawn_domingo_life()` le Domingo ; `_rebuild_human_cost()` (mémorial, DESPEJO) suit les flags `voie_trafico`/`voie_consortium`.
- Pas de singleton direct entre scripts métier : tout passe par **EventBus**
- Typage statique systématique en GDScript (`var x: Vector2 = ...`, `func f() -> void`)
- Commentaires en français, brefs, uniquement pour le *pourquoi*
- Les couleurs des bâtiments viennent de `BUILDING_COLORS` / `FAVELA_COLORS` (palette cohérente)

## Mobile first
La cible primaire est iOS (`build_ios.sh`, `export_ios/`). Toute UI doit fonctionner sans clavier ni souris :
- Pas de feature gated derrière un raccourci clavier — toujours offrir un bouton à l'écran
- Touch targets ≥ 44pt ; police minimum 12px (préférer 14-16px pour le contenu, 18+ pour les titres)
- Les raccourcis clavier existants (`P`/`C`/`J`/`K`, `Ctrl+F1..F4` debug, `F5`/`F9` save) sont des bonus dev — ne pas en dépendre côté gameplay
- `MobileControls.tscn` (joystick virtuel) gère le déplacement en touch ; le bouton 📱 du HUD ouvre le téléphone, qui contient toutes les apps

## Gating narratif MAIN/SIDE
La trame est gated, les activités libres ne le sont pas. Sur `Quest.gd` :
- `quest_type` : `Quest.QuestType.MAIN` (trame, ~45 quêtes) ou `SIDE` (défaut, ~50 quêtes) — ~95 `.tres` au total dans `resources/quests/`
- `prerequisite_quest_ids: Array[String]` : à compléter avant que `is_available()` passe true
- `required_act` : acte minimum (0 = dispo dès le début)

Avancement d'acte = seuils de dette payée (`CampaignManager`, constantes `ACTn_THRESHOLD`) **+** quelques conditions narratives. Les seuils sont des jalons de RYTHME : la quête de fin de voie (`complete_endgame`) solde de toute façon le reliquat de la dette totale (`DEBT_TOTAL = 50 000`).
- **Acte 1 → 2** : `act1_heritage` complété + flag `act1_closed` (retour à la maison + nuit chez tio Zé, posé par `Act1NightCutscene`) + **500 R$** payés (`ACT1_THRESHOLD`). `ACT_PIVOT_QUESTS = {2: ["act1_heritage"]}` — les anciens pivots `act1_meet_*` / `act2_*` n'existent plus.
- **Acte 2 → 3** : **échantillon libre** — chaque patron offre sa mission intro sans sceller de voie ; passage débloqué au seul seuil **2 000 R$** (`ACT2_THRESHOLD`). Le vrai choix de voie se fait en acte 3.
- **Acte 3 → 4** : la voie est scellée (pacte → flag `voie_*`), le joueur enchaîne la chaîne A1–A7 ; passage passif à **6 000 R$** (`ACT3_THRESHOLD`).
- **Acte 4 → 5** : `complete_endgame(path)` au couronnement (A9/B9/C9/D9) — solde la dette, scelle l'endgame et ouvre l'acte 5 (Reinado/Carnaval).

**4 voies mutuellement exclusives** (`enum Endgame`, `VOIE_FLAGS`) : Tráfico (Tito), Polícia (Ramos), Consórcio (Magalhães), Prefeito (Padre). Chaque voie est linéaire en interne.

À chaque MAIN complétée, `HUD.MAIN_NEXT_HINT[quest_id]` fournit le toast jalon ("✓ X — Va voir Y au [lieu]"). À étendre dans ce dictionnaire à chaque ajout de MAIN.

**Canon des identités (ne jamais confondre dans un texte joueur)** : Zé = l'oncle disparu (la maison, la carrocinha, la dette sont les siennes) ; **Seu João = le vieux compadre de Zé**, pas du sang, qui veille sur mãe et vovó à la table — le joueur l'appelle « tio » par respect mais l'UI ne dit jamais « tio Zé » pour lui. Mãe dit « meu filho », vovó « meu neto » (jamais « sobrinho » en famille). Titres d'acte : **source unique `CampaignManager.ACT_TITLES`** (+ `ACT_CARDS` pour la carte d'acte `ActCard.tscn` jouée à chaque bascule 2→5) — le HUD, `ObjectiveBanner`, le Diário (`NarrativeJournal.categories()`) et l'app Saúde les lisent. `NarrativeJournal.story_so_far()` génère le résumé « Onde estou » (tête de la Crônica + 1re catégorie du Diário).

**Canon de l'arc Zé** : Zé = frère de la mère du joueur ; il a simulé sa noyade (dette consortium + il portait pour Tito) et se cache comme concierge du Palace. La révélation se joue au spot tioze de la voie (variante `medalhao_reveal`, pose `tio_ze_revealed`) → sa re-capture par la Mafia da Baía en découle → `act4_tio_ze_rescue` (pose `ze_rescued`, il retourne au Palace). Les spots tioze, la mère (HouseInterior), l'épilogue et le ZeEveSpot (banc de dominos, veille du Carnaval) réagissent à ces deux flags. Dom Nilton solde la dette en personne au couronnement (knots `nilton_settlement_*`, joués par `Act3FinaleCutscenes`).

Si un knot tente `accept_quest` sur une quête bloquée, `DialogueBridge._show_locked_message` affiche "Pas encore le bon moment — d'abord : <prereqs>". Le `QuestLog` sépare HISTÓRIA (✦ doré) et ATIVIDADES (• bleu).

## Workflows fréquents
- **Ajouter un NPC** : copier `scenes/npcs/NPC.tscn` → adapter script + ajouter les knots dans le bon `scripts/dialogues/*Dialogues.gd` → instancier dans `Copacabana.tscn` avec `position`
- **Ajouter une quête** : créer un `.tres` dans `resources/quests/` → ajouter les knots d'offre/rappel/fin dans `scripts/dialogues/*Dialogues.gd` (l'`ink_knot` de la quête y pointe) → enregistrer dans `MainBoot.QUEST_RESOURCES` ; tagger `quest_type = 1` si MAIN et lister `prerequisite_quest_ids` ; vérifier avec `tools/check_quest_gating.gd`
- **Ajouter un knot de dialogue** : éditer le fichier d'acte/domaine concerné (`Act1..4Dialogues.gd` / `Side{Plage,Services,Baia}Dialogues.gd`) — `const KNOTS` ; key = `ink_knot`, value = `{speaker, text, choices, on_choose?}`. La résolution runtime est par clé globale, le fichier choisi n'a pas d'incidence fonctionnelle (juste l'organisation)
- **Ajouter une tuile / régler le tileset** : utiliser l'agent `tileset-atlas` (cf `.claude/agents/`)
- **Habiller un district** (`scripts/world/DistrictDresser.gd`, appelé par la base `scripts/districts/District.gd`) : les scènes de `scenes/districts/` sont des ColorRect plats ; on tague les dalles de sol avec un groupe (`ground_sand|sea|road|calcadao|sidewalk|grass`) et une dalle `district_backdrop` (étendue à la bbox + marge, z=-10, fin du gris hors carte) → l'habilleur superpose les tuiles de l'atlas (shader répété, 1 Sprite2D par dalle) et pose l'écume sur chaque couture sable/mer. Faire pointer la racine sur `District.gd` (ou, si un enfant porte déjà un AmbientDrifter comme la Favela, un script racine minimal qui appelle `DistrictDresser.dress(self)` — deux drifters sur le même sous-arbre doubleraient la dérive), supprimer les faux décors en rects (vagues, écume). Vérifier avec `tools/screenshot_scene.gd` (scène seule, sans autoloads) ou `tools/ScreenshotWorld.tscn` (monde réel : `godot --path . tools/ScreenshotWorld.tscn -- <prefix> "x:y:zoom,..."`, coordonnées = offset du district + local). Façades : `building` / `building_favela` sur le ColorRect de façade → `BuildingDressing.paint_relief` (helper partagé avec `_spawn_building` et `_spawn_favela_house` de Copa) ajoute ombre portée, arête éclairée, fondation, bande de toit, et fenêtres + porte si aucun ColorRect dessiné après ne tombe dans la façade ; `building_favela` saute la bande de toit (déjà dessinée) et pose un décor de toit (antenne, caixa d'água, linge). Props : `prop_palm` / `prop_umbrella` / `prop_beach_cart` / `prop_towel` sur un ColorRect-empreinte (du haut de la couronne au pied) → masqué, remplacé par le sprite atlas ancré au pied via `PropSprites` (helper partagé avec Copa), couleur du rect = toile du parasol ; les lampadaires restent en rects (c'est aussi le cas à Copa). Groupes recolorés `ground_plaza` (grain du pavé) / `ground_dirt` (grain du sable) : la dalle garde SA couleur (esplanades, mirantes, terre du morro) et gagne juste de la matière. Un nouveau `class_name` n'est vu par les outils CLI qu'après `godot --headless --editor --quit --path .` (cache de classes). Les 12 districts joués sont habillés ; `AterroFlamengo.tscn` n'est référencé nulle part (scène morte, non taguée)
- **Tester** : `./run_tests.sh` (~3100 assertions, headless via `IntegrationTest.tscn` + `PlaythroughDriver.tscn`) ou ouvrir Godot
- **Skip d'acte (debug build)** : `Ctrl+F1..F4` (`scripts/debug/DebugConsole.gd`) → reset / skip vers acte 2/3/4 avec pivots auto-complétés ; `Ctrl+Shift+F4` voie Tráfico, `Ctrl+Alt+F4` voie Prefeito

## Export
`export_presets.cfg` configure l'export iOS (voir `export_ios.zip` / dossier `export_ios/`).
