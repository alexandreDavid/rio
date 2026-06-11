# Rio — Copacabana (Godot 4.6)

Vertical slice d'un jeu 2D top-down situé sur la plage de Copacabana à Rio. Quête principale autour du milho (maïs grillé), mini-jeux (volley, padaria, valet, surf…), système de réputation multi-axes, dialogues à choix structurés.

Langue de travail : **français** (code, commentaires, dialogues, UI).

## Stack
- Godot **4.6** Forward+ (`project.godot` line `config/features`)
- Scripts GDScript statiquement typés — préférer `Node2D` explicite aux `Variant` non typés
- Dialogues : knots structurés (dicts `const KNOTS`) dans `scripts/dialogues/Act1..4Dialogues.gd` + `Side{Plage,Services,Baia}Dialogues.gd` (SIDE re-splités par domaine), fusionnés au runtime par `DialogueBridge._merge_external_dialogues()`. `DialogueBridge` expose un contrat de signaux (`line_shown` / `choices_presented` / `dialogue_finished`) indépendant du moteur : `InkStoryLoader.gd` reste branché comme backend interchangeable, mais **le plugin inkgd n'est pas installé** et `ink/milho.ink` est un vestige non chargé — tout le contenu réel vit dans les dicts ci-dessus

## Autoloads (singletons)
Ordre important dans `project.godot` — ne pas changer sans raison :
- **EventBus** (`scripts/core/EventBus.gd`) — bus global de signaux. Les systèmes ne se référencent jamais directement, ils émettent/écoutent ici.
- **GameManager**, **ReputationSystem**, **TimeOfDay**, **QuestManager**, **DialogueBridge**, **SaveSystem**, **AudioManager**, **SelfCheck**, **BuildingManager**

## Layout de la map (`scripts/world/CopacabanaGenerator.gd`)
Map horizontale orientée ouest→est. **LEME à l'est (x haut), FORTE à l'ouest (x bas).** 5 postes : Posto 5 côté forte, Posto 1 côté Leme.

Zones par bande Y (du nord au sud) :
```
y < -200         Favelas (Morro à l'ouest, Leme à l'est)
y = -192..-128   2ème rangée d'immeubles + police + bar flic + academia
y = -128..-64    Nossa Senhora de Copacabana (route intérieure)
y = -64..0       1ère rangée d'immeubles + palace + commerces
y = 0..64        Av. Atlântica (route front de mer)
y = 64..128      Calçadão (motif vague noir/blanc)
y = 128..400     Sable
y = 400..600     Mer
```
Constantes clés (dans `scripts/world/CopacabanaConfig.gd`, préchargé `Cfg` par le générateur) : `BUILDING_Y=-32`, `SECOND_ROW_Y=-160`, `POSTO_Y=168`, `PALACE_X=1700`, `POLICE_X=1200`, `ACADEMIA_X=700`, `COP_BAR_X=1380`.

Limite de la zone jouable (bâtiments NPC) : `map_start_x=160`, `map_end_x=2200`. Les strips de tiles (sable, calçadão, route, mer) couvrent toute la map décorée : `Cfg.MAP_LEFT=-300` → `Cfg.MAP_RIGHT=3200`, soit `Cfg.MAP_TOTAL_W=3500` (inclut Forte à l'ouest et Leme à l'est).

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
- `y=660..920`  — décors (palmiers, parasols, serviette, bar ambulant)

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

Helper : `_spawn_tile_strip(name, y_top, y_bot, region, z_idx=-5)` pour remplir une bande rectangulaire. `_spawn_prop_sprite(parent, region, pos, target_h)` pour un décor ponctuel (ancrage par la base).

## NPCs & quêtes
- 1 scène `.tscn` par NPC dans `scenes/npcs/` — la scène de base `NPC.tscn` définit le comportement commun
- Quêtes = ressources `.tres` dans `resources/quests/` (schéma `Quest.gd` + `QuestObjective.gd`)
- Dialogues en Ink dans `ink/`, chargés par `DialogueBridge` qui relie au NPC via un `npc_id`
- Instancier un NPC dans `scenes/world/Copacabana.tscn` avec `ExtResource` + `position`

## Intérieurs
Instanciés **une seule fois** loin du monde joué (x=~900..3000, y=-3000) via `_spawn_interiors()`. On y téléporte le joueur via les portes (`BuildingDoor.tscn`) qui portent un `destination: Vector2` et un `prompt_text`. Les positions cibles sont les `SpawnPoint` dans chaque intérieur.

## Conventions
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

Si un knot tente `accept_quest` sur une quête bloquée, `DialogueBridge._show_locked_message` affiche "Pas encore le bon moment — d'abord : <prereqs>". Le `QuestLog` sépare HISTÓRIA (✦ doré) et ATIVIDADES (• bleu).

## Workflows fréquents
- **Ajouter un NPC** : copier `scenes/npcs/NPC.tscn` → adapter script + ajouter les knots dans le bon `scripts/dialogues/*Dialogues.gd` → instancier dans `Copacabana.tscn` avec `position`
- **Ajouter une quête** : créer un `.tres` dans `resources/quests/` → ajouter les knots d'offre/rappel/fin dans `scripts/dialogues/*Dialogues.gd` (l'`ink_knot` de la quête y pointe) → enregistrer dans `MainBoot.QUEST_RESOURCES` ; tagger `quest_type = 1` si MAIN et lister `prerequisite_quest_ids` ; vérifier avec `tools/check_quest_gating.gd`
- **Ajouter un knot de dialogue** : éditer le fichier d'acte/domaine concerné (`Act1..4Dialogues.gd` / `Side{Plage,Services,Baia}Dialogues.gd`) — `const KNOTS` ; key = `ink_knot`, value = `{speaker, text, choices, on_choose?}`. La résolution runtime est par clé globale, le fichier choisi n'a pas d'incidence fonctionnelle (juste l'organisation)
- **Ajouter une tuile / régler le tileset** : utiliser l'agent `tileset-atlas` (cf `.claude/agents/`)
- **Tester** : `./run_tests.sh` (~3100 assertions, headless via `IntegrationTest.tscn` + `PlaythroughDriver.tscn`) ou ouvrir Godot
- **Skip d'acte (debug build)** : `Ctrl+F1..F4` (`scripts/debug/DebugConsole.gd`) → reset / skip vers acte 2/3/4 avec pivots auto-complétés ; `Ctrl+Shift+F4` voie Tráfico, `Ctrl+Alt+F4` voie Prefeito

## Export
`export_presets.cfg` configure l'export iOS (voir `export_ios.zip` / dossier `export_ios/`).
