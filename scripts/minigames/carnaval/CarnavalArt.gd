extends Node2D

# La nuit du desfile sur la Marquês de Sapucaí — rendu seul, aucune règle de
# jeu ici. Fond peint une fois en pixels de 4 px (ciel, morro, arquibancadas
# pleines en perspective, Arco da Apoteose, piste) ; couches animées par-dessus :
# projecteurs, carro alegórico qui avance, bateria qui marque le temps, pistes
# lumineuses des 4 instruments, ligne de frappe, confettis et serpentins.

const P: int = 4
const X0: int = -480
const Y0: int = -200
const ART_W: int = 720
const ART_H: int = 375
# Perspective : œil à 1 unité du sol, piste de demi-largeur AV_W, gradins à
# 45° jusqu'à STAND_H, Praça da Apoteose à la profondeur AV_END.
const VP: Vector2 = Vector2(920.0, 200.0)
const F: float = 880.0
const AV_W: float = 1.32
const STAND_H: float = 2.0
const AV_END: float = 10.0
const ROW_H: float = 0.1
const SEAT: float = 0.085
const FRISA_H: float = 0.32
const LANE_HALF: float = 65.0
const S_TOP: float = 0.62
const BEAT: float = 0.5

const LINE: Color = Color(0.12, 0.08, 0.16, 1.0)
const GREEN: Color = Color(0.10, 0.62, 0.36, 1.0)
const PINK: Color = Color(0.96, 0.38, 0.64, 1.0)
const GOLD: Color = Color(1.0, 0.80, 0.24, 1.0)
const GOLD_DK: Color = Color(0.78, 0.50, 0.12, 1.0)
const GOLD_HI: Color = Color(1.0, 0.95, 0.62, 1.0)
const WHITE: Color = Color(0.96, 0.95, 0.92, 1.0)
const RISER: Color = Color(0.22, 0.19, 0.31, 1.0)
const RISER_HI: Color = Color(0.40, 0.36, 0.50, 1.0)
const GAP: Color = Color(0.12, 0.09, 0.19, 1.0)
const SKINS: Array[Color] = [
	Color(0.96, 0.80, 0.64), Color(0.85, 0.64, 0.46), Color(0.68, 0.47, 0.32),
	Color(0.50, 0.33, 0.22), Color(0.36, 0.24, 0.17),
]
const HAIRS: Array[Color] = [
	Color(0.10, 0.08, 0.07), Color(0.24, 0.15, 0.09), Color(0.42, 0.27, 0.14),
	Color(0.80, 0.62, 0.30), Color(0.96, 0.40, 0.66),
]
# Verde e rosa en majorité (l'école), le reste en fantasias.
const SHIRTS: Array[Color] = [
	Color(0.10, 0.62, 0.36), Color(0.96, 0.38, 0.64), Color(0.10, 0.62, 0.36),
	Color(0.96, 0.38, 0.64), Color(0.96, 0.96, 0.94), Color(0.98, 0.84, 0.16),
	Color(0.20, 0.45, 0.88), Color(0.96, 0.55, 0.18), Color(0.86, 0.16, 0.20),
	Color(0.62, 0.30, 0.86),
]
const CONFETTI: Array[Color] = [
	Color(0.98, 0.84, 0.16), Color(0.96, 0.38, 0.64), Color(0.10, 0.70, 0.40),
	Color(0.30, 0.62, 0.98), Color(0.98, 0.98, 0.96), Color(0.96, 0.55, 0.18),
]

# Icônes pixel des instruments (12×10) : k trait, w peau, g/d métal, b baguette.
const ICONS: Array = [
	[  # tamborim + baguette
		"..kkkkk...kk",
		".kwwwwwk.kbk",
		"kwwwwwwwkbk.",
		"kwwwwwwkbk..",
		"kwwwwwkbwk..",
		"kwwwwkbwwk..",
		"kgwwwwwwgk..",
		".kggggggk...",
		"..kkkkkk....",
		"............",
	],
	[  # surdo
		"..kkkkkkkk..",
		".kwwwwwwwwk.",
		"kwwwwwwwwwwk",
		"kgwwwwwwwwgk",
		"kdkkkkkkkkdk",
		"kdgkgggkggdk",
		"kdggkgkgggdk",
		"kdgggkgggkdk",
		"kkdggggggdkk",
		"..kkkkkkkk..",
	],
	[  # cuíca (couchée, peau à gauche, tige dedans)
		"............",
		".kk.kkkkkkk.",
		"kwwkgggggggk",
		"kwwkggdggggk",
		"kwwkbbbbbbbk",
		"kwwkggggdggk",
		"kwwkgggggggk",
		".kk.kkkkkkk.",
		"..........k.",
		"............",
	],
	[  # agogô (deux cloches sur l'anse)
		"..kk....kk..",
		".kwgk..kwgk.",
		".kwgk..kwgk.",
		"kwggdk.kwgk.",
		"kwggdkkwggdk",
		"kwgggdkwggdk",
		"kkkkkkkkkkkk",
		"..k......k..",
		"...kkkkkk...",
		"............",
	],
]
# Versions de poche pour les ritmistas (pixels du personnage).
const SMALL: Array = [
	[".kkk.", "kwwwk", "kwwwk", "kgggk", ".kkk."],
	[".kkkkk.", "kwwwwwk", "kgwwwgk", "kdkgkdk", "kdgkgdk", ".kkkkk."],
	["kkkkkk.", "kwgggk.", "kwgdgkk", "kwgggk.", "kkkkkk."],
	["kk.kk.", "kgkkgk", "kgkkgk", "kkkkkk"],
]
const ICON_COLORS: Dictionary = {
	"k": Color(0.12, 0.08, 0.16), "w": Color(0.98, 0.96, 0.90), "g": Color(0.74, 0.76, 0.84),
	"d": Color(0.46, 0.47, 0.58), "b": Color(0.62, 0.38, 0.20),
}

