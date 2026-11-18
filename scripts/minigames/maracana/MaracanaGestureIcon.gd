extends Control

# Grosse icône pixel du geste attendu (flèche ou cible « tape »), cadre dont
# les cases s'éteignent avec la fenêtre de réaction : vert = PERFECT encore
# possible, jaune = juste GOOD, rouge = presque trop tard.

const CELL: float = 24.0
const GRID: int = 12
const DARK: Color = Color(0.07, 0.07, 0.16, 0.86)
const LINE: Color = Color(0.13, 0.10, 0.12, 1.0)
const OFF: Color = Color(0.28, 0.28, 0.36, 1.0)
const GREEN: Color = Color(0.45, 0.95, 0.45, 1.0)
const YELLOW: Color = Color(0.98, 0.84, 0.25, 1.0)
const RED: Color = Color(0.95, 0.30, 0.25, 1.0)

const ARROW_UP: Array[String] = [
	"...##...",
	"..####..",
	".######.",
	"########",
	"..####..",
	"..####..",
	"..####..",
	"..####..",
]
const TAP: Array[String] = [
	"..####..",
	".#....#.",
	"#..##..#",
	"#.####.#",
	"#.####.#",
	"#..##..#",
	".#....#.",
	"..####..",
]

var cmd: int = -1
var tint: Color = Color.WHITE
var ratio: float = 1.0
var perfect: bool = true
var _pop: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(CELL * GRID, CELL * GRID)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_cmd(idx: int, color: Color) -> void:
	cmd = idx
	tint = color
	ratio = 1.0
	perfect = true
	_pop = 0.14
	visible = true

func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta, 0.0)
	# Apparition en deux crans (pas d'interpolation lisse).
	scale = Vector2.ONE * (1.2 if _pop > 0.07 else (1.1 if _pop > 0.0 else 1.0))
	if visible:
		queue_redraw()

func _draw() -> void:
	if cmd < 0:
		return
	var shake: float = 0.0
	if ratio < 0.25:
		shake = 4.0 if int(_t * 30.0) % 2 == 0 else -4.0
	var o: Vector2 = Vector2(shake, 0.0)
	var full: float = CELL * GRID
	# Fond à coins coupés.
	draw_rect(Rect2(o + Vector2(CELL, 0), Vector2(full - CELL * 2, full)), DARK)
	draw_rect(Rect2(o + Vector2(0, CELL), Vector2(full, full - CELL * 2)), DARK)
	# Cadre-chrono : cases du pourtour, éteintes dans le sens horaire.
	var cells: Array[Vector2i] = _perimeter()
	var lit: int = int(ceilf(ratio * cells.size()))
	var col: Color = GREEN if perfect else (RED if ratio < 0.25 else YELLOW)
	for k in cells.size():
		var c: Vector2i = cells[k]
		var r: Rect2 = Rect2(o + Vector2(c) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
		draw_rect(r.grow(3.0), LINE)
		draw_rect(r, col if k < lit else OFF)
	# Glyphe 8×8 au centre, ombre portée puis couleur de l'ordre.
	var rows: Array[String] = TAP if cmd == 4 else ARROW_UP
	for y in 8:
		for x in 8:
			var s: Vector2i = _rot(x, y)
			if rows[s.y][s.x] != "#":
				continue
			var p: Vector2 = o + Vector2(2 + x, 2 + y) * CELL
			draw_rect(Rect2(p + Vector2(6, 6), Vector2(CELL, CELL)), LINE)
	for y in 8:
		for x in 8:
			var s: Vector2i = _rot(x, y)
			if rows[s.y][s.x] != "#":
				continue
			var p: Vector2 = o + Vector2(2 + x, 2 + y) * CELL
			draw_rect(Rect2(p, Vector2(CELL, CELL)), tint)
			draw_rect(Rect2(p + Vector2(0, CELL - 6), Vector2(CELL, 6)), tint.darkened(0.25))

# Pixel source du glyphe pour la case (x, y) selon la direction demandée.
func _rot(x: int, y: int) -> Vector2i:
	match cmd:
		1:  # gauche : la pointe à gauche
			return Vector2i(y, x)
		2:  # droite
			return Vector2i(7 - y, x)
		3:  # bas
			return Vector2i(x, 7 - y)
	return Vector2i(x, y)

# Pourtour en partant du milieu du haut, sens horaire, sans les coins coupés.
func _perimeter() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var last: int = GRID - 1
	for x in range(GRID / 2, last):
		out.append(Vector2i(x, 0))
	for y in range(1, last):
		out.append(Vector2i(last, y))
	for x in range(last - 1, 0, -1):
		out.append(Vector2i(x, last))
	for y in range(last - 1, 0, -1):
		out.append(Vector2i(0, y))
	for x in range(1, GRID / 2):
		out.append(Vector2i(x, 0))
	return out
