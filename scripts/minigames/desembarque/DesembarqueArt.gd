extends RefCounted

# Peintre pixel-art du Desembarque (aucune règle ici) : le hall d'arrivée du
# Santos Dumont — baies vitrées sur la baie et le Pão de Açúcar, panneau des
# vols, porte coulissante, sol en granito poli, garde-corps et faixa amarela,
# pancartes des chauffeurs, plaque de táxi du joueur. Tout est peint une fois
# en pixels natifs affichés ×3 (NEAREST), textures en cache.
# Calques : dehors (ciel, baie, couloir derrière la porte) < avion et vantaux
# < hall (vitres translucides, trou de la porte) < figurants < garde-corps.

const N: int = 3
const ORIGIN: Vector2 = Vector2(-1200, -560)
const W: int = 800
const H: int = 374
const WALL_B: int = 77          # bas du mur = ligne de sortie des passagers (y −329)
const WIN_T: int = 5
const WIN_B: int = 61
# Porte du desembarque (natif) : bloc maçonné et ouverture vitrée.
const DOOR_X0: int = 430
const DOOR_X1: int = 545
const OPEN_X0: int = 446
const OPEN_X1: int = 530
const OPEN_T: int = 24
const PILLAR_X0: int = 402
const PILLAR_X1: int = 426
const BOARD: Rect2i = Rect2i(549, 9, 162, 44)
const RAIL_TOP: int = 84
const RAIL_FRONT: int = 243
const RAIL_L: int = 437
const RAIL_R: int = 537

const INK: Color = Color(0.13, 0.10, 0.12)
const STONE: Color = Color(0.89, 0.87, 0.82)
const STONE_D: Color = Color(0.78, 0.76, 0.72)
const STEEL: Color = Color(0.30, 0.33, 0.39)
const STEEL_HI: Color = Color(0.55, 0.59, 0.66)
const CHROME: Color = Color(0.86, 0.89, 0.93)
const CHROME_D: Color = Color(0.52, 0.56, 0.62)
const GRANITO: Color = Color(0.80, 0.78, 0.74)
const YELLOW: Color = Color(0.98, 0.80, 0.16)
const TAXI_BLUE: Color = Color(0.16, 0.30, 0.66)
const BOARD_BG: Color = Color(0.07, 0.08, 0.11)
const LED_Y: Color = Color(1.0, 0.82, 0.18)
const LED_W: Color = Color(0.95, 0.95, 0.92)
const LED_G: Color = Color(0.40, 0.92, 0.45)
const PAPER: Color = Color(0.99, 0.98, 0.94)
const PAPER_D: Color = Color(0.86, 0.84, 0.78)

# Plaque du joueur (monde) : coin haut-gauche et pastilles calées sur la grille ×3.
const CARD_POS: Vector2 = Vector2(-900, -440)
const CARD_NW: int = 214
const CARD_NH: int = 140
const CHIP_NX: Array[int] = [7, 77, 147]
const CHIP_NY: int = 56
const CHIP_NW: int = 60
const CHIP_NH: int = 44

static var _cache: Dictionary = {}


static func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(c))


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


# Lettrage pixel : glyphes 5×7 de PixelFont (accents compris), 1 px d'espace.
static func _text(img: Image, x: int, y: int, s: String, c: Color, k: int = 1) -> void:
	var cx: int = x
	for ch in s:
		if ch == " ":
			cx += 3 * k
			continue
		var rows: Array = PixelFont._rows(ch)
		if rows.is_empty():
			cx += 4 * k
			continue
		var gw: int = 0
		for r in rows.size():
			var row: String = rows[r]
			gw = maxi(gw, row.length())
			for i in row.length():
				if row[i] == "#":
					_fr(img, cx + i * k, y + (r - 2) * k, k, k, c)
		cx += (gw + 1) * k


static func text_width(s: String, k: int = 1) -> int:
	var w: int = 0
	for ch in s:
		if ch == " ":
			w += 3
			continue
		var rows: Array = PixelFont._rows(ch)
		var gw: int = 3
		for row in rows:
			gw = maxi(gw, (row as String).length())
		w += gw + 1
	return (w - 1) * k