var lane_x: Array = [560.0, 800.0, 1040.0, 1280.0]
var lane_colors: Array = []
var top_y: float = 80.0
var hit_y: float = 720.0
var fall_speed: float = 426.0
var lead_in: float = 2.0
var duration: float = 90.0
var clock: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t: float = 0.0
var _beams: Node2D
var _float: Sprite2D
var _float_tex: ImageTexture
var _track: Node2D
var _fx: Node2D
var _crew: Array = []            # {spr, inst, foot, s, ph, inst_off}
var _player: Sprite2D
var _player_inst: Sprite2D
var _player_foot: float = 0.0
var _player_hop: float = 0.0
var _mestre_baton: Sprite2D
var _note_tex: Array[ImageTexture] = []
var _small_tex: Array[ImageTexture] = []
var _press_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_col: Array[Color] = [WHITE, WHITE, WHITE, WHITE]
var _confetti: Array = []        # {pos, vel, col, ph, size}
var _streamers: Array = []       # {pos, vel, col, ph, len}
var _lamps: Array[Vector2] = []
var _streak: int = 0
var _breque: bool = false
var _rain: float = 0.0
var _popups: Dictionary = {}     # lane → Label affiché
var _streamer_t: float = 0.0

func setup(lanes: Array, colors: Array, spawn_y: float, target_y: float, speed: float,
		lead: float, total: float) -> void:
	lane_x = lanes
	lane_colors = colors
	top_y = spawn_y
	hit_y = target_y
	fall_speed = speed
	lead_in = lead
	duration = total

func _ready() -> void:
	_rng.seed = 1984
	z_index = -1
	if lane_colors.is_empty():
		lane_colors = [Color(0.85, 0.3, 0.5), Color(0.4, 0.65, 0.95), Color(0.55, 0.95, 0.55), Color(0.95, 0.85, 0.4)]
	for i in 4:
		_note_tex.append(_build_note(i))
		_small_tex.append(_icon_texture(SMALL[i], 1))
	var bg: Sprite2D = Sprite2D.new()
	bg.centered = false
	bg.position = Vector2(X0, Y0)
	bg.scale = Vector2(P, P)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = ImageTexture.create_from_image(_build_static())
	add_child(bg)
	_beams = _layer(_draw_beams)
	_build_float()
	_build_far_bateria()
	var hw: Sprite2D = Sprite2D.new()
	hw.centered = false
	hw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hw.texture = ImageTexture.create_from_image(_build_highway())
	hw.position = Vector2(_hw_x0(), _hw_y0())
	hw.scale = Vector2(P, P)
	add_child(hw)
	_track = _layer(_draw_track)
	_build_near_bateria()
	_fx = _layer(_draw_fx)
	_fx.z_index = 3

func _layer(cb: Callable) -> Node2D:
	var n: Node2D = Node2D.new()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.draw.connect(cb.bind(n))
	add_child(n)
	return n

# =====================================================================
# API du jeu
# =====================================================================

func note_texture(lane: int) -> Texture2D:
	return _note_tex[lane]

# Icône d'instrument agrandie (boutons tactiles).
func icon_texture(lane: int, k: int) -> Texture2D:
	return _icon_texture(ICONS[lane], k)

# Échelle de la fausse perspective de la piste (1 sur la ligne de frappe).
func lane_scale(y: float) -> float:
	return lerpf(S_TOP, 1.0, (y - top_y) / (hit_y - top_y))

func lane_center(lane: int, y: float) -> float:
	return VP.x + (float(lane_x[lane]) - VP.x) * lane_scale(y)

func press(lane: int) -> void:
	_press_t[lane] = 0.12
	_player_hop = 0.12
	_player_inst.texture = _small_tex[lane]

func hit(lane: int, perfect: bool) -> void:
	_streak += 1
	var col: Color = lane_colors[lane]
	_flash(lane, col.lightened(0.5) if perfect else col)
	_popup(lane, "PERFEITO!" if perfect else "BOA", GOLD_HI if perfect else Color(0.85, 1.0, 0.85))
	_burst(Vector2(lane_x[lane], hit_y), 36 if perfect else 14, col)
	if perfect and _streak % 12 == 0:
		_burst(Vector2(VP.x, hit_y - 200.0), 90, GOLD)
		_popup(-1, "ARRASOU! %d" % _streak, GOLD)

func off_beat(lane: int) -> void:
	_streak = 0
	_flash(lane, Color(1.0, 0.25, 0.25))
	_popup(lane, "ATRAVESSOU", Color(1.0, 0.45, 0.42))

func miss(lane: int) -> void:
	_streak = 0
	_popup(lane, "PASSOU", Color(0.72, 0.70, 0.82))

# Mesure qui arrive : 0 base, 1 virada, 2 breque.
func phase(which: int) -> void:
	_breque = which == 2
	if which == 1:
		_popup(-2, "VIRADA!", PINK)
	elif which == 2:
		_popup(-2, "BREQUE!", Color(0.5, 0.95, 0.65))

