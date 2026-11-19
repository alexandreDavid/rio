extends RefCounted

# Peintre pixel-art du Valet : la cour du Copacabana Palace vue de haut —
# façade blanche art déco, marquise, tapis rouge, dallage de granit, haies
# fleuries et palmiers impériaux, parking marqué au sol, calçadão en bas.
# Tout le fixe est peint une fois dans UNE image (cache) en pixels natifs
# affichés ×3 (NEAREST) — la densité des personnages de CharacterSpriteFactory.

const N: int = 3
# Le décor déborde de l'arène (1920×1080) pour les écrans larges (keep_height).
const ORIGIN: Vector2 = Vector2(-240, 0)
const W: int = 800
const H: int = 360

const OUTLINE: Color = Color(0.13, 0.10, 0.12, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.05, 0.32)
const FACADE: Color = Color(0.97, 0.95, 0.89)
const FACADE_SH: Color = Color(0.84, 0.82, 0.78)
const FACADE_D: Color = Color(0.66, 0.64, 0.64)
const WINDOW: Color = Color(0.20, 0.30, 0.45)
const WINDOW_HI: Color = Color(0.56, 0.74, 0.88)
const GOLD: Color = Color(0.95, 0.76, 0.30)
const GOLD_D: Color = Color(0.66, 0.47, 0.17)
const CANOPY: Color = Color(0.13, 0.18, 0.33)
const CANOPY_HI: Color = Color(0.22, 0.30, 0.50)
const MARBLE: Color = Color(0.93, 0.90, 0.83)
const MARBLE_D: Color = Color(0.86, 0.82, 0.74)
const CARPET: Color = Color(0.74, 0.11, 0.14)
const CARPET_HI: Color = Color(0.88, 0.25, 0.23)
const PAVE: Color = Color(0.80, 0.76, 0.68)
const ASPHALT: Color = Color(0.28, 0.29, 0.32)
const LINE: Color = Color(0.95, 0.95, 0.91)
const YELLOW: Color = Color(0.98, 0.80, 0.22)
const HEDGE: Color = Color(0.20, 0.47, 0.25)
const HEDGE_HI: Color = Color(0.36, 0.64, 0.32)
const HEDGE_D: Color = Color(0.11, 0.29, 0.16)
const BOUGAIN: Color = Color(0.90, 0.30, 0.58)
const SOIL: Color = Color(0.40, 0.28, 0.18)

const GLASS: Color = Color(0.20, 0.27, 0.38, 1.0)
const GLASS_HI: Color = Color(0.58, 0.74, 0.88, 1.0)
const TYRE: Color = Color(0.09, 0.09, 0.11, 1.0)
const HEAD: Color = Color(0.99, 0.97, 0.84, 1.0)
const TAIL: Color = Color(0.92, 0.18, 0.16, 1.0)
const CHROME: Color = Color(0.86, 0.88, 0.90, 1.0)
const LEATHER: Color = Color(0.86, 0.72, 0.52, 1.0)
const HAZARD: Color = Color(1.0, 0.60, 0.10, 1.0)

# Voitures de luxe (palette d'art, distincte des CAR_COLORS logiques).
const LUX_COLORS: Array[Color] = [
	Color(0.74, 0.10, 0.13),   # vermelho
	Color(0.15, 0.24, 0.50),   # azul-marinho
	Color(0.93, 0.93, 0.89),   # branco pérola
	Color(0.84, 0.71, 0.46),   # champanhe
	Color(0.13, 0.38, 0.25),   # verde inglês
	Color(0.30, 0.31, 0.36),   # grafite
	Color(0.70, 0.73, 0.78),   # prata
]
# 0 = berline, 1 = cabriolet, 2 = coupé sport.
const LUX_KINDS: Array[int] = [2, 0, 1, 0, 1, 0, 2]

# Glyphes 3×5 pour le lettrage peint (fronton, numéros de place).
const GLYPHS: Dictionary = {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
	"E": "111100110100111", "L": "100100100100111", "N": "110101101101101",
	"O": "010101101101010", "P": "110101110100100",
	"1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	"4": "101101111001001", "5": "111100110001110",
}

static var _cache: Dictionary = {}


static func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


# Mélange alpha (ombres portées sur le décor déjà peint).
static func _blend(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(c))


static func _text(img: Image, x: int, y: int, s: String, c: Color, k: int = 1) -> void:
	var cx: int = x
	for ch in s:
		if GLYPHS.has(ch):
			var g: String = GLYPHS[ch]
			for i in 15:
				if g[i] == "1":
					_fr(img, cx + (i % 3) * k, y + (i / 3) * k, k, k, c)
		cx += 4 * k