static func _outline(img: Image, c: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixelv(q).a > 0.5:
					img.set_pixel(x, y, c)
					break


static func _tex(key: String, img: Image) -> ImageTexture:
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func layer(tex: Texture2D, pos: Vector2, z: int, scale_px: float = N) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.scale = Vector2(scale_px, scale_px)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	return s


static func world(nx: int, ny: int) -> Vector2:
	return ORIGIN + Vector2(nx * N, ny * N)


# --- Dehors : ciel, Niterói, Pão de Açúcar, baie, pista ; couloir derrière la porte ---

static func outside() -> ImageTexture:
	if _cache.has("outside"):
		return _cache["outside"]
	var img: Image = Image.create(W, WALL_B, false, Image.FORMAT_RGBA8)
	var bands: Array[Color] = [Color(0.36, 0.62, 0.90), Color(0.44, 0.69, 0.93), Color(0.54, 0.77, 0.96),
		Color(0.66, 0.84, 0.97), Color(0.78, 0.90, 0.98)]
	var limits: Array[int] = [10, 19, 27, 34]
	for r in WALL_B:
		var b: int = 0
		while b < limits.size() and r >= limits[b]:
			b += 1
		_fr(img, 0, r, W, 1, bands[b])
		# Tramage d'une rangée entre deux bandes (dégradé GBA).
		if b < limits.size() and limits[b] - r == 1:
			for x in range(r % 2, W, 2):
				img.set_pixel(x, r, bands[b + 1])
	for c: Vector3i in [Vector3i(60, 12, 26), Vector3i(250, 8, 18), Vector3i(520, 15, 30), Vector3i(700, 7, 20)]:
		_cloud(img, c.x, c.y, c.z)
	# Niterói au loin.
	var hz: int = 44
	var hill: Color = Color(0.56, 0.66, 0.80)
	var hill_hi: Color = Color(0.68, 0.76, 0.88)
	for x in W:
		var hh: float = 4.0 + 3.0 * sin(x * 0.021) + 2.0 * sin(x * 0.057 + 1.2)
		var top: int = hz - int(hh)
		_fr(img, x, top, 1, hz - top + 1, hill)
		_px(img, x, top, hill_hi)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 51
	for i in 90:
		var bx: int = rng.randi_range(0, W - 2)
		var bh: int = rng.randi_range(1, 2)
		_fr(img, bx, hz - bh + 1, rng.randi_range(1, 2), bh, Color(0.84, 0.87, 0.93))
	# Baie de Guanabara.
	var bay: Color = Color(0.22, 0.52, 0.72)
	_fr(img, 0, hz + 1, W, WALL_B - hz - 1, bay)
	_fr(img, 0, hz + 1, W, 1, bay.lightened(0.3))
	for i in 140:
		var sx: int = rng.randi_range(0, W - 4)
		var sy: int = rng.randi_range(hz + 2, 56)
		_fr(img, sx, sy, rng.randi_range(2, 4), 1, bay.lightened(0.28 if i % 3 else 0.5))
	# Morro da Urca puis Pão de Açúcar, plantés dans l'eau à gauche de la porte.
	var rock: Color = Color(0.56, 0.55, 0.60)
	var veg: Color = Color(0.27, 0.50, 0.36)
	var urca: Image = GroundPainter.dome(46, 16, rock, veg, 5).get_image()
	img.blend_rect(urca, Rect2i(0, 0, 46, 16), Vector2i(300, hz + 3 - 16))
	var pao: Image = GroundPainter.dome(28, 36, rock, veg, 3).get_image()
	img.blend_rect(pao, Rect2i(0, 0, 28, 36), Vector2i(346, hz + 3 - 36))
	# Câble du bondinho Urca → Pão.
	var a: Vector2 = Vector2(323, hz - 12)
	var b2: Vector2 = Vector2(359, hz - 32)
	for i in 41:
		var p: Vector2 = a.lerp(b2, float(i) / 40.0)
		_px(img, int(p.x), int(p.y), Color(0.25, 0.25, 0.3))
	_fr(img, 340, hz - 22, 3, 2, Color(0.96, 0.78, 0.3))
	# Voiliers.
	for v: Vector2i in [Vector2i(140, 51), Vector2i(470, 49), Vector2i(640, 53), Vector2i(760, 50)]:
		_fr(img, v.x - 2, v.y, 6, 1, INK)
		for i in 4:
			_fr(img, v.x + 1 - i / 2, v.y - 4 + i, i / 2 + 1, 1, PAPER)
	# Pista du Santos Dumont : tarmac, axe blanc, jet garé (sans compagnie réelle).
	_fr(img, 0, 56, W, WALL_B - 56, Color(0.43, 0.44, 0.47))
	_fr(img, 0, 56, W, 1, Color(0.58, 0.60, 0.63))
	for x in range(0, W, 14):
		_fr(img, x, 59, 7, 1, Color(0.95, 0.95, 0.92))
	var jet: Image = plane_image()
	img.blend_rect(jet, Rect2i(0, 0, jet.get_width(), jet.get_height()), Vector2i(640, 48))
	img.blend_rect(jet, Rect2i(0, 0, jet.get_width(), jet.get_height()), Vector2i(90, 49))
	_paint_corridor(img)
	return _tex("outside", img)


static func _cloud(img: Image, cx: int, cy: int, wn: int) -> void:
	var white: Color = Color(1, 1, 1)
	var under: Color = Color(0.84, 0.91, 0.98)
	_fr(img, cx - wn / 2, cy, wn, 2, white)
	_fr(img, cx - wn / 2 + 2, cy + 2, wn - 4, 1, under)
	_fr(img, cx - wn / 3, cy - 2, wn / 3, 2, white)
	_fr(img, cx - wn / 10, cy - 4, wn / 3, 4, white)
	_fr(img, cx + wn / 4, cy - 2, wn / 5, 2, white)


# Couloir de la zone de bagages derrière la porte : murs en fuite, fond éclairé.
static func _paint_corridor(img: Image) -> void:
	var x0: int = OPEN_X0 - 4
	var x1: int = OPEN_X1 + 4
	_fr(img, x0, OPEN_T - 4, x1 - x0, WALL_B - OPEN_T + 4, Color(0.42, 0.45, 0.52))
	var cx: int = (OPEN_X0 + OPEN_X1) / 2
	var end: Rect2i = Rect2i(cx - 22, OPEN_T + 6, 44, 30)
	# Plafond, murs, sol en trapèzes vers le fond.
	for y in range(OPEN_T - 4, end.position.y):
		_fr(img, x0, y, x1 - x0, 1, Color(0.30, 0.32, 0.38))
	for y in range(end.end.y, WALL_B):
		var k: float = float(y - end.end.y) / float(WALL_B - end.end.y)
		_fr(img, x0, y, x1 - x0, 1, Color(0.62, 0.62, 0.64).lerp(Color(0.72, 0.71, 0.70), k))
	_fr(img, end.position.x, end.position.y, end.size.x, end.size.y, Color(0.88, 0.91, 0.94))
	# Tapis à bagages au fond, avec deux valises.
	_fr(img, end.position.x + 2, end.end.y - 8, end.size.x - 4, 4, Color(0.18, 0.18, 0.2))
	_fr(img, end.position.x + 8, end.end.y - 12, 6, 4, Color(0.75, 0.2, 0.25))
	_fr(img, end.position.x + 26, end.end.y - 11, 7, 3, Color(0.25, 0.45, 0.75))
	# Néons au plafond.
	for i in 3:
		_fr(img, cx - 14 + i * 12, OPEN_T - 1 + i, 5, 1, Color(0.95, 0.97, 1.0))


# --- Hall : mur à baies vitrées, porte, pilier à horloge, panneau des vols, granito ---

static func hall() -> ImageTexture:
	if _cache.has("hall"):
		return _cache["hall"]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	_paint_wall(img)
	_paint_door_block(img)
	_paint_pillar(img)
	_paint_board(img)
	_paint_floor(img, rng)
	return _tex("hall", img)


static func _is_window(x: int, y: int) -> bool:
	if y < WIN_T or y >= WIN_B:
		return false
	if x >= DOOR_X0 and x < DOOR_X1:
		return false
	if x >= PILLAR_X0 and x < PILLAR_X1:
		return false
	return true


static func _paint_wall(img: Image) -> void:
	_fr(img, 0, 0, W, WALL_B, STONE)
	# Plafond : dalle sombre et spots.
	_fr(img, 0, 0, W, WIN_T, Color(0.28, 0.29, 0.33))
	_fr(img, 0, WIN_T - 1, W, 1, Color(0.18, 0.19, 0.22))
	for x in range(8, W, 24):
		_fr(img, x, 1, 4, 1, Color(1.0, 0.97, 0.82))
	# Vitres : teinte légère + reflets obliques (le dehors se voit à travers).
	var tint: Color = Color(0.78, 0.92, 1.0, 0.14)
	var streak: Color = Color(1, 1, 1, 0.28)
	for y in range(WIN_T, WIN_B):
		for x in W:
			if not _is_window(x, y):
				continue
			var c: Color = tint
			var d: int = posmod(x + y, 46)
			if d < 3 or d == 7:
				c = streak
			img.set_pixel(x, y, c)
	# Montants et traverse d'acier.
	for x in range(0, W, 40):
		for y in range(WIN_T, WIN_B):
			if _is_window(x, y) or _is_window(x + 1, y):
				_px(img, x, y, STEEL)
				_px(img, x + 1, y, STEEL_HI)
	for x in W:
		if _is_window(x, 33):
			_px(img, x, 33, STEEL)
			_px(img, x, 34, STEEL_HI)
	# Appui, parement en pierre, plinthe en granit sombre.
	_fr(img, 0, WIN_B, W, 2, STEEL)
	_fr(img, 0, WIN_B, W, 1, STEEL_HI)
	for x in range(0, W, 30):
		_fr(img, x, WIN_B + 2, 1, WALL_B - WIN_B - 6, STONE_D)
	_fr(img, 0, 68, W, 1, STONE_D)
	_fr(img, 0, WALL_B - 4, W, 4, Color(0.34, 0.33, 0.35))
	_fr(img, 0, WALL_B - 4, W, 1, Color(0.50, 0.49, 0.51))


static func _paint_door_block(img: Image) -> void:
	_fr(img, DOOR_X0, 0, DOOR_X1 - DOOR_X0, WALL_B - 4, Color(0.93, 0.92, 0.88))
	_fr(img, DOOR_X0, 0, 2, WALL_B - 4, STONE_D)
	_fr(img, DOOR_X1 - 2, 0, 2, WALL_B - 4, STONE_D)
	# Bandeau « DESEMBARQUE » lettres jaunes sur fond bleu nuit.
	_fr(img, DOOR_X0 + 3, 6, DOOR_X1 - DOOR_X0 - 6, 13, Color(0.10, 0.13, 0.22))
	_fr(img, DOOR_X0 + 3, 18, DOOR_X1 - DOOR_X0 - 6, 1, Color(0.05, 0.06, 0.1))
	var label: String = "DESEMBARQUE"
	var tw: int = text_width(label)
	var tx: int = (DOOR_X0 + DOOR_X1) / 2 - tw / 2 + 4
	_text(img, tx, 9, label, LED_Y)
	# Pictogramme « avion qui atterrit ».
	var px0: int = tx - 11
	_fr(img, px0, 12, 7, 1, LED_Y)
	_fr(img, px0 + 2, 10, 2, 2, LED_Y)
	_fr(img, px0 + 1, 13, 2, 1, LED_Y)
	_fr(img, px0, 15, 8, 1, LED_Y)
	# Ouverture : cadre inox, l'intérieur reste transparent (couloir + vantaux).
	_fr(img, OPEN_X0 - 2, OPEN_T - 2, OPEN_X1 - OPEN_X0 + 4, WALL_B - OPEN_T + 2, CHROME_D)
	_fr(img, OPEN_X0 - 2, OPEN_T - 2, OPEN_X1 - OPEN_X0 + 4, 1, CHROME)
	_fr(img, OPEN_X0, OPEN_T, OPEN_X1 - OPEN_X0, WALL_B - OPEN_T, Color(0, 0, 0, 0))
	# Capteur de la porte automatique.
	_fr(img, (OPEN_X0 + OPEN_X1) / 2 - 3, OPEN_T - 4, 6, 2, INK)
	_px(img, (OPEN_X0 + OPEN_X1) / 2 + 1, OPEN_T - 4, Color(1.0, 0.3, 0.2))


static func _paint_pillar(img: Image) -> void:
	_fr(img, PILLAR_X0, WIN_T, PILLAR_X1 - PILLAR_X0, WALL_B - 4 - WIN_T, Color(0.84, 0.83, 0.80))
	_fr(img, PILLAR_X0, WIN_T, 2, WALL_B - 4 - WIN_T, Color(0.95, 0.94, 0.91))
	_fr(img, PILLAR_X1 - 2, WIN_T, 2, WALL_B - 4 - WIN_T, STONE_D)
	# Horloge de gare : cadran blanc, aiguilles à 14 h 05 (l'heure du panneau).
	var cx: int = (PILLAR_X0 + PILLAR_X1) / 2
	var cy: int = 46
	_ellipse(img, cx, cy, 9.5, 9.5, INK)
	_ellipse(img, cx, cy, 8.0, 8.0, Color(0.98, 0.98, 0.96))
	for i in 12:
		var ang: float = TAU * float(i) / 12.0
		_px(img, cx + int(round(cos(ang) * 6.5)), cy + int(round(sin(ang) * 6.5)), INK)
	for i in 5:
		var ang_m: float = TAU * (5.0 / 60.0) - PI / 2.0
		_px(img, cx + int(round(cos(ang_m) * i)), cy + int(round(sin(ang_m) * i)), INK)
	for i in 4:
		var ang_h: float = TAU * (2.08 / 12.0) - PI / 2.0
		_px(img, cx + int(round(cos(ang_h) * i)), cy + int(round(sin(ang_h) * i)), INK)
	_px(img, cx, cy, Color(0.85, 0.15, 0.15))


static func _paint_board(img: Image) -> void:
	var b: Rect2i = BOARD
	# Tiges de suspension.
	_fr(img, b.position.x + 14, 0, 1, b.position.y, STEEL)
	_fr(img, b.end.x - 15, 0, 1, b.position.y, STEEL)
	_fr(img, b.position.x - 1, b.position.y - 1, b.size.x + 2, b.size.y + 2, INK)
	_fr(img, b.position.x, b.position.y, b.size.x, b.size.y, Color(0.22, 0.24, 0.28))
	_fr(img, b.position.x + 2, b.position.y + 2, b.size.x - 4, b.size.y - 4, BOARD_BG)
	var x0: int = b.position.x + 5
	_fr(img, b.position.x + 2, b.position.y + 2, b.size.x - 4, 10, Color(0.12, 0.2, 0.42))
	_text(img, x0, b.position.y + 4, "PONTE AÉREA · CHEGADAS", LED_W)
	var lines: Array = [
		["14:05", "SÃO PAULO", "ATERRISSADO", LED_Y],
		["14:20", "BRASÍLIA", "CONFIRMADO", LED_W],
		["14:40", "CONGONHAS", "PREVISTO", LED_W],
	]
	var city_x: int = x0 + text_width("14:05") + 5
	var status_x: int = city_x
	for l in lines:
		status_x = maxi(status_x, city_x + text_width(l[1]) + 10)
	for i in lines.size():
		var y: int = b.position.y + 15 + i * 9
		var l: Array = lines[i]
		_text(img, x0, y, l[0], LED_W)
		_text(img, city_x, y, l[1], LED_Y)
		_text(img, status_x, y, l[2], l[3])
	# Lignes de balayage des LED.
	for y in range(b.position.y + 2, b.end.y - 2, 2):
		_blend(img, b.position.x + 2, y, b.size.x - 4, 1, Color(0, 0, 0, 0.18))


# Granito poli : mouchetis, grandes dalles, reflets des baies.
static func _paint_floor(img: Image, rng: RandomNumberGenerator) -> void:
	_fr(img, 0, WALL_B, W, H - WALL_B, GRANITO)
	var specks: Array[Color] = [Color(0.66, 0.64, 0.62), Color(0.90, 0.89, 0.86),
		Color(0.56, 0.52, 0.50), Color(0.74, 0.70, 0.64)]
	for i in 26000:
		var x: int = rng.randi_range(0, W - 1)
		var y: int = rng.randi_range(WALL_B, H - 1)
		img.set_pixel(x, y, specks[i % specks.size()])
	for y in range(WALL_B + 22, H, 30):
		_fr(img, 0, y, W, 1, Color(0.70, 0.68, 0.65))
		_fr(img, 0, y + 1, W, 1, Color(0.88, 0.87, 0.84))
	for y in range(WALL_B, H, 30):
		var off: int = 0 if ((y - WALL_B) / 30) % 2 == 0 else 32
		for x in range(off, W, 64):
			_fr(img, x, maxi(y - 8, WALL_B), 1, 30, Color(0.72, 0.70, 0.67))
	# Reflets : chaque vitre se mire dans le sol, en s'estompant.
	for x in W:
		var refl: bool = _is_window(x, 30) and posmod(x, 40) > 2
		for y in range(WALL_B, WALL_B + 64):
			var k: float = 1.0 - float(y - WALL_B) / 64.0
			if refl:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(Color(0.85, 0.94, 1.0, 0.30 * k)))
			elif x >= OPEN_X0 and x < OPEN_X1:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(Color(0.2, 0.22, 0.3, 0.22 * k)))
	# Faixa amarela d'attente devant les garde-corps.
	_hazard(img, 300, RAIL_FRONT + 4, RAIL_L - 300, 3)
	_hazard(img, RAIL_R, RAIL_FRONT + 4, 790 - RAIL_R, 3)
	# Bandes jaunes le long de l'allée des passagers.
	_fr(img, RAIL_L + 3, RAIL_TOP, 1, RAIL_FRONT - RAIL_TOP, YELLOW)
	_fr(img, RAIL_R - 3, RAIL_TOP, 1, RAIL_FRONT - RAIL_TOP, YELLOW)
	# Repère au sol : c'est là que le passager s'arrête devant toi (traces de pas).
	var sx: int = 487
	var sy: int = 286
	for r: Rect2i in [Rect2i(sx - 30, sy - 5, 60, 1), Rect2i(sx - 30, sy + 6, 60, 1),
			Rect2i(sx - 30, sy - 5, 1, 12), Rect2i(sx + 29, sy - 5, 1, 12)]:
		_fr(img, r.position.x, r.position.y, r.size.x, r.size.y, YELLOW)
	for f: Vector2i in [Vector2i(sx - 9, sy - 2), Vector2i(sx + 4, sy - 2)]:
		_fr(img, f.x, f.y, 4, 5, Color(0.92, 0.70, 0.12))
		_fr(img, f.x + 1, f.y - 1, 2, 1, Color(0.92, 0.70, 0.12))
	# Grande faixa de sécurité vers la sortie táxi (bas de l'écran).
	_hazard(img, 0, 326, W, 4)


