extends RefCounted

# Décor du Racha peint en pixel-art à la densité du jeu (1 px natif = 3 px
# monde, comme les personnages) : l'Av. Atlântica fermée pour la course, au
# coucher du soleil. Tout le fixe tient dans UNE image calculée une fois (cache) ;
# seuls la mer et les voitures bougent. Les voitures sont pré-rendues dans 16 caps
# (pas de rotation de sprite : les pixels restent sur la grille).

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const N: int = 3
const ORIGIN: Vector2 = Vector2(-480, -240)
const W: int = 960
const H: int = 520

# Bandes de l'avenue (monde), du nord au sud.
const FACADE_BASE: float = 128.0
const NORTH_CURB: float = 240.0
const CICLO_Y: float = 840.0
const CALC_Y: float = 910.0
const SAND_Y: float = 975.0
const SEA_Y: float = 1035.0
const MEDIAN_TOP: float = 400.0
const MEDIAN_BOT: float = 680.0

const CAR_F: int = 44          # cellule d'un cap de voiture (natif)
const CAR_DIRS: int = 16

const SKY: Array = [
	Color(0.33, 0.29, 0.52), Color(0.55, 0.35, 0.57), Color(0.84, 0.45, 0.52),
	Color(0.97, 0.60, 0.42), Color(1.0, 0.78, 0.50),
]
const SKY_BANDS: Array = [-240.0, -170.0, -110.0, -55.0, 0.0]
const CLOUD: Color = Color(0.99, 0.78, 0.66)
const CLOUD_D: Color = Color(0.86, 0.54, 0.58)
const SUN: Color = Color(1.0, 0.94, 0.66)
const SUN_RIM: Color = Color(1.0, 0.82, 0.50)
const MORRO_FAR: Color = Color(0.50, 0.38, 0.58)
const MORRO: Color = Color(0.25, 0.34, 0.38)
const MORRO_D: Color = Color(0.19, 0.27, 0.32)
const MORRO_LIT: Color = Color(0.62, 0.48, 0.42)
const ROCK: Color = Color(0.46, 0.40, 0.50)
const ROCK_LIT: Color = Color(0.80, 0.56, 0.48)
const BUILD_COLS: Array = [
	Color(0.96, 0.88, 0.74), Color(0.98, 0.76, 0.62), Color(0.88, 0.86, 0.84), Color(0.99, 0.89, 0.62),
	Color(0.74, 0.83, 0.88), Color(0.92, 0.70, 0.68), Color(0.80, 0.86, 0.74), Color(0.97, 0.95, 0.90),
]
const AWNINGS: Array = [
	Color(0.84, 0.24, 0.22), Color(0.18, 0.56, 0.38), Color(0.22, 0.42, 0.78), Color(0.96, 0.56, 0.18),
]
const LIT: Color = Color(1.0, 0.84, 0.46)
const LIT_HI: Color = Color(1.0, 0.95, 0.72)
const GLASS_DARK: Color = Color(0.27, 0.29, 0.44)
const GLASS_REF: Color = Color(0.96, 0.62, 0.52)
const SHOP: Color = Color(0.99, 0.80, 0.52)
const SHOP_D: Color = Color(0.42, 0.30, 0.26)
const TANK: Color = Color(0.56, 0.60, 0.66)
const DARK: Color = Color(0.12, 0.11, 0.14)
const STONE: Color = Color(0.84, 0.79, 0.73)
const CURB_L: Color = Color(0.90, 0.88, 0.84)
const CURB_D: Color = Color(0.36, 0.34, 0.38)
const ASPH: Color = Color(0.30, 0.29, 0.34)
const ASPH_D: Color = Color(0.25, 0.24, 0.29)
const ASPH_L: Color = Color(0.36, 0.35, 0.40)
const ASPH_P: Color = Color(0.33, 0.32, 0.38)
const SKID: Color = Color(0.21, 0.20, 0.24)
const LINE: Color = Color(0.94, 0.92, 0.86)
const YEL: Color = Color(0.99, 0.80, 0.28)
const KERB_R: Color = Color(0.86, 0.22, 0.20)
const MOSAIC_B: Color = Color(0.17, 0.16, 0.19)
const MOSAIC_W: Color = Color(0.95, 0.91, 0.84)
const HEDGE: Color = Color(0.24, 0.50, 0.30)
const HEDGE_D: Color = Color(0.17, 0.38, 0.25)
const HEDGE_L: Color = Color(0.36, 0.62, 0.34)
const FLOWER: Color = Color(0.95, 0.38, 0.58)
const CICLO: Color = Color(0.74, 0.40, 0.31)
const CONE: Color = Color(0.98, 0.50, 0.16)
const POLE: Color = Color(0.24, 0.26, 0.30)
const LAMP: Color = Color(1.0, 0.96, 0.76)
const GLOW: Color = Color(1.0, 0.84, 0.50)
const KIOSK_ROOF: Color = Color(0.18, 0.62, 0.62)
const WOOD: Color = Color(0.62, 0.42, 0.26)