static func text_width(s: String, k: int = 1) -> int:
	return s.length() * 4 * k - k


# Contour sombre automatique : tout pixel vide qui touche un pixel plein.
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


static func _nx(world_x: float) -> int:
	return int(round((world_x - ORIGIN.x) / float(N)))


static func _ny(world_y: float) -> int:
	return int(round((world_y - ORIGIN.y) / float(N)))


# Sprite du décor complet, à poser en premier dans l'arène.
static func backdrop() -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "CourtArt"
	spr.texture = _backdrop_tex()
	spr.centered = false
	spr.position = ORIGIN
	spr.scale = Vector2(N, N)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr


static func _backdrop_tex() -> ImageTexture:
	if _cache.has("court"):
		return _cache["court"]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(ASPHALT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1923   # inauguration du Palace
	_paint_parking(img, rng)
	_paint_driveway(img, rng)
	_paint_hedges(img, rng)
	_paint_facade(img)
	_paint_porch(img)
	_paint_marquee(img)
	_paint_calcadao(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["court"] = tex
	return tex


# --- Façade art déco (monde y 0..96 = natif 0..32) ---
# Les voitures s'arrêtent dès y 138 (logique) : la façade et le porche
# tiennent au-dessus, sous les compteurs du HUD.

const FACADE_B: int = 32
const PORCH_B: int = 47

static func _paint_facade(img: Image) -> void:
	_fr(img, 0, 0, W, FACADE_B, FACADE)
	# Acrotère et corniche.
	_fr(img, 0, 0, W, 2, Color(0.99, 0.98, 0.95))
	_fr(img, 0, 2, W, 1, FACADE_SH)
	_fr(img, 0, 4, W, 1, FACADE_D)
	_fr(img, 0, 5, W, 1, FACADE_SH)
	var pav_l: int = _nx(760.0)
	var pav_r: int = _nx(1160.0)
	# Travées des ailes : pilastres, fenêtres cintrées à balcon, arcade.
	var x: int = 0
	while x < W:
		var in_pav: bool = x + 16 > pav_l - 2 and x < pav_r + 2
		if not in_pav:
			_fr(img, x, 6, 2, FACADE_B - 6, FACADE_SH)
			_fr(img, x, 6, 1, FACADE_B - 6, Color(1, 1, 1))
			_window(img, x + 5, 8, 6, 8)
			_fr(img, x + 4, 17, 8, 1, OUTLINE)
			for k in 4:
				_px(img, x + 4 + k * 2, 16, OUTLINE)
			_arch(img, x + 4, 21, 8, FACADE_B - 21, Color(0.30, 0.26, 0.24))
		x += 16
	_fr(img, 0, 19, W, 1, FACADE_D)
	# Pavillon central en saillie : fronton doré « COPACABANA PALACE ».
	_fr(img, pav_l - 2, 0, pav_r - pav_l + 4, FACADE_B, FACADE_SH)
	_fr(img, pav_l, 0, pav_r - pav_l, FACADE_B, FACADE)
	_fr(img, pav_l, 0, pav_r - pav_l, 1, Color(1, 1, 1))
	_fr(img, pav_r - 2, 1, 2, FACADE_B - 1, FACADE_SH)
	var label: String = "COPACABANA PALACE"
	var tw: int = text_width(label)
	var tx: int = (pav_l + pav_r) / 2 - tw / 2
	_fr(img, tx - 3, 2, tw + 6, 9, GOLD_D)
	_fr(img, tx - 2, 3, tw + 4, 7, Color(0.18, 0.20, 0.30))
	_text(img, tx, 4, label, GOLD)
	# Motif art déco : rayons dorés de part et d'autre du lettrage.
	for k in 3:
		_fr(img, tx - 8 - k * 4, 4 + k, 2, 5 - k, GOLD)
		_fr(img, tx + tw + 6 + k * 4, 4 + k, 2, 5 - k, GOLD)
	# Pavillon : fenêtres hautes entre pilastres cannelés.
	var px: int = pav_l + 4
	while px + 10 < pav_r:
		_window(img, px + 2, 13, 6, 9)
		_fr(img, px + 1, 23, 8, 1, FACADE_D)
		px += 12
	for cx in [pav_l + 1, pav_r - 4]:
		_fr(img, cx, 11, 3, FACADE_B - 11, FACADE_SH)
		_fr(img, cx + 1, 11, 1, FACADE_B - 11, Color(1, 1, 1))
	_fr(img, 0, FACADE_B - 1, W, 1, FACADE_D)


static func _window(img: Image, x: int, y: int, w: int, h: int) -> void:
	_fr(img, x - 1, y - 1, w + 2, h + 2, FACADE_D)
	_fr(img, x, y, w, h, WINDOW)
	_px(img, x, y, FACADE_D)
	_px(img, x + w - 1, y, FACADE_D)
	_fr(img, x + 1, y + 1, 2, 1, WINDOW_HI)
	_fr(img, x + w / 2, y, 1, h, Color(0.86, 0.86, 0.84))


static func _arch(img: Image, x: int, y: int, w: int, h: int, inside: Color) -> void:
	_fr(img, x, y + 1, w, h - 1, inside)
	_fr(img, x + 1, y, w - 2, 1, inside)
	_fr(img, x + 1, y + 2, w - 2, 1, GOLD.darkened(0.35))
	_fr(img, x + w / 2 - 1, y + 4, 2, h - 4, inside.lightened(0.18))


# --- Marquise (monde y 78..120) au-dessus des portes ---

static func _paint_marquee(img: Image) -> void:
	var l: int = _nx(846.0)
	var r: int = _nx(1074.0)
	var t: int = 24
	var b: int = 37
	_blend(img, l + 2, b, r - l, 4, SHADOW)
	_fr(img, l - 1, t - 1, r - l + 2, b - t + 2, OUTLINE)
	_fr(img, l, t, r - l, b - t, CANOPY)
	_fr(img, l, t, r - l, 2, CANOPY_HI)
	# Liseré doré et festons.
	_fr(img, l, b - 3, r - l, 1, GOLD)
	var x: int = l
	while x < r:
		_fr(img, x, b - 2, 2, 2, GOLD_D if (x - l) % 4 == 0 else CANOPY)
		_px(img, x + 1, b, GOLD)
		x += 4
	var k: int = l + 8
	while k < r - 4:
		_fr(img, k, t + 2, 1, b - t - 5, CANOPY.darkened(0.25))
		k += 10
	# Nom de l'hôtel sur le bandeau de la marquise.
	var tw: int = text_width("PALACE")
	_text(img, (l + r) / 2 - tw / 2, t + 4, "PALACE", GOLD)
	# Poteaux de laiton aux coins.
	for px in [l + 1, r - 3]:
		_fr(img, px, b, 2, 3, GOLD_D)
		_px(img, px, b, GOLD)


# --- Porche de marbre, portes, tapis rouge (monde y 96..141) ---

static func _paint_porch(img: Image) -> void:
	var top: int = FACADE_B
	_fr(img, 0, top, W, PORCH_B - top, MARBLE)
	for y in range(top, PORCH_B - 4, 5):
		for x in range(0, W, 5):
			if ((x / 5) + (y / 5)) % 2 == 0:
				_fr(img, x, y, 5, 5, MARBLE_D)
	_blend(img, 0, top, W, 2, SHADOW)
	# Grandes portes vitrées à encadrement doré (axe du tapis).
	var c: int = _nx(960.0)
	_fr(img, c - 10, top - 9, 20, 9, GOLD_D)
	_fr(img, c - 9, top - 8, 18, 8, GLASS)
	_fr(img, c - 1, top - 8, 2, 8, GOLD)
	_fr(img, c - 8, top - 7, 3, 1, GLASS_HI)
	_fr(img, c + 2, top - 7, 3, 1, GLASS_HI)
	# Degraus et bordure de granit.
	_fr(img, 0, PORCH_B - 4, W, 1, Color(1, 1, 1))
	_fr(img, 0, PORCH_B - 3, W, 1, MARBLE_D.darkened(0.08))
	_fr(img, 0, PORCH_B - 2, W, 1, Color(0.90, 0.89, 0.86))
	_fr(img, 0, PORCH_B - 1, W, 1, Color(0.50, 0.48, 0.46))
	# Tapis rouge, liseré doré, potelets et cordons.
	_fr(img, c - 10, top, 20, PORCH_B - top, GOLD_D)
	_fr(img, c - 9, top, 18, PORCH_B - top, CARPET)
	_fr(img, c - 8, top, 2, PORCH_B - top, CARPET_HI)
	for y in range(top + 2, PORCH_B, 4):
		_px(img, c - 3, y, CARPET.darkened(0.2))
		_px(img, c + 4, y + 2, CARPET.darkened(0.2))
	for side in [-1, 1]:
		var sx: int = c + side * 14
		for y in [top + 5, top + 12]:
			_fr(img, sx, y, 2, 2, GOLD)
			_px(img, sx + 1, y + 1, GOLD_D)
		_fr(img, sx, top + 7, 1, 5, Color(0.62, 0.08, 0.10))
		_fr(img, sx + 1, top + 8, 1, 4, Color(0.62, 0.08, 0.10))
	# Vasques de palmiers nains aux angles du pavillon.
	for vx in [_nx(770.0), _nx(1150.0)]:
		_planter(img, vx, top + 8)


static func _planter(img: Image, cx: int, cy: int) -> void:
	_blend(img, cx - 4, cy - 2, 10, 9, SHADOW)
	_fr(img, cx - 5, cy - 4, 10, 8, Color(0.55, 0.52, 0.50))
	_fr(img, cx - 4, cy - 3, 8, 6, SOIL)
	for d in [Vector2i(-6, -6), Vector2i(3, -7), Vector2i(-7, 1), Vector2i(4, 1), Vector2i(-2, -9), Vector2i(-1, 3)]:
		_fr(img, cx + d.x, cy + d.y, 5, 3, HEDGE)
		_fr(img, cx + d.x + 1, cy + d.y, 3, 1, HEDGE_HI)


# --- Allée de granit (monde y 222..600) ---

static func _paint_driveway(img: Image, rng: RandomNumberGenerator) -> void:
	var top: int = PORCH_B
	var bot: int = 200
	_fr(img, 0, top, W, bot - top, PAVE)
	var row: int = 0
	var y: int = top
	while y < bot:
		var off: int = 0 if row % 2 == 0 else 6
		var x: int = -off
		while x < W:
			var tone: Color = PAVE.lightened(rng.randf_range(0.0, 0.08)) if rng.randf() < 0.5 \
				else PAVE.darkened(rng.randf_range(0.0, 0.06))
			_fr(img, x + 1, y + 1, 11, 5, tone)
			_px(img, x + 2, y + 1, tone.lightened(0.12))
			x += 12
		_fr(img, 0, y, W, 1, PAVE.darkened(0.11))
		var xj: int = -off
		while xj < W:
			_fr(img, xj, y, 1, 6, PAVE.darkened(0.11))
			xj += 12
		y += 6
		row += 1
	# Zone de dépose : pointillés jaunes devant le tapis.
	var l: int = _nx(720.0)
	var r: int = _nx(1200.0)
	var zt: int = PORCH_B + 1
	var zb: int = _ny(300.0)
	var x2: int = l
	while x2 < r:
		_fr(img, x2, zb, 4, 1, YELLOW)
		x2 += 6
	var y2: int = zt
	while y2 < zb:
		_fr(img, l, y2, 1, 4, YELLOW)
		_fr(img, r - 1, y2, 1, 4, YELLOW)
		y2 += 6
	# Taches d'huile et traces de pneus discrètes.
	for i in 14:
		var ox: int = rng.randi_range(l + 6, r - 10)
		var oy: int = rng.randi_range(zt + 4, zb - 4)
		_fr(img, ox, oy, rng.randi_range(2, 4), 1, PAVE.darkened(0.22))
	# Rosace de pedra portuguesa au milieu de l'allée.
	_medallion(img, _nx(960.0), _ny(450.0))
	# Lampadaires art déco de part et d'autre de la dépose.
	for lx in [620.0, 1300.0, 110.0, 1810.0]:
		_lamp(img, _nx(lx), _ny(250.0))
	# Deux palmiers impériaux en vasques rondes, de part et d'autre.
	for cx in [_nx(200.0), _nx(1720.0)]:
		_round_bed(img, cx, 128)


static func _medallion(img: Image, cx: int, cy: int) -> void:
	var black: Color = Color(0.20, 0.20, 0.22)
	var white: Color = Color(0.95, 0.94, 0.89)
	for y in range(-24, 25):
		for x in range(-24, 25):
			var v: Vector2 = Vector2(x, y)
			var d: float = v.length()
			if d > 24.0:
				continue
			var col: Color = white
			if d > 22.0:
				col = black
			elif d > 20.0:
				col = white
			elif d > 18.5:
				col = GOLD_D
			else:
				# Étoile des vents à huit branches, vagues entre les branches.
				var a: float = fposmod(v.angle(), TAU / 8.0) - TAU / 16.0
				var ray: float = (1.0 - absf(a) / (TAU / 16.0)) * 18.0
				if d < 3.0:
					col = GOLD
				elif d < ray * 0.85:
					col = black if a < 0.0 else Color(0.36, 0.36, 0.40)
				else:
					var band: int = int(floor((d + sin(v.angle() * 8.0) * 1.5) / 3.0))
					col = white if band % 2 == 0 else MARBLE_D
			_px(img, cx + x, cy + y, col)


static func _lamp(img: Image, cx: int, cy: int) -> void:
	# Réverbère art déco vu de haut : socle, bras en croix, quatre globes.
	_blend(img, cx - 2, cy + 2, 12, 6, SHADOW)
	_fr(img, cx - 5, cy - 1, 11, 3, OUTLINE)
	_fr(img, cx - 1, cy - 5, 3, 11, OUTLINE)
	_fr(img, cx - 4, cy, 9, 1, Color(0.25, 0.27, 0.30))
	_fr(img, cx, cy - 4, 1, 9, Color(0.25, 0.27, 0.30))
	for d in [Vector2i(-5, -1), Vector2i(4, -1), Vector2i(-1, -5), Vector2i(-1, 4)]:
		_fr(img, cx + d.x - 1, cy + d.y - 1, 4, 4, OUTLINE)
		_fr(img, cx + d.x, cy + d.y, 2, 2, Color(0.99, 0.95, 0.78))
		_px(img, cx + d.x, cy + d.y, Color(1, 1, 1))
	_fr(img, cx - 1, cy - 1, 3, 3, GOLD_D)
	_px(img, cx, cy, GOLD)


static func _round_bed(img: Image, cx: int, cy: int) -> void:
	for y in range(-11, 12):
		for x in range(-11, 12):
			var d: float = Vector2(x, y).length()
			if d <= 11.0:
				var c: Color = Color(0.86, 0.84, 0.80) if d > 9.0 else HEDGE
				if d <= 9.0 and (x * 7 + y * 13) % 5 == 0:
					c = BOUGAIN if (x + y) % 3 == 0 else HEDGE_HI
				_px(img, cx + x, cy + y, c)
	_palm(img, cx, cy, 991 + cx)


# --- Haies fleuries et palmiers entre l'allée et le parking (monde y 600..652) ---

static func _paint_hedges(img: Image, rng: RandomNumberGenerator) -> void:
	var top: int = 200
	var bot: int = 217
	# Bandes de pelouse + haies, interrompues face aux places (accès).
	var gaps: Array = [[170.0, 310.0], [490.0, 630.0], [890.0, 1030.0], [1290.0, 1430.0], [1610.0, 1750.0]]
	_fr(img, 0, top, W, bot - top, Color(0.86, 0.84, 0.80))
	var x0: int = 0
	var segments: Array = []
	for g in gaps:
		var gl: int = _nx(float(g[0]) - 20.0)
		var gr: int = _nx(float(g[1]) + 20.0)
		segments.append(Vector2i(x0, gl))
		x0 = gr
	segments.append(Vector2i(x0, W))
	for s in segments:
		var seg: Vector2i = s
		if seg.y - seg.x < 6:
			continue
		_blend(img, seg.x + 1, bot - 1, seg.y - seg.x, 3, SHADOW)
		_fr(img, seg.x, top + 1, seg.y - seg.x, bot - top - 2, HEDGE_D)
		_fr(img, seg.x + 1, top + 2, seg.y - seg.x - 2, bot - top - 4, HEDGE)
		for i in (seg.y - seg.x) * 2:
			var hx: int = rng.randi_range(seg.x + 1, seg.y - 2)
			var hy: int = rng.randi_range(top + 2, bot - 3)
			_px(img, hx, hy, HEDGE_HI if rng.randf() < 0.6 else HEDGE_D)
		for i in (seg.y - seg.x) / 3:
			var fx: int = rng.randi_range(seg.x + 2, seg.y - 3)
			var fy: int = rng.randi_range(top + 3, bot - 4)
			_px(img, fx, fy, BOUGAIN)
			_px(img, fx + 1, fy, BOUGAIN.lightened(0.25))
	# Palmiers impériaux au milieu des haies.
	for wx in [60.0, 400.0, 760.0, 1160.0, 1520.0, 1860.0]:
		_palm(img, _nx(wx), 208, int(wx))
	# Accès : les entrées de place sont bordées d'une ligne de granit.
	for g in gaps:
		_fr(img, _nx(float(g[0]) - 20.0), bot - 1, _nx(float(g[1]) + 20.0) - _nx(float(g[0]) - 20.0), 1, Color(0.70, 0.68, 0.66))


# Cime de palmier impérial vue de haut : palmes en étoile, cœur sombre.
static func _palm(img: Image, cx: int, cy: int, seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var n: int = 40
	var crown: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	crown.fill(Color(0, 0, 0, 0))
	var leaf: Color = Color(0.24, 0.58, 0.30)
	var leaf_hi: Color = Color(0.50, 0.80, 0.36)
	var leaf_lo: Color = Color(0.15, 0.40, 0.22)
	var c: Vector2 = Vector2(19.5, 19.5)
	var count: int = 9
	for i in count:
		var a: float = TAU * float(i) / float(count) + rng.randf_range(-0.18, 0.18)
		var dir: Vector2 = Vector2.from_angle(a)
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var length: float = rng.randf_range(14.0, 18.5)
		var lit: bool = dir.x + dir.y < 0.0
		var r: float = 1.5
		while r < length:
			var t: float = r / length
			var half: float = sin(t * PI) * 2.8
			var p: Vector2 = c + dir * r + nrm * t * t * 2.2
			var s: float = -half
			while s <= half:
				var q: Vector2 = p + nrm * s
				var qi: Vector2i = Vector2i(int(q.x), int(q.y))
				if qi.x >= 0 and qi.y >= 0 and qi.x < n and qi.y < n:
					var col: Color = leaf
					if absf(s) < 0.6:
						col = leaf_hi if lit else leaf
					elif s > 0.0:
						col = leaf if lit else leaf_lo
					crown.set_pixelv(qi, col)
				s += 0.5
			r += 0.5
	_fr(crown, 18, 18, 3, 3, Color(0.42, 0.30, 0.16))
	_px(crown, 19, 18, Color(0.58, 0.44, 0.24))
	_outline(crown, Color(0.08, 0.20, 0.10))
	# Ombre portée (décalée vers le bas-droite), puis la cime.
	for y in n:
		for x in n:
			if crown.get_pixel(x, y).a > 0.5:
				var sx: int = cx - n / 2 + x + 3
				var sy: int = cy - n / 2 + y + 4
				if sx >= 0 and sy >= 0 and sx < W and sy < H:
					img.set_pixel(sx, sy, img.get_pixel(sx, sy).blend(SHADOW))
	img.blend_rect(crown, Rect2i(0, 0, n, n), Vector2i(cx - n / 2, cy - n / 2))


# --- Parking (monde y 652..1030) ---

const SLOT_CENTERS: Array[float] = [240.0, 560.0, 960.0, 1360.0, 1680.0]

static func _paint_parking(img: Image, rng: RandomNumberGenerator) -> void:
	var top: int = 217
	var bot: int = 344
	_fr(img, 0, top, W, bot - top, ASPHALT)
	for i in W * (bot - top) / 5:
		var gx: int = rng.randi_range(0, W - 1)
		var gy: int = rng.randi_range(top, bot - 1)
		var r: float = rng.randf()
		var c: Color = ASPHALT.darkened(0.12) if r < 0.6 else ASPHALT.lightened(0.10 if r < 0.95 else 0.3)
		img.set_pixel(gx, gy, c)
	# Places : lignes blanches latérales + fond, butée de roues, numéro peint.
	for i in SLOT_CENTERS.size():
		var cx: float = SLOT_CENTERS[i]
		var l: int = _nx(cx - 70.0)
		var r2: int = _nx(cx + 70.0)
		var t: int = _ny(690.0)
		var b: int = _ny(870.0)
		_fr(img, l - 1, t, 2, b - t + 1, LINE)
		_fr(img, r2 - 1, t, 2, b - t + 1, LINE)
		_fr(img, l - 1, b, r2 - l + 2, 2, LINE)
		# Coins usés de la peinture.
		_px(img, l - 1, t + 7, LINE.darkened(0.3))
		_px(img, r2, t + 20, LINE.darkened(0.3))
		_fr(img, l + 8, b - 5, r2 - l - 16, 2, Color(0.62, 0.60, 0.58))
		_fr(img, l + 8, b - 5, r2 - l - 16, 1, Color(0.78, 0.76, 0.74))
		var num: String = str(i + 1)
		var nw: int = text_width(num, 2)
		_text(img, (l + r2) / 2 - nw / 2, b + 4, num, LINE, 2)
	# Voie de circulation : pointillés et flèches.
	var lane_y: int = _ny(975.0)
	var x: int = 4
	while x < W:
		_fr(img, x, lane_y, 8, 1, YELLOW)
		x += 14
	for ax in [_nx(400.0), _nx(1160.0), _nx(1520.0), _nx(760.0)]:
		_arrow(img, ax, lane_y - 6)
	# Bordure côté rue.
	_fr(img, 0, bot - 2, W, 2, Color(0.90, 0.89, 0.86))


static func _arrow(img: Image, x: int, y: int) -> void:
	_fr(img, x - 6, y, 9, 1, LINE)
	for k in 3:
		_fr(img, x + 3 - k, y - k, 1, 2 * k + 1, LINE)


# Calçadão de Copacabana en bas : vagues noir/blanc parallèles à la plage.
static func _paint_calcadao(img: Image) -> void:
	var top: int = 344
	var black: Color = Color(0.16, 0.16, 0.18)
	var white: Color = Color(0.95, 0.94, 0.89)
	for y in range(top, H):
		for x in W:
			var wob: float = sin(TAU * float(x) / 24.0) * 2.5
			var band: int = int(floor((float(y - top) + wob + 2.0) / 4.0))
			var col: Color = black if posmod(band, 2) == 0 else white
			if (x * 3 + y * 5) % 11 == 0:
				col = col.darkened(0.12) if col == white else col.lightened(0.12)
			img.set_pixel(x, y, col)


# --- Voitures de luxe vues de dessus (nez vers le haut) ---
# Natif 32×48 : caisse 28×44 (= la hitbox 88×132 à ×3), ombre décalée.

static func car(color: Color, kind: int) -> ImageTexture:
	var key: String = "car_%s_%d" % [color.to_html(false), kind]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = color
	var light: Color = base.lightened(0.30)
	var shade: Color = base.darkened(0.22)
	var dark: Color = base.darkened(0.6) if base.get_luminance() > 0.2 else OUTLINE
	_fr(img, 3, 4, 29, 44, SHADOW)
	# Roues qui dépassent.
	for wy in [7, 31]:
		_fr(img, 0, wy, 3, 8, TYRE)
		_fr(img, 27, wy, 3, 8, TYRE)
		_px(img, 0, wy + 1, Color(0.3, 0.3, 0.32))
	# Caisse, coins arrondis.
	_fr(img, 1, 0, 28, 44, dark)
	_fr(img, 2, 1, 26, 42, base)
	for c in [Vector2i(1, 0), Vector2i(28, 0), Vector2i(1, 43), Vector2i(28, 43)]:
		img.set_pixelv(c, Color(0, 0, 0, 0))
	_fr(img, 2, 2, 1, 40, light)
	_fr(img, 26, 2, 2, 40, shade)
	# Capot : phares, calandre chromée, nervure.
	var hood_end: int = 14 if kind == 2 else 12
	_fr(img, 3, 1, 5, 2, HEAD)
	_fr(img, 22, 1, 5, 2, HEAD)
	_fr(img, 11, 0, 8, 1, CHROME)
	_fr(img, 14, 3, 2, hood_end - 5, light)
	_fr(img, 4, hood_end - 1, 22, 1, shade)
	# Rétroviseurs.
	_fr(img, 0, hood_end + 1, 2, 2, base)
	_fr(img, 28, hood_end + 1, 2, 2, base)
	# Pare-brise.
	_fr(img, 4, hood_end, 22, 5, dark)
	_fr(img, 5, hood_end + 1, 20, 4, GLASS)
	for k in 3:
		_px(img, 8 + k, hood_end + 3 - k, GLASS_HI)
		_px(img, 10 + k, hood_end + 3 - k, GLASS_HI)
	var cab_t: int = hood_end + 5
	if kind == 1:
		# Cabriolet : habitacle ouvert, sièges cuir, capote repliée.
		_fr(img, 4, cab_t, 22, 14, Color(0.24, 0.17, 0.14))
		_fr(img, 6, cab_t + 1, 7, 6, LEATHER)
		_fr(img, 17, cab_t + 1, 7, 6, LEATHER)
		_fr(img, 6, cab_t + 1, 7, 1, LEATHER.lightened(0.25))
		_fr(img, 17, cab_t + 1, 7, 1, LEATHER.lightened(0.25))
		_fr(img, 7, cab_t - 1, 5, 1, OUTLINE)
		_fr(img, 6, cab_t + 9, 18, 4, LEATHER.darkened(0.12))
		_fr(img, 6, cab_t + 9, 18, 1, LEATHER)
		_fr(img, 4, cab_t + 14, 22, 3, Color(0.12, 0.12, 0.14))
		_fr(img, 5, cab_t + 14, 20, 1, Color(0.26, 0.26, 0.30))
	else:
		var roof_h: int = 8 if kind == 2 else 11
		# Vitres latérales, toit, lunette arrière.
		_fr(img, 3, cab_t, 2, roof_h, GLASS)
		_fr(img, 25, cab_t, 2, roof_h, GLASS)
		_fr(img, 5, cab_t, 20, roof_h, base.lerp(light, 0.35))
		_fr(img, 6, cab_t + 1, 12, 1, light.lightened(0.15))
		_fr(img, 5, cab_t + roof_h - 1, 20, 1, shade)
		_fr(img, 4, cab_t + roof_h, 22, 4, dark)
		_fr(img, 5, cab_t + roof_h, 20, 3, GLASS)
		_fr(img, 7, cab_t + roof_h, 6, 1, GLASS_HI)
	if kind == 2:
		# Coupé sport : double bande de course.
		_fr(img, 12, 1, 2, 42, LINE if base.get_luminance() < 0.7 else OUTLINE)
		_fr(img, 16, 1, 2, 42, LINE if base.get_luminance() < 0.7 else OUTLINE)
	# Coffre, feux arrière, pare-chocs.
	_fr(img, 4, 38, 22, 1, shade)
	_fr(img, 3, 41, 5, 2, TAIL)
	_fr(img, 22, 41, 5, 2, TAIL)
	_fr(img, 11, 42, 8, 1, CHROME)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Feux de détresse (même cadre que la voiture) : quatre clignotants orange.
static func hazard() -> ImageTexture:
	if _cache.has("hazard"):
		return _cache["hazard"]
	var img: Image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in [Vector2i(0, 0), Vector2i(26, 0), Vector2i(0, 40), Vector2i(26, 40)]:
		_fr(img, p.x, p.y, 4, 4, HAZARD)
		_fr(img, p.x + 1, p.y + 1, 2, 2, Color(1.0, 0.92, 0.55))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["hazard"] = tex
	return tex


# Bulle « ! » au-dessus d'une voiture réclamée.
static func alert_badge() -> ImageTexture:
	if _cache.has("alert"):
		return _cache["alert"]
	var img: Image = Image.create(11, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fr(img, 1, 0, 9, 11, Color(0.98, 0.97, 0.92))
	_fr(img, 0, 1, 11, 9, Color(0.98, 0.97, 0.92))
	_fr(img, 4, 11, 3, 1, Color(0.98, 0.97, 0.92))
	_px(img, 5, 12, Color(0.98, 0.97, 0.92))
	_fr(img, 5, 2, 2, 5, TAIL)
	_fr(img, 5, 8, 2, 2, TAIL)
	_outline(img, OUTLINE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["alert"] = tex
	return tex


# Ondes de klaxon (côté droit ; flip_h pour la gauche).
static func honk_waves() -> ImageTexture:
	if _cache.has("honk"):
		return _cache["honk"]
	var img: Image = Image.create(9, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in [3, 6]:
		for y in range(-r, r + 1):
			var x: int = int(round(sqrt(float(r * r - y * y))))
			_px(img, x, 6 + y, YELLOW)
	_outline(img, OUTLINE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["honk"] = tex
	return tex


# Ticket du client au-dessus de sa tête : la voiture attendue (couleur) ou la
# clé (il vient la confier). La jauge de patience se pose dessous, en code.
static func client_ticket(color: Color, wants_car: bool) -> ImageTexture:
	var key: String = "ticket_%s_%s" % [color.to_html(false), wants_car]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(14, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var paper: Color = Color(0.98, 0.97, 0.92)
	_fr(img, 1, 1, 12, 13, paper)
	_fr(img, 2, 0, 10, 15, paper)
	if wants_car:
		# Mini-voiture vue de haut dans la couleur réclamée.
		_fr(img, 4, 1, 6, 9, color.darkened(0.55) if color.get_luminance() > 0.2 else OUTLINE)
		_fr(img, 5, 2, 4, 7, color)
		_fr(img, 5, 4, 4, 2, GLASS)
		_fr(img, 5, 7, 4, 1, GLASS)
		_px(img, 5, 2, HEAD)
		_px(img, 8, 2, HEAD)
	else:
		# Clé dorée.
		_fr(img, 3, 2, 4, 4, GOLD_D)
		_fr(img, 4, 3, 2, 2, paper)
		_fr(img, 7, 3, 4, 2, GOLD)
		_px(img, 9, 5, GOLD)
		_px(img, 10, 5, GOLD)
		_px(img, 3, 2, paper)
	# Logement de la jauge.
	_fr(img, 2, 10, 10, 4, OUTLINE)
	_outline(img, OUTLINE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
