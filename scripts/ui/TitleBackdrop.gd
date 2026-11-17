class_name TitleBackdrop
extends Control

# Décor animé de l'écran titre : la baie au coucher du soleil, en pixel-art.
# Le fond fixe (ciel, Pão de Açúcar, mer, sable, calçadão) est peint une fois
# dans une image basse résolution agrandie en NEAREST ; seuls les éléments
# vivants (reflets, écume, fenêtres, palmiers, mouettes) sont redessinés.

const GRID_H: int = 180          # hauteur de la grille en pixels natifs
const FPS: float = 12.0          # cadence volontairement « pixel-art »

const SKY_STOPS: Array[Color] = [
	Color(0.13, 0.12, 0.34), Color(0.36, 0.2, 0.45), Color(0.78, 0.38, 0.45),
	Color(0.97, 0.6, 0.42), Color(1.0, 0.8, 0.5),
]
const MOUNTAIN: Color = Color(0.2, 0.14, 0.29)
const MOUNTAIN_RIM: Color = Color(0.5, 0.3, 0.42)
const FAR_HILLS: Color = Color(0.4, 0.25, 0.42)
const CITY: Color = Color(0.16, 0.12, 0.24)
const SAND: Color = Color(0.93, 0.79, 0.56)
const STONE_DARK: Color = Color(0.12, 0.11, 0.14)
const STONE_LIGHT: Color = Color(0.94, 0.91, 0.86)
const SUN: Color = Color(1.0, 0.9, 0.58)
const SPARKLE: Color = Color(1.0, 0.86, 0.6)
const FOAM: Color = Color(0.98, 0.96, 0.9)
const PALM: Color = Color(0.1, 0.09, 0.14)
const WINDOW_LIT: Color = Color(1.0, 0.82, 0.45)

var _tex: ImageTexture = null
var _grid_w: int = 0
var _px: float = 6.0
var _time: float = 0.0
var _acc: float = 0.0
var _horizon: int = 0
var _shore: int = 0
var _calcadao: int = 0
var _sun: Vector2i = Vector2i.ZERO
var _windows: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / FPS:
		_time += _acc
		_acc = 0.0
		queue_redraw()


func _rebuild() -> void:
	if size.y <= 0.0:
		return
	_px = size.y / float(GRID_H)
	_grid_w = int(ceil(size.x / _px))
	_horizon = int(GRID_H * 0.5)
	_shore = int(GRID_H * 0.74)
	_calcadao = int(GRID_H * 0.87)
	_sun = Vector2i(int(_grid_w * 0.66), _horizon - 12)
	_rng.seed = 2026
	_windows.clear()
	var img: Image = Image.create(_grid_w, GRID_H, false, Image.FORMAT_RGBA8)
	_paint_sky(img)
	_paint_sun(img)
	_paint_far_hills(img)
	_paint_city(img)
	_paint_sugarloaf(img)
	_paint_sea(img)
	_paint_sand(img)
	_paint_calcadao(img)
	_tex = ImageTexture.create_from_image(img)
	queue_redraw()


# --- Fond fixe ------------------------------------------------------------

func _sky_color(y: int, x: int) -> Color:
	var t: float = clampf(float(y) / float(_horizon), 0.0, 1.0) * float(SKY_STOPS.size() - 1)
	var i: int = mini(int(t), SKY_STOPS.size() - 2)
	var f: float = t - float(i)
	# Tramage ordonné à la frontière des bandes : dégradé lisible en gros pixels.
	var bayer: float = [0.0, 0.5, 0.75, 0.25][(x % 2) + 2 * (y % 2)]
	return SKY_STOPS[i + 1] if f > 0.15 + bayer * 0.7 else SKY_STOPS[i]


func _paint_sky(img: Image) -> void:
	for y in _horizon:
		for x in _grid_w:
			img.set_pixel(x, y, _sky_color(y, x))


func _paint_sun(img: Image) -> void:
	var r: int = 13
	for y in range(_sun.y - r, _sun.y + r + 1):
		for x in range(_sun.x - r, _sun.x + r + 1):
			if x < 0 or x >= _grid_w or y < 0 or y >= _horizon:
				continue
			var d: Vector2 = Vector2(x - _sun.x, y - _sun.y)
			if d.length() > float(r):
				continue
			# Bas du disque strié : le soleil « fond » dans l'horizon.
			var dy: int = y - _sun.y
			if dy > 2 and (dy % 4 == 0 or (dy > 7 and dy % 4 == 1)):
				continue
			img.set_pixel(x, y, SUN.lerp(Color(1.0, 0.65, 0.45), clampf(float(dy + r) / float(2 * r), 0.0, 1.0) * 0.6))


