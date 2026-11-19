extends RefCounted

# Peintures pixel du Surf / Kite (1 px natif = 3 px monde, NEAREST, comme
# GroundPainter et les personnages). Vue depuis la plage vers le large : ciel,
# horizon (Dois Irmãos et l'Arpoador au surf, Pedra da Gávea à la Barra pour
# le kite), mer en perspective, sable au premier plan. Les vagues sont des
# textures « de face » cachées par (palier, hauteur native, stade) : corps
# répété sur toute la largeur + pic en A posé par-dessus.
# Tout est peint par colonnes/rangées (fill_rect) : le coût au chargement
# reste de l'ordre de la dizaine de ms.

const D: int = 3
const BG_RECT: Rect2 = Rect2(-330, -210, 2580, 1500)
const HORIZON_Y: float = 120.0
const SHORE_Y: float = 1005.0
const TILE_W: int = 64

const WHITE: Color = Color(0.97, 0.99, 1.0, 1)
const FOAM_SH: Color = Color(0.72, 0.87, 0.93, 1)
const FOAM_DEEP: Color = Color(0.5, 0.76, 0.86, 1)
const OUTLINE: Color = Color(0.07, 0.11, 0.17, 1)
const ROCK: Color = Color(0.52, 0.47, 0.43, 1)
const SAND: Color = Color(0.94, 0.84, 0.6, 1)

# Rampe de face par palier (marola → bomba : plus haute, plus sombre).
const FACES: Array = [
	[Color(0.58, 0.9, 0.88), Color(0.3, 0.7, 0.78), Color(0.16, 0.5, 0.68), Color(0.08, 0.33, 0.52)],
	[Color(0.52, 0.9, 0.8), Color(0.24, 0.66, 0.74), Color(0.11, 0.44, 0.64), Color(0.05, 0.28, 0.47)],
	[Color(0.46, 0.88, 0.74), Color(0.18, 0.6, 0.68), Color(0.07, 0.36, 0.56), Color(0.03, 0.2, 0.38)],
]

static var _cache: Dictionary = {}

# --- Outils ---

static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

# Rangée tramée (une colonne sur deux) : transition de bande sans dégradé.
static func _dither_row(img: Image, y: int, c: Color, phase: int = 0) -> void:
	if y < 0 or y >= img.get_height():
		return
	for x in range(phase, img.get_width(), 2):
		img.set_pixel(x, y, c)

static func _ny(world_y: float) -> int:
	return int(floor((world_y - BG_RECT.position.y) / float(D)))

static func _nx(world_x: float) -> int:
	return int(floor((world_x - BG_RECT.position.x) / float(D)))

static func sprite(tex: Texture2D, centered: bool = true) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = centered
	s.scale = Vector2(D, D)
	return s

# --- Décor fixe ---

