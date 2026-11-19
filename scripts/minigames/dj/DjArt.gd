extends RefCounted

# Peintures pixel du set DJ au sommet du Morro da Urca (1 px natif = 3 px
# monde, comme GroundPainter et les personnages) : ciel couchant tramé, baie
# de Guanabara, Corcovado et Cristo, Pão de Açúcar et câble du bondinho,
# scène, mur LED des pistes, puis les éléments qui bougent (enceintes,
# console, pads de notes, lumières de la ville qui s'allument).

const N: int = 3
const ORIGIN: Vector2 = Vector2(-360, 0)
const W: int = 880           # 2640 px monde : couvre les écrans jusqu'à ~2,4:1
const H: int = 360
const HORIZON: float = 546.0
const DECK_Y: float = 762.0
const FLOOR_Y: float = 900.0
const PANEL: Rect2 = Rect2(470, 44, 900, 716)
const LANE_TOP: float = 56.0
const LANE_HALF: float = 66.0
const LIGHTS_TOP: float = 270.0
const LIGHTS_BOT: float = 720.0
const CRISTO_X: float = 120.0
const PAO_X: float = 1612.0
const PAO_Y: float = 262.0
# Câble du bondinho : sommet du Pão → gare de l'Urca (derrière l'enceinte droite).
const CABLE_A: Vector2 = Vector2(1762, 270)
const CABLE_B: Vector2 = Vector2(1452, 700)

const SKY: Array = [
	Color(0.15, 0.11, 0.30), Color(0.25, 0.15, 0.40), Color(0.42, 0.20, 0.48),
	Color(0.64, 0.27, 0.50), Color(0.86, 0.38, 0.45), Color(0.97, 0.56, 0.38),
	Color(1.0, 0.74, 0.44),
]
const SKY_BANDS: Array = [0.0, 96.0, 176.0, 256.0, 334.0, 410.0, 476.0]
const STAR: Color = Color(0.92, 0.88, 1.0)
const CLOUD: Color = Color(1.0, 0.72, 0.62)
const CLOUD_D: Color = Color(0.74, 0.40, 0.56)
const SUN: Color = Color(1.0, 0.93, 0.62)
const SUN_RIM: Color = Color(1.0, 0.74, 0.44)
const RIDGE: Color = Color(0.36, 0.23, 0.44)
const RIDGE_LIT: Color = Color(0.80, 0.46, 0.50)
const HILLS: Color = Color(0.24, 0.16, 0.32)
const HILLS_LIT: Color = Color(0.52, 0.30, 0.44)
const BLD: Array = [Color(0.20, 0.15, 0.30), Color(0.24, 0.18, 0.34), Color(0.18, 0.14, 0.27)]
const BLD_RIM: Color = Color(0.48, 0.30, 0.46)
const WIN_OFF: Color = Color(0.30, 0.23, 0.40)
const WIN_ON: Color = Color(1.0, 0.85, 0.50)
const WIN_COOL: Color = Color(0.80, 0.90, 1.0)
const WATER: Array = [Color(0.62, 0.36, 0.52), Color(0.46, 0.27, 0.48), Color(0.32, 0.20, 0.42), Color(0.24, 0.16, 0.36)]
const WATER_BANDS: Array = [546.0, 572.0, 608.0, 650.0]
const TREE: Color = Color(0.13, 0.15, 0.21)
const TREE_L: Color = Color(0.22, 0.22, 0.30)
const DARK: Color = Color(0.08, 0.06, 0.11)
const METAL: Color = Color(0.58, 0.56, 0.66)
const METAL_D: Color = Color(0.32, 0.30, 0.40)
const PLANK: Color = Color(0.22, 0.16, 0.24)
const PLANK_L: Color = Color(0.27, 0.20, 0.29)
const STONE: Color = Color(0.17, 0.13, 0.21)
const STONE_L: Color = Color(0.22, 0.17, 0.26)
const OUTLINE: Color = Color(0.06, 0.04, 0.09)
const WHITE: Color = Color(0.98, 0.97, 0.93)

# Icônes des pads (7×6 natifs) : grosse caisse, caisse claire, charleston, synthé.
const ICONS: Array = [
	["..XXX..", ".X...X.", "X..X..X", "X..X..X", ".X...X.", "..XXX.."],
	["X.....X", ".X...X.", "..X.X..", "XXXXXXX", "X.....X", "XXXXXXX"],
	["...X...", ".XXXXX.", "XXXXXXX", "...X...", "...X...", "..XXX.."],
	[".X.....", "X.X....", "X.X....", "...X..X", "...X..X", "....XX."],
]

static var _cache: Dictionary = {}


static func nx(wx: float) -> int:
	return int(roundf((wx - ORIGIN.x) / float(N)))


static func ny(wy: float) -> int:
	return int(roundf((wy - ORIGIN.y) / float(N)))


