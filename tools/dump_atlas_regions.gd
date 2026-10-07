extends SceneTree

# Outil dev : extrait des régions d'un atlas en PNG agrandis (pour juger une
# tuile sans ouvrir l'éditeur). Chaque région est répétée 3×2 pour voir la couture.
# Usage : godot --headless --path . --script tools/dump_atlas_regions.gd -- <res_png> <out_prefix> "x:y:w:h,..." [scale]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("args: <res_png> <out_prefix> <x:y:w:h,...> [scale]")
		quit(2)
		return
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if img == null:
		push_error("image introuvable : " + args[0])
		quit(2)
		return
	var scale: int = int(args[3]) if args.size() > 3 else 3
	var idx: int = 0
	for spec in args[2].split(","):
		var p: PackedStringArray = spec.split(":")
		var r: Rect2i = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
		var tile: Image = img.get_region(r)
		var out: Image = Image.create(r.size.x * 3, r.size.y * 2, false, Image.FORMAT_RGBA8)
		for i in 3:
			for j in 2:
				out.blit_rect(tile, Rect2i(Vector2i.ZERO, r.size), Vector2i(i * r.size.x, j * r.size.y))
		out.resize(out.get_width() * scale, out.get_height() * scale, Image.INTERPOLATE_NEAREST)
		out.save_png("%s_%d.png" % [args[1], idx])
		print("saved %s_%d.png %s" % [args[1], idx, r])
		idx += 1
	quit(0)
