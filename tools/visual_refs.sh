#!/usr/bin/env bash
# Captures de référence du rendu (jeu complet, HUD inclus) et comparaison.
#   tools/visual_refs.sh          → capture dans tools/visual_refs/current/ et compare à ref/
#   tools/visual_refs.sh --update → remplace les références par les captures courantes
# Nécessite une fenêtre (pas headless). Les sauvegardes sont mises à l'abri le
# temps de la capture. Un écart > 4 % sur une vue = sortie 1 (PNJ et trafic font ~2 % de bruit).
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
DIR=tools/visual_refs
VIEWS="1000:110:1,1550:40:1,-15000:-3400:1,-900:150:1,7200:-2950:1,1550:40:2"
NAMES=(copa_calcadao copa_palace favela zona_sul maison copa_palace_soir)
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore() { rm -f "$SAVEDIR"/savegame_slot[123].json; cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true; rm -rf "$STASH"; }
trap restore EXIT
cp -p "$SAVEDIR"/savegame_slot[123].json "$STASH"/ 2>/dev/null || true
rm -f "$SAVEDIR"/savegame_slot[123].json
mkdir -p "$DIR/current" "$DIR/ref"
rm -f "$DIR"/current/*.png
SHOT_WAIT_MS=4000 "$GODOT_BIN" --path . tools/ScreenshotMain.tscn -- "$DIR/current/v" "$VIEWS" 2>&1 | grep -E "saved|SCRIPT ERROR"
i=0
for n in "${NAMES[@]}"; do
	[ -f "$DIR/current/v_$i.png" ] && mv "$DIR/current/v_$i.png" "$DIR/current/$n.png"
	i=$((i+1))
done
if [ "${1:-}" = "--update" ]; then
	cp "$DIR"/current/*.png "$DIR/ref/"
	echo "références mises à jour"
	exit 0
fi
rc=0
for n in "${NAMES[@]}"; do
	if [ -f "$DIR/ref/$n.png" ]; then
		"$GODOT_BIN" --headless --path . -s tools/image_diff.gd -- "$DIR/ref/$n.png" "$DIR/current/$n.png" 4 2>&1 | grep "écart\|DIFF" || rc=1
	else
		echo "$n : pas de référence"
	fi
done
exit $rc
