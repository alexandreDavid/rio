#!/usr/bin/env bash
# Capture le jeu complet (Main + HUD) sur une partie NEUVE, les sauvegardes du
# joueur mises à l'abri pendant la capture (et remises, même sur Ctrl-C).
#   tools/capture_main.sh <out_prefix> "x:y:zoom,..." [SHOT_WAIT_MS]
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore() { rm -f "$SAVEDIR"/savegame_slot[123].json; cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true; rm -rf "$STASH"; }
trap restore EXIT
cp -p "$SAVEDIR"/savegame_slot[123].json "$SAVEDIR"/settings.cfg "$STASH"/ 2>/dev/null || true
rm -f "$SAVEDIR"/savegame_slot[123].json
SHOT_WAIT_MS="${3:-4000}" "$GODOT_BIN" --path . tools/ScreenshotMain.tscn -- "$1" "$2" 2>&1 | grep -E "saved|SCRIPT ERROR"
