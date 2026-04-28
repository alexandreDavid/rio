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

"$GODOT_BIN" --headless --path . scenes/tests/IntegrationTest.tscn
