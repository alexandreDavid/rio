class_name BuildingDressing
extends RefCounted

# Relief des façades, partagé entre Copacabana (immeubles générés, maisons de
# favela) et l'habilleur des districts (ColorRect taguées `building`). Tout est
# en ColorRect, posé dans le repère local du parent : ombre portée derrière la
# façade, bande de toit, fondation, arête éclairée, et, si la façade est nue,
# une grille de fenêtres et une porte. Les cotes suivent la hauteur de la
# façade pour qu'une maison de 24 px et une tour de 160 px gardent la même
# proportion de relief.

const WINDOW_COLOR: Color = Color(0.25, 0.35, 0.55, 1)
const WINDOW_LIT_COLOR: Color = Color(0.95, 0.85, 0.5, 1)
const DOOR_COLOR: Color = Color(0.35, 0.25, 0.18, 1)
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.30)

# Décor de toit (favelas) : 0 antenne TV, 1 caixa d'água, 2 linge, autre = rien.
enum Roof { ANTENNA = 0, TANK = 1, LAUNDRY = 2, NONE = 3 }


# Options : roof_band (défaut true), roof_offset (hauteur d'un toit déjà dessiné,
# pour poser le décor au-dessus), roof_kind (Roof.*, défaut NONE), windows /
# door (défaut false), door_left (défaut false), seed (variations déterministes).
# `insert_at` = index de la façade dans parent : l'ombre passe juste avant,
# le reste juste après, donc les détails déjà dessinés plus loin restent dessus.
static func paint_relief(parent: Node, insert_at: int, rect: Rect2, color: Color, opts: Dictionary = {}) -> void:
	var h: float = rect.size.y
	var small: bool = h < 60.0
	var roof_h: float = 5.0 if small else clampf(roundf(h * 0.07), 6.0, 9.0)
	var overhang: float = 1.0 if small else 3.0
	var foundation_h: float = 3.0 if small else clampf(roundf(h * 0.05), 4.0, 6.0)
	var highlight_w: float = 2.0 if small else 3.0
	var shadow_off: float = 2.0 if small else 4.0
	var shadow_grow: float = 1.0 if small else 2.0
	var seed: int = int(opts.get("seed", int(rect.position.x * 7.0 + rect.position.y * 13.0)))

	var idx: int = insert_at
	var shadow: ColorRect = _rect(parent, rect.position + Vector2(shadow_off, shadow_off), rect.size + Vector2(shadow_grow, shadow_grow), SHADOW_COLOR, "Shadow")
	parent.move_child(shadow, idx)
	idx += 2  # après l'ombre ET la façade

	# Arête éclairée à gauche (lumière du matin venant de l'est)
	var hi: ColorRect = _rect(parent, rect.position + Vector2(0, roof_h * 0.6), Vector2(highlight_w, h - roof_h * 0.6 - foundation_h - 1.0),
		Color(minf(color.r + 0.12, 1.0), minf(color.g + 0.12, 1.0), minf(color.b + 0.12, 1.0), 0.9), "Highlight")
	parent.move_child(hi, idx)
	idx += 1
	# Fondation béton
	var found: ColorRect = _rect(parent, Vector2(rect.position.x, rect.end.y - foundation_h), Vector2(rect.size.x, foundation_h),
		Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 1), "Foundation")
	parent.move_child(found, idx)
	idx += 1
	# Bande de toit (sauf si la scène en dessine déjà une)
	var roof_offset: float = float(opts.get("roof_offset", 0.0))
	if opts.get("roof_band", true):
		var roof: ColorRect = _rect(parent, Vector2(rect.position.x - overhang, rect.position.y - roof_h * 0.6), Vector2(rect.size.x + overhang * 2.0, roof_h),
			Color(color.r * 0.40, color.g * 0.40, color.b * 0.40, 1), "Roof")
		parent.move_child(roof, idx)
		idx += 1
		roof_offset = roof_h * 0.6

	if opts.get("windows", false):
		idx = _paint_windows(parent, idx, rect, roof_h, foundation_h, seed)
	if opts.get("door", false):
		idx = _paint_door(parent, idx, rect, small, bool(opts.get("door_left", false)))
	var kind: int = int(opts.get("roof_kind", Roof.NONE))
	if kind != Roof.NONE:
		_paint_roof_decor(parent, idx, rect, kind, roof_offset, small)