static func _hazard(img: Image, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var on: bool = posmod(xx + yy, 8) < 4
			_px(img, xx, yy, YELLOW if on else Color(0.16, 0.15, 0.17))
	_fr(img, x, y + h, w, 1, Color(0.62, 0.60, 0.57))


# --- Garde-corps inox (calque avant, par-dessus les chauffeurs) ---

static func rails() -> ImageTexture:
	if _cache.has("rails"):
		return _cache["rails"]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rail_side(img, RAIL_L, RAIL_TOP, RAIL_FRONT)
	_rail_side(img, RAIL_R, RAIL_TOP, RAIL_FRONT)
	_rail_front(img, 300, RAIL_L, RAIL_FRONT)
	_rail_front(img, RAIL_R, 790, RAIL_FRONT)
	return _tex("rails", img)


const POST_H: int = 16


static func _post(img: Image, x: int, y: int) -> void:
	_blend(img, x - 1, y, 4, 1, Color(0, 0, 0.05, 0.25))
	_fr(img, x, y - POST_H, 1, POST_H, CHROME)
	_fr(img, x + 1, y - POST_H, 1, POST_H, CHROME_D)
	_fr(img, x - 1, y - 1, 4, 1, STEEL)


# Garde-corps qui file vers la porte : poteaux qui rapetissent un peu au fond.
static func _rail_side(img: Image, x: int, y0: int, y1: int) -> void:
	for y in range(y1, y0 - 1, -13):
		_post(img, x, y)
	_fr(img, x, y0 - POST_H, 2, y1 - y0 + 1, CHROME)
	_fr(img, x + 1, y0 - POST_H, 1, y1 - y0 + 1, CHROME_D)


static func _rail_front(img: Image, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1, 18):
		_post(img, x, y)
	_post(img, x1, y)
	_fr(img, x0, y - POST_H - 1, x1 - x0 + 2, 1, CHROME)
	_fr(img, x0, y - POST_H, x1 - x0 + 2, 1, CHROME_D)
	# Ruban jaune et noir tendu à mi-hauteur.
	for x in range(x0, x1 + 2):
		var on: bool = posmod(x, 6) < 3
		_px(img, x, y - 9, YELLOW if on else INK)
		_px(img, x, y - 8, YELLOW.darkened(0.25) if on else INK)


# --- Petits sprites ---

# Jet de la ponte aérea (livrée inventée : blanc, bande bleue, dérive jaune).
static func plane_image() -> Image:
	var img: Image = Image.create(32, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body: Color = Color(0.97, 0.97, 0.96)
	_fr(img, 3, 4, 25, 3, body)
	_fr(img, 27, 5, 3, 2, body)
	_px(img, 30, 5, body)
	_fr(img, 3, 6, 25, 1, Color(0.8, 0.82, 0.86))
	_fr(img, 4, 5, 23, 1, TAXI_BLUE)
	for x in range(8, 26, 2):
		_px(img, x, 4, Color(0.3, 0.4, 0.55))
	_fr(img, 1, 1, 4, 4, YELLOW)
	_fr(img, 2, 0, 2, 1, YELLOW)
	_fr(img, 12, 7, 8, 1, Color(0.75, 0.77, 0.80))
	_fr(img, 13, 8, 3, 1, Color(0.55, 0.58, 0.62))
	_outline(img, Color(0.25, 0.28, 0.35))
	return img


static func plane() -> ImageTexture:
	if _cache.has("plane"):
		return _cache["plane"]
	return _tex("plane", plane_image())


# Vantail vitré de la porte coulissante (moitié de l'ouverture).
static func door_panel() -> ImageTexture:
	if _cache.has("door"):
		return _cache["door"]
	var w: int = (OPEN_X1 - OPEN_X0) / 2
	var h: int = WALL_B - OPEN_T
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.62, 0.80, 0.92, 0.45))
	for y in h:
		for x in w:
			if posmod(x + y, 23) < 2:
				img.set_pixel(x, y, Color(1, 1, 1, 0.55))
	_fr(img, 0, 0, w, 2, CHROME_D)
	_fr(img, 0, h - 3, w, 3, CHROME_D)
	_fr(img, 0, 0, 2, h, CHROME)
	_fr(img, w - 2, 0, 2, h, CHROME_D)
	# Bande d'avertissement vitrophanie à hauteur d'yeux.
	_fr(img, 2, 22, w - 4, 2, Color(0.95, 0.95, 0.95, 0.85))
	for x in range(3, w - 3, 4):
		_px(img, x, 22, Color(0.98, 0.80, 0.16, 0.95))
	return _tex("door", img)


