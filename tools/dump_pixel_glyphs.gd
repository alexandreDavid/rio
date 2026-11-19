extends SceneTree
# Exporte les glyphes de PixelFont (cellules de 11 rangées) en JSON, pour
# tools/build_pixel_ttf.py :
#   godot --headless --path . -s tools/dump_pixel_glyphs.gd -- <out.json>
func _init() -> void:
	var out: Dictionary = {}
	for ch in PixelFont._all_chars():
		out[ch] = {"rows": PixelFont._rows(ch), "advance": PixelFont._advance(ch, false)}
	# Emojis décoratifs sans dessin : glyphe vide de largeur nulle.
	for ch in PixelIcons.SILENT:
		if not out.has(ch):
			out[ch] = {"rows": [], "advance": 0}
	var f: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
