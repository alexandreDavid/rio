#!/usr/bin/env bash
# Lance les tests d'intégration en mode headless.
# Usage: ./run_tests.sh
# Exit code 0 si tout passe, 1 sinon.

set -e

cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot_v4.6.2.app/Contents/MacOS/Godot" \
		"/Applications/Godot_v4.5-stable.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot 2.app/Contents/MacOS/Godot" \
		"$(command -v godot || true)"; do
		if [[ -x "$candidate" ]]; then
			GODOT_BIN="$candidate"
			break
		fi
	done
fi

if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
	echo "Godot introuvable. Définis GODOT_BIN, ex:"
	echo "  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./run_tests.sh"
	exit 2
fi

echo "Godot: $GODOT_BIN"
echo "Lancement des tests d'intégration…"
echo ""

# Les drivers instancient Main : SaveSystem autosauve dans le slot courant.
# On met les vraies sauvegardes à l'abri le temps des tests et on les remet
# (y compris sur Ctrl-C). Sans ça, un run de tests écrase la partie du joueur.
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore_saves() {
	rm -f "$SAVEDIR"/savegame_slot[123].json
	cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true
	rm -rf "$STASH"
}
trap restore_saves EXIT
cp -p "$SAVEDIR"/savegame_slot[123].json "$SAVEDIR"/ng_plus.json "$SAVEDIR"/settings.cfg "$STASH"/ 2>/dev/null || true
rm -f "$SAVEDIR"/savegame_slot[123].json

# Suite d'intégration (assertions abstraites) + pilotes « réels » qui chargent la
# vraie scène Main et simulent les interactions joueur (flux acte 1→3, paiement,
# patrons, et contrat complet par voie) + audit d'accessibilité géométrique (le
# joueur peut-il physiquement atteindre chaque interactif ?). Chaque scène quitte
# avec un code != 0 en cas d'échec ; on agrège.
rc=0
for scene in \
	"scenes/tests/IntegrationTest.tscn" \
	"scenes/tests/PlaythroughDriver.tscn" \
	"scenes/tests/VoieDriver.tscn" \
	"tools/ReachabilityAudit.tscn"; do
	echo ""
	echo "=== $scene ==="
	"$GODOT_BIN" --headless --path . "$scene" || rc=1
done
exit $rc
