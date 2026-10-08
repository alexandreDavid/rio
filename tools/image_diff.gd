extends SceneTree

# Outil dev : écart moyen entre deux PNG (0 = identiques, 100 = opposés).
# Usage : godot --headless --path . -s tools/image_diff.gd -- a.png b.png [seuil_pct]
# Code de sortie 1 si l'écart dépasse le seuil (défaut 2 %).

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: a.png b.png [seuil]")
		quit(2)
		return
	var a: Image = Image.load_from_file(args[0])
	var b: Image = Image.load_from_file(args[1])
	if a == null or b == null:
		push_error("image illisible")
		quit(2)
		return
	if a.get_size() != b.get_size():
		print("DIFF %s : tailles différentes %s vs %s" % [args[1].get_file(), a.get_size(), b.get_size()])
		quit(1)
		return
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var total: float = 0.0
	var step: int = 2  # un pixel sur deux suffit
	var n: int = 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 3
	var pct: float = 100.0 * total / float(n)
	var threshold: float = float(args[2]) if args.size() >= 3 else 2.0
	print("%s : écart %.2f %% (seuil %.1f)" % [args[1].get_file(), pct, threshold])
	quit(1 if pct > threshold else 0)