func finish(qualifies: bool) -> void:
	if qualifies:
		_burst(Vector2(VP.x, 400.0), 160, GOLD)
		_popup(-1, "REINADO!", GOLD)

# =====================================================================
# Boucle
# =====================================================================

func _process(delta: float) -> void:
	_t += delta
	for i in 4:
		_press_t[i] = maxf(_press_t[i] - delta, 0.0)
		_flash_t[i] = maxf(_flash_t[i] - delta, 0.0)
	_player_hop = maxf(_player_hop - delta, 0.0)
	_step_particles(delta)
	_step_float()
	_step_crew()
	_beams.queue_redraw()
	_track.queue_redraw()
	_fx.queue_redraw()

func _beat_frac() -> float:
	return fposmod(clock - lead_in, BEAT) / BEAT

func _beat_idx() -> int:
	return int(floorf((clock - lead_in) / BEAT))

# =====================================================================
# Fond statique
# =====================================================================

static func _hash(a: int, b: int, c: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

func _build_static() -> Image:
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	for j in ART_H:
		var y: float = float(Y0 + j * P) + P * 0.5
		var v: float = (VP.y - y) / F
		for i in ART_W:
			var x: float = float(X0 + i * P) + P * 0.5
			img.set_pixel(i, j, _shade((x - VP.x) / F, v, i, j))
	_paint_arch(img)
	_paint_lamp_posts(img)
	return img

# Couleur d'un pixel : gradin (plan à 45° depuis le bord de la piste), piste,
# praça au-delà de l'arche, ou ciel.
func _shade(u: float, v: float, i: int, j: int) -> Color:
	var side: int = -1 if u < 0.0 else 1
	var den: float = absf(u) - v
	if den > 0.0:
		var z: float = (AV_W + 1.0) / den
		var e: float = v * z + 1.0
		if z <= AV_END and e >= 0.0 and e <= STAND_H:
			return _stand(z, e, side)
	if v < 0.0:
		var zg: float = -1.0 / v
		var xg: float = u * zg
		if zg <= AV_END and absf(xg) <= AV_W:
			return _avenue(xg, zg)
		if zg > AV_END:
			return _plaza(xg, zg)
	return _sky(i, j)

func _stand(z: float, e: float, side: int) -> Color:
	var fog: float = clampf((z - 2.0) / (AV_END - 2.0), 0.0, 1.0) * 0.3
	var col: Color = GAP
	if e < FRISA_H:
		col = _frisa(z, e, side)
	elif e > STAND_H - 0.09:
		col = Color(0.80, 0.76, 0.88) if e > STAND_H - 0.03 else Color(0.56, 0.52, 0.66)
	else:
		var re: float = (e - FRISA_H) / ROW_H
		var r: int = int(re)
		var fr: float = re - float(r)
		var sz: float = z / SEAT + float(r) * 0.37
		var s: int = int(sz)
		var fs: float = sz - float(s)
		var h: int = _hash(r, s, side)
		if fr < 0.16:
			col = RISER if fr < 0.11 else RISER_HI
		elif fr < 0.56 and fs > 0.1 and fs < 0.9:
			col = SHIRTS[h % SHIRTS.size()]
			if fs > 0.72:
				col = col.darkened(0.28)
		elif fr >= 0.56 and fr < 0.93 and fs > 0.28 and fs < 0.72:
			col = SKINS[(h >> 4) % SKINS.size()]
			if fr > 0.8:
				col = HAIRS[(h >> 8) % HAIRS.size()]
			if (h >> 16) % 29 == 0:
				col = WHITE  # flash de téléphone
		elif fr >= 0.4 and (h >> 12) % 4 == 0 and fs > 0.06 and fs < 0.2:
			col = SKINS[(h >> 4) % SKINS.size()]  # bras levé
		# Public dans la pénombre (les pistes doivent ressortir), le haut encore plus.
		col = col.darkened(0.2 if r <= 11 else 0.3)
	return col.darkened(fog)

# Frisas du bas : mur blanc des camarotes, lampes, public accoudé, guirlande.
func _frisa(z: float, e: float, side: int) -> Color:
	if e < 0.035:
		return Color(0.16, 0.12, 0.22)
	if fposmod(z / 0.7, 1.0) < 0.05:
		return Color(0.98, 0.96, 1.0)
	if e > 0.27:
		return GREEN if int(z / 0.18) % 2 == 0 else PINK
	if e > 0.155:
		var h: int = _hash(int(z / 0.06), 7, side)
		var fs: float = fposmod(z / 0.06, 1.0)
		if e > 0.2 and fs > 0.25 and fs < 0.75:
			return SKINS[h % SKINS.size()] if e < 0.245 else HAIRS[(h >> 3) % HAIRS.size()]
		return SHIRTS[(h >> 5) % SHIRTS.size()].darkened(0.2) if e < 0.2 else Color(0.20, 0.14, 0.26)
	if e > 0.10 and e < 0.13 and fposmod(z / 0.35, 1.0) < 0.3:
		return Color(1.0, 0.92, 0.55)
	return Color(0.88, 0.84, 0.92)

func _avenue(xg: float, zg: float) -> Color:
	var col: Color = Color(0.44, 0.41, 0.50)
	if absf(xg) < 0.55:
		col = Color(0.50, 0.47, 0.56)
	if fposmod(zg / 0.6, 1.0) < 0.05:
		col = col.darkened(0.18)
	if absf(xg) > AV_W - 0.07:
		col = WHITE.darkened(0.08)
	var h: int = _hash(int(xg * 30.0 + 100.0), int(zg * 30.0), 3)
	if h % 29 == 0:
		col = CONFETTI[(h >> 5) % CONFETTI.size()]
	return col

func _plaza(xg: float, zg: float) -> Color:
	var col: Color = Color(0.30, 0.26, 0.38)
	if _hash(int(xg * 10.0 + 400.0), int(zg * 2.0), 9) % 7 == 0:
		col = Color(0.36, 0.32, 0.44)
	return col

# Ciel en bandes tramées, étoiles, et le morro de São Carlos piqué de lumières.
func _sky(i: int, j: int) -> Color:
	var y: float = float(Y0 + j * P)
	var x: float = float(X0 + i * P)
	var hill: float = VP.y + 30.0 - 70.0 * exp(-pow((x - 1300.0) / 380.0, 2.0)) \
		- 46.0 * exp(-pow((x - 520.0) / 300.0, 2.0))
	if y > hill:
		var h: int = _hash(i, j, 5)
		if y > hill + 6.0 and h % 9 == 0:
			return Color(1.0, 0.86, 0.45) if h % 2 == 0 else Color(0.95, 0.95, 0.80)
		return Color(0.10, 0.08, 0.18)
	var bands: Array = [[-200.0, Color(0.05, 0.04, 0.14)], [-40.0, Color(0.08, 0.06, 0.20)],
		[70.0, Color(0.12, 0.08, 0.26)], [150.0, Color(0.18, 0.10, 0.32)]]
	var col: Color = bands[0][1]
	for b in bands.size():
		if y >= bands[b][0] or (y >= bands[b][0] - P and i % 2 == 0):
			col = bands[b][1]
	var hs: int = _hash(i, j, 1)
	if hs % 97 == 0 and y < 120.0:
		col = Color(0.95, 0.95, 0.85) if hs % 3 == 0 else Color(0.55, 0.55, 0.80)
	return col

func _put(img: Image, i: int, j: int, c: Color) -> void:
	if i >= 0 and j >= 0 and i < ART_W and j < ART_H:
		img.set_pixel(i, j, c)

func _ai(x: float) -> int:
	return int(floorf((x - X0) / P))

func _aj(y: float) -> int:
	return int(floorf((y - Y0) / P))

# Arco da Apoteose : le « M » de Niemeyer au bout de la piste — deux arches
# blanches posées sur un pilier central, guirlande de lampes.
func _paint_arch(img: Image) -> void:
	var base: float = VP.y + F / AV_END
	var pts: Array[Vector2] = []
	for sgn in [-1.0, 1.0]:
		for k in 120:
			var t: float = float(k) / 119.0
			var dx: float = 240.0 - 240.0 * t   # du pied extérieur vers le centre
			var x: float = VP.x + sgn * dx
			var y: float
			if dx > 120.0:
				y = 104.0 + (base - 104.0) * pow((dx - 120.0) / 120.0, 2.0)
			else:
				y = 104.0 + (178.0 - 104.0) * pow((120.0 - dx) / 120.0, 2.0)
			pts.append(Vector2(x, y))
	for k in 30:
		pts.append(Vector2(VP.x, lerpf(178.0, base, float(k) / 29.0)))
	for pass_i in 3:
		var rad: int = [4, 3, 1][pass_i]
		var col: Color = [LINE, Color(0.86, 0.85, 0.92), WHITE][pass_i]
		for p in pts:
			var ci: int = _ai(p.x)
			var cj: int = _aj(p.y) - (1 if pass_i == 2 else 0)
			for dj in range(-rad, rad + 1):
				for di in range(-rad, rad + 1):
					if di * di + dj * dj <= rad * rad + 1:
						_put(img, ci + di, cj + dj, col)
	for k in range(0, pts.size() - 30, 8):
		_put(img, _ai(pts[k].x), _aj(pts[k].y) - 3, Color(1.0, 0.88, 0.40))

# Mâts des projecteurs sur le parapet des arquibancadas.
func _paint_lamp_posts(img: Image) -> void:
	for side in [-1.0, 1.0]:
		for z in [3.6, 5.2, 7.0, 8.8]:
			var x: float = VP.x + F * side * (AV_W + STAND_H) / z
			var y_base: float = VP.y - F * (STAND_H - 1.0) / z
			var y_top: float = VP.y - F * (STAND_H + 0.45 - 1.0) / z
			var i: int = _ai(x)
			for j in range(_aj(y_top), _aj(y_base) + 1):
				_put(img, i, j, Color(0.30, 0.28, 0.40))
			var w: int = maxi(2, int(16.0 / z))
			for dj in range(-1, 2):
				for di in range(-w, w + 1):
					_put(img, i + di, _aj(y_top) + dj, LINE if absi(di) == w or dj != 0 else Color(1.0, 0.98, 0.85))
			_lamps.append(Vector2(x, y_top))

# =====================================================================
# Piste des instruments (image fixe) et ligne de frappe (animée)
# =====================================================================

func _hw_x0() -> float:
	return 380.0

func _hw_y0() -> float:
	return 32.0

func _build_highway() -> Image:
	var w: int = 290
	var h: int = 190
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var y_end: float = hit_y + 52.0
	for j in h:
		var y: float = _hw_y0() + float(j * P) + P * 0.5
		if y > y_end:
			break
		var s: float = lane_scale(y)
		var a: float = 0.22 if y < 300.0 else (0.34 if y < 520.0 else 0.46)
		if y < 60.0 and j % 2 == 0:
			continue
		for lane in 4:
			var c: float = VP.x + (float(lane_x[lane]) - VP.x) * s
			var half: float = LANE_HALF * s
			var col: Color = lane_colors[lane]
			for i in w:
				var x: float = _hw_x0() + float(i * P) + P * 0.5
				var d: float = absf(x - c)
				if d > half:
					continue
				if d > half - P:
					img.set_pixel(i, j, Color(col.r, col.g, col.b, 0.95))
				elif d > half - 2.0 * P:
					img.set_pixel(i, j, Color(col.r, col.g, col.b, a * 0.9).darkened(0.1))
				else:
					var f: Color = col.darkened(0.62)
					img.set_pixel(i, j, Color(f.r, f.g, f.b, a))
	return img

func _draw_track(n: Node2D) -> void:
	# Traits de temps qui descendent avec les notes (mesure en doré).
	var first: int = int(ceilf((clock - 0.1 - lead_in) / BEAT))
	for b in range(first, first + 5):
		var bt: float = lead_in + float(b) * BEAT
		var y: float = hit_y - (bt - clock) * fall_speed
		if y < top_y - 20.0 or y > hit_y + 4.0:
			continue
		var s: float = lane_scale(y)
		var col: Color = Color(1.0, 0.85, 0.35, 0.55) if b % 8 == 0 else Color(1.0, 1.0, 1.0, 0.18)
		for lane in 4:
			var c: float = lane_center(lane, y)
			var half: float = (LANE_HALF - 6.0) * s
			n.draw_rect(Rect2(_snap(c - half), _snap(y) - 2.0, _snap(half * 2.0), 4.0), col)
	# Ligne de frappe : barre dorée cerclée, un réceptacle par instrument.
	var x0: float = lane_center(0, hit_y) - LANE_HALF - 24.0
	var x1: float = lane_center(3, hit_y) + LANE_HALF + 24.0
	n.draw_rect(Rect2(x0, hit_y - 8.0, x1 - x0, 16.0), LINE)
	n.draw_rect(Rect2(x0 + 4.0, hit_y - 4.0, x1 - x0 - 8.0, 8.0), GOLD)
	n.draw_rect(Rect2(x0 + 4.0, hit_y - 4.0, x1 - x0 - 8.0, 4.0), GOLD_HI)
	var beat_on: bool = _beat_frac() < 0.18 and clock > lead_in
	for lane in 4:
		var col: Color = lane_colors[lane]
		var c: float = lane_x[lane]
		var grow: float = 8.0 if _press_t[lane] > 0.0 else (4.0 if beat_on else 0.0)
		var r: Rect2 = Rect2(c - 64.0 - grow, hit_y - 28.0 - grow * 0.5, 128.0 + grow * 2.0, 56.0 + grow)
		n.draw_rect(r, LINE)
		n.draw_rect(r.grow(-4.0), col)
		var inner: Rect2 = r.grow(-10.0)
		var fill: Color = col.darkened(0.55)
		if _press_t[lane] > 0.0:
			fill = col.lightened(0.35)
		n.draw_rect(inner, fill)
		var tex: Texture2D = _note_tex[lane]
		var ts: Vector2 = tex.get_size() * float(P)
		n.draw_texture_rect(tex, Rect2(Vector2(c, hit_y) - ts * 0.5, ts), false, Color(1, 1, 1, 0.28))
		if _flash_t[lane] > 0.0:
			var a: float = _flash_t[lane] / 0.18
			var fc: Color = _flash_col[lane]
			var top: float = hit_y - 360.0
			for k in 6:
				var yy: float = top + float(k) * 60.0
				var s: float = lane_scale(yy)
				var half: float = LANE_HALF * s
				var cc: float = lane_center(lane, yy)
				n.draw_rect(Rect2(_snap(cc - half), yy, _snap(half * 2.0), 60.0),
					Color(fc.r, fc.g, fc.b, a * 0.08 * float(k + 1)))

static func _snap(v: float) -> float:
	return floorf(v / P) * P

# =====================================================================
# Projecteurs
# =====================================================================

func _draw_beams(n: Node2D) -> void:
	var cols: Array[Color] = [Color(1.0, 0.98, 0.85, 0.11), Color(0.96, 0.40, 0.66, 0.12), Color(0.2, 0.9, 0.55, 0.11)]
	for k in _lamps.size():
		var src: Vector2 = _lamps[k]
		var side: float = -1.0 if src.x < VP.x else 1.0
		var ang: float = -PI * 0.5 + side * (0.35 + 0.3 * sin(_t * 0.5 + float(k) * 1.7))
		var dir: Vector2 = Vector2.from_angle(ang)
		var spread: float = 0.09
		var far: float = 1600.0
		var a: Vector2 = src + dir.rotated(-spread) * far
		var b: Vector2 = src + dir.rotated(spread) * far
		n.draw_colored_polygon(PackedVector2Array([src, a, b]), cols[k % cols.size()])

# =====================================================================
# Carro alegórico
# =====================================================================

func _build_float() -> void:
	var w: int = 64
	var h: int = 60
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Plumes en éventail, verde e rosa, de chaque côté.
	for sgn in [-1, 1]:
		var base: Vector2 = Vector2(32 + sgn * 22, 44)
		for r in 9:
			var ang: float = -PI * 0.5 + sgn * (0.15 + float(r) * 0.14)
			var col: Color = PINK if r % 2 == 0 else GREEN
			for d in range(4, 28):
				var p: Vector2 = base + Vector2.from_angle(ang) * float(d)
				_img_put(img, int(p.x), int(p.y), col if d < 25 else WHITE)
	# Socle : jupe dorée festonnée, bande de pierreries.
	_img_box(img, 3, 44, 60, 57, GOLD)
	for x in range(3, 61):
		if x % 4 == 0:
			_img_put(img, x, 56, GOLD_DK)
			_img_put(img, x, 55, GOLD_DK)
		_img_put(img, x, 44, GOLD_HI)
		_img_put(img, x, 57, GOLD_DK)
	for x in range(5, 59, 3):
		_img_put(img, x, 48, PINK if x % 2 == 0 else GREEN)
		_img_put(img, x, 49, WHITE)
	# Étage : arcades sombres éclairées.
	_img_box(img, 11, 31, 52, 43, GOLD)
	for x in range(11, 53):
		_img_put(img, x, 31, GOLD_HI)
	for k in 4:
		var ax: int = 14 + k * 10
		_img_box(img, ax, 34, ax + 5, 42, Color(0.26, 0.12, 0.34))
		_img_put(img, ax + 2, 37, Color(1.0, 0.9, 0.5))
		_img_put(img, ax + 3, 39, Color(1.0, 0.9, 0.5))
	# Couronne géante : bandeau orné et cinq pointes perlées.
	_img_box(img, 17, 23, 46, 30, GOLD)
	for x in range(17, 47):
		_img_put(img, x, 23, GOLD_HI)
		_img_put(img, x, 30, GOLD_DK)
	for x in range(19, 46, 5):
		_img_put(img, x, 26, PINK)
		_img_put(img, x, 27, PINK.darkened(0.3))
	for k in 5:
		var cx: int = 20 + k * 6
		var tip: int = 8 if k == 2 else (12 if k % 2 == 1 else 15)
		for y in range(tip, 23):
			var half: int = int(float(y - tip) / float(23 - tip) * 2.5)
			for x in range(cx - half, cx + half + 1):
				_img_put(img, x, y, GOLD if x <= cx else GOLD_DK)
		_img_put(img, cx, tip - 1, WHITE)
		_img_put(img, cx, tip - 2, WHITE)
	_img_outline(img)
	_float_tex = ImageTexture.create_from_image(img)
	_float = Sprite2D.new()
	_float.texture = _float_tex
	_float.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_float.centered = true
	_float.offset = Vector2(0, -h * 0.5)
	add_child(_float)
	_step_float()

# Le carro remonte la piste pendant tout le desfile.
func _step_float() -> void:
	var k: float = clampf(clock / maxf(duration, 1.0), 0.0, 1.0)
	var z: float = lerpf(9.4, 6.4, k)
	var ground: float = VP.y + F / z
	var s: float = (F * 2.3 / z) / 64.0
	_float.position = Vector2(VP.x, _snap(ground) + (-P if _beat_frac() < 0.15 else 0.0))
	_float.scale = Vector2(s, s)

func _img_put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _img_box(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_img_put(img, x, y, c)

func _img_outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, LINE)
					break

# =====================================================================
# Notes et icônes
# =====================================================================

func _icon_image(rows: Array) -> Image:
	var h: int = rows.size()
	var w: int = String(rows[0]).length()
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch: String = row[x]
			if ICON_COLORS.has(ch):
				img.set_pixel(x, y, ICON_COLORS[ch])
	return img

func _icon_texture(rows: Array, k: int) -> ImageTexture:
	var img: Image = _icon_image(rows)
	if k > 1:
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# Pastille de la couleur du bouton, icône de l'instrument au centre (30×12,
# affichée ×4 = 120×48).
func _build_note(lane: int) -> ImageTexture:
	var w: int = 30
	var h: int = 12
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = lane_colors[lane]
	for y in h:
		for x in w:
			var corner: bool = (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
			if corner:
				continue
			var c: Color = col
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 or ((x == 1 or x == w - 2) and (y == 1 or y == h - 2)):
				c = LINE
			elif y == 1:
				c = col.lightened(0.45)
			elif y == h - 2:
				c = col.darkened(0.35)
			elif x < 4 or x > w - 5:
				c = col.lightened(0.15)
			img.set_pixel(x, y, c)
	# Petits éclats de chaque côté de l'icône.
	for p in [Vector2i(4, 4), Vector2i(5, 7), Vector2i(25, 4), Vector2i(24, 7)]:
		img.set_pixel(p.x, p.y, WHITE)
	var icon: Image = _icon_image(ICONS[lane])
	img.blend_rect(icon, Rect2i(0, 0, icon.get_width(), icon.get_height()), Vector2i(9, 1))
	return ImageTexture.create_from_image(img)

# =====================================================================
# Bateria
# =====================================================================

# Uniforme de l'école : chemise rose, chapeau vert ou blanc, bermuda blanche.
func _ritmista_cfg(k: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 700 + k * 13
	return {
		"skin": CharacterSpriteFactory.PALETTE_SKIN[rng.randi() % CharacterSpriteFactory.PALETTE_SKIN.size()],
		"hair_color": CharacterSpriteFactory.PALETTE_HAIR_COLOR[rng.randi() % 3],
		"hair_style": CharacterSpriteFactory.PALETTE_HAIR_STYLE[rng.randi() % CharacterSpriteFactory.PALETTE_HAIR_STYLE.size()],
		"shirt_color": PINK if k % 3 != 2 else GREEN,
		"shirt_pattern": "solid" if k % 2 == 0 else "stripe_h",
		"pants_color": Color(0.95, 0.95, 0.92),
		"hat_style": "fedora" if k % 4 != 3 else "cap",
		"hat_color": GREEN if k % 3 != 2 else WHITE,
	}

func _char(height: float, cfg: Dictionary, dir: int) -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = CharacterSpriteFactory.build_sheet(cfg)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, dir * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
	var s: float = height / float(CharacterSpriteFactory.CELL_H)
	spr.scale = Vector2(s, s)
	return spr

# Ritmista + son instrument (pixels de même taille que ceux du personnage).
func _add_ritmista(pos: Vector2, height: float, k: int, inst: int) -> void:
	var spr: Sprite2D = _char(height, _ritmista_cfg(k), CharacterSpriteFactory.DIR_DOWN)
	spr.position = pos
	add_child(spr)
	var nat: float = height / 32.0
	var it: Sprite2D = Sprite2D.new()
	it.texture = _small_tex[inst]
	it.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	it.scale = Vector2(nat, nat)
	var off: Vector2 = [Vector2(6, -20), Vector2(0, -9), Vector2(3, -11), Vector2(6, -19)][inst] * nat
	it.position = pos + off
	add_child(it)
	_crew.append({"spr": spr, "inst": it, "pos": pos, "off": off, "nat": nat, "ph": k % 2})

func _build_far_bateria() -> void:
	# Deux rangs au fond, entre les pistes : petits, mais ils dansent.
	var rows: Array = [[5.6, 64.0, 7], [4.3, 96.0, 6]]
	var k: int = 0
	for row in rows:
		var z: float = row[0]
		var y: float = _snap(VP.y + F / z)
		var half: float = F * (AV_W - 0.2) / z
		var count: int = row[2]
		for c in count:
			var x: float = VP.x - half + half * 2.0 * (float(c) + 0.5) / float(count)
			_add_ritmista(Vector2(_snap(x), y), row[1], k, [1, 0, 3, 1, 2, 0, 1][c % 7])
			k += 1

func _build_near_bateria() -> void:
	var spots: Array = [
		[Vector2(268, 560), 128.0, 1], [Vector2(372, 640), 128.0, 0],
		[Vector2(1572, 560), 128.0, 3], [Vector2(1468, 640), 128.0, 1],
		[Vector2(140, 700), 160.0, 2], [Vector2(1700, 700), 160.0, 1],
	]
	var k: int = 20
	for sp in spots:
		_add_ritmista(sp[0], sp[1], k, sp[2])
		k += 1
	# Le joueur devant la bateria, et le mestre de dos qui la rege.
	_player = _char(192.0, CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices()),
		CharacterSpriteFactory.DIR_DOWN)
	_player_foot = 1060.0
	_player.position = Vector2(300, _player_foot)
	add_child(_player)
	_player_inst = Sprite2D.new()
	_player_inst.texture = _small_tex[0]
	_player_inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_inst.scale = Vector2(6, 6)
	add_child(_player_inst)
	var mestre: Sprite2D = _char(192.0, {
		"skin": CharacterSpriteFactory.PALETTE_SKIN[3], "hair_color": HAIRS[0], "hair_style": "short",
		"shirt_color": WHITE, "shirt_pattern": "solid", "pants_color": Color(0.92, 0.92, 0.90),
		"hat_style": "fedora", "hat_color": WHITE,
	}, CharacterSpriteFactory.DIR_UP)
	mestre.position = Vector2(1620, 1060)
	add_child(mestre)
	_crew.append({"spr": mestre, "inst": null, "pos": mestre.position, "off": Vector2.ZERO, "nat": 6.0, "ph": 0})
	var baton: Image = Image.create(3, 9, false, Image.FORMAT_RGBA8)
	baton.fill(Color(0, 0, 0, 0))
	for y in 9:
		baton.set_pixel(1, y, LINE if y > 1 else WHITE)
		if y > 6:
			baton.set_pixel(0, y, Color(0.85, 0.64, 0.46))
			baton.set_pixel(2, y, Color(0.85, 0.64, 0.46))
	_mestre_baton = Sprite2D.new()
	_mestre_baton.texture = ImageTexture.create_from_image(baton)
	_mestre_baton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mestre_baton.scale = Vector2(6, 6)
	_mestre_baton.offset = Vector2(0, -4.5)
	add_child(_mestre_baton)

# Chacun marque le temps : pas gauche/droite à chaque temps, petit saut sur
# l'attaque, instrument qui frappe.
func _step_crew() -> void:
	var playing: bool = clock > lead_in
	var bi: int = _beat_idx()
	var hitting: bool = playing and _beat_frac() < 0.2
	for c in _crew:
		var spr: Sprite2D = c["spr"]
		var nat: float = c["nat"]
		var col: int = 0
		if playing:
			col = 1 + (bi + int(c["ph"])) % 2
		var row_y: float = spr.region_rect.position.y
		spr.region_rect = Rect2(col * CharacterSpriteFactory.CELL_W, row_y, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		var lift: float = -nat if hitting and not _breque else 0.0
		spr.position = c["pos"] + Vector2(0, lift)
		var it: Sprite2D = c["inst"]
		if it:
			it.position = c["pos"] + c["off"] + Vector2(0, lift * 2.0 if hitting else 0.0)
	var hop: float = -12.0 if _player_hop > 0.0 else 0.0
	_player.position = Vector2(300, _player_foot + hop)
	_player.region_rect.position.x = CharacterSpriteFactory.CELL_W * (1 + bi % 2) if playing else 0.0
	_player_inst.position = Vector2(300 + 6 * 4, _player_foot - 6 * 12 + hop * 1.5)
	# Le mestre lève le bâton sur le temps, les deux bras en l'air au breque.
	var up: bool = hitting or _breque
	_mestre_baton.position = Vector2(1620 + 6 * 8, 1060 - 6 * (24 if up else 17))
	_mestre_baton.rotation = -0.5 if up else 0.4

# =====================================================================
# Confettis, serpentins, éclats
# =====================================================================

func _flash(lane: int, col: Color) -> void:
	_flash_t[lane] = 0.18
	_flash_col[lane] = col

func _burst(at: Vector2, count: int, tint: Color) -> void:
	for k in count:
		var ang: float = -PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		var sp: float = _rng.randf_range(260.0, 720.0)
		var col: Color = tint if k % 3 == 0 else CONFETTI[_rng.randi() % CONFETTI.size()]
		_confetti.append({"pos": at + Vector2(_rng.randf_range(-40, 40), 0), "vel": Vector2.from_angle(ang) * sp,
			"col": col, "ph": _rng.randf() * TAU, "size": 8.0 if _rng.randf() < 0.5 else 4.0, "life": 2.2})

func _step_particles(delta: float) -> void:
	# Pluie de confettis permanente depuis les arquibancadas.
	_rain += delta * (14.0 + minf(float(_streak), 30.0))
	while _rain >= 1.0:
		_rain -= 1.0
		var x: float = _rng.randf_range(-300.0, 2200.0)
		_confetti.append({"pos": Vector2(x, -40.0), "vel": Vector2(_rng.randf_range(-30, 30), _rng.randf_range(60, 130)),
			"col": CONFETTI[_rng.randi() % CONFETTI.size()], "ph": _rng.randf() * TAU,
			"size": 4.0, "life": 12.0})
	var keep: Array = []
	for p in _confetti:
		p["life"] -= delta
		var v: Vector2 = p["vel"]
		v.y = minf(v.y + 520.0 * delta, 150.0)
		v.x *= 1.0 - 1.6 * delta
		p["vel"] = v
		p["pos"] += v * delta + Vector2(sin(_t * 4.0 + p["ph"]) * 30.0 * delta, 0)
		if p["life"] > 0.0 and p["pos"].y < 1120.0:
			keep.append(p)
	_confetti = keep
	# Serpentins qui tombent en ondulant sur les côtés.
	_streamer_t -= delta
	if _streamer_t <= 0.0:
		_streamer_t = _rng.randf_range(0.6, 1.4)
		var left: bool = _rng.randf() < 0.5
		var x: float = _rng.randf_range(-200.0, 420.0) if left else _rng.randf_range(1420.0, 2100.0)
		_streamers.append({"pos": Vector2(x, -60.0), "col": CONFETTI[_rng.randi() % CONFETTI.size()],
			"ph": _rng.randf() * TAU, "len": _rng.randi_range(14, 22), "speed": _rng.randf_range(70.0, 120.0)})
	var keep_s: Array = []
	for s in _streamers:
		s["pos"] += Vector2(0, s["speed"] * delta)
		if s["pos"].y < 1200.0:
			keep_s.append(s)
	_streamers = keep_s

func _draw_fx(n: Node2D) -> void:
	for s in _streamers:
		var col: Color = s["col"]
		var p0: Vector2 = s["pos"]
		for k in int(s["len"]):
			var p: Vector2 = p0 + Vector2(sin(_t * 3.0 + s["ph"] + float(k) * 0.55) * 14.0, -float(k) * 6.0)
			n.draw_rect(Rect2(_snap(p.x), _snap(p.y), P, P * 2.0), col if k % 4 != 0 else col.darkened(0.25))
	for p in _confetti:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var flip: bool = sin(_t * 9.0 + p["ph"]) > 0.0
		var col: Color = p["col"] if flip else (p["col"] as Color).darkened(0.3)
		var w: float = sz if flip else P
		n.draw_rect(Rect2(_snap(pos.x), _snap(pos.y), w, sz), col)

# Mot qui éclate au-dessus de la ligne (-1 = centre de l'écran, -2 = annonce).
func _popup(lane: int, text: String, col: Color) -> void:
	var old: Variant = _popups.get(lane)
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	var lb: Label = Label.new()
	_popups[lane] = lb
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var size: int = 44 if lane >= 0 else 66
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", LINE)
	lb.add_theme_constant_override("outline_size", 12)
	lb.size = Vector2(440, 80)
	var cx: float = VP.x if lane < 0 else float(lane_x[lane])
	var y: float = hit_y + 30.0
	if lane == -1:
		y = 300.0
	elif lane == -2:
		y = 150.0
	lb.position = Vector2(cx - 220.0, y)
	_fx.add_child(lb)
	var tw: Tween = lb.create_tween()
	tw.tween_property(lb, "position:y", y - 24.0, 0.08)
	tw.tween_property(lb, "position:y", y - 8.0, 0.1)
	tw.tween_interval(0.35 if lane >= 0 else 0.8)
	tw.tween_property(lb, "modulate:a", 0.0, 0.25)
	tw.tween_callback(lb.queue_free)