const TIRE: Color = Color(0.10, 0.10, 0.12)
const GLASS: Color = Color(0.30, 0.42, 0.58)
const GLASS_HI: Color = Color(0.66, 0.80, 0.92)
const HEADLIGHT: Color = Color(1.0, 0.97, 0.76)
const TAIL: Color = Color(0.96, 0.16, 0.16)
const OUTLINE: Color = Color(0.09, 0.08, 0.11)

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
	if x1 <= x0 or y1 <= y0:
		return
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func _wbox(img: Image, wx0: float, wy0: float, wx1: float, wy1: float, c: Color) -> void:
	_box(img, nx(wx0), ny(wy0), nx(wx1), ny(wy1), c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


# --- Décor fixe -------------------------------------------------------------

# `lamps` = pieds des lampadaires (monde) ; `grid` = cases de départ.
static func backdrop(outer: Rect2, inner: Rect2, start_x: float, grid: Array, lamps: Array) -> ImageTexture:
	if _cache.has("backdrop"):
		return _cache["backdrop"]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2611
	_sky(img, rng)
	_morros(img, rng)
	_buildings(img, rng)
	_sidewalk_north(img, rng)
	_avenue(img, rng, outer, inner)
	_track_marks(img, outer, inner, start_x, grid)
	_ciclovia(img, rng)
	_calcadao(img, rng)
	_sand(img, rng)
	_closures(img, outer)
	_barriers(img, outer)
	_lamps(img, lamps)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["backdrop"] = tex
	return tex


static func _sky(img: Image, rng: RandomNumberGenerator) -> void:
	var bottom: int = ny(FACADE_BASE)
	for y in bottom:
		var wy: float = ORIGIN.y + y * N
		var b: int = 0
		for i in SKY_BANDS.size():
			if wy >= float(SKY_BANDS[i]):
				b = i
		_box(img, 0, y, W, y + 1, SKY[b])
		# Transition tramée sur deux rangées : pas de dégradé lisse.
		if b + 1 < SKY_BANDS.size():
			var to_next: int = ny(float(SKY_BANDS[b + 1])) - y
			if to_next == 1:
				for x in range(y % 2, W, 2):
					img.set_pixel(x, y, SKY[b + 1])
			elif to_next == 2:
				for x in range(y % 4, W, 4):
					img.set_pixel(x, y, SKY[b + 1])
	# Soleil couchant côté Forte (ouest), à moitié derrière le morro.
	var sc: Vector2i = Vector2i(nx(-110.0), ny(22.0))
	for dy in range(-15, 16):
		for dx in range(-15, 16):
			var d: float = Vector2(dx, dy).length()
			if d <= 13.0:
				_px(img, sc.x + dx, sc.y + dy, SUN)
			elif d <= 14.5:
				_px(img, sc.x + dx, sc.y + dy, SUN_RIM)
	for i in 9:
		var cx: int = rng.randi_range(0, W - 40)
		var cy: int = ny(rng.randf_range(-220.0, 10.0))
		var len: int = rng.randi_range(14, 44)
		_box(img, cx, cy, cx + len, cy + 1, CLOUD)
		_box(img, cx + 4, cy + 1, cx + len - 3, cy + 2, CLOUD_D)


# Silhouettes : chaîne lointaine, morros verts, et le Pão de Açúcar côté Leme.
static func _morros(img: Image, rng: RandomNumberGenerator) -> void:
	var base: int = ny(FACADE_BASE)
	for x in W:
		var wx: float = ORIGIN.x + x * N
		var top: float = FACADE_BASE - (95.0 + 22.0 * sin(wx * 0.011) + 14.0 * sin(wx * 0.029 + 1.3))
		_box(img, x, ny(top), x + 1, base, MORRO_FAR)
	# [centre x, demi-largeur, hauteur, roche nue ?]
	var humps: Array = [
		[-380.0, 190.0, 120.0, false], [-150.0, 160.0, 82.0, false], [520.0, 260.0, 105.0, false],
		[1300.0, 300.0, 110.0, false], [1890.0, 80.0, 72.0, false], [2010.0, 66.0, 122.0, true],
		[2290.0, 170.0, 115.0, false],
	]
	for h in humps:
		var cx: float = h[0]
		var hw: float = h[1]
		var hh: float = h[2]
		var rock: bool = h[3]
		for x in range(nx(cx - hw), nx(cx + hw) + 1):
			if x < 0 or x >= W:
				continue
			var t: float = absf((ORIGIN.x + x * N - cx) / hw)
			if t >= 1.0:
				continue
			# Pão de Açúcar : flancs raides, sommet arrondi (superellipse).
			var k: float = pow(1.0 - pow(t, 3.0), 0.35) if rock else pow(1.0 - t * t, 0.6)
			var top: int = ny(FACADE_BASE - hh * k)
			var body: Color = ROCK if rock else MORRO
			_box(img, x, top, x + 1, base, body)
			if rock:
				# Mata au pied du pain de sucre.
				_box(img, x, ny(FACADE_BASE - hh * 0.32), x + 1, base, MORRO)
			var west: bool = ORIGIN.x + x * N < cx
			_px(img, x, top, (ROCK_LIT if rock else MORRO_LIT) if west else body.darkened(0.15))
			for y in range(top + 2, base):
				if rng.randf() < 0.05:
					_px(img, x, y, MORRO_D)
	# Bondinho : câble Urca → Pão et une cabine.
	var a: Vector2 = Vector2(nx(1890.0), ny(FACADE_BASE - 72.0))
	var b: Vector2 = Vector2(nx(2010.0), ny(FACADE_BASE - 122.0))
	for i in 41:
		var p: Vector2 = a.lerp(b, i / 40.0)
		_px(img, int(p.x), int(p.y), DARK)
	var cab: Vector2 = a.lerp(b, 0.45)
	_box(img, int(cab.x) - 1, int(cab.y) + 1, int(cab.x) + 2, int(cab.y) + 3, KERB_R)


static func _buildings(img: Image, rng: RandomNumberGenerator) -> void:
	var base: int = ny(FACADE_BASE)
	var x: int = 0
	while x < W:
		var bw: int = rng.randi_range(28, 64)
		var wx: float = ORIGIN.x + x * N
		var top: float
		if wx < 30.0:
			top = rng.randf_range(62.0, 92.0)       # côté Forte : on voit le couchant
		elif wx > 1820.0 and wx < 2150.0:
			top = rng.randf_range(78.0, 96.0)       # dégage le Pão de Açúcar
		elif rng.randf() < 0.75:
			top = rng.randf_range(-240.0, 20.0)
		else:
			top = rng.randf_range(-20.0, 50.0)
		_building(img, rng, x, mini(x + bw, W), ny(top), base)
		x += bw + (rng.randi_range(1, 3) if rng.randf() < 0.35 else 0)


static func _building(img: Image, rng: RandomNumberGenerator, x0: int, x1: int, ty: int, by: int) -> void:
	var c: Color = BUILD_COLS[rng.randi() % BUILD_COLS.size()]
	_box(img, x0, maxi(ty, 0), x1, by, c)
	_box(img, x0, maxi(ty, 0), x0 + 1, by, c.lightened(0.16))   # arête éclairée (ouest)
	_box(img, x1 - 2, maxi(ty, 0), x1, by, c.darkened(0.18))
	var roof: bool = ty > 0
	if roof:
		_box(img, x0, ty, x1, ty + 2, c.darkened(0.34))
		_box(img, x0 + 1, ty + 2, x1 - 1, ty + 3, c.lightened(0.1))
		var r: float = rng.randf()
		if r < 0.45:
			var cx: int = rng.randi_range(x0 + 3, maxi(x0 + 3, x1 - 9))
			_box(img, cx, ty - 4, cx + 6, ty, TANK)
			_box(img, cx, ty - 4, cx + 6, ty - 3, TANK.lightened(0.25))
		elif r < 0.7:
			_box(img, x0 + 4, ty - 7, x0 + 5, ty, DARK)
			_box(img, x0 + 2, ty - 6, x0 + 7, ty - 5, DARK)
	var store_top: int = by - 12
	var style: int = rng.randi() % 3
	var awning: Color = AWNINGS[rng.randi() % AWNINGS.size()]
	var fy: int = store_top - 7
	while fy > ty + 3:
		if style == 1:
			# Bandeau vitré continu (immeuble années 70).
			for wx in range(x0 + 2, x1 - 3):
				var lit: bool = rng.randf() < 0.12 if (wx - x0) % 4 != 0 else false
				_box(img, wx, fy + 1, wx + 1, fy + 5, GLASS_DARK if (wx - x0) % 4 != 0 else c.darkened(0.25))
				if lit:
					_box(img, wx, fy + 2, wx + 1, fy + 5, LIT)
			_px(img, x0 + 3, fy + 1, GLASS_REF)
		else:
			var wx: int = x0 + 3
			while wx + 3 <= x1 - 3:
				if rng.randf() < 0.5:
					_box(img, wx, fy + 1, wx + 3, fy + 5, LIT)
					_box(img, wx, fy + 1, wx + 3, fy + 2, LIT_HI)
				else:
					_box(img, wx, fy + 1, wx + 3, fy + 5, GLASS_DARK)
					_px(img, wx, fy + 1, GLASS_REF)
				if style == 2:
					_box(img, wx, fy + 1, wx + 3, fy + 2, awning)   # store de fenêtre
				wx += 5
		_box(img, x0 + 1, fy + 6, x1 - 2, fy + 7, c.lightened(0.1))  # dalle de balcon
		fy -= 7
	# Rez-de-chaussée : marquise rayée puis vitrine éclairée.
	for sx in range(x0, x1):
		var col: Color = awning if ((sx - x0) / 2) % 2 == 0 else MOSAIC_W
		_box(img, sx, store_top, sx + 1, store_top + 3, col)
		if (sx - x0) % 2 == 0:
			_px(img, sx, store_top + 3, col.darkened(0.2))
	_box(img, x0 + 1, store_top + 4, x1 - 1, by - 1, SHOP)
	for sx in range(x0 + 1, x1 - 1, 6):
		_box(img, sx, store_top + 4, sx + 1, by - 1, SHOP_D)
	var door: int = rng.randi_range(x0 + 3, maxi(x0 + 3, x1 - 6))
	_box(img, door, store_top + 5, door + 3, by - 1, SHOP_D.darkened(0.3))
	_box(img, x0, by - 1, x1, by, c.darkened(0.45))


# Trottoir nord en pedra portuguesa claire, bordure blanche côté avenue.
static func _sidewalk_north(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(FACADE_BASE)
	var y1: int = ny(NORTH_CURB)
	_box(img, 0, y0, W, y1, STONE)
	_box(img, 0, y0, W, y0 + 1, STONE.darkened(0.3))   # ombre du rez-de-chaussée
	for i in 2400:
		var x: int = rng.randi_range(0, W - 1)
		var y: int = rng.randi_range(y0 + 1, y1 - 3)
		img.set_pixel(x, y, STONE.darkened(0.08) if i % 3 else STONE.lightened(0.08))
	_box(img, 0, y1 - 2, W, y1 - 1, CURB_L)
	_box(img, 0, y1 - 1, W, y1, CURB_D)


static func _avenue(img: Image, rng: RandomNumberGenerator, outer: Rect2, inner: Rect2) -> void:
	_wbox(img, ORIGIN.x, NORTH_CURB, ORIGIN.x + W * N, MEDIAN_TOP, ASPH)
	_wbox(img, ORIGIN.x, MEDIAN_BOT, ORIGIN.x + W * N, CICLO_Y, ASPH)
	_wbox(img, outer.position.x, MEDIAN_TOP, inner.position.x, MEDIAN_BOT, ASPH)
	_wbox(img, inner.end.x, MEDIAN_TOP, outer.end.x, MEDIAN_BOT, ASPH)
	# Grain du bitume, rustines, fissures (on n'écrit que sur l'asphalte nu).
	var y0: int = ny(NORTH_CURB)
	var y1: int = ny(CICLO_Y)
	for i in 9000:
		var x: int = rng.randi_range(0, W - 1)
		var y: int = rng.randi_range(y0, y1 - 1)
		if img.get_pixel(x, y).is_equal_approx(ASPH):
			img.set_pixel(x, y, ASPH_D if i % 2 else ASPH_L)
	for i in 34:
		var x: int = rng.randi_range(0, W - 14)
		var y: int = rng.randi_range(y0 + 2, y1 - 10)
		if not img.get_pixel(x, y).is_equal_approx(ASPH) and not img.get_pixel(x, y).is_equal_approx(ASPH_D) \
				and not img.get_pixel(x, y).is_equal_approx(ASPH_L):
			continue
		var pw: int = rng.randi_range(5, 14)
		var ph: int = rng.randi_range(3, 7)
		_box(img, x, y, x + pw, y + ph, ASPH_P)
		_box(img, x, y + ph, x + pw, y + ph + 1, ASPH_D)
	for i in 22:
		var p: Vector2i = Vector2i(rng.randi_range(0, W - 1), rng.randi_range(y0 + 2, y1 - 2))
		for k in rng.randi_range(5, 12):
			if img.get_pixel(p.x, p.y).r < 0.4:
				_px(img, p.x, p.y, ASPH_D.darkened(0.15))
			p += Vector2i(1, rng.randi_range(-1, 1))
	# Canteiro central : à l'ouest, au milieu, à l'est (les retornos le coupent).
	_median(img, rng, 0, ny(MEDIAN_TOP), nx(outer.position.x), ny(MEDIAN_BOT))
	_median(img, rng, nx(inner.position.x), ny(inner.position.y), nx(inner.end.x), ny(inner.end.y))
	_median(img, rng, nx(outer.end.x), ny(MEDIAN_TOP), W, ny(MEDIAN_BOT))


static func _median(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, x1: int, y1: int) -> void:
	_box(img, x0, y0, x1, y1, CURB_L)
	_box(img, x0 + 1, y0 + 1, x1 - 1, y1 - 1, HEDGE)
	for y in range(y0 + 1, y1 - 1):
		for x in range(x0 + 1, x1 - 1):
			var r: float = rng.randf()
			if r < 0.22:
				img.set_pixel(x, y, HEDGE_D)
			elif r < 0.36:
				img.set_pixel(x, y, HEDGE_L)
			elif r < 0.40:
				img.set_pixel(x, y, FLOWER)
	_box(img, x0, y1 - 1, x1, y1, CURB_D)
	# Au canteiro, des ondes plus larges et assourdies : la piste reste lisible.
	_mosaic(img, rng, x0 + 5, y0 + 5, x1 - 5, y1 - 5, MOSAIC_B.lerp(MOSAIC_W, 0.4), MOSAIC_W.darkened(0.05))


# Ondes de Burle Marx : bandes noir/blanc perpendiculaires à la mer, ondulées.
static func _mosaic(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, x1: int, y1: int,
		dark: Color = MOSAIC_B, light: Color = MOSAIC_W) -> void:
	x0 = maxi(x0, 0)
	x1 = mini(x1, W)
	if x1 <= x0 or y1 <= y0:
		return
	for y in range(y0, y1):
		var shift: int = int(roundf(4.0 * sin(TAU * float(y) / 30.0)))
		for x in range(x0, x1):
			var black: bool = posmod(x + shift, 12) < 5
			var c: Color = dark if black else light
			if rng.randf() < 0.07:
				c = c.lightened(0.12) if black else c.darkened(0.07)
			img.set_pixel(x, y, c)


static func _track_marks(img: Image, outer: Rect2, inner: Rect2, start_x: float, grid: Array) -> void:
	# Lignes de rive blanches, à 12 px des bordures.
	_rect_line(img, outer.grow(-12.0), LINE)
	_rect_line(img, inner.grow(12.0), LINE)
	# Axe jaune tireté sur la boucle.
	var c0: Vector2 = Vector2(330, 320)
	var c1: Vector2 = Vector2(1590, 760)
	_dash(img, Vector2(c0.x, c0.y), Vector2(c1.x, c0.y))
	_dash(img, Vector2(c1.x, c0.y), Vector2(c1.x, c1.y))
	_dash(img, Vector2(c1.x, c1.y), Vector2(c0.x, c1.y))
	_dash(img, Vector2(c0.x, c1.y), Vector2(c0.x, c0.y))
	# Traces de gomme dans les quatre virages.
	var corners: Array = [
		[inner.position, PI, 1.5 * PI], [Vector2(inner.end.x, inner.position.y), 1.5 * PI, TAU],
		[inner.end, 0.0, 0.5 * PI], [Vector2(inner.position.x, inner.end.y), 0.5 * PI, PI],
	]
	for cdef in corners:
		var cc: Vector2 = cdef[0]
		for rr in [24.0, 32.0, 44.0]:
			var steps: int = int(rr * 1.6)
			for i in steps:
				if (i / 5) % 3 == 2:
					continue
				var a: float = lerpf(cdef[1], cdef[2], float(i) / float(steps))
				var p: Vector2 = Vector2(nx(cc.x), ny(cc.y)) + Vector2(cos(a), sin(a)) * rr
				if img.get_pixel(clampi(int(p.x), 0, W - 1), clampi(int(p.y), 0, H - 1)).r < 0.4:
					_px(img, int(p.x), int(p.y), SKID)
	# Vibreurs rouge/blanc aux coins (intérieur et extérieur).
	_kerb_corner(img, Vector2i(nx(outer.position.x), ny(outer.position.y)), 1, 1)
	_kerb_corner(img, Vector2i(nx(outer.end.x), ny(outer.position.y)), -1, 1)
	_kerb_corner(img, Vector2i(nx(outer.end.x), ny(outer.end.y)), -1, -1)
	_kerb_corner(img, Vector2i(nx(outer.position.x), ny(outer.end.y)), 1, -1)
	_kerb_corner(img, Vector2i(nx(inner.position.x), ny(inner.position.y)), -1, -1)
	_kerb_corner(img, Vector2i(nx(inner.end.x), ny(inner.position.y)), 1, -1)
	_kerb_corner(img, Vector2i(nx(inner.end.x), ny(inner.end.y)), 1, 1)
	_kerb_corner(img, Vector2i(nx(inner.position.x), ny(inner.end.y)), -1, 1)
	# Ligne de départ/arrivée en damier (3 colonnes).
	var sx: int = nx(start_x) - 4
	for y in range(ny(outer.position.y), ny(inner.position.y)):
		for col in 3:
			var dark: bool = ((y - ny(outer.position.y)) / 3 + col) % 2 == 0
			_box(img, sx + col * 3, y, sx + col * 3 + 3, y + 1, DARK if dark else LINE)
	# Cases de la grille : un crochet blanc devant chaque voiture.
	for g in grid:
		var gp: Vector2 = g
		var fx: int = nx(gp.x + 38.0)
		var gy0: int = ny(gp.y - 20.0)
		var gy1: int = ny(gp.y + 20.0)
		_box(img, fx, gy0, fx + 1, gy1, LINE)
		_box(img, fx - 4, gy0, fx, gy0 + 1, LINE)
		_box(img, fx - 4, gy1 - 1, fx, gy1, LINE)


static func _rect_line(img: Image, r: Rect2, c: Color) -> void:
	var x0: int = nx(r.position.x)
	var y0: int = ny(r.position.y)
	var x1: int = nx(r.end.x)
	var y1: int = ny(r.end.y)
	_box(img, x0, y0, x1, y0 + 1, c)
	_box(img, x0, y1 - 1, x1, y1, c)
	_box(img, x0, y0, x0 + 1, y1, c)
	_box(img, x1 - 1, y0, x1, y1, c)


static func _dash(img: Image, a: Vector2, b: Vector2) -> void:
	var na: Vector2 = Vector2(nx(a.x), ny(a.y))
	var nb: Vector2 = Vector2(nx(b.x), ny(b.y))
	var len: int = int(na.distance_to(nb))
	var d: Vector2 = (nb - na) / maxf(float(len), 1.0)
	var side: Vector2 = Vector2(-d.y, d.x)
	for i in len:
		if i % 11 >= 6:
			continue
		var p: Vector2 = na + d * i
		_px(img, int(p.x), int(p.y), YEL)
		_px(img, int(p.x + side.x), int(p.y + side.y), YEL)


# Vibreur en L : deux bras de 24 px natifs, 3 d'épaisseur, tournés vers (sx, sy).
static func _kerb_corner(img: Image, c: Vector2i, sx: int, sy: int) -> void:
	for i in 24:
		for t in 3:
			var col: Color = KERB_R if (i / 3) % 2 == 0 else LINE
			_px(img, c.x + sx * i, c.y + sy * t if sy > 0 else c.y + sy * t - 1, col)
			_px(img, c.x + sx * t if sx > 0 else c.x + sx * t - 1, c.y + sy * i, col)


static func _ciclovia(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(CICLO_Y)
	var y1: int = ny(CALC_Y)
	_box(img, 0, y0, W, y1, CICLO)
	for i in 1500:
		img.set_pixel(rng.randi_range(0, W - 1), rng.randi_range(y0, y1 - 1), CICLO.darkened(0.1) if i % 2 else CICLO.lightened(0.07))
	_box(img, 0, y0, W, y0 + 1, CURB_L)
	_box(img, 0, y0 + 1, W, y0 + 2, CURB_D)
	var mid: int = ny((CICLO_Y + CALC_Y) * 0.5)
	for x in range(0, W, 9):
		_box(img, x, mid, x + 5, mid + 1, LINE)
	_box(img, 0, y1 - 1, W, y1, CICLO.darkened(0.3))


static func _calcadao(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(CALC_Y)
	var y1: int = ny(SAND_Y)
	_mosaic(img, rng, 0, y0, W, y1)
	# Quiosques de praia, hors du circuit.
	for kx in [-330.0, 1960.0]:
		var x0: int = nx(kx)
		var top: int = y0 + 2
		_box(img, x0, top + 6, x0 + 30, top + 13, WOOD)
		_box(img, x0, top + 12, x0 + 30, top + 13, WOOD.darkened(0.35))
		_box(img, x0 + 3, top + 7, x0 + 27, top + 9, SHOP)
		for i in 30:
			_box(img, x0 + i, top, x0 + i + 1, top + 6, KIOSK_ROOF if (i / 3) % 2 == 0 else MOSAIC_W)
		_box(img, x0 - 1, top + 5, x0 + 31, top + 6, KIOSK_ROOF.darkened(0.3))


static func _sand(img: Image, rng: RandomNumberGenerator) -> void:
	var y0: int = ny(SAND_Y)
	var y1: int = ny(SEA_Y)
	var sand_col: Color = Cfg.SAND_COLOR.lerp(Color(1.0, 0.72, 0.52), 0.18)
	var tile: Image = GroundPainter.sand(sand_col, 5).get_image()
	if tile.get_format() != Image.FORMAT_RGBA8:
		tile.convert(Image.FORMAT_RGBA8)
	var tw: int = tile.get_width()
	for x in range(0, W, tw):
		img.blit_rect(tile, Rect2i(0, 0, mini(tw, W - x), mini(tile.get_height(), y1 - y0)), Vector2i(x, y0))
	_box(img, 0, y0, W, y0 + 1, sand_col.darkened(0.25))
	# Sable mouillé et frange d'écume (la mer animée commence juste dessous).
	for y in range(y1 - 3, y1):
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.14))
	for x in W:
		if rng.randf() < 0.55:
			_px(img, x, y1 - 1, MOSAIC_W)
		if rng.randf() < 0.18:
			_px(img, x, y1 - 2, MOSAIC_W)
	# Cangas étendues.
	var cangas: Array = [AWNINGS[0], AWNINGS[2], AWNINGS[3], Color(0.6, 0.3, 0.7)]
	for i in 7:
		var x: int = rng.randi_range(4, W - 12)
		var y: int = rng.randi_range(y0 + 3, y1 - 10)
		var col: Color = cangas[i % cangas.size()]
		_box(img, x, y, x + 8, y + 5, col)
		_box(img, x, y + 2, x + 8, y + 3, col.lightened(0.35))


# Bouts de l'avenue fermés : zébras jaunes (zone lente) + muret de cônes.
static func _closures(img: Image, outer: Rect2) -> void:
	for side in [-1, 1]:
		var x0: int = nx(outer.position.x - 60.0) if side < 0 else nx(outer.end.x)
		var x1: int = nx(outer.position.x) if side < 0 else nx(outer.end.x + 60.0)
		var y0: int = ny(NORTH_CURB)
		var y1: int = ny(CICLO_Y)
		for y in range(y0, y1):
			for x in range(x0, x1):
				img.set_pixel(x, y, YEL if posmod(x + y * side, 8) < 3 else ASPH_D)
		_box(img, x0, y0, x0 + 1, y1, LINE)
		_box(img, x1 - 1, y0, x1, y1, LINE)
		# Cônes, côté extérieur.
		var cx: int = x0 - 4 if side < 0 else x1 + 1
		for y in range(y0 + 1, y1 - 3, 6):
			_box(img, cx, y + 3, cx + 3, y + 4, DARK)
			_box(img, cx, y, cx + 3, y + 3, CONE)
			_box(img, cx, y + 1, cx + 3, y + 2, MOSAIC_W)
			_px(img, cx, y, CONE.lightened(0.3))


# Grades rouge/blanc qui retiennent le public, au nord et côté plage.
static func _barriers(img: Image, outer: Rect2) -> void:
	var x0: int = nx(outer.position.x - 60.0)
	var x1: int = nx(outer.end.x + 60.0)
	for wy in [168.0, 902.0]:
		var y: int = ny(wy)
		_box(img, x0, y + 3, x1, y + 4, DARK)
		for x in range(x0, x1):
			var col: Color = KERB_R if ((x - x0) / 5) % 2 == 0 else MOSAIC_W
			_px(img, x, y, col.lightened(0.2))
			_px(img, x, y + 1, col)
			_px(img, x, y + 2, col.darkened(0.15))
		for x in range(x0, x1, 10):
			_box(img, x, y + 3, x + 1, y + 5, POLE)


static func _lamps(img: Image, lamps: Array) -> void:
	for l in lamps:
		var p: Vector2 = l
		var c: Vector2i = Vector2i(nx(p.x), ny(p.y))
		# Halo en paliers (pas de dégradé lisse).
		for dy in range(-14, 15):
			for dx in range(-18, 19):
				var d: float = Vector2(dx, dy * 1.3).length()
				if d <= 10.0:
					_blend(img, c.x + dx, c.y + dy, Color(GLOW, 0.16))
				elif d <= 17.0:
					_blend(img, c.x + dx, c.y + dy, Color(GLOW, 0.08))
	for l in lamps:
		var p: Vector2 = l
		var c: Vector2i = Vector2i(nx(p.x), ny(p.y))
		_box(img, c.x - 1, c.y - 1, c.x + 2, c.y + 1, POLE.darkened(0.3))
		_box(img, c.x, c.y - 12, c.x + 1, c.y, POLE)
		_box(img, c.x - 3, c.y - 12, c.x + 4, c.y - 11, POLE)
		for hx in [-3, 3]:
			_px(img, c.x + hx, c.y - 11, LAMP)
			_blend(img, c.x + hx - 1, c.y - 11, Color(LAMP, 0.45))
			_blend(img, c.x + hx + 1, c.y - 11, Color(LAMP, 0.45))
			_blend(img, c.x + hx, c.y - 10, Color(LAMP, 0.45))


# --- Mer animée --------------------------------------------------------------

static func sea_frames() -> Array:
	if _cache.has("sea"):
		return _cache["sea"]
	var col: Color = Cfg.SEA_COLOR.lerp(Color(0.46, 0.42, 0.64), 0.3)
	var strip: Image = GroundPainter.sea(col, 9).get_image()
	var h: int = strip.get_height()
	var frames: Array = []
	for f in GroundPainter.SEA_FRAMES:
		frames.append(ImageTexture.create_from_image(strip.get_region(Rect2i(f * h, 0, h, h))))
	_cache["sea"] = frames
	return frames


# --- Voitures ----------------------------------------------------------------

# Bande de CAR_DIRS caps (cellules CAR_F × CAR_F natives), cap 0 = vers +x.
static func car_strip(body: Color, stripe: Color) -> ImageTexture:
	var key: String = "car_%s_%s" % [body.to_html(false), stripe.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(CAR_F * CAR_DIRS, CAR_F, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in CAR_DIRS:
		_car_frame(img, f * CAR_F, TAU * float(f) / float(CAR_DIRS), body, stripe)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Couleur d'un point du repère voiture (avant = +x), ou alpha 0 hors carrosserie.
static func _car_local(lx: float, ly: float, body: Color, stripe: Color) -> Color:
	var ax: float = absf(lx)
	var ay: float = absf(ly)
	var wheel: bool = ax >= 4.5 and ax <= 8.5 and ay < 6.0 and ay >= 4.0
	var inside: bool = ax < 11.0 and ay < 5.0 and not (ax > 9.6 and ay > 3.6)
	if not inside:
		return TIRE if wheel else Color(0, 0, 0, 0)
	if lx > 9.8 and ay >= 1.8 and ay < 4.0:
		return HEADLIGHT
	if lx < -10.0 and ay >= 1.8 and ay < 4.0:
		return TAIL
	if ay < 3.6:
		if lx >= 1.8 and lx < 4.6:
			return GLASS_HI if (ly < -1.0 and lx > 3.4) else GLASS
		if lx >= -7.2 and lx < -4.8:
			return GLASS
		if lx >= -4.8 and lx < 1.8:
			return body.lightened(0.12)       # toit
	elif lx >= -4.8 and lx < 2.4:
		return GLASS.darkened(0.25)           # vitres latérales
	if ay < 1.3 and (lx >= 4.6 or lx < -7.2):
		return stripe
	return body


static func _car_frame(img: Image, ox: int, ang: float, body: Color, stripe: Color) -> void:
	var half: float = CAR_F * 0.5
	var cs: float = cos(ang)
	var sn: float = sin(ang)
	var cols: Array = []
	cols.resize(CAR_F * CAR_F)
	var beam: PackedFloat32Array = PackedFloat32Array()
	beam.resize(CAR_F * CAR_F)
	for y in CAR_F:
		for x in CAR_F:
			var cx: float = x + 0.5 - half
			var cy: float = y + 0.5 - half
			var lx: float = cx * cs + cy * sn
			var ly: float = -cx * sn + cy * cs
			cols[y * CAR_F + x] = _car_local(lx, ly, body, stripe)
			# Faisceau des phares, en deux paliers.
			if lx > 11.5 and lx < 19.0 and absf(ly) < 2.6 + (lx - 11.0) * 0.45:
				beam[y * CAR_F + x] = 0.24 if lx < 15.0 else 0.12
	var solid: Callable = func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= CAR_F or y >= CAR_F:
			return false
		return (cols[y * CAR_F + x] as Color).a > 0.5
	for y in CAR_F:
		for x in CAR_F:
			var c: Color = cols[y * CAR_F + x]
			if c.a > 0.5:
				# Lumière du couchant : arête haute éclairée, bas ombré.
				if c == body or c == stripe:
					if not solid.call(x, y - 1):
						c = c.lightened(0.22)
					elif not solid.call(x, y + 1):
						c = c.darkened(0.3)
				img.set_pixel(ox + x, y, c)
			elif solid.call(x - 1, y) or solid.call(x + 1, y) or solid.call(x, y - 1) or solid.call(x, y + 1):
				img.set_pixel(ox + x, y, OUTLINE)
			elif solid.call(x - 1, y - 2) or solid.call(x - 2, y - 2):
				img.set_pixel(ox + x, y, Color(0, 0, 0, 0.35))   # ombre portée
			elif beam[y * CAR_F + x] > 0.0:
				img.set_pixel(ox + x, y, Color(HEADLIGHT, beam[y * CAR_F + x]))


# --- Petits sprites ----------------------------------------------------------

# Double chevron « >> » (vers +x), contour sombre.
static func chevron() -> ImageTexture:
	if _cache.has("chevron"):
		return _cache["chevron"]
	var img: Image = Image.create(13, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ox in [2, 6]:
		for r in 7:
			var d: int = absi(r - 3)
			_px(img, ox + d, r + 2, Color.WHITE)
			_px(img, ox + d + 1, r + 2, Color.WHITE)
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["chevron"] = tex
	return tex


# Flèche « c'est toi » au-dessus de la voiture du joueur.
static func marker() -> ImageTexture:
	if _cache.has("marker"):
		return _cache["marker"]
	var img: Image = Image.create(9, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in 4:
		_box(img, 1 + r, 1 + r, 8 - r, 2 + r, YEL if r > 0 else YEL.lightened(0.4))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["marker"] = tex
	return tex


# Drapeau à damier, 2 frames (le tissu ondule).
static func flag() -> ImageTexture:
	if _cache.has("flag"):
		return _cache["flag"]
	var img: Image = Image.create(24, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in 2:
		var ox: int = f * 12
		_box(img, ox + 1, 1, ox + 2, 15, Color(0.75, 0.72, 0.68))
		for x in 8:
			var wave: int = (1 if ((x + f * 2) / 2) % 2 == 0 else 0)
			for y in 6:
				var dark: bool = (x / 2 + y / 2) % 2 == 0
				_px(img, ox + 2 + x, 1 + y + wave, DARK if dark else Color.WHITE)
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["flag"] = tex
	return tex


static func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
