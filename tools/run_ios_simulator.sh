#!/usr/bin/env bash
# Lance le jeu dans le simulateur iOS (iPhone 17) : le vrai rendu iOS sans
# passer par le téléphone — pas de police emoji système, encoche, zone sûre.
#   tools/run_ios_simulator.sh [--no-export] [nom ou UDID du simulateur]
#
# Godot ne fournit pas de bibliothèque pour simulateur arm64 (seulement
# x86_64, que les simulateurs récents refusent). Il faut la compiler une fois :
#   cd ~/dev/godot-src/godot-<version>-stable
#   ../venv/bin/scons platform=ios target=template_debug arch=arm64 ios_simulator=yes
# (sources : github.com/godotengine/godot/releases, même version que l'éditeur ;
#  SCons : python3 -m venv ../venv && ../venv/bin/pip install scons — 2 min de build.)
# Chemin de la bibliothèque : RIO_SIM_LIB.
set -euo pipefail
cd "$(dirname "$0")/.."
EXPORT=1
DEVICE="iPhone 17"
for arg in "$@"; do
	case "$arg" in
		--no-export) EXPORT=0 ;;
		*) DEVICE="$arg" ;;
	esac
done
LIB="${RIO_SIM_LIB:-$(ls "$HOME"/dev/godot-src/godot-*-stable/bin/libgodot.ios.template_debug.arm64.simulator.a 2>/dev/null | tail -1)}"
if [[ -z "$LIB" || ! -f "$LIB" ]]; then
	echo "❌ Bibliothèque Godot pour simulateur arm64 introuvable (voir l'en-tête de ce script)."
	exit 2
fi
if [[ "$EXPORT" == "1" || ! -d export_ios/Rio.xcodeproj ]]; then
	./build_ios.sh --no-open
fi
# Le projet exporté ne contient que la tranche x86_64 du simulateur : on y met l'arm64.
cp "$LIB" export_ios/Rio.xcframework/ios-arm64_x86_64-simulator/libgodot.a
DD="${RIO_SIM_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/RioSim}"
xcodebuild -project export_ios/Rio.xcodeproj -scheme Rio -configuration Debug \
	-sdk iphonesimulator -destination "platform=iOS Simulator,name=$DEVICE" \
	-derivedDataPath "$DD" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build \
	| grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
APP="$DD/Build/Products/Debug-iphonesimulator/Rio.app"
[[ -d "$APP" ]] || { echo "❌ Build simulateur échoué."; exit 3; }
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" >/dev/null
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.iansa.rio
echo "✅ Jeu lancé dans le simulateur « $DEVICE ». Capture : xcrun simctl io \"$DEVICE\" screenshot out.png"
echo "⚠️  export_ios/ contient maintenant la bibliothèque du simulateur : relancer ./build_ios.sh avant un build pour le téléphone n'est PAS nécessaire (tranche séparée), mais l'export suivant la remplacera."
