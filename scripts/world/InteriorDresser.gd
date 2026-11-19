class_name InteriorDresser
extends RefCounted

# Habille une scène d'intérieur (scenes/interiors/*.tscn, des ColorRect à
# plat) : sol peint, mur du fond avec plinthe et fenêtres, relief de chaque
# meuble (contour, arête, ombre, grain pour le bois), étiquettes en police
# pixel. Tout ce qui est ajouté est ENFANT du rect habillé : il suit sa
# visibilité (mémorial, bascules par flag) et se dessine juste au-dessus.
# Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste H).

const INTERIORS_DIR: String = "res://scenes/interiors/"
const LINE: float = 3.0            # 1 px natif
const OUTER_WALL: float = 12.0     # épaisseur du mur extérieur autour du sol
const SIDE_WALL: float = 6.0       # bande sombre intérieure gauche/droite/bas
const WINDOW_SPACING: float = 150.0
const MIN_RECT: float = 6.0

# Genre de sol par nom de scène (sous-chaîne) ; planches par défaut.
const FLOOR_KINDS: Dictionary = {
	"House": "planks", "Bar": "planks", "Arpoador": "planks", "Restaurant": "planks",
	"Penthouse": "planks", "Padaria": "tiles", "Pharmacy": "tiles", "Mercadinho": "tiles",
	"Shop": "tiles", "Academia": "tiles", "Police": "tiles", "Confeitaria": "tiles",
	"Palace": "marble", "LeParc": "marble", "MAC": "marble", "Office": "carpet",
	"Peninsula": "marble", "Church": "stone", "Museu": "stone", "Colombo": "stone",
}


# Intérieurs dont les meubles sont peints par FurniturePainter (les autres
# gardent le relief générique tant que leurs rects n'ont pas été revus).
const FURNISHED: Array = ["HouseInterior"]


static func is_interior(node: Node) -> bool:
	return node != null and node.scene_file_path.begins_with(INTERIORS_DIR)


# Habille tous les intérieurs instanciés sous `root`.
static func dress_all_under(root: Node) -> void:
	for n in root.find_children("*", "Node2D", true, false):
		if is_interior(n):
			dress(n)


static func dress(root: Node) -> void:
	if root.has_meta("interior_dressed"):
		return
	root.set_meta("interior_dressed", true)
	var kind: String = floor_kind(root)
	var furnished: bool = false
	for key in FURNISHED:
		furnished = furnished or root.scene_file_path.contains(key)
	var floor: ColorRect = find_floor(root)
	var rects: Array[ColorRect] = []
	_collect(root, rects)
	if floor != null:
		_dress_floor(floor, kind, root)
	for cr in rects:
		if cr == floor or cr.has_meta("dressing"):
			continue
		if cr.size.x < MIN_RECT or cr.size.y < MIN_RECT or not cr.visible:
			continue
		if not (furnished and _furnish(cr)):
			_relief(cr)
	for l in root.find_children("*", "Label", true, false):
		var label: Label = l as Label
		if label != null and not label.has_theme_font_override("font"):
			PixelFont.style_world_label(label)


static func floor_kind(root: Node) -> String:
	var name: String = root.scene_file_path.get_file() if root.scene_file_path != "" else String(root.name)
	for key in FLOOR_KINDS:
		if name.contains(key):
			return FLOOR_KINDS[key]
	return "planks"


# Le sol : rect « Floor » / « Ground », sinon le plus grand ColorRect direct.
static func find_floor(root: Node) -> ColorRect:
	var named: Node = root.get_node_or_null("Floor")
	if named == null:
		named = root.get_node_or_null("Ground")
	if named is ColorRect:
		return named as ColorRect
	var best: ColorRect = null
	for c in root.get_children():
		if c is ColorRect and (best == null or (c as ColorRect).get_rect().get_area() > best.get_rect().get_area()):
			best = c as ColorRect
	return best


static func _collect(node: Node, out: Array[ColorRect]) -> void:
	for child in node.get_children():
		if child is ColorRect:
			out.append(child as ColorRect)
		_collect(child, out)


static func _dress_floor(floor: ColorRect, kind: String, root: Node) -> void:
	var seed: int = int(absf(floor.position.x * 7.0 + floor.position.y * 13.0)) % 977 + 1
	var w: float = floor.size.x
	var h: float = floor.size.y
	# Mur extérieur : anneau sombre derrière le sol (le vide devient un mur).
	var outer: ColorRect = _rect(floor, "OuterWall", Vector2(-OUTER_WALL, -OUTER_WALL), Vector2(w + 2 * OUTER_WALL, h + 2 * OUTER_WALL), Color(0.17, 0.15, 0.14, 1))
	outer.show_behind_parent = true
	# Sol peint, dans la couleur de la dalle.
	_overlay(floor, "FloorTiles", InteriorPainter.floor_texture(kind, floor.color, seed), Rect2(0, 0, InteriorPainter.TILE, InteriorPainter.TILE), Vector2.ZERO, Vector2(w, h))
	# Mur du fond : bande en haut, papier peint dérivé du sol (plus clair, désaturé).
	var wall_color: Color = floor.color.lightened(0.22)
	wall_color.s = wall_color.s * 0.5
	var wall_h: float = InteriorPainter.WALL_H * InteriorPainter.DENSITY
	_overlay(floor, "BackWall", InteriorPainter.wall(wall_color), Rect2(0, 0, InteriorPainter.TILE, InteriorPainter.WALL_H), Vector2.ZERO, Vector2(w, wall_h))
	# Fenêtres régulièrement espacées, flaque de lumière sur le sol.
	var count: int = maxi(1, int(w / WINDOW_SPACING))
	var ww: float = InteriorPainter.WINDOW_W * InteriorPainter.DENSITY
	var wh: float = InteriorPainter.WINDOW_H * InteriorPainter.DENSITY
	for i in count:
		var cx: float = w * (float(i) + 0.5) / float(count)
		var win: Sprite2D = Sprite2D.new()
		win.name = "Window%d" % i
		win.texture = InteriorPainter.window(false)
		win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		win.centered = false
		win.scale = Vector2(InteriorPainter.DENSITY, InteriorPainter.DENSITY)
		win.position = Vector2(roundf(cx - ww * 0.5), LINE)
		floor.add_child(win)
		var pool: ColorRect = _rect(floor, "Light%d" % i, Vector2(cx - ww * 0.6, wall_h), Vector2(ww * 1.2, wh * 1.6), Color(1, 1, 0.9, 0.07))
		pool.set_meta("dressing", true)
	# Bandes sombres gauche / droite / bas : l'épaisseur des murs vue de dessus.
	var side: Color = floor.color.darkened(0.35)
	_rect(floor, "WallL", Vector2(0, wall_h), Vector2(SIDE_WALL, h - wall_h), side)
	_rect(floor, "WallR", Vector2(w - SIDE_WALL, wall_h), Vector2(SIDE_WALL, h - wall_h), side)
	_rect(floor, "WallB", Vector2(0, h - SIDE_WALL), Vector2(w, SIDE_WALL), side)


