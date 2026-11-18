#!/usr/bin/env bash
# Vérifie le jeu TEL QU'EXPORTÉ pour iOS, sur Mac : exporte le paquet, le lance
# avec le moteur de rendu du téléphone (gl_compatibility) et
#   1. compare la position de chaque élément d'interface avec un lancement
#      depuis l'éditeur (un écart = un élément décalé sur l'appareil) ;
#   2. passe l'audit tactile au format iPhone 17 (captures dans <out_dir>).
#   tools/export_check.sh <out_dir>
# À lancer avant chaque build iOS : un lancement depuis l'éditeur ne voit pas
# les défauts propres à l'export. Sauvegardes du joueur mises à l'abri.
set -u
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/rio_export_check}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
SAVEDIR="$HOME/Library/Application Support/Godot/app_userdata/Rio — Copacabana"
STASH="$(mktemp -d)"
restore() { for i in 1 2 3; do rm -f "$SAVEDIR/savegame_slot$i.json"; done; cp -p "$STASH"/* "$SAVEDIR"/ 2>/dev/null || true; rm -rf "$STASH"; }
trap restore EXIT
for i in 1 2 3; do cp -p "$SAVEDIR/savegame_slot$i.json" "$STASH"/ 2>/dev/null || true; rm -f "$SAVEDIR/savegame_slot$i.json"; done
cp -p "$SAVEDIR/settings.cfg" "$STASH"/ 2>/dev/null || true
"$GODOT_BIN" --headless --path . --export-pack "iOS" "$OUT/Rio.pck" 2>&1 | grep -E "^ERROR|SCRIPT ERROR" | head -5
export RIO_SAFE_INSETS=167,0,167,54
# Deux instances de Godot enchaînées sans pause : la seconde se ferme parfois
# toute seule au démarrage (constaté le 2026-11-18). On laisse la première finir.
sleep 3
"$GODOT_BIN" --path . --rendering-method gl_compatibility --resolution 1311x603 tools/UiTouchAudit.tscn -- "$OUT/editeur" > "$OUT/editeur.log" 2>&1
sleep 3
(cd "$OUT" && "$GODOT_BIN" --main-pack "$OUT/Rio.pck" --rendering-method gl_compatibility --resolution 1311x603 res://tools/UiTouchAudit.tscn -- "$OUT/ecran" > "$OUT/export.log" 2>&1)
grep "^LAYOUT" "$OUT/editeur.log" | sort > "$OUT/layout_editeur.txt"
grep "^LAYOUT" "$OUT/export.log" | sort > "$OUT/layout_export.txt"
[ -s "$OUT/layout_editeur.txt" ] && [ -s "$OUT/layout_export.txt" ] || echo "!! une des deux mesures est vide : relancer"
echo "== ÉLÉMENTS DÉCALÉS À L'EXPORT : $(diff "$OUT/layout_editeur.txt" "$OUT/layout_export.txt" | grep -c '^>') sur $(wc -l < "$OUT/layout_export.txt" | tr -d ' ') (éditeur < / export >)"
diff "$OUT/layout_editeur.txt" "$OUT/layout_export.txt" | grep "^[<>]" | sort -t'|' -k1,1 -s
grep -E "^   |^== AUDIT|SCRIPT ERROR" "$OUT/export.log"
