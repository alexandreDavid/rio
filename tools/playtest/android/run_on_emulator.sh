#!/usr/bin/env bash
# Joue le jeu sur un émulateur Android déjà démarré, sans Java ni Gradle :
# export du projet → injection dans le gabarit APK de Godot → signature v2
# maison (make_apk.py) → installation → lancement.
#   tools/playtest/android/run_on_emulator.sh            # jeu normal (tests tactiles à la main)
#   tools/playtest/android/run_on_emulator.sh bot [budget_s=21600] [voie] [accélération=4]
# Le bot écrit user://playtest.json ; le récupérer avec :
#   adb exec-out run-as com.godot.game cat files/playtest.json > run.json
# NB : le simulateur iOS (iOS 27) refuse le binaire — Godot 4.6 ne fournit que
# la tranche x86_64 pour simulateur ; il faudrait compiler un gabarit arm64.
set -euo pipefail
cd "$(dirname "$0")/../../.."
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
BT="${ANDROID_BUILD_TOOLS:-$HOME/Library/Android/sdk/build-tools/36.0.0}"
TPL="$HOME/Library/Application Support/Godot/export_templates/4.6.2.stable/android_debug.apk"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$GODOT_BIN" --headless --path . --export-pack "iOS" "$W/project.zip" >/dev/null 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$W/key.pem" -out "$W/cert.pem" -days 30 -subj "/CN=Rio Dev Test" 2>/dev/null
openssl x509 -in "$W/cert.pem" -outform DER -out "$W/cert.der"
args=()
if [ "${1:-}" = "bot" ]; then
	printf '[application]\n\nrun/main_scene="res://tools/playtest/PlaytestBot.tscn"\n' > "$W/override.cfg"
	args=("+override.cfg=$W/override.cfg" "--" "${2:-21600}" "user://playtest.json" "${3:-policia}" "${4:-4}")
fi
python3 -I tools/playtest/android/make_apk.py "$TPL" "$W/project.zip" "$W/unsigned.apk" ${args[@]+"${args[@]}"}
"$BT/zipalign" -f -P 16 4 "$W/unsigned.apk" "$W/aligned.apk"
python3 -I tools/playtest/android/make_apk.py --sign "$W/aligned.apk" "$W/rio.apk" "$W/key.pem" "$W/cert.der"
"$ADB" uninstall com.godot.game >/dev/null 2>&1 || true
"$ADB" install "$W/rio.apk"
"$ADB" logcat -c
"$ADB" shell monkey -p com.godot.game -c android.intent.category.LAUNCHER 1 >/dev/null
echo "lancé — suivre avec : $ADB logcat | grep ' godot '"