static func backdrop(kite: bool) -> ImageTexture:
	var key: String = "bg_%s" % kite
	if _cache.has(key):
		return _cache[key]
	var w: int = int(BG_RECT.size.x) / D
	var h: int = int(BG_RECT.size.y) / D
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41 if kite else 17
	var hy: int = _ny(HORIZON_Y)
	var sy: int = _ny(SHORE_Y)
	# Ciel : 5 bandes, transitions tramées.
	var skies: Array = [Color(0.27, 0.56, 0.87), Color(0.35, 0.64, 0.91), Color(0.46, 0.72, 0.94), Color(0.6, 0.81, 0.96), Color(0.76, 0.89, 0.97)]
	var band_h: int = hy / skies.size()
	for i in skies.size():
		var y0: int = i * band_h
		var y1: int = hy if i == skies.size() - 1 else (i + 1) * band_h
		_fill(img, 0, y0, w, y1 - y0, skies[i])
		if i > 0:
			_dither_row(img, y0, skies[i - 1], 0)
			_dither_row(img, y0 - 1, skies[i], 1)
	if kite:
		# Vent : longs cirrus effilochés.
		for i in 9:
			var cx: int = rng.randi_range(0, w)
			var cy: int = rng.randi_range(hy - 40, hy - 12)
			var ln: int = rng.randi_range(40, 90)
			_fill(img, cx, cy, ln, 1, Color(0.92, 0.96, 1.0))
			_fill(img, cx + 8, cy + 1, ln - 20, 1, Color(0.8, 0.9, 0.98))
	for i in (4 if kite else 6):
		_cloud(img, rng.randi_range(-20, w), rng.randi_range(hy - 36, hy - 16), rng.randi_range(10, 22), rng)
	# Mer : du voile d'horizon au bleu profond puis au turquoise du bord.
	var stops: Array = [
		[0.0, Color(0.48, 0.72, 0.85)], [0.03, Color(0.4, 0.65, 0.82)], [0.08, Color(0.32, 0.59, 0.78)],
		[0.15, Color(0.25, 0.53, 0.74)], [0.26, Color(0.2, 0.49, 0.71)], [0.42, Color(0.16, 0.46, 0.68)],
		[0.62, Color(0.13, 0.44, 0.65)], [0.8, Color(0.15, 0.5, 0.67)], [0.87, Color(0.2, 0.58, 0.7)],
		[0.93, Color(0.3, 0.67, 0.73)], [0.97, Color(0.42, 0.76, 0.76)],
	]
	var prev: Color = stops[0][1]
	for y in range(hy, sy):
		var t: float = float(y - hy) / float(sy - hy)
		var c: Color = stops[0][1]
		for s in stops:
			if t >= float(s[0]):
				c = s[1]
		_fill(img, 0, y, w, 1, c)
		if c != prev:
			_dither_row(img, y, prev, y % 2)
			prev = c
	_fill(img, 0, hy, w, 1, Color(0.82, 0.91, 0.96))
	# Houle de fond : traits clairs/sombres qui s'allongent en approchant.
	var y2: int = hy + 2
	while y2 < sy - 4:
		var t2: float = float(y2 - hy) / float(sy - hy)
		var base: Color = img.get_pixel(0, y2)
		var n: int = int(lerpf(14.0, 7.0, t2))
		for k in n:
			var x: int = rng.randi_range(0, w)
			var ln2: int = int(lerpf(2.0, 12.0, t2)) + rng.randi_range(0, 4)
			_fill(img, x, y2, ln2, 1, base.lightened(0.16))
			_fill(img, x + 1, y2 + 1, maxi(1, ln2 - 3), 1, base.darkened(0.12))
		if kite:
			# Moutons : le vent casse les crêtes.
			for k in int(lerpf(3.0, 6.0, t2)):
				var x3: int = rng.randi_range(0, w)
				var ln3: int = 1 + int(t2 * 3.0)
				_fill(img, x3, y2, ln3, 1, WHITE)
				_px(img, x3 + ln3, y2 + 1, FOAM_SH)
		y2 += 2 + int(t2 * 7.0)
	# Bord : bande d'écume, sable mouillé, sable sec.
	for x in w:
		var sw: int = int(round(sin(float(x) * 0.09) * 1.5 + sin(float(x) * 0.031 + 1.3) * 1.5))
		_fill(img, x, sy + sw - 1, 1, 2, WHITE if (x / 3) % 4 != 0 else FOAM_SH)
		_fill(img, x, sy + sw + 1, 1, 3, Color(0.74, 0.66, 0.48))
		_fill(img, x, sy + sw + 4, 1, h - sy, SAND)
	for i in w * (h - sy) / 18:
		var gx: int = rng.randi_range(0, w - 1)
		var gy: int = rng.randi_range(sy + 6, h - 1)
		_px(img, gx, gy, SAND.darkened(0.08) if i % 3 else SAND.lightened(0.1))
	if kite:
		_barra_skyline(img, hy, rng)
	else:
		_ipanema_skyline(img, hy, rng)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _cloud(img: Image, cx: int, cy: int, r: int, rng: RandomNumberGenerator) -> void:
	# Cumulus : 3 lobes, dessous plat et ombré.
	var lobes: Array = [Vector3(0, 0, r), Vector3(-r * 0.8, r * 0.25, r * 0.6), Vector3(r * 0.85, r * 0.2, r * 0.65)]
	var bottom: int = cy + int(r * 0.45)
	for l in lobes:
		var lr: float = l.z * 0.5
		var lx: float = cx + l.x
		var ly: float = cy + l.y * 0.5
		for yy in range(int(ly - lr * 0.7), bottom + 1):
			var dy: float = (float(yy) - ly) / (lr * 0.7)
			var hw: int = int(lr * 1.6 * sqrt(maxf(0.0, 1.0 - dy * dy))) if yy < ly else int(lr * 1.6)
			var c: Color = Color(1, 1, 1) if yy < bottom - 2 else Color(0.84, 0.9, 0.97)
			_fill(img, int(lx) - hw, yy, hw * 2, 1, c)

