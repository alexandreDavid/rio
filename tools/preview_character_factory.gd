extends SceneTree

# Génère un montage PNG du rendu CharacterSpriteFactory pour inspection visuelle.
# Lancer : GODOT_BIN --headless --path . --script tools/preview_character_factory.gd
# Sortie : tools/character_preview.png

const Factory = preload("res://scripts/world/CharacterSpriteFactory.gd")
const ZOOM: int = 4
const PAD: int = 8

func _init() -> void:
	var cw: int = Factory.CELL_W
	var ch: int = Factory.CELL_H
	var bg: Color = Color(0.16, 0.17, 0.20, 1.0)

	# Rangée 1 : un panel de personnages (cellule DOWN/idle) variés.
	var showcase: Array = [
		Factory.config_from_indices(Factory.default_indices()),
		Factory.config_for_npc("tito"),
		Factory.config_for_npc("ramos"),
		Factory.config_for_npc("contessa"),
		Factory.config_for_npc("padeiro"),
		Factory.config_for_npc("vovo"),
		Factory.config_for_npc("padre"),
		Factory.random_config(7),
	]
	# Rangée 2 : le perso par défaut sous ses 3 directions × 3 frames.
	var def_cfg: Dictionary = Factory.config_from_indices(Factory.default_indices())

	var cell_w: int = cw * ZOOM
	var cell_h: int = ch * ZOOM
	var row1_w: int = showcase.size() * (cell_w + PAD) + PAD
	var row2_w: int = 9 * (cell_w + PAD) + PAD
	var total_w: int = maxi(row1_w, row2_w)
	var total_h: int = PAD + cell_h + PAD + cell_h + PAD

	var out: Image = Image.create(total_w, total_h, false, Image.FORMAT_RGBA8)
	out.fill(bg)

	var x: int = PAD
	for cfg in showcase:
		var sheet: ImageTexture = Factory.build_sheet(cfg)
		_blit_cell(out, sheet.get_image(), 0, 0, cw, ch, x, PAD)
		x += cell_w + PAD

	# Rangée 2 : 3 directions (lignes 0=DOWN,1=UP,2=RIGHT) × 3 frames.
	var sheet2: Image = Factory.build_sheet(def_cfg).get_image()
	x = PAD
	var y2: int = PAD + cell_h + PAD
	for dir in 3:
		for frame in 3:
			_blit_cell(out, sheet2, frame * cw, dir * ch, cw, ch, x, y2)
			x += cell_w + PAD

	var path: String = "res://tools/character_preview.png"
	var err: int = out.save_png(path)
	if err == OK:
		print("[preview] écrit : ", ProjectSettings.globalize_path(path),
			" (", total_w, "x", total_h, ")")
	else:
		printerr("[preview] échec save_png : ", err)
	quit()

# Copie la cellule (sx,sy,cw,ch) de `src`, agrandie ×ZOOM en plus proche
# voisin, sur `dst` à (dx,dy).
func _blit_cell(dst: Image, src: Image, sx: int, sy: int, cw: int, ch: int, dx: int, dy: int) -> void:
	var cell: Image = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	cell.blit_rect(src, Rect2i(sx, sy, cw, ch), Vector2i.ZERO)
	# BILINEAR : reproduit le filtrage LINEAR utilisé en jeu (rendu lissé).
	cell.resize(cw * ZOOM, ch * ZOOM, Image.INTERPOLATE_BILINEAR)
	dst.blit_rect(cell, Rect2i(0, 0, cw * ZOOM, ch * ZOOM), Vector2i(dx, dy))