# Relief d'un meuble : ombre portée (derrière), grain si bois, arête claire
# en haut-gauche, contour sombre. Les rects translucides (tapis, lumière)
# n'ont que le contour.
static func _relief(cr: ColorRect) -> void:
	var w: float = cr.size.x
	var h: float = cr.size.y
	var opaque: bool = cr.color.a >= 0.9
	var dark: Color = cr.color.darkened(0.55)
	dark.a = cr.color.a
	if opaque:
		var shadow: ColorRect = _rect(cr, "Shadow", Vector2(LINE, LINE), Vector2(w, h), Color(0, 0, 0, 0.28))
		shadow.show_behind_parent = true
		if _is_wood(cr):
			_overlay(cr, "Grain", InteriorPainter.planks(cr.color, int(absf(cr.position.x + cr.position.y)) % 97 + 1), Rect2(0, 0, InteriorPainter.TILE, InteriorPainter.TILE), Vector2(LINE, LINE), Vector2(w - 2 * LINE, h - 2 * LINE))
		var light: Color = cr.color.lightened(0.25)
		_rect(cr, "EdgeTop", Vector2(LINE, LINE), Vector2(w - 2 * LINE, LINE), light)
		_rect(cr, "EdgeLeft", Vector2(LINE, LINE), Vector2(LINE, h - 2 * LINE), light)
	_rect(cr, "OutlineT", Vector2.ZERO, Vector2(w, LINE), dark)
	_rect(cr, "OutlineB", Vector2(0, h - LINE), Vector2(w, LINE), dark)
	_rect(cr, "OutlineL", Vector2.ZERO, Vector2(LINE, h), dark)
	_rect(cr, "OutlineR", Vector2(w - LINE, 0), Vector2(LINE, h), dark)


# Meuble peint (FurniturePainter) : le rect dont le nom — ou celui de son
# corps parent — désigne un genre connu devient un sprite ; l'aplat s'efface
# (self_modulate) et les détails en rects posés dedans (oreiller, plaque…)
# sont masqués. Faux si le rect n'est pas un meuble connu.
static func _furnish(cr: ColorRect) -> bool:
	var parent: Node = cr.get_parent()
	var kind: String = FurniturePainter.kind_for(String(cr.name))
	var grouped: bool = false
	if kind == "" and parent != null:
		kind = FurniturePainter.kind_for(String(parent.name))
		grouped = kind != ""
	if kind == "":
		return false
	if grouped:
		# Seul le plus grand rect du corps porte le meuble.
		for sib in parent.get_children():
			if sib is ColorRect and sib != cr and not sib.has_meta("dressing"):
				if (sib as ColorRect).size.x * (sib as ColorRect).size.y > cr.size.x * cr.size.y:
					return true
				(sib as ColorRect).visible = false
	if kind != "rug" and kind != "tv" and kind != "altar":
		var shadow: ColorRect = _rect(cr, "Shadow", Vector2(LINE, LINE), cr.size, Color(0, 0, 0, 0.28))
		shadow.show_behind_parent = true
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Furniture"
	spr.set_meta("dressing", true)
	spr.texture = FurniturePainter.build(kind, cr.size, cr.color, int(absf(cr.position.x + cr.position.y)) % 97 + 1)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(FurniturePainter.DENSITY, FurniturePainter.DENSITY)
	cr.add_child(spr)
	cr.self_modulate.a = 0.0
	return true


static func _is_wood(cr: ColorRect) -> bool:
	var c: Color = cr.color
	return c.r > c.g and c.g > c.b and (c.r - c.b) > 0.15 and c.s > 0.25 and c.v < 0.8


static func _rect(parent: Node, name: String, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.name = name
	r.set_meta("dressing", true)
	r.offset_left = pos.x
	r.offset_top = pos.y
	r.offset_right = pos.x + size.x
	r.offset_bottom = pos.y + size.y
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


# Texture native répétée par le shader de tuiles (cellule = native × 3).
static func _overlay(parent: Node, name: String, tex: Texture2D, region: Rect2, pos: Vector2, size: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = name
	s.set_meta("dressing", true)
	s.texture = tex
	s.centered = false
	s.position = pos
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = DistrictDresser.tile_shader()
	mat.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	mat.set_shader_parameter("cell", region.size * float(InteriorPainter.DENSITY))
	s.material = mat
	parent.add_child(s)
	return s