# Masse de morne vue de loin : profil par colonne (hauteurs natives au-dessus
# de l'horizon), granit en haut, mata en bas, face gauche éclairée.
static func _mass(img: Image, hy: int, x0: int, heights: PackedFloat32Array, rock: Color, veg: Color, rng: RandomNumberGenerator, veg_ratio: float = 0.5) -> void:
	var n: int = heights.size()
	for i in n:
		var hh: int = int(round(heights[i]))
		if hh <= 0:
			continue
		var x: int = x0 + i
		var slope: float = heights[mini(i + 1, n - 1)] - heights[maxi(i - 1, 0)]
		var lit: bool = slope > 0.25
		var vy: int = int(float(hh) * veg_ratio) + rng.randi_range(-1, 1)
		for yy in hh:
			var c: Color
			if yy < vy:
				c = veg.lightened(0.1) if lit else veg
				if rng.randf() < 0.12:
					c = veg.darkened(0.18)
			else:
				c = rock.lightened(0.14) if lit else rock
				if rng.randf() < 0.05:
					c = rock.darkened(0.15)
			_px(img, x, hy - 1 - yy, c)
		_px(img, x, hy - hh, rock.darkened(0.25) if hh > vy else veg.darkened(0.25))

static func _profile(n: int, peaks: Array) -> PackedFloat32Array:
	# peaks : [centre, hauteur, demi-largeur, exposant] — on garde le max.
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v: float = 0.0
		for p in peaks:
			var u: float = absf(float(i) - float(p[0])) / float(p[2])
			if u < 1.0:
				v = maxf(v, float(p[1]) * pow(1.0 - u * u, float(p[3])) * (1.0 - 0.35 * u))
		out[i] = v
	return out

static func _buildings(img: Image, hy: int, x0: int, x1: int, hmin: int, hmax: int, rng: RandomNumberGenerator) -> void:
	var cols: Array = [Color(0.88, 0.87, 0.83), Color(0.8, 0.83, 0.86), Color(0.9, 0.84, 0.74), Color(0.76, 0.79, 0.8)]
	var x: int = x0
	while x < x1:
		var bw: int = rng.randi_range(3, 7)
		var bh: int = rng.randi_range(hmin, hmax)
		var c: Color = cols[rng.randi() % cols.size()]
		_fill(img, x, hy - bh, bw, bh, c)
		_fill(img, x + bw - 1, hy - bh, 1, bh, c.darkened(0.15))
		for wy in range(hy - bh + 1, hy - 1, 2):
			for wx in range(x + 1, x + bw - 1, 2):
				_px(img, wx, wy, c.darkened(0.25))
		x += bw + rng.randi_range(0, 1)
	_fill(img, x0, hy - 1, x1 - x0, 1, Color(0.3, 0.5, 0.36))

static func _ipanema_skyline(img: Image, hy: int, rng: RandomNumberGenerator) -> void:
	var haze_rock: Color = Color(0.6, 0.64, 0.72)
	var haze_veg: Color = Color(0.4, 0.56, 0.55)
	# Ilhas Cagarras au large.
	_mass(img, hy, _nx(380), _profile(60, [[14, 7, 14, 0.7], [38, 5, 12, 0.8], [52, 3, 7, 1.0]]), Color(0.62, 0.68, 0.76), Color(0.48, 0.62, 0.64), rng, 0.4)
	# Pedra da Gávea derrière, plus voilée (table au sommet).
	var gx: int = _nx(1640)
	var gav: PackedFloat32Array = _profile(140, [[70, 26, 70, 0.35]])
	for i in gav.size():
		gav[i] = minf(gav[i], 22.0)
	_mass(img, hy, gx, gav, Color(0.66, 0.71, 0.8), Color(0.5, 0.64, 0.66), rng, 0.4)
	# Ipanema / Leblon : la ville au pied du morne.
	_buildings(img, hy, _nx(780), _nx(1200), 2, 6, rng)
	# Morro Dois Irmãos : le grand à gauche, le petit à droite, Vidigal au pied.
	var dx: int = _nx(1130)
	var dois: PackedFloat32Array = _profile(190, [[52, 36, 52, 0.85], [118, 24, 46, 0.9], [160, 9, 32, 1.0]])
	_mass(img, hy, dx, dois, haze_rock, haze_veg, rng, 0.42)
	var vid: Array = [Color(0.86, 0.5, 0.36), Color(0.95, 0.92, 0.84), Color(0.92, 0.78, 0.4), Color(0.52, 0.66, 0.84), Color(0.8, 0.42, 0.42)]
	for i in 70:
		var vx: int = dx + rng.randi_range(8, 70)
		var vy: int = hy - 1 - rng.randi_range(0, 9)
		if img.get_pixel(vx, vy).g < 0.6 and img.get_pixel(vx, vy).b < 0.7:
			_px(img, vx, vy, vid[rng.randi() % vid.size()])