func _paint_far_hills(img: Image) -> void:
	for x in _grid_w:
		var h: float = 7.0 + 4.0 * sin(float(x) * 0.045) + 3.0 * sin(float(x) * 0.13 + 1.3)
		for y in range(_horizon - int(h), _horizon):
			img.set_pixel(x, y, FAR_HILLS)


func _paint_city(img: Image) -> void:
	# Le front de mer qui s'étire vers Leme, à droite de la baie.
	var x: int = int(_grid_w * 0.34)
	while x < _grid_w:
		var w: int = _rng.randi_range(5, 9)
		var h: int = _rng.randi_range(8, 19)
		for bx in range(x, mini(x + w - 1, _grid_w)):
			for by in range(_horizon - h, _horizon):
				img.set_pixel(bx, by, CITY)
		for wy in range(_horizon - h + 2, _horizon - 1, 3):
			for wx in range(x + 1, mini(x + w - 2, _grid_w), 2):
				if _rng.randf() < 0.45:
					_windows.append(Vector2i(wx, wy))
		x += w
	# Un lampadaire sur deux allumé en permanence, le reste scintille au rythme.


func _paint_sugarloaf(img: Image) -> void:
	var base_x: float = _grid_w * 0.12
	_dome(img, base_x, 17.0, 64.0, 0.25)
	_dome(img, base_x + 34.0, 26.0, 26.0, 0.0)
	# Le câble du bondinho entre les deux sommets.
	var a: Vector2 = Vector2(base_x + 2.0, _horizon - 63)
	var b: Vector2 = Vector2(base_x + 34.0, _horizon - 25)
	for i in 60:
		var t: float = float(i) / 59.0
		var p: Vector2 = a.lerp(b, t) + Vector2(0.0, sin(t * PI) * 3.0)
		if int(p.x) >= 0 and int(p.x) < _grid_w:
			img.set_pixel(int(p.x), int(p.y), MOUNTAIN)


# Morro en dôme penché (lean > 0 : flanc droit plus raide, comme le Pão).
func _dome(img: Image, cx: float, half_w: float, height: float, lean: float) -> void:
	for x in range(int(cx - half_w * 1.6), int(cx + half_w * 1.6) + 1):
		if x < 0 or x >= _grid_w:
			continue
		var u: float = (float(x) - cx) / half_w
		u = u / (1.0 + lean) if u < 0.0 else u * (1.0 + lean)
		var hh: float = height * maxf(0.0, 1.0 - u * u * 0.55) if absf(u) < 1.35 else 0.0
		hh = minf(hh, height) * (1.0 - maxf(0.0, absf(u) - 1.0) * 0.9)
		if hh <= 0.0:
			continue
		var top: int = _horizon - int(hh)
		for y in range(top, _horizon):
			img.set_pixel(x, y, MOUNTAIN)
		if u > 0.15 and u < 1.1:
			img.set_pixel(x, top, MOUNTAIN_RIM)
			if top + 1 < _horizon:
				img.set_pixel(x, top + 1, MOUNTAIN_RIM)


func _paint_sea(img: Image) -> void:
	var near: Color = Color(0.24, 0.47, 0.6)
	var deep: Color = Color(0.2, 0.28, 0.5)
	var glow: Color = Color(0.86, 0.52, 0.5)
	for y in range(_horizon, _shore):
		var t: float = float(y - _horizon) / float(_shore - _horizon)
		var base: Color = glow.lerp(deep, minf(1.0, t * 2.2)) if t < 0.45 else deep.lerp(near, (t - 0.45) / 0.55)
		for x in _grid_w:
			var c: Color = base
			if (x + y * 3) % 23 == 0:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)


func _paint_sand(img: Image) -> void:
	for y in range(_shore, _calcadao):
		for x in _grid_w:
			var c: Color = SAND
			var n: int = (x * 73 + y * 151) % 17
			if n == 0:
				c = SAND.darkened(0.12)
			elif n == 5:
				c = SAND.lightened(0.1)
			img.set_pixel(x, y, c)
	# Bordure du calçadão.
	for x in _grid_w:
		img.set_pixel(x, _calcadao - 1, Color(0.62, 0.58, 0.52))


func _paint_calcadao(img: Image) -> void:
	# Le motif d'ondes noir et blanc de l'Avenida Atlântica.
	for y in range(_calcadao, GRID_H):
		for x in _grid_w:
			var v: float = float(y - _calcadao) * 1.0 - 3.2 * sin(TAU * float(x) / 15.0)
			var band: int = int(floor(v / 3.0))
			img.set_pixel(x, y, STONE_LIGHT if posmod(band, 2) == 0 else STONE_DARK)


# --- Éléments vivants -----------------------------------------------------