static func trolley() -> ImageTexture:
	if _cache.has("trolley"):
		return _cache["trolley"]
	var img: Image = Image.create(34, 30, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Bagages empilés.
	_fr(img, 6, 6, 18, 9, Color(0.20, 0.42, 0.30))
	_fr(img, 7, 7, 16, 1, Color(0.32, 0.58, 0.42))
	_fr(img, 13, 4, 5, 2, INK)
	_fr(img, 5, 15, 22, 6, Color(0.62, 0.36, 0.20))
	_fr(img, 6, 16, 20, 1, Color(0.76, 0.48, 0.28))
	_fr(img, 15, 15, 1, 6, Color(0.40, 0.22, 0.12))
	# Chariot inox.
	_fr(img, 3, 21, 26, 2, CHROME)
	_fr(img, 3, 23, 26, 1, CHROME_D)
	_fr(img, 28, 2, 2, 21, CHROME)
	_fr(img, 26, 1, 6, 2, Color(0.85, 0.2, 0.2))
	for wx in [5, 25]:
		_fr(img, wx, 24, 3, 3, INK)
	_outline(img, INK)
	return _tex("trolley", img)


# Pancarte d'un chauffeur de la cooperativa : nom griffonné au marqueur.
static func driver_sign(kind: int) -> ImageTexture:
	var key: String = "sign_%d" % kind
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(28, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 1, 1, 26, 12, PAPER)
	_fr(img, 1, 12, 26, 1, PAPER_D)
	var words: Array[String] = ["SR. LIMA", "TÁXI", "DRA. ANA", "SILVA", "HOTEL", "GOMES"]
	var ink: Array[Color] = [INK, Color(0.75, 0.12, 0.12), Color(0.12, 0.25, 0.6)]
	var s: String = words[kind % words.size()]
	var w: int = text_width(s)
	if w <= 24:
		_text(img, 14 - w / 2, 4, s, ink[kind % ink.size()])
	else:
		_fr(img, 4, 5, 20, 2, ink[kind % ink.size()])
	if kind % 2 == 1:
		_fr(img, 3, 3, 22, 1, YELLOW)
	_outline(img, INK)
	return _tex(key, img)


# Dos de la pancarte du joueur : carton, ruban adhésif, mains qui la tiennent.
static func player_sign_back(skin: Color) -> ImageTexture:
	var key: String = "back_%s" % skin.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(40, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 1, 1, 38, 15, Color(0.82, 0.68, 0.46))
	_fr(img, 1, 1, 38, 1, Color(0.90, 0.78, 0.58))
	_fr(img, 1, 14, 38, 2, Color(0.66, 0.52, 0.34))
	_fr(img, 4, 3, 7, 2, Color(0.95, 0.93, 0.85, 0.9))
	_fr(img, 29, 11, 7, 2, Color(0.95, 0.93, 0.85, 0.9))
	_fr(img, 15, 7, 10, 1, Color(0.58, 0.45, 0.28))
	_fr(img, 7, 15, 4, 4, skin)
	_fr(img, 29, 15, 4, 4, skin)
	_outline(img, INK)
	return _tex(key, img)


# Valise du passager : corps EXACTEMENT de la couleur de la carte, poignée,
# roulettes ; seul un liseré clair distingue la valise noire de son contour.
static func suitcase(body: Color) -> ImageTexture:
	var key: String = "mala_%s" % body.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(10, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 3, 0, 4, 1, Color(0.35, 0.35, 0.38))
	_fr(img, 3, 1, 1, 2, Color(0.35, 0.35, 0.38))
	_fr(img, 6, 1, 1, 2, Color(0.35, 0.35, 0.38))
	_fr(img, 1, 3, 8, 8, body)
	_outline(img, INK)
	if body.get_luminance() < 0.25:
		_fr(img, 1, 3, 8, 1, Color(0.45, 0.45, 0.5))
	_fr(img, 2, 12, 2, 1, INK)
	_fr(img, 6, 12, 2, 1, INK)
	return _tex(key, img)


# Bulle au-dessus d'un passager : « salut » (main qui fait coucou) ou « fronce ».
static func bubble(kind: String) -> ImageTexture:
	var key: String = "bubble_" + kind
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(16, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 1, 1, 14, 10, PAPER)
	_fr(img, 2, 0, 12, 1, PAPER)
	_fr(img, 2, 11, 12, 1, PAPER)
	_fr(img, 5, 12, 3, 1, PAPER)
	_fr(img, 5, 13, 1, 1, PAPER)
	if kind == "wave":
		var skin: Color = Color(0.98, 0.78, 0.55)
		_fr(img, 6, 4, 5, 5, skin)
		for i in 4:
			_fr(img, 6 + i, 2 + (1 if i == 0 else 0), 1, 3, skin)
		_fr(img, 11, 5, 2, 1, skin)
		_px(img, 3, 3, Color(0.9, 0.6, 0.1))
		_px(img, 3, 6, Color(0.9, 0.6, 0.1))
		_px(img, 13, 2, Color(0.9, 0.6, 0.1))
	else:
		# Veine de colère + sourcils froncés.
		var red: Color = Color(0.86, 0.16, 0.16)
		for p: Vector2i in [Vector2i(5, 2), Vector2i(6, 3), Vector2i(4, 4), Vector2i(3, 3), Vector2i(7, 2), Vector2i(5, 5)]:
			_px(img, p.x, p.y, red)
		_fr(img, 8, 6, 3, 1, INK)
		_fr(img, 11, 5, 2, 1, INK)
		_px(img, 10, 8, INK)
		_px(img, 12, 8, INK)
		_fr(img, 9, 10, 4, 1, INK)
	_outline(img, INK)
	return _tex(key, img)


# Éclat d'étoiles pour le Perfeito.
static func burst() -> ImageTexture:
	if _cache.has("burst"):
		return _cache["burst"]
	var img: Image = Image.create(41, 41, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 10:
		var ang: float = TAU * float(i) / 10.0
		var r0: float = 10.0
		var r1: float = 18.0 if i % 2 == 0 else 14.0
		for s in 6:
			var r: float = lerpf(r0, r1, float(s) / 5.0)
			_px(img, 20 + int(round(cos(ang) * r)), 20 + int(round(sin(ang) * r)), YELLOW if i % 2 == 0 else PAPER)
	for c: Vector2i in [Vector2i(6, 8), Vector2i(33, 10), Vector2i(8, 32), Vector2i(34, 31)]:
		_fr(img, c.x - 1, c.y, 3, 1, PAPER)
		_fr(img, c.x, c.y - 1, 1, 3, PAPER)
	return _tex("burst", img)


# --- Plaque de táxi du joueur ---

static func card() -> ImageTexture:
	if _cache.has("card"):
		return _cache["card"]
	var img: Image = Image.create(CARD_NW + 3, CARD_NH + 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var w: int = CARD_NW
	var h: int = CARD_NH
	_fr(img, 3, 3, w, h, Color(0, 0, 0.05, 0.35))
	_fr(img, 0, 0, w, h, INK)
	_fr(img, 1, 1, w - 2, h - 2, PAPER)
	_fr(img, 1, h - 3, w - 2, 2, PAPER_D)
	# Bandeau táxi carioca : jaune, liseré bleu, damier.
	_fr(img, 1, 1, w - 2, 20, YELLOW)
	_fr(img, 1, 1, w - 2, 1, Color(1.0, 0.92, 0.5))
	_fr(img, 1, 17, w - 2, 3, TAXI_BLUE)
	_fr(img, 1, 20, w - 2, 1, INK)
	_text(img, 6, 5, "TÁXI", INK, 2)
	var tx: int = 6 + text_width("TÁXI", 2) + 6
	for i in 14:
		for j in 2:
			if (i + j) % 2 == 0:
				_fr(img, tx + i * 3, 6 + j * 3, 3, 3, INK)
	var coop: String = "COOP. SANTOS DUMONT"
	_text(img, w - 6 - text_width(coop), 7, coop, INK)
	# Ligne de séparation sous le nom.
	_fr(img, 6, 50, w - 12, 1, PAPER_D)
	# Logements des trois pastilles (cadre sombre + ombre).
	for i in 3:
		var x: int = CHIP_NX[i]
		_fr(img, x - 1, CHIP_NY - 1, CHIP_NW + 2, CHIP_NH + 2, INK)
		# Fond papier : la pastille translucide « sem chapéu » reste claire.
		_fr(img, x, CHIP_NY, CHIP_NW, CHIP_NH, PAPER)
		_fr(img, x + 1, CHIP_NY + CHIP_NH + 1, CHIP_NW, 1, PAPER_D)
	# Trous de punaise.
	for p: Vector2i in [Vector2i(4, h - 6), Vector2i(w - 6, h - 6)]:
		_fr(img, p.x, p.y, 2, 2, Color(0.75, 0.2, 0.2))
	return _tex("card", img)


static func chip_world_rect(i: int) -> Rect2:
	return Rect2(CARD_POS + Vector2(CHIP_NX[i] * N, CHIP_NY * N), Vector2(CHIP_NW * N, CHIP_NH * N))


# Petites icônes de pastille : chemise, boné, panamá, tête nue, valise.
static func icon(kind: String) -> ImageTexture:
	var key: String = "icon_" + kind
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 0, 0, 14, 14, INK)
	_fr(img, 1, 1, 12, 12, PAPER)
	match kind:
		"shirt":
			_fr(img, 4, 3, 6, 8, INK)
			_fr(img, 2, 3, 2, 3, INK)
			_fr(img, 10, 3, 2, 3, INK)
			_fr(img, 6, 3, 2, 1, PAPER)
		"cap":
			_fr(img, 4, 5, 6, 3, INK)
			_fr(img, 5, 4, 4, 1, INK)
			_fr(img, 8, 8, 4, 1, INK)
		"fedora":
			_fr(img, 5, 4, 4, 4, INK)
			_fr(img, 2, 8, 10, 1, INK)
			_fr(img, 5, 6, 4, 1, Color(0.75, 0.15, 0.15))
		"none":
			_fr(img, 5, 4, 4, 4, INK)
			_fr(img, 2, 8, 10, 1, INK)
			for i in 10:
				_px(img, 2 + i, 11 - i, Color(0.85, 0.15, 0.15))
				_px(img, 3 + i, 11 - i, Color(0.85, 0.15, 0.15))
		"bag":
			_fr(img, 3, 5, 8, 6, INK)
			_fr(img, 5, 3, 4, 1, INK)
			_fr(img, 5, 4, 1, 1, INK)
			_fr(img, 8, 4, 1, 1, INK)
			_fr(img, 4, 11, 1, 1, INK)
			_fr(img, 9, 11, 1, 1, INK)
	return _tex(key, img)


# Ombre portée sous les pieds d'un passager (unités du personnage ×3).
static func shadow() -> ImageTexture:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var img: Image = Image.create(16, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 2, 0, 12, 4, Color(0, 0, 0.05, 0.28))
	_fr(img, 0, 1, 16, 2, Color(0, 0, 0.05, 0.28))
	return _tex("shadow", img)