static func _box(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, img.get_width())
	y1 = mini(y1, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func _blend_box(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, img.get_width())
	y1 = mini(y1, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	var r: Image = Image.create(x1 - x0, y1 - y0, false, Image.FORMAT_RGBA8)
	r.fill(c)
	img.blend_rect(r, Rect2i(0, 0, x1 - x0, y1 - y0), Vector2i(x0, y0))


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(maxi(steps, 1)))
		_px(img, int(p.x), int(p.y), c)


# Sprite NEAREST ×3 posé par son coin haut-gauche (monde).
static func sprite(tex: Texture2D, top_left: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(N, N)
	s.position = top_left
	return s


# --- Décor fixe -------------------------------------------------------------

static func backdrop(lane_x: Array, lane_colors: Array, target_y: float) -> ImageTexture:
	if _cache.has("backdrop"):
		return _cache["backdrop"]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1958
	_sky(img, rng)
	_ridge(img, rng)
	_pao(img)
	var _w: Array = _city(img)
	_water(img, rng)
	_cable(img)
	_treeline(img, rng)
	_stage(img, rng)
	_panel(img, lane_x, lane_colors, target_y)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["backdrop"] = tex
	return tex


static func _sky(img: Image, rng: RandomNumberGenerator) -> void:
	var bottom: int = ny(HORIZON)
	for y in bottom:
		var wy: float = ORIGIN.y + y * N
		var b: int = 0
		for i in SKY_BANDS.size():
			if wy >= float(SKY_BANDS[i]):
				b = i
		_box(img, 0, y, W, y + 1, SKY[b])
		# Transition tramée sur trois rangées : pas de dégradé lisse.
		if b + 1 < SKY_BANDS.size():
			var to_next: int = ny(float(SKY_BANDS[b + 1])) - y
			var step: int = [0, 2, 3, 5][clampi(to_next, 0, 3)]
			if to_next >= 1 and to_next <= 3:
				for x in range(y % step, W, step):
					img.set_pixel(x, y, SKY[b + 1])
	# Étoiles qui percent déjà le haut du ciel.
	for i in 70:
		var sx: int = rng.randi_range(0, W - 1)
		var sy: int = rng.randi_range(0, ny(150.0))
		_px(img, sx, sy, STAR if rng.randf() < 0.5 else STAR.darkened(0.3))
	for i in 5:
		var bx: int = rng.randi_range(4, W - 4)
		var by: int = rng.randi_range(2, ny(110.0))
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_px(img, bx + d.x, by + d.y, STAR)
	# Soleil couchant derrière la crête, coupé de bandes « rétro ».
	var sc: Vector2i = Vector2i(nx(330.0), ny(474.0))
	for dy in range(-17, 18):
		for dx in range(-17, 18):
			var d: float = Vector2(dx, dy).length()
			if dy > 2 and (dy % 4 == 0 or (dy > 9 and dy % 4 == 1)):
				continue
			if d <= 15.0:
				_px(img, sc.x + dx, sc.y + dy, SUN)
			elif d <= 16.5:
				_px(img, sc.x + dx, sc.y + dy, SUN_RIM)
	# Nuages en traînées, liseré éclairé dessus, ventre rosé dessous.
	for i in 16:
		var cx: int = rng.randi_range(-20, W - 20)
		var cy: int = ny(rng.randf_range(150.0, 440.0))
		var len: int = rng.randi_range(18, 70)
		_box(img, cx, cy, cx + len, cy + 1, CLOUD)
		_box(img, cx + 5, cy + 1, cx + len - 4, cy + 2, CLOUD_D)
		if len > 40:
			_box(img, cx + 12, cy - 1, cx + len - 18, cy, CLOUD.lightened(0.2))


# Massif de la Tijuca : Corcovado (avec le Cristo) à gauche, crête lointaine.
static func _ridge(img: Image, rng: RandomNumberGenerator) -> void:
	var base: int = ny(HORIZON)
	for x in W:
		var wx: float = ORIGIN.x + x * N
		var top: float = 470.0 + 18.0 * sin(wx * 0.006 + 0.7) + 10.0 * sin(wx * 0.021)
		# Corcovado : pic raide (le Cristo y est posé).
		var u: float = absf(wx - CRISTO_X) / 150.0
		if u < 1.0:
			top = minf(top, 342.0 + 128.0 * pow(u, 1.4))
		# Dois Irmãos tout à gauche.
		var v: float = absf(wx + 250.0) / 90.0
		if v < 1.0:
			top = minf(top, 420.0 + 50.0 * v * v)
		var ty: int = ny(top)
		_box(img, x, ty, x + 1, base, RIDGE)
		# Rebord éclairé côté soleil.
		var toward_sun: bool = wx > CRISTO_X and wx < 330.0 or wx > 520.0
		_px(img, x, ty, RIDGE_LIT if toward_sun else RIDGE.lightened(0.12))
		for y in range(ty + 2, base):
			if rng.randf() < 0.03:
				_px(img, x, y, RIDGE.darkened(0.15))
	# Collines de Botafogo, plus proches et plus sombres.
	var humps: Array = [[-200.0, 220.0, 70.0], [420.0, 260.0, 54.0], [980.0, 200.0, 44.0], [1340.0, 240.0, 60.0]]
	for h in humps:
		var cx: float = h[0]
		var hw: float = h[1]
		var hh: float = h[2]
		for x in range(nx(cx - hw), nx(cx + hw) + 1):
			if x < 0 or x >= W:
				continue
			var t: float = absf((ORIGIN.x + x * N - cx) / hw)
			if t >= 1.0:
				continue
			var ty: int = ny(HORIZON - hh * pow(1.0 - t * t, 0.7))
			_box(img, x, ty, x + 1, base, HILLS)
			_px(img, x, ty, HILLS_LIT if ORIGIN.x + x * N < cx else HILLS.lightened(0.08))
	# Cristo Redentor éteint (les lumières le révèlent plus tard).
	_cristo(img, Color(0.22, 0.15, 0.30))


# Silhouette du Cristo (natif) : socle, robe, bras en croix, tête.
static func _cristo(img: Image, c: Color, oy: int = 0) -> void:
	var x: int = nx(CRISTO_X)
	var y: int = ny(342.0) - oy
	_box(img, x - 2, y - 3, x + 3, y, c)
	_box(img, x - 1, y - 13, x + 2, y - 3, c)
	_box(img, x - 6, y - 12, x + 7, y - 10, c)
	_box(img, x, y - 15, x + 1, y - 13, c)
	_px(img, x - 1, y - 14, c)
	_px(img, x + 1, y - 14, c)


static func _pao(img: Image) -> void:
	var tex: ImageTexture = GroundPainter.dome(102, 114, Color(0.58, 0.40, 0.50), Color(0.18, 0.23, 0.28), 4)
	var d: Image = tex.get_image()
	img.blend_rect(d, Rect2i(0, 0, d.get_width(), d.get_height()), Vector2i(nx(PAO_X), ny(PAO_Y)))
	# Gare du sommet et lueur dorée sur la face ouest.
	var top: Vector2i = Vector2i(nx(CABLE_A.x), ny(CABLE_A.y))
	_box(img, top.x - 4, top.y - 2, top.x + 4, top.y + 3, Color(0.30, 0.22, 0.34))
	_box(img, top.x - 3, top.y - 1, top.x + 3, top.y, Color(0.52, 0.40, 0.48))


static func _city(img: Image) -> Array:
	# Tirage propre : lights() le refait pour retrouver les fenêtres.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var base: int = ny(HORIZON)
	var x: int = 0
	var end_x: int = nx(PAO_X + 40.0)
	var windows: Array = []
	while x < end_x:
		var bw: int = rng.randi_range(5, 14)
		var bh: int = rng.randi_range(4, 15)
		# Plus haut côté Botafogo/Centro, plus bas vers l'Urca.
		if ORIGIN.x + x * N > 900.0:
			bh = rng.randi_range(3, 8)
		var col: Color = BLD[rng.randi() % BLD.size()]
		_box(img, x, base - bh, x + bw, base, col)
		_box(img, x, base - bh, x + bw, base - bh + 1, BLD_RIM)
		for wy in range(base - bh + 2, base - 1, 2):
			for wx in range(x + 1, x + bw - 1, 2):
				_px(img, wx, wy, WIN_OFF)
				windows.append(Vector2i(wx, wy))
		x += bw + rng.randi_range(0, 2)
	return windows


static func _water(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(HORIZON)
	var y1: int = ny(720.0)
	for y in range(y0, y1):
		var wy: float = ORIGIN.y + y * N
		var b: int = 0
		for i in WATER_BANDS.size():
			if wy >= float(WATER_BANDS[i]):
				b = i
		_box(img, 0, y, W, y + 1, WATER[b])
		if b + 1 < WATER_BANDS.size() and ny(float(WATER_BANDS[b + 1])) - y == 1:
			for xx in range(y % 2, W, 2):
				img.set_pixel(xx, y, WATER[b + 1])
	# Risées : tirets clairs (ciel reflété) et sombres.
	for i in 520:
		var rx: int = rng.randi_range(0, W - 8)
		var ry: int = rng.randi_range(y0 + 1, y1 - 1)
		var len: int = rng.randi_range(2, 7)
		var light: bool = rng.randf() < 0.55
		var base_c: Color = img.get_pixel(rx, ry)
		_box(img, rx, ry, rx + len, ry + 1, base_c.lightened(0.18) if light else base_c.darkened(0.15))
	# Chemin de soleil : tirets dorés sous le disque, de plus en plus larges.
	var sx: int = nx(330.0)
	for y in range(y0, y1, 2):
		var k: float = float(y - y0) / float(y1 - y0)
		var spread: int = int(4.0 + k * 22.0)
		for j in 3:
			var len: int = rng.randi_range(2, 6 + int(k * 6.0))
			var ox: int = sx + rng.randi_range(-spread, spread)
			_box(img, ox, y, ox + len, y + 1, SUN if rng.randf() < 0.4 else SUN_RIM)


static func _cable(img: Image) -> void:
	var a: Vector2 = Vector2(nx(CABLE_A.x), ny(CABLE_A.y))
	var b: Vector2 = Vector2(nx(CABLE_B.x), ny(CABLE_B.y))
	_line(img, a, b, DARK)
	_line(img, a + Vector2(3, 0), b + Vector2(3, 0), DARK.lightened(0.12))


# Lisière de la mata de l'Urca sous la terrasse (cache le pied du Pão).
static func _treeline(img: Image, rng: RandomNumberGenerator) -> void:
	var base: int = ny(DECK_Y) + 1
	for x in W:
		var wx: float = ORIGIN.x + x * N
		var top: float = 676.0 + 14.0 * sin(wx * 0.045) + 9.0 * sin(wx * 0.11 + 2.0)
		var ty: int = ny(top)
		_box(img, x, ty, x + 1, base, TREE)
		_px(img, x, ty, TREE_L)
		if (x / 3) % 2 == 0:
			_px(img, x, ty + 1, TREE_L)
		for y in range(ty + 2, base):
			if rng.randf() < 0.05:
				_px(img, x, y, TREE_L)
	# Quelques palmiers en silhouette.
	for px_w in [-300.0, 30.0, 1430.0, 1980.0, 2200.0]:
		var px: int = nx(px_w)
		var top_y: int = ny(600.0)
		_box(img, px, top_y, px + 1, ny(700.0), TREE)
		for f in [Vector2i(-5, 1), Vector2i(5, 1), Vector2i(-4, -2), Vector2i(4, -2), Vector2i(0, -3)]:
			_line(img, Vector2(px, top_y), Vector2(px + f.x, top_y + f.y + 2), TREE)
			_line(img, Vector2(px, top_y), Vector2(px + f.x, top_y + f.y + 1), TREE)


# Scène : plancher, nez de scène à LED, terrasse dallée pour la foule.
static func _stage(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(DECK_Y)
	var y_face: int = ny(FLOOR_Y - 30.0)
	var y_floor: int = ny(FLOOR_Y)
	_box(img, 0, y0, W, y0 + 1, METAL.lightened(0.15))
	_box(img, 0, y0 + 1, W, y0 + 3, METAL)
	_box(img, 0, y0 + 3, W, y0 + 4, METAL_D)
	for y in range(y0 + 4, y_face):
		var row: int = (y - y0 - 4) / 3
		_box(img, 0, y, W, y + 1, PLANK_L if row % 2 == 0 else PLANK)
		if (y - y0 - 4) % 3 == 2:
			_box(img, 0, y, W, y + 1, PLANK.darkened(0.25))
		else:
			var off: int = (row * 17) % 31
			for jx in range(off, W, 31):
				_px(img, jx, y, PLANK.darkened(0.3))
	_box(img, 0, y_face, W, y_floor, DARK)
	_box(img, 0, y_face, W, y_face + 1, METAL_D)
	# Terrasse : dalles sombres jointoyées.
	for y in range(y_floor, H):
		var c: Color = STONE if ((y - y_floor) / 6) % 2 == 0 else STONE_L.darkened(0.08)
		_box(img, 0, y, W, y + 1, c)
		if (y - y_floor) % 6 == 0:
			_box(img, 0, y, W, y + 1, STONE.darkened(0.3))
		else:
			var off: int = (((y - y_floor) / 6) % 2) * 6
			for jx in range(off, W, 12):
				_px(img, jx, y, STONE.darkened(0.3))
	for i in 220:
		_px(img, rng.randi_range(0, W - 1), rng.randi_range(y_floor + 1, H - 1), STONE_L)


# Mur LED derrière les pistes, structure en treillis, pistes « égaliseur ».
static func _panel(img: Image, lane_x: Array, lane_colors: Array, target_y: float) -> void:
	var x0: int = nx(PANEL.position.x)
	var x1: int = nx(PANEL.end.x)
	var y0: int = ny(PANEL.position.y)
	var y1: int = ny(PANEL.end.y)
	_blend_box(img, x0, y0, x1, y1, Color(0.04, 0.02, 0.09, 0.80))
	# Grille de diodes éteintes, à peine visible.
	for y in range(y0 + 1, y1, 3):
		for x in range(x0 + 1, x1, 3):
			_blend(img, x, y, Color(0.5, 0.4, 0.8, 0.07))
	# Treillis : tours latérales + poutre du haut (deux rails, diagonales).
	_truss(img, x0 - 8, y0 - 8, 8, y1 - y0 + 12, true)
	_truss(img, x1, y0 - 8, 8, y1 - y0 + 12, true)
	_truss(img, x0 - 8, y0 - 8, x1 - x0 + 16, 8, false)
	# Projecteurs suspendus sous la poutre.
	for i in 9:
		var cx: int = x0 + 6 + i * (x1 - x0 - 12) / 8
		_box(img, cx - 2, y0, cx + 3, y0 + 4, DARK)
		_box(img, cx - 1, y0 + 4, cx + 2, y0 + 5, METAL)
	var t_row: int = ny(target_y)
	for i in lane_x.size():
		var col: Color = lane_colors[i]
		var lx0: int = nx(float(lane_x[i]) - LANE_HALF)
		var lx1: int = nx(float(lane_x[i]) + LANE_HALF)
		var ly0: int = ny(LANE_TOP)
		var ly1: int = ny(PANEL.end.y) - 2
		_blend_box(img, lx0, ly0, lx1, ly1, Color(col.r, col.g, col.b, 0.10))
		for y in range(ly0, ly1):
			var k: float = float(y - ly0) / float(ly1 - ly0)
			# Bords néon, plus vifs en bas (vers la ligne de frappe).
			var edge: Color = Color(col.r, col.g, col.b, 0.35 + 0.55 * k)
			_blend(img, lx0, y, edge)
			_blend(img, lx1 - 1, y, edge)
			# Graduations d'égaliseur sur les deux bords.
			if (y - ly0) % 6 == 0:
				var tick: Color = Color(col.r, col.g, col.b, 0.25 + 0.6 * k)
				_blend_box(img, lx0 + 1, y, lx0 + 4, y + 1, tick)
				_blend_box(img, lx1 - 4, y, lx1 - 1, y + 1, tick)
			# Tramage qui s'éclaire à l'approche de la ligne.
			if k > 0.72 and (x0 + y) % 2 == 0:
				var dens: int = 5 if k < 0.85 else 3
				for x in range(lx0 + 2 + (y % dens), lx1 - 2, dens):
					_blend(img, x, y, Color(col.r, col.g, col.b, 0.22))
			if (y - ly0) % 4 == 0:
				_blend(img, (lx0 + lx1) / 2, y, Color(1, 1, 1, 0.10))
	# Ligne de frappe : liseré doré + barre blanche.
	_box(img, x0 + 1, t_row - 2, x1 - 1, t_row - 1, Color(1.0, 0.80, 0.42))
	_box(img, x0 + 1, t_row - 1, x1 - 1, t_row + 1, WHITE)
	_box(img, x0 + 1, t_row + 1, x1 - 1, t_row + 2, Color(1.0, 0.80, 0.42, 1).darkened(0.3))


static func _truss(img: Image, x: int, y: int, w: int, h: int, vertical: bool) -> void:
	if vertical:
		_box(img, x, y, x + 1, y + h, METAL_D)
		_box(img, x + 1, y, x + 2, y + h, METAL)
		_box(img, x + w - 2, y, x + w - 1, y + h, METAL)
		_box(img, x + w - 1, y, x + w, y + h, METAL_D)
		for k in range(0, h, w - 2):
			_line(img, Vector2(x + 2, y + k), Vector2(x + w - 3, y + k + w - 3), METAL_D)
			_box(img, x + 1, y + k, x + w - 1, y + k + 1, METAL_D)
	else:
		_box(img, x, y, x + w, y + 1, METAL_D)
		_box(img, x, y + 1, x + w, y + 2, METAL)
		_box(img, x, y + h - 2, x + w, y + h - 1, METAL)
		_box(img, x, y + h - 1, x + w, y + h, METAL_D)
		for k in range(0, w, h - 2):
			_line(img, Vector2(x + k, y + 2), Vector2(x + k + h - 3, y + h - 3), METAL_D)
			_box(img, x + k, y + 1, x + k + 1, y + h - 1, METAL_D)


# --- Lumières de la ville (4 vagues qui s'allument pendant le set) ----------

# Image recadrée sur [LIGHTS_TOP, LIGHTS_BOT] : fenêtres, orla, reflets, Cristo.
static func lights(group: int) -> ImageTexture:
	var key: String = "lights_%d" % group
	if _cache.has(key):
		return _cache[key]
	var top: int = ny(LIGHTS_TOP)
	var h: int = ny(LIGHTS_BOT) - top
	var img: Image = Image.create(W, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var full: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var base: int = ny(HORIZON)
	var pick: RandomNumberGenerator = RandomNumberGenerator.new()
	pick.seed = 77
	for wp in _city(full):
		var g: int = pick.randi() % 5
		var cool: bool = pick.randf() < 0.25
		if g == group:
			_px(img, wp.x, wp.y - top, WIN_COOL if cool else WIN_ON)
	# Orla : chapelet de lampadaires au ras de l'eau + reflets verticaux.
	if group == 1 or group == 2:
		for x in range(group, nx(PAO_X), 5):
			_px(img, x, base - top, WIN_ON)
			for k in range(2, 14, 2):
				if pick.randf() < 0.7:
					_px(img, x, base - top + k, Color(1.0, 0.80, 0.45, 0.55 - k * 0.03))
	# Cristo illuminé (blanc) avec halo tramé.
	if group == 1:
		var cx: int = nx(CRISTO_X)
		var cy: int = ny(342.0) - top
		for dy in range(-22, 4):
			for dx in range(-12, 13):
				if (dx + dy) % 2 == 0 and Vector2(dx, dy + 9).length() < 12.0:
					_px(img, cx + dx, cy + dy, Color(1.0, 0.95, 0.80, 0.22))
		var tmp: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
		tmp.fill(Color(0, 0, 0, 0))
		_cristo(tmp, Color(0.96, 0.95, 0.88))
		img.blend_rect(tmp, Rect2i(0, top, W, h), Vector2i(0, 0))
	# Feu rouge du sommet du Pão et gare éclairée.
	if group == 0:
		var p: Vector2i = Vector2i(nx(CABLE_A.x), ny(CABLE_A.y) - top)
		_box(img, p.x - 3, p.y - 1, p.x + 3, p.y, WIN_ON)
		_px(img, p.x, p.y - 4, Color(1.0, 0.25, 0.2))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# --- Éléments mobiles -------------------------------------------------------

# Cabine du bondinho (natif 10×9), suspendue par son chariot.
static func cabin() -> ImageTexture:
	if _cache.has("cabin"):
		return _cache["cabin"]
	var img: Image = Image.create(11, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_box(img, 4, 0, 7, 1, DARK)
	_box(img, 5, 1, 6, 3, DARK)
	_box(img, 1, 3, 10, 9, Color(0.92, 0.70, 0.30))
	_box(img, 0, 3, 11, 4, DARK)
	_box(img, 0, 9, 11, 10, DARK)
	_box(img, 0, 4, 1, 9, DARK)
	_box(img, 10, 4, 11, 9, DARK)
	_box(img, 2, 4, 9, 7, WIN_ON)
	_box(img, 5, 4, 6, 7, Color(0.92, 0.70, 0.30).darkened(0.3))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["cabin"] = tex
	return tex


# Tour d'enceintes (2 caissons) : façade grillagée, boomers, tweeter.
static func speaker() -> ImageTexture:
	if _cache.has("speaker"):
		return _cache["speaker"]
	var w: int = 34
	var h: int = 72
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body: Color = Color(0.12, 0.10, 0.15)
	var face: Color = Color(0.18, 0.16, 0.21)
	for cab in 2:
		var y0: int = cab * 36
		_box(img, 0, y0, w, y0 + 36, OUTLINE)
		_box(img, 1, y0 + 1, w - 1, y0 + 35, body)
		_box(img, 3, y0 + 3, w - 3, y0 + 33, face)
		_box(img, 1, y0 + 1, w - 1, y0 + 2, body.lightened(0.25))
		# Grille : trame fine.
		for yy in range(y0 + 3, y0 + 33, 2):
			for xx in range(3 + (yy % 4) / 2, w - 3, 2):
				_px(img, xx, yy, face.darkened(0.2))
		var woofer: Vector2i = Vector2i(w / 2, y0 + 21)
		_cone(img, woofer, 10)
		_cone(img, Vector2i(w / 2, y0 + 7), 3)
		# Coins métal.
		for c in [Vector2i(1, y0 + 1), Vector2i(w - 3, y0 + 1), Vector2i(1, y0 + 33), Vector2i(w - 3, y0 + 33)]:
			_box(img, c.x, c.y, c.x + 2, c.y + 2, METAL)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["speaker"] = tex
	return tex


static func _cone(img: Image, c: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d: float = Vector2(dx, dy).length()
			if d > float(r) + 0.3:
				continue
			var col: Color = Color(0.30, 0.28, 0.34)
			if d > float(r) - 1.0:
				col = OUTLINE
			elif d > float(r) - 2.2:
				col = Color(0.46, 0.44, 0.52)
			elif d < float(r) * 0.3:
				col = Color(0.10, 0.09, 0.12)
			elif dx + dy < -1:
				col = Color(0.38, 0.36, 0.44)
			_px(img, c.x + dx, c.y + dy, col)


# Console du DJ : deux platines, table de mixage à LED, façade néon.
static func console(lane_colors: Array) -> ImageTexture:
	if _cache.has("console"):
		return _cache["console"]
	var w: int = 112
	var h: int = 40
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Plateau.
	_box(img, 0, 6, w, 14, OUTLINE)
	_box(img, 1, 7, w - 1, 13, Color(0.26, 0.24, 0.30))
	_box(img, 1, 7, w - 1, 8, Color(0.42, 0.40, 0.48))
	# Platines (vues de face, légèrement d'en haut) et bras.
	for cx in [18, w - 19]:
		_box(img, cx - 15, 2, cx + 16, 9, OUTLINE)
		_box(img, cx - 14, 3, cx + 15, 8, Color(0.36, 0.34, 0.40))
		_box(img, cx - 11, 3, cx + 12, 7, Color(0.10, 0.09, 0.12))
		_box(img, cx - 9, 4, cx + 10, 6, Color(0.20, 0.19, 0.24))
		_box(img, cx - 2, 4, cx + 3, 6, lane_colors[0] if cx < w / 2 else lane_colors[1])
		_box(img, cx + 11, 0, cx + 12, 4, METAL)
	# Table de mixage au centre : faders et potards colorés.
	var mx: int = w / 2
	_box(img, mx - 14, 0, mx + 14, 9, OUTLINE)
	_box(img, mx - 13, 1, mx + 13, 8, Color(0.20, 0.19, 0.24))
	for i in 4:
		var kx: int = mx - 10 + i * 7
		_box(img, kx, 2, kx + 2, 3, lane_colors[i])
		_box(img, kx, 4, kx + 2, 8, Color(0.08, 0.07, 0.10))
		_box(img, kx, 5 + (i % 3), kx + 2, 6 + (i % 3), WHITE)
	# Façade : caisson sombre, bandeau néon rose, logo pixel.
	_box(img, 3, 14, w - 3, h, OUTLINE)
	_box(img, 4, 14, w - 4, h - 1, Color(0.10, 0.08, 0.14))
	_box(img, 4, 16, w - 4, 18, lane_colors[0])
	_box(img, 4, 16, w - 4, 17, lane_colors[0].lightened(0.35))
	_box(img, 4, h - 4, w - 4, h - 3, lane_colors[1].darkened(0.2))
	# « RIO » en grosses lettres pixel au milieu de la façade.
	var glyphs: Array = [
		["XXX.", "X..X", "XXX.", "X.X.", "X..X"],
		[".X.", ".X.", ".X.", ".X.", ".X."],
		[".XX.", "X..X", "X..X", "X..X", ".XX."],
	]
	var gx: int = mx - 9
	for g in glyphs:
		for ry in g.size():
			var row: String = g[ry]
			for rx in row.length():
				if row[rx] == "X":
					_box(img, gx + rx * 2, 21 + ry * 2, gx + rx * 2 + 2, 23 + ry * 2, lane_colors[3])
		gx += (g[0] as String).length() * 2 + 2
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["console"] = tex
	return tex


# Pad de note (natif 43×12) : coins échancrés, modelé, icône de l'instrument.
static func pad(lane: int, col: Color) -> ImageTexture:
	var key: String = "pad_%d" % lane
	if _cache.has(key):
		return _cache[key]
	var w: int = 43
	var h: int = 12
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_box(img, 1, 0, w - 1, h, OUTLINE)
	_box(img, 0, 1, w, h - 1, OUTLINE)
	_box(img, 1, 1, w - 1, h - 1, col)
	_box(img, 2, 1, w - 2, 2, col.lightened(0.45))
	_box(img, 1, 2, 2, h - 2, col.lightened(0.25))
	_box(img, 2, h - 2, w - 2, h - 1, col.darkened(0.35))
	_box(img, w - 2, 2, w - 1, h - 2, col.darkened(0.25))
	# Petites diodes aux extrémités.
	_box(img, 4, 5, 6, 7, WHITE)
	_box(img, w - 6, 5, w - 4, 7, WHITE)
	_icon(img, lane, Vector2i(18, 3), 1, WHITE, col.darkened(0.55))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _icon(img: Image, lane: int, at: Vector2i, s: int, c: Color, shadow: Color) -> void:
	var rows: Array = ICONS[lane]
	for pass_i in 2:
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] != "X":
					continue
				var p: Vector2i = at + Vector2i(rx, ry) * s
				if pass_i == 0:
					_box(img, p.x + s, p.y + s, p.x + 2 * s, p.y + 2 * s, shadow)
				else:
					_box(img, p.x, p.y, p.x + s, p.y + s, c)


# Icône seule (pour les boutons de lane), agrandie `s` fois.
static func icon_texture(lane: int, col: Color) -> ImageTexture:
	var key: String = "icon_%d" % lane
	if _cache.has(key):
		return _cache[key]
	var s: int = 6
	var img: Image = Image.create(8 * s, 7 * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_icon(img, lane, Vector2i.ZERO, s, WHITE, col.darkened(0.6))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# --- Personnages ------------------------------------------------------------

const CW: int = 64
const CH: int = 96


# Cellule native 21×32 extraite d'une planche ×3.
static func _native(sheet: Image, col: int, row: int) -> Image:
	var n: Image = Image.create(21, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 21:
			n.set_pixel(x, y, sheet.get_pixel(col * CW + x * 3 + 1, row * CH + y * 3 + 1))
	return n


static func _put(dst: Image, n: Image, col: int) -> void:
	for y in 32:
		for x in 21:
			var c: Color = n.get_pixel(x, y)
			if c.a > 0.01:
				dst.fill_rect(Rect2i(col * CW + x * 3, y * 3, 3, 3), c)


static func _outline(n: Image) -> void:
	var line: Color = CharacterSpriteFactory.LINE_COLOR
	var line32: int = line.to_rgba32()
	var edges: Array = []
	for y in 32:
		for x in 21:
			if n.get_pixel(x, y).a > 0.01:
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px: int = x + off.x
				var py: int = y + off.y
				if px >= 0 and py >= 0 and px < 21 and py < 32:
					var c: Color = n.get_pixel(px, py)
					if c.a > 0.01 and c.to_rgba32() != line32:
						edges.append(Vector2i(x, y))
						break
	for e in edges:
		n.set_pixel(e.x, e.y, line)


# Bras levé (côté gauche = -1, droit = +1) : on efface le bras pendant et on
# trace un bras en V au-dessus de l'épaule.
static func _raise_arm(n: Image, side: int, skin: Color, shirt: Color) -> void:
	var sx: int = 4 if side < 0 else 16
	var ox: int = 3 if side < 0 else 17
	for y in range(15, 24):
		n.set_pixel(sx, y, Color(0, 0, 0, 0))
		n.set_pixel(ox, y, Color(0, 0, 0, 0))
	var out: int = -1 if side < 0 else 1
	for y in range(12, 15):
		n.set_pixel(sx, y, shirt)
	for y in range(8, 12):
		n.set_pixel(sx + out, y, skin)
	for y in range(5, 8):
		n.set_pixel(sx + out * 2, y, skin)
	n.set_pixel(sx + out * 2, 4, skin.darkened(0.15))


# Planche de figurant vu de dos : idle, pas G, pas D, bras levés, un bras.
static func crowd_sheet(cfg: Dictionary) -> ImageTexture:
	var sheet: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var out: Image = Image.create(CW * 5, CH, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var skin: Color = cfg.get("skin", Color(0.86, 0.70, 0.55))
	var shirt: Color = cfg.get("shirt_color", Color(0.85, 0.55, 0.4))
	for f in 3:
		_put(out, _native(sheet, f, CharacterSpriteFactory.DIR_UP), f)
	var both: Image = _native(sheet, 0, CharacterSpriteFactory.DIR_UP)
	_raise_arm(both, -1, skin, shirt)
	_raise_arm(both, 1, skin, shirt)
	_outline(both)
	_put(out, both, 3)
	var one: Image = _native(sheet, 1, CharacterSpriteFactory.DIR_UP)
	_raise_arm(one, 1, skin, shirt)
	_outline(one)
	_put(out, one, 4)
	return ImageTexture.create_from_image(out)


# Planche du DJ (de face, casque sur les oreilles) : idle, poing levé.
static func dj_sheet(cfg: Dictionary, accent: Color) -> ImageTexture:
	var sheet: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var out: Image = Image.create(CW * 2, CH, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var skin: Color = cfg.get("skin", Color(0.86, 0.70, 0.55))
	var shirt: Color = cfg.get("shirt_color", Color(0.85, 0.55, 0.4))
	for f in 2:
		var n: Image = _native(sheet, 0, CharacterSpriteFactory.DIR_DOWN)
		_headphones(n, accent)
		if f == 1:
			_raise_arm(n, 1, skin, shirt)
		_outline(n)
		_put(out, n, f)
	return ImageTexture.create_from_image(out)


static func _headphones(n: Image, accent: Color) -> void:
	var band: Color = Color(0.16, 0.15, 0.20)
	for x in range(6, 15):
		n.set_pixel(x, 2, band)
	n.set_pixel(5, 3, band)
	n.set_pixel(15, 3, band)
	for y in range(4, 8):
		n.set_pixel(4, y, band)
		n.set_pixel(16, y, band)
	for y in range(8, 12):
		for x in [3, 4]:
			n.set_pixel(x, y, band)
		for x in [16, 17]:
			n.set_pixel(x, y, band)
	n.set_pixel(3, 9, accent)
	n.set_pixel(17, 9, accent)
	n.set_pixel(3, 10, accent)
	n.set_pixel(17, 10, accent)
