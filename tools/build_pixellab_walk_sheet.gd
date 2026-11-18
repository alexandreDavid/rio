extends SceneTree

# Assemble la planche de marche 3×3 d'un NPC (format NPC.gd : lignes bas / haut /
# droite, colonnes arrêt / pas gauche / pas droit) à partir des frames PixelLab
# rangées dans assets/sprites/npcs/src_pixellab/<id>/<direction>_<frame>.png.
# Lancer : GODOT_BIN --headless --path . --script tools/build_pixellab_walk_sheet.gd -- <id>
# Sortie : assets/sprites/npcs/<id>_walk.png (puis réimporter : --headless --import)

const SRC_DIR: String = "res://assets/sprites/npcs/src_pixellab/"
const OUT_DIR: String = "res://assets/sprites/npcs/"
const ROWS: Array[String] = ["south", "north", "east"]
# Frames du cycle « walking-4-frames » : 0 = debout, 1 et 3 = les deux pas.
const COLS: Array[int] = [0, 1, 3]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage : -- <npc_id>")
		quit(1)
		return
	var id: String = args[0]
	var src: String = ProjectSettings.globalize_path(SRC_DIR + id + "/")
	var frames: Array = []
	var cell: Vector2i = Vector2i.ZERO
	for dir in ROWS:
		var row: Array[Image] = []
		for f in COLS:
			var img: Image = Image.load_from_file("%s%s_%d.png" % [src, dir, f])
			if img == null:
				printerr("frame manquante : %s_%d.png" % [dir, f])
				quit(1)
				return
			img.convert(Image.FORMAT_RGBA8)
			cell = img.get_size()
			row.append(img)
		frames.append(row)
	var out: Image = Image.create(cell.x * COLS.size(), cell.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for r in ROWS.size():
		# Un seul décalage par direction : les pieds touchent le bas de la cellule
		# (comme les persos de CharacterSpriteFactory) sans effacer le rebond du pas.
		var lowest: int = 0
		for img in frames[r]:
			var used: Rect2i = (img as Image).get_used_rect()
			lowest = maxi(lowest, used.position.y + used.size.y)
		var dy: int = cell.y - lowest
		for c in COLS.size():
			out.blit_rect(frames[r][c], Rect2i(Vector2i.ZERO, cell), Vector2i(c * cell.x, r * cell.y + dy))
			if dy > 0:
				_close_top_outline(out, frames[r][c], Vector2i(c * cell.x, r * cell.y + dy))
	var path: String = OUT_DIR + id + "_walk.png"
	var err: int = out.save_png(path)
	print("[walk_sheet] ", path, " ", out.get_size(), " err=", err)
	quit()

# PixelLab coupe le contour quand la tête touche le haut de sa cellule : on
# referme le trait au-dessus de chaque pixel clair de la rangée 0, dans la
# teinte la plus sombre de la frame.
func _close_top_outline(out: Image, frame: Image, at: Vector2i) -> void:
	var line: Color = Color(0, 0, 0, 1)
	var darkest: float = 10.0
	for y in frame.get_height():
		for x in frame.get_width():
			var px: Color = frame.get_pixel(x, y)
			if px.a > 0.5 and px.get_luminance() < darkest:
				darkest = px.get_luminance()
				line = px
	for x in frame.get_width():
		var top: Color = frame.get_pixel(x, 0)
		if top.a > 0.5 and top.get_luminance() > darkest + 0.12:
			out.set_pixel(at.x + x, at.y - 1, line)
