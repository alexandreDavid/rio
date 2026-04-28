# Rio — Copacabana (Godot 4.6)

Vertical slice d'un jeu 2D top-down situé sur la plage de Copacabana à Rio. Quête principale autour du milho (maïs grillé), mini-jeu de beach-volley, système de réputation multi-axes, dialogues via Ink.

Langue de travail : **français** (code, commentaires, dialogues, UI).

## Stack
- Godot **4.6** Forward+ (`project.godot` line `config/features`)
- Scripts GDScript statiquement typés — préférer `Node2D` explicite aux `Variant` non typés
- Dialogues : Ink (dossier `ink/`), chargés par `scripts/quests/InkStoryLoader.gd`

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
Constantes clés : `BUILDING_Y=-32`, `SECOND_ROW_Y=-160`, `POSTO_Y=168`, `PALACE_X=1700`, `POLICE_X=1200`, `ACADEMIA_X=700`, `COP_BAR_X=1380`.

Limite de la zone jouable : `map_start_x=160`, `map_end_x=2200`, `total_w=2400` pour les strips de tiles.

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

Régions utilisées (`scripts/world/CopacabanaGenerator.gd:65+`) :
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

## Workflows fréquents
- **Ajouter un NPC** : copier `scenes/npcs/NPC.tscn` → adapter script + dialogue Ink → instancier dans `Copacabana.tscn` avec `position`
- **Ajouter une quête** : créer un `.tres` dans `resources/quests/` → référencer l'ID Ink → enregistrer dans `QuestManager` (cherche par pattern les autres quêtes)
- **Ajouter une tuile / régler le tileset** : utiliser l'agent `tileset-atlas` (cf `.claude/agents/`)
- **Tester** : ouvrir le projet dans Godot ou lancer `godot --path . scenes/main/Main.tscn` ; le `SelfCheck` autoload vérifie des invariants au démarrage

## Export
`export_presets.cfg` configure l'export iOS (voir `export_ios.zip` / dossier `export_ios/`).
