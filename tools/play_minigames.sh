#!/usr/bin/env bash
# Salle d'arcade des mini-jeux (hors partie) : tools/play_minigames.sh
# Les mini-jeux émettent minigame_ended (réputation, flags…) : les sauvegardes
# sont mises à l'abri le temps de jouer, puis restaurées.
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
cp -p "$SAVEDIR"/savegame_slot[123].json "$SAVEDIR"/settings.cfg "$STASH"/ 2>/dev/null || true
restore() { rm -f "$SAVEDIR"/savegame_slot[123].json; cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true; rm -rf "$STASH"; }
trap restore EXIT
"$GODOT_BIN" --path . --resolution 1560x720 tools/MinigamePicker.tscn
