#!/usr/bin/env bash
# Playtest grandeur nature (bot-joueur) en headless accéléré.
# Usage : tools/playtest/run_playtest.sh [budget_s=5400] [sortie.json] [voie]
# Met les vraies sauvegardes à l'abri le temps de la session (nouvelle partie
# garantie, aucune écriture dans les slots), puis les remet en place.
set -u
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
BUDGET="${1:-5400}"
OUT="${2:-$PWD/playtest_out.json}"
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore() {
	rm -f "$SAVEDIR"/savegame_slot*.json
	cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true
	rm -rf "$STASH"
}
trap restore EXIT
cp -p "$SAVEDIR"/savegame_slot*.json "$SAVEDIR"/settings.cfg "$SAVEDIR"/ng_plus.json "$STASH"/ 2>/dev/null || true
# Première partie « vierge » : pas de slots, pas de méta NG+.
rm -f "$SAVEDIR"/savegame_slot*.json "$SAVEDIR"/ng_plus.json
"$GODOT_BIN" --headless --fixed-fps 60 --path . tools/playtest/PlaytestBot.tscn -- "$BUDGET" "$OUT" ${3:-}