func _draw() -> void:
	if _tex == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(_grid_w, GRID_H) * _px), false)
	_draw_windows()
	_draw_sun_path()
	_draw_foam()
	_draw_gulls()
	_draw_palm(int(_grid_w * 0.04), _calcadao + 2, 1.0, 0.0)
	_draw_palm(int(_grid_w * 0.95), _calcadao + 4, -1.0, 1.7)
	_draw_palm(int(_grid_w * 0.86), _calcadao, -1.0, 3.1)


func _cell(x: float, y: float, c: Color, w: float = 1.0, h: float = 1.0) -> void:
	draw_rect(Rect2(Vector2(floorf(x), floorf(y)) * _px, Vector2(w, h) * _px), c)


func _draw_windows() -> void:
	var tick: int = int(_time * 2.0)
	for i in _windows.size():
		# Chaque fenêtre a sa propre phase : la ville s'allume par à-coups.
		if (i * 7 + tick * (1 + i % 3)) % 11 < 6:
			var w: Vector2i = _windows[i]
			_cell(w.x, w.y, WINDOW_LIT)


func _draw_sun_path() -> void:
	# Colonne de reflets sous le soleil, qui s'élargit vers le rivage.
	for y in range(_horizon + 1, _shore - 2):
		var t: float = float(y - _horizon) / float(_shore - _horizon)
		var spread: float = 3.0 + t * 26.0
		var wob: float = sin(_time * 1.7 + float(y) * 0.9) * 2.0
		var n: int = 1 + int(t * 3.0)
		for k in n:
			var seed: float = float(y * 13 + k * 31)
			var phase: float = fmod(seed * 0.37 + _time * (0.6 + float(k) * 0.2), 1.0)
			var x: float = float(_sun.x) + wob + (phase - 0.5) * 2.0 * spread
			var len: float = 2.0 + floorf(t * 5.0)
			if fmod(seed + floorf(_time * 3.0), 3.0) < 2.0:
				_cell(x, y, SPARKLE, len)
	# Quelques éclats épars sur toute la baie.
	var tick: int = int(_time * FPS)
	for i in 26:
		var x: int = (i * 97 + tick * 3 * (i % 4 + 1)) % maxi(_grid_w, 1)
		var y: int = _horizon + 3 + (i * 37) % maxi(_shore - _horizon - 5, 1)
		if (tick + i) % 5 < 2:
			_cell(x, y, Color(1, 1, 1, 0.55), 2.0)


func _draw_foam() -> void:
	# L'écume monte et redescend sur le sable.
	var reach: float = (sin(_time * 0.9) * 0.5 + 0.5) * 3.0
	var y0: float = float(_shore) - 1.0 + reach
	for x in _grid_w:
		var edge: float = y0 + floorf(sin(float(x) * 0.31 + _time * 1.3) * 1.2)
		_cell(x, edge, FOAM)
		if (x + int(_time * 4.0)) % 5 != 0:
			_cell(x, edge - 1.0, Color(FOAM, 0.55))


func _draw_gulls() -> void:
	for i in 3:
		var speed: float = 6.0 + float(i) * 2.5
		var x: float = fmod(_time * speed + float(i) * 97.0, float(_grid_w + 40)) - 20.0
		var y: float = 22.0 + float(i) * 11.0 + sin(_time * 0.8 + float(i)) * 3.0
		var flap: bool = int(_time * 4.0 + float(i)) % 2 == 0
		var c: Color = Color(0.15, 0.12, 0.22)
		_cell(x, y, c)
		if flap:
			_cell(x - 2.0, y - 1.0, c, 2.0)
			_cell(x + 1.0, y - 1.0, c, 2.0)
		else:
			_cell(x - 2.0, y + 1.0, c, 2.0)
			_cell(x + 1.0, y + 1.0, c, 2.0)


func _draw_palm(base_x: int, base_y: int, lean_dir: float, phase: float) -> void:
	var sway: float = sin(_time * 0.9 + phase) * 1.5
	var height: int = 58
	var top: Vector2 = Vector2.ZERO
	for i in height:
		var t: float = float(i) / float(height)
		var x: float = float(base_x) + lean_dir * (t * t * 10.0) + sway * t * t
		var y: float = float(base_y - i)
		_cell(x, y, PALM, 3.0 if i < height * 0.6 else 2.0)
		top = Vector2(x + 1.0, y)
	# Palmes : arcs qui retombent, balancés avec le tronc.
	for k in 7:
		var ang: float = -PI * 0.5 + (float(k) - 3.0) * 0.48 + sway * 0.04
		var length: int = 18 + (k % 3) * 4
		for j in length:
			var t2: float = float(j) / float(length)
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			var p: Vector2 = top + dir * float(j) + Vector2(0.0, t2 * t2 * 9.0)
			_cell(p.x, p.y, PALM, 2.0 if t2 < 0.7 else 1.0)
