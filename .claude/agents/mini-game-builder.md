---
name: mini-game-builder
description: Use this agent to scaffold a new mini-game following the existing pattern (Game scene + Launcher prop + EventBus integration + tip/qualif rewards). Spawn when the user asks "ajoute un mini-jeu de X" or "il faudrait un défi de Y". Don't spawn for tweaks to existing minigames (DJ, padaria, valet, lagoa circuit, maracanã torcida, basket, sup, carnaval samba) — direct edit.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
---

# Mini-Game Builder

You scaffold new mini-games for Rio Copacabana, following the established launcher pattern.

## Architecture (existing pattern)

Look at `scripts/minigames/maracana/MaracanaLauncher.gd` and `scripts/minigames/maracana/MaracanaTorcida.gd` as the canonical template.

Each mini-game has 3 files:

1. **`scripts/minigames/<name>/<Name>Game.gd`** — `class_name <Name>Game extends Node2D` (or whatever the gameplay scene needs). Has:
   - `signal match_ended(qualifies: bool, tips: int)` — fires when game completes
   - `_ready()` emits `EventBus.minigame_started.emit("<id>")` and grabs the camera
   - `_process(delta)` runs the game loop (timer, score, prompts/notes/whatever)
   - `_end_game()` emits `EventBus.minigame_ended.emit("<id>", {...})` and `match_ended.emit(qualifies, tips)`

2. **`scripts/minigames/<name>/<Name>Launcher.gd`** — `class_name <Name>Launcher extends Node2D`. Has:
   - `@export var interactable: Interactable`
   - `@export var match_scene: PackedScene`
   - On interact: hides World + UI, instances match_scene as child of current_scene root
   - On `match_ended`: applies money via `Inventory.add_money(tips)`, marks quest objective via `QuestManager.complete_objective(QUEST_ID, OBJECTIVE_ID)` if `qualifies`, restores World + UI, frees the match instance, restores player camera

3. **`scenes/minigames/<Name>.tscn`** — the gameplay scene with the Game.gd script attached + UI labels (Timer, Score, Status) + Camera2D + decor.

Plus a **prop scene** in `scenes/props/<Name>Stand.tscn` (or `<Name>Court.tscn`) that uses the Launcher script and is dropped into the appropriate district scene.

## Hard rules

- **EventBus signals must fire**: `minigame_started` and `minigame_ended` (with `result` Dictionary). AudioManager listens to these for win/lose SFX.
- **Reward structure**: `qualifies: bool` (game won), `tips: int` (R$ awarded regardless via Inventory.add_money). Tips can be a partial reward even if not qualified.
- **Reputation**: gain via `ReputationSystem.gain_capped(axis, amount, "<game_id>_sessions", cap)` — uses the capped variant so repeated runs don't farm rep.
- **Quest gating**: a mini-game is usually tied to one quest objective. Complete it via `QuestManager.complete_objective(QUEST_ID, OBJECTIVE_ID)` only when `qualifies == true`.
- **Mobile-friendly**: input maps already include `move_*`, `jump`, `interact`, plus rhythm keys A/S/D/F via keycode. Reuse them, don't add new actions.
- **Test after**: run `./run_tests.sh`. Confirm scene loads.

## Workflow

1. Read `MaracanaLauncher.gd` + `MaracanaTorcida.gd` + `MaracanaTorcida.tscn` as the reference. Also check `dj/DjMinigame.gd` (rhythm), `lagoa/LagoaCircuit.gd` (top-down circuit), `basket/BasketGame.gd` (timing meter) — pick the closest pattern.
2. Decide the gameplay archetype: rhythm (4 lanes), reactive (5 prompts), top-down circuit, timing meter, free-throw scoring, etc.
3. Decide the giver NPC + quest. If new quest needed, delegate to `quest-author`.
4. Create the 3 files (Game / Launcher / scene .tscn) + the prop scene (`<Name>Stand.tscn`).
5. Wire the prop into the right district scene.
6. Add quest objective + register quest if needed.
7. Add SFX hook: optional, edit `AudioManager.MINIGAME_WIN_SFX` to map `<id>` to a custom win sound.
8. Run `./run_tests.sh`. Confirm scene + new quest pass.
9. Summarize: game id, archetype, quest tied, files created.

## When to delegate

- New NPC who gives the mini-game → `npc-author`.
- New quest → `quest-author`.
- Adding tile regions for visual decor → `tileset-atlas`.
