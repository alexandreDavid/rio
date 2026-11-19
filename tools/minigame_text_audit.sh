#!/usr/bin/env bash
# Audit de lisibilité des mini-jeux au format iPhone 17 : textes visibles sous
# le plancher du jeu (~25 px de canevas), une capture par mini-jeu.
#   tools/minigame_text_audit.sh <out_prefix>
# Sauvegardes du joueur mises à l'abri pendant l'audit (et remises, même sur Ctrl-C).
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore() { for i in 1 2 3; do rm -f "$SAVEDIR/savegame_slot$i.json"; done; cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true; rm -rf "$STASH"; }
trap restore EXIT
for i in 1 2 3; do cp -p "$SAVEDIR/savegame_slot$i.json" "$STASH"/ 2>/dev/null || true; rm -f "$SAVEDIR/savegame_slot$i.json"; done
cp -p "$SAVEDIR/settings.cfg" "$STASH"/ 2>/dev/null || true
RIO_SAFE_INSETS=167,0,167,54 "$GODOT_BIN" --path . --resolution 1311x603 tools/MinigameTextAudit.tscn -- "${1:-/tmp/mg_text}" 2>&1 | grep -E "^-- |^   |^== AUDIT|SCRIPT ERROR|Parse Error"