static func _barra_skyline(img: Image, hy: int, rng: RandomNumberGenerator) -> void:
	# Barra : tours le long de la plage, Pedra da Gávea et Pedra Bonita.
	_buildings(img, hy, _nx(-330), _nx(760), 5, 16, rng)
	_mass(img, hy, _nx(880), _profile(70, [[16, 6, 16, 0.7], [46, 8, 20, 0.7]]), Color(0.6, 0.67, 0.76), Color(0.46, 0.6, 0.62), rng, 0.6)
	_mass(img, hy, _nx(1150), _profile(90, [[45, 22, 45, 0.6]]), Color(0.62, 0.66, 0.74), Color(0.42, 0.58, 0.54), rng, 0.55)
	var gav: PackedFloat32Array = _profile(170, [[85, 40, 85, 0.5]])
	for i in gav.size():
		gav[i] = minf(gav[i], 32.0) + (2.0 if i > 70 and i < 120 and gav[i] >= 32.0 else 0.0)
	_mass(img, hy, _nx(1360), gav, Color(0.58, 0.6, 0.66), Color(0.38, 0.55, 0.48), rng, 0.38)
	_mass(img, hy, _nx(1900), _profile(120, [[35, 14, 35, 0.8], [80, 10, 30, 0.9]]), Color(0.68, 0.72, 0.8), Color(0.54, 0.66, 0.68), rng, 0.4)

# Pedra do Arpoador, sur la gauche, posée devant les vagues. Le spot de surf
# est à son pied ; quelques silhouettes au sommet regardent la session.
const ROCK_ORIGIN: Vector2 = Vector2(-330, 165)

static func _rock_edge(wy: float) -> float:
	if wy < 230.0:
		var t: float = (wy - 165.0) / 65.0
		return lerpf(-260.0, 10.0, sqrt(clampf(t, 0.0, 1.0)))
	if wy < 420.0:
		return 10.0 + 30.0 * sin((wy - 230.0) / 190.0 * PI)
	if wy < 700.0:
		return lerpf(10.0, -95.0, (wy - 420.0) / 280.0)
	return lerpf(-95.0, -150.0, (wy - 700.0) / 600.0)