static func _paint_windows(parent: Node, idx: int, rect: Rect2, roof_h: float, foundation_h: float, seed: int) -> int:
	var small: bool = rect.size.y < 60.0
	var win: Vector2 = Vector2(5, 5) if small else Vector2(10, 12)
	var step: Vector2 = Vector2(9, 9) if small else Vector2(22, 24)
	var margin_x: float = 4.0 if small else 10.0
	var top: float = rect.position.y + roof_h + (2.0 if small else 6.0)
	var bottom: float = rect.end.y - foundation_h - (10.0 if small else 24.0)  # on laisse la place de la porte
	var cols: int = int(floor((rect.size.x - margin_x * 2.0 + (step.x - win.x)) / step.x))
	var rows: int = int(floor((bottom - top + (step.y - win.y)) / step.y))
	if cols <= 0 or rows <= 0:
		return idx
	var x0: float = rect.position.x + (rect.size.x - (cols * step.x - (step.x - win.x))) * 0.5
	var k: int = 0
	for r in rows:
		for c in cols:
			var lit: bool = ((seed + k * 7919) % 5) == 0
			var w: ColorRect = _rect(parent, Vector2(x0 + c * step.x, top + r * step.y), win, WINDOW_LIT_COLOR if lit else WINDOW_COLOR, "Window")
			parent.move_child(w, idx)
			idx += 1
			k += 1
	return idx


static func _paint_door(parent: Node, idx: int, rect: Rect2, small: bool, door_left: bool) -> int:
	var size: Vector2 = Vector2(5, 8) if small else Vector2(12, clampf(roundf(rect.size.y * 0.22), 16.0, 26.0))
	var x: float
	if small:
		x = rect.position.x + 4.0 if door_left else rect.end.x - 4.0 - size.x
	else:
		x = rect.position.x + rect.size.x * 0.5 - size.x * 0.5
	var door: ColorRect = _rect(parent, Vector2(x, rect.end.y - 1.0 - size.y), size, DOOR_COLOR, "Door")
	parent.move_child(door, idx)
	return idx + 1


# Décor de toit typique des favelas cariocas, posé au-dessus de la bande de toit.
static func _paint_roof_decor(parent: Node, idx: int, rect: Rect2, kind: int, roof_offset: float, small: bool) -> void:
	var s: float = 1.0 if small else 1.8  # échelle des détails (modérée : au morro les maisons se touchent)
	var top: float = rect.position.y - roof_offset
	var cx: float = rect.position.x + rect.size.x * 0.5
	match kind:
		Roof.ANTENNA:
			parent.move_child(_rect(parent, Vector2(cx - 1.0 * s, top - 11.0 * s), Vector2(2.0 * s, 11.0 * s), Color(0.22, 0.20, 0.18, 1), "Antenna"), idx)
			parent.move_child(_rect(parent, Vector2(cx - 5.0 * s, top - 9.0 * s), Vector2(10.0 * s, 1.0 * s), Color(0.22, 0.20, 0.18, 1), "AntennaArm"), idx + 1)
		Roof.TANK:
			var tx: float = rect.end.x - 8.0 * s
			parent.move_child(_rect(parent, Vector2(tx, top - 6.0 * s), Vector2(7.0 * s, 6.0 * s), Color(0.25, 0.45, 0.70, 1), "Tank"), idx)
			parent.move_child(_rect(parent, Vector2(tx, top - 7.0 * s), Vector2(7.0 * s, 2.0 * s), Color(0.18, 0.32, 0.50, 1), "TankLid"), idx + 1)
		Roof.LAUNDRY:
			parent.move_child(_rect(parent, Vector2(rect.position.x + 2.0 * s, top - 5.0 * s), Vector2(rect.size.x - 4.0 * s, 1.0 * s), Color(0.30, 0.28, 0.25, 1), "Line"), idx)
			var laundry_colors: Array = [Color(0.95, 0.85, 0.45, 1), Color(0.85, 0.35, 0.42, 1), Color(0.40, 0.65, 0.85, 1)]
			for k in 3:
				var cxk: float = rect.position.x + 4.0 * s + k * (rect.size.x - 12.0 * s) / 2.0
				parent.move_child(_rect(parent, Vector2(cxk, top - 4.0 * s), Vector2(3.0 * s, 4.0 * s), laundry_colors[k], "Cloth"), idx + 1 + k)


static func _rect(parent: Node, pos: Vector2, size: Vector2, color: Color, name: String) -> ColorRect:
	var cr: ColorRect = ColorRect.new()
	cr.name = name
	cr.offset_left = pos.x
	cr.offset_top = pos.y
	cr.offset_right = pos.x + size.x
	cr.offset_bottom = pos.y + size.y
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr
