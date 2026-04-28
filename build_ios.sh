#!/usr/bin/env bash
# Rebuild iOS complet et propre. Purge tous les caches Godot + Xcode,
# ré-exporte le projet, puis ouvre Xcode.
#
# Usage :
#   ./build_ios.sh              # rebuild + ouvre Xcode
#   ./build_ios.sh --test       # lance les tests d'intégration d'abord
#   ./build_ios.sh --no-open    # rebuild sans ouvrir Xcode

set -e

cd "$(dirname "$0")"

RUN_TESTS=0
OPEN_XCODE=1
for arg in "$@"; do
	case "$arg" in
		--test) RUN_TESTS=1 ;;
		--no-open) OPEN_XCODE=0 ;;
	esac
done

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot_v4.6.2.app/Contents/MacOS/Godot" \
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
	echo "❌ Godot introuvable. Définis GODOT_BIN."
	exit 2
fi

echo "🎮 Godot: $GODOT_BIN"
echo ""

# Tests optionnels
if [[ "$RUN_TESTS" == "1" ]]; then
	echo "🧪 Tests d'intégration…"
	"$GODOT_BIN" --headless --path . scenes/tests/IntegrationTest.tscn
	echo ""
fi

# Purge des caches
echo "🧹 Purge des caches…"
rm -rf .godot/ export_ios/
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Rio"* 2>/dev/null || true
echo "   caches Godot + Xcode vidés"
echo ""

# Import ressources + export iOS
echo "📦 Import ressources (Godot)…"
"$GODOT_BIN" --headless --path . --import 2>&1 | tail -5
echo ""

echo "📱 Export iOS…"
mkdir -p export_ios
"$GODOT_BIN" --headless --path . --export-debug "iOS" export_ios/Rio.xcodeproj 2>&1 | tail -20
echo ""

# Vérification
XCODEPROJ="export_ios/Rio.xcodeproj"
if [[ ! -d "$XCODEPROJ" ]]; then
	echo "❌ Export échoué : $XCODEPROJ absent"
	exit 3
fi

echo "✅ Projet Xcode généré : $XCODEPROJ"

# Workaround : Godot 4.6 exporte TARGETED_DEVICE_FAMILY vide, iOS refuse alors
# l'install avec "unsupported family". On force "1,2" (iPhone + iPad).
PBX="$XCODEPROJ/project.pbxproj"
if grep -q 'TARGETED_DEVICE_FAMILY = "";' "$PBX"; then
	sed -i '' 's|TARGETED_DEVICE_FAMILY = "";|TARGETED_DEVICE_FAMILY = "1,2";|g' "$PBX"
	echo "🔧 TARGETED_DEVICE_FAMILY patché → 1,2 (iPhone + iPad)"
fi
echo ""

if [[ "$OPEN_XCODE" == "1" ]]; then
	echo "🛠  Ouverture dans Xcode…"
	echo ""
	echo "Étapes manuelles :"
	echo "  1. ⌘+Shift+K (Clean Build Folder)"
	echo "  2. Sélectionne ton iPhone en device"
	echo "  3. ⌘+R (build + push)"
	echo ""
	echo "Sur l'iPhone : supprime d'abord l'ancienne app (appui long → Retirer l'app)"
	echo "pour être sûr de partir propre."
	open "$XCODEPROJ"
fi