static func arpoador_rock() -> ImageTexture:
	if _cache.has("rock"):
		return _cache["rock"]
	var w: int = 400 / D
	var h: int = (1300 - 165) / D
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var light: Color = ROCK.lightened(0.18)
	var shade: Color = ROCK.darkened(0.18)
	var dark: Color = ROCK.darkened(0.45)
	var prev_r: int = 0
	for y in h:
		var wy: float = ROCK_ORIGIN.y + (float(y) + 0.5) * D
		var r: int = int(floor((_rock_edge(wy) - ROCK_ORIGIN.x) / D)) + rng.randi_range(-1, 0)
		if r <= 0:
			continue
		_fill(img, 0, y, r, 1, ROCK)
		# Strates : bandes sombres légèrement inclinées.
		if y % 17 == 0:
			var sl: int = rng.randi_range(8, 30)
			_fill(img, r - sl - 4, y, sl, 1, shade)
			_fill(img, r - sl - 2, y + 1, sl - 4, 1, light)
		_fill(img, r - 5, y, 3, 1, light)
		_fill(img, r - 1, y, 1, 1, dark)
		if y > 0 and r > prev_r:
			_fill(img, prev_r, y - 1, r - prev_r, 1, light.lightened(0.1))
		prev_r = r
		# Écume au pied : la mer cogne contre la pierre.
		if wy > 260.0 and wy < SHORE_Y:
			var fw: int = rng.randi_range(1, 3)
			_fill(img, r, y, fw, 1, WHITE if rng.randf() < 0.6 else FOAM_SH)
	# Facettes et fissures.
	for i in 260:
		var fx: int = rng.randi_range(2, w - 4)
		var fy: int = rng.randi_range(8, h - 2)
		if img.get_pixel(fx, fy).a > 0.0 and img.get_pixel(fx + 3, fy).a > 0.0:
			var c: Color = [light, shade, shade, dark][rng.randi() % 4]
			_fill(img, fx, fy, rng.randi_range(1, 3), 1, c)
	# Mata rase au sommet, et des silhouettes qui regardent la mer.
	for x in range(0, 82):
		var top: int = -1
		for y in 30:
			if img.get_pixel(x, y).a > 0.0:
				top = y
				break
		if top < 0:
			continue
		_fill(img, x, top, 1, 2 + (x * 7 % 3), Color(0.32, 0.5, 0.3) if x % 5 else Color(0.42, 0.6, 0.34))
		_px(img, x, top, Color(0.2, 0.34, 0.2))
	var people: Array = [Color(0.85, 0.3, 0.3), Color(0.95, 0.8, 0.3), Color(0.3, 0.5, 0.85), Color(0.95, 0.95, 0.9), Color(0.3, 0.7, 0.45)]
	for i in 7:
		var px: int = 18 + i * 9 + rng.randi_range(-2, 2)
		var top2: int = 0
		while top2 < 40 and img.get_pixel(px, top2).a == 0.0:
			top2 += 1
		_fill(img, px, top2 - 3, 1, 3, people[i % people.size()])
		_px(img, px, top2 - 4, Color(0.55, 0.36, 0.25))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["rock"] = tex
	return tex

# --- Vagues ---

# Stade : 0 = houle ronde, 1 = la crête fume, 2 = la lèvre déferle.
static func _face_column(img: Image, x: int, bottom: int, hh: int, ramp: Array, stage: int, rng: RandomNumberGenerator, foam_rows: int = 0) -> void:
	if hh <= 0:
		return
	var top: int = bottom - hh
	if hh <= 3:
		_fill(img, x, top, 1, hh, ramp[1])
		_px(img, x, top, ramp[0].lightened(0.3) if stage == 0 else WHITE)
		return
	var b1: int = top + int(ceil(hh * 0.3))
	var b2: int = top + int(ceil(hh * 0.6))
	var b3: int = top + int(ceil(hh * 0.88))
	_fill(img, x, top, 1, b1 - top, ramp[0])
	_fill(img, x, b1, 1, b2 - b1, ramp[1])
	_fill(img, x, b2, 1, b3 - b2, ramp[2])
	_fill(img, x, b3, 1, bottom - b3, ramp[3])
	# Trame aux coutures de bandes.
	if x % 2 == 0:
		_px(img, x, b1, ramp[0])
		_px(img, x, b2, ramp[1])
		_px(img, x, b3, ramp[2])
	# Filets d'eau aspirés le long de la face.
	if rng.randf() < 0.08:
		var s0: int = b1 + rng.randi_range(0, maxi(1, (b2 - b1)))
		_fill(img, x, s0, 1, rng.randi_range(2, 4), ramp[1].lightened(0.2))
	# Lèvre.
	if stage == 0:
		_px(img, x, top, ramp[0].lightened(0.32))
	else:
		_px(img, x, top, WHITE)
		if stage == 2:
			_px(img, x, top + 1, FOAM_SH)
	if foam_rows > 0:
		var fr: int = mini(foam_rows, hh - 1)
		_fill(img, x, top, 1, fr, WHITE)
		_fill(img, x, top + fr, 1, 1, FOAM_SH)
		if rng.randf() < 0.4:
			_px(img, x, top + fr + 1, FOAM_SH)
		for k in 2:
			var sp: int = top + rng.randi_range(1, fr)
			_px(img, x, sp, FOAM_SH if rng.randf() < 0.5 else WHITE)
	# Ombre au pied : le creux devant la vague.
	_px(img, x, bottom - 1, ramp[3].darkened(0.25))

const SPRAY_ROOM: int = 6

