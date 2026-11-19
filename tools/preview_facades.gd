extends SceneTree

# Planche de façades du morro (FacadePainter, style favela), agrandie ×6, pour
# juger le peintre sans lancer le jeu.
# Lancer : GODOT_BIN --headless --path . --script tools/preview_facades.gd -- <sortie.png>

const SIZES: Array = [Vector2(60, 40), Vector2(100, 90), Vector2(120, 100), Vector2(130, 120), Vector2(180, 140), Vector2(180, 120)]
const COLORS: Array = [
	Color(0.88, 0.35, 0.32), Color(0.95, 0.75, 0.28), Color(0.32, 0.65, 0.85), Color(0.85, 0.55, 0.35),
	Color(0.88, 0.45, 0.62), Color(0.55, 0.75, 0.45), Color(0.78, 0.65, 0.45), Color(0.92, 0.9, 0.85),
]
const ZOOM: int = 6

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://facades.png"
	var style: String = args[1] if args.size() > 1 else "favela"
	var cells: Array = []
	var k: int = 0
	for row in 3:
		for s in SIZES:
			var img: Image = FacadePainter.build_image(s, COLORS[k % COLORS.size()],
				{"style": style, "seed": 17 + k * 131, "door_left": k % 2 == 0})
			cells.append(img)
			k += 1
	var cols: int = SIZES.size()
	var cw: int = 64
	var ch: int = 54
	var sheet: Image = Image.create(cols * cw, 3 * ch, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.55, 0.42, 0.32, 1))
	for i in cells.size():
		var img: Image = cells[i]
		var ox: int = (i % cols) * cw + int((cw - img.get_width()) / 2)
		var oy: int = int(i / cols) * ch + ch - 2 - img.get_height()
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(ox, oy))
	sheet.resize(sheet.get_width() * ZOOM, sheet.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	print("[facades] ", out_path, " err=", sheet.save_png(out_path))
	quit()