static func wave_body(tier: int, hn: int, stage: int) -> ImageTexture:
	var key: String = "body_%d_%d_%d" % [tier, hn, stage]
	if _cache.has(key):
		return _cache[key]
	var h: int = hn + SPRAY_ROOM
	var img: Image = Image.create(TILE_W, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tier * 131 + hn * 7 + stage
	var ramp: Array = FACES[tier]
	for x in TILE_W:
		var wob: float = sin(TAU * float(x) / 32.0 + float(tier)) * 0.8 + sin(TAU * float(x) * 3.0 / 64.0) * 0.6
		var hh: int = maxi(1, hn + int(round(wob * clampf(float(hn) / 12.0, 0.0, 1.0))))
		_face_column(img, x, h, hh, ramp, stage, rng)
		if stage >= 1 and rng.randf() < 0.12:
			_px(img, x, h - hh - rng.randi_range(1, 2), Color(1, 1, 1, 0.75))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# Pic en A : la section la plus haute, celle qui déferle la première.
# `hb` = hauteur du corps (raccord aux bords), `pw` = largeur du pic (natif).
static func wave_peak(tier: int, hn: int, hb: int, pw: int, stage: int) -> ImageTexture:
	var key: String = "peak_%d_%d_%d_%d_%d" % [tier, hn, hb, pw, stage]
	if _cache.has(key):
		return _cache[key]
	var w: int = pw * 2
	var h: int = hn + SPRAY_ROOM
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tier * 977 + hn * 13 + pw + stage * 5
	var ramp: Array = FACES[tier]
	for x in w:
		var u: float = absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
		var hh: int = int(round(profile_h(hn, hb, pw, u * float(pw))))
		var foam: int = 0
		if stage == 2 and u < 0.42:
			foam = int(float(hh) * (0.18 + 0.4 * (1.0 - u / 0.42))) + rng.randi_range(-1, 1)
		_face_column(img, x, h, hh, ramp, stage if u < 0.7 else mini(stage, 1), rng, maxi(foam, 0))
		# Ombre du tube juste sous la lèvre, sur les flancs du déferlement.
		if stage == 2 and u >= 0.42 and u < 0.6 and hh > 6:
			_fill(img, x, h - hh + 1, 1, 2, ramp[3])
		# Embruns au-dessus de la crête.
		if stage >= 1 and u < 0.55:
			for k in (2 if stage == 2 else 1):
				if rng.randf() < 0.35:
					_px(img, x, h - hh - rng.randi_range(1, SPRAY_ROOM - 1), Color(1, 1, 1, 0.8))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# Mousse d'une vague cassée (bore) : sommet déchiqueté, remous bleutés.
static func whitewater(hn: int) -> ImageTexture:
	var key: String = "ww_%d" % hn
	if _cache.has(key):
		return _cache[key]
	var h: int = hn + SPRAY_ROOM
	var img: Image = Image.create(TILE_W, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hn * 31 + 3
	for x in TILE_W:
		var hh: int = maxi(1, hn + int(round(sin(float(x) * TAU / 16.0) * 1.2)) + rng.randi_range(-1, 1))
		var top: int = h - hh
		_fill(img, x, top, 1, hh, FOAM_SH)
		_fill(img, x, top, 1, maxi(1, hh / 2), WHITE)
		_fill(img, x, h - maxi(1, hh / 5), 1, maxi(1, hh / 5), FOAM_DEEP)
		for k in maxi(1, hh / 4):
			_px(img, x, top + rng.randi_range(0, hh - 1), WHITE if rng.randf() < 0.5 else FOAM_DEEP)
		if rng.randf() < 0.3:
			_px(img, x, top - rng.randi_range(1, 3), Color(1, 1, 1, 0.7))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# Profil d'une vague (hauteur native d'une colonne) : corps `hb` partout,
# bosse en A de demi-largeur `pw` autour du pic (`dx` = écart au pic, natif).
static func profile_h(hn: int, hb: int, pw: int, dx: float) -> float:
	var u: float = absf(dx) / float(pw)
	if u >= 1.0:
		return float(hb)
	return float(hb) + float(hn - hb) * pow(1.0 - u, 1.5) * (1.0 - 0.25 * u)

# Mousse de la vague ridée (non cachée : elle change pendant la ride) :
# épouse le profil de la face, extrémités en pente, sommet déchiqueté.
# `off` = colonne de départ relative au pic.
static func ride_foam(hn: int, hb: int, pw: int, off: int, wn: int) -> ImageTexture:
	var h: int = hn + SPRAY_ROOM
	var img: Image = Image.create(maxi(wn, 1), h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hn * 17 + off
	var ramp: int = mini(16, wn / 2)
	for x in wn:
		var edge: float = 1.0
		if ramp > 0:
			edge = clampf(float(mini(x, wn - 1 - x)) / float(ramp), 0.0, 1.0)
		var ph: float = profile_h(hn, hb, pw, float(off + x))
		var hh: int = int(ph * (0.1 + 0.82 * sqrt(edge))) + int(round(sin(float(off + x) * TAU / 11.0) * 1.5)) + rng.randi_range(-1, 1)
		if hh <= 0:
			continue
		var top: int = h - hh
		_fill(img, x, top, 1, hh, FOAM_SH)
		_fill(img, x, top, 1, maxi(1, hh * 3 / 5), WHITE)
		_fill(img, x, h - maxi(1, hh / 6), 1, maxi(1, hh / 6), FOAM_DEEP)
		for k in maxi(1, hh / 5):
			_px(img, x, top + rng.randi_range(0, hh - 1), WHITE if rng.randf() < 0.4 else FOAM_DEEP)
		for k in 2:
			if rng.randf() < 0.45:
				_px(img, x, top - rng.randi_range(1, SPRAY_ROOM - 1), Color(1, 1, 1, 0.8))
	return ImageTexture.create_from_image(img)

# --- Planches & aile ---

const BOARD_COLORS: Array = [Color(0.98, 0.78, 0.22), Color(0.95, 0.42, 0.3), Color(0.25, 0.7, 0.85)]

# Pranchão vu de derrière (rider assis au line-up) : nez vers l'horizon.
static func board_back(col: Color) -> ImageTexture:
	var key: String = "bb_%s" % col.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var w: int = 13
	var h: int = 34
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var t: float = float(y) / float(h - 1)
		var hw: float = 6.0 * sqrt(clampf(t * 1.6, 0.0, 1.0)) if t < 0.62 else 6.0 - 2.5 * pow((t - 0.62) / 0.38, 2.0)
		var x0: int = int(round(6.0 - hw))
		var x1: int = int(round(6.0 + hw))
		for x in range(x0, x1 + 1):
			var c: Color = col.lightened(0.18) if x < 6 else col
			if x == x0 or x == x1 or y == 0 or y == h - 1:
				c = OUTLINE
			elif x == 6:
				c = Color(0.97, 0.95, 0.9)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# Planche de profil, nez à droite, rocker et dérive. `twin` = twin-tip de
# kite (symétrique, straps, ailerons aux deux bouts).
static func board_side(col: Color, twin: bool = false) -> ImageTexture:
	var key: String = "bs_%s_%s" % [col.to_html(false), twin]
	if _cache.has(key):
		return _cache[key]
	var w: int = 30 if twin else 44
	var h: int = 9
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in w:
		var u: float = float(x) / float(w - 1)
		var rock: float
		if twin:
			rock = 2.5 * pow(absf(u * 2.0 - 1.0), 4.0)
		else:
			rock = 4.0 * pow(maxf(0.0, (u - 0.7) / 0.3), 2.0) + 1.0 * pow(maxf(0.0, (0.15 - u) / 0.15), 2.0)
		var top: int = 4 - int(round(rock))
		var th: int = 3 if (x > 1 and x < w - 2) else 2
		img.set_pixel(x, top, OUTLINE)
		for k in range(1, th):
			img.set_pixel(x, top + k, col.lightened(0.2) if k == 1 else col)
		if top + th < h:
			img.set_pixel(x, top + th, OUTLINE)
		if not twin and x % 7 == 0 and x > 4 and x < w - 6:
			img.set_pixel(x, top + 1, Color(0.97, 0.95, 0.9))
	if twin:
		for fx in [3, w - 4]:
			img.set_pixel(fx, 7, OUTLINE)
			img.set_pixel(fx, 8, OUTLINE)
		for sx in [8, 9, w - 10, w - 9]:
			img.set_pixel(sx, 2, Color(0.15, 0.15, 0.18))
	else:
		for k in 3:
			img.set_pixel(4 + k, 7, OUTLINE)
			img.set_pixel(4, 8, OUTLINE)
			img.set_pixel(5, 8, OUTLINE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# Aile de kite vue de face : bord d'attaque gonflé, panneaux alternés,
# lattes sombres, bouts d'aile recourbés.
static func kite_wing() -> ImageTexture:
	if _cache.has("kite"):
		return _cache["kite"]
	var w: int = 48
	var h: int = 22
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var panels: Array = [Color(0.95, 0.3, 0.28), Color(0.98, 0.82, 0.25), Color(0.95, 0.3, 0.28), Color(0.2, 0.68, 0.82), Color(0.95, 0.3, 0.28), Color(0.98, 0.82, 0.25)]
	for x in w:
		var u: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
		var top: int = int(round(10.0 * pow(absf(u), 2.4)))
		var th: int = int(round(lerpf(8.0, 4.0, absf(u))))
		var c: Color = panels[int((u * 0.5 + 0.5) * panels.size() * 0.999)]
		img.set_pixel(x, top, OUTLINE)
		img.set_pixel(x, top + 1, Color(0.97, 0.97, 0.94))
		img.set_pixel(x, top + 2, Color(0.82, 0.84, 0.86))
		for k in range(3, th + 3):
			img.set_pixel(x, top + k, c.darkened(0.15) if k > th else c)
		img.set_pixel(x, top + th + 3, OUTLINE)
		if x % 8 == 4:
			for k in range(3, th + 2):
				img.set_pixel(x, top + k, c.darkened(0.3))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["kite"] = tex
	return tex

# --- Jauges ---

# Bande d'équilibre (640×60 monde → 213×20) : rouge aux bords, vert au centre.
static func balance_strip() -> ImageTexture:
	if _cache.has("bal"):
		return _cache["bal"]
	var w: int = 213
	var h: int = 20
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var zones: Array = [[0.0, Color(0.85, 0.25, 0.22)], [0.06, Color(0.95, 0.52, 0.25)], [0.2, Color(0.96, 0.8, 0.3)], [0.4, Color(0.36, 0.78, 0.42)], [0.6, Color(0.96, 0.8, 0.3)], [0.8, Color(0.95, 0.52, 0.25)], [0.94, Color(0.85, 0.25, 0.22)]]
	for x in w:
		var u: float = float(x) / float(w)
		var c: Color = zones[0][1]
		for z in zones:
			if u >= float(z[0]):
				c = z[1]
		_fill(img, x, 0, 1, h, c)
		_px(img, x, 0, c.lightened(0.3))
		_px(img, x, 1, c.lightened(0.15))
		_px(img, x, h - 1, c.darkened(0.3))
		_px(img, x, h - 2, c.darkened(0.15))
		# Vaguelettes : motif du calçadão discret dans la jauge.
		var wy: int = 10 + int(round(sin(float(x) * TAU / 14.0) * 3.0))
		_px(img, x, wy, c.lightened(0.22))
	_fill(img, 106, 2, 1, h - 4, Color(1, 1, 1, 0.8))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["bal"] = tex
	return tex

# Curseur : petite planche debout (18×72 monde).
static func cursor_board() -> ImageTexture:
	if _cache.has("cur"):
		return _cache["cur"]
	var img: Image = Image.create(6, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 24:
		var hw: int = 1 if (y < 3 or y > 21) else 2
		for x in range(3 - hw - 1, 3 + hw + 1):
			var edge: bool = x == 3 - hw - 1 or x == 3 + hw or y == 0 or y == 23
			img.set_pixel(x, y, OUTLINE if edge else (Color(1, 1, 1) if x == 3 else Color(0.95, 0.95, 0.92)))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["cur"] = tex
	return tex

# Jauge de l'aile (44×400 monde → 15×133), zone verte = fenêtre de saut.
static func kite_strip(band_min: float, band_max: float) -> ImageTexture:
	var key: String = "ks_%.2f_%.2f" % [band_min, band_max]
	if _cache.has(key):
		return _cache[key]
	var w: int = 15
	var h: int = 133
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var p: float = 1.0 - float(y) / float(h)
		var c: Color = Color(0.2, 0.26, 0.36)
		if p > band_max:
			c = Color(0.82, 0.26, 0.24)
		elif p >= band_min:
			c = Color(0.34, 0.78, 0.42)
		_fill(img, 0, y, w, 1, c)
		_px(img, 0, y, c.lightened(0.25))
		_px(img, w - 1, y, c.darkened(0.3))
		if y % 13 == 0:
			_fill(img, 1, y, 3, 1, c.lightened(0.35))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
