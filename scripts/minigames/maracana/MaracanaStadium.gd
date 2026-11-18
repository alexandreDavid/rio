extends Node2D

# Le Maracanã vu depuis la torcida — rendu seul, aucune règle de jeu ici.
# Fond pré-peint une fois en pixels de 4 px (ciel, Corcovado, marquise,
# gradins pleins, pelouse rayée) ; couches animées par-dessus : joueurs et
# ballon, ola et bandeirões d'en face, fumigènes, torcida du premier plan, le
# joueur de dos qui fait le geste, confettis.

const P: int = 4
const X0: int = -480
const Y0: int = -400
const ART_W: int = 720
const ART_H: int = 450
const CX: float = 960.0
const U_SPAN: float = 1500.0
# Fosse de la pelouse (ellipse) et terrain en perspective (trapèze).
const ELL_C: Vector2 = Vector2(960.0, 545.0)
const ELL_R: Vector2 = Vector2(1250.0, 205.0)
const FAR_Y: float = 400.0
const NEAR_Y: float = 690.0
const FAR_HW: float = 540.0
const NEAR_HW: float = 840.0
# Haut du parapet devant la torcida du premier plan.
const NEAR_TOP: float = 772.0
const PLAYER_X: float = 960.0
const PLAYER_FEET: float = 1078.0
const PLAYER_PX: float = 9.0
const BEAT: float = 0.45
const OLA_TIME: float = 2.4
const OLA_FROM: float = -420.0
const OLA_TO: float = 2380.0

const LINE: Color = Color(0.13, 0.10, 0.12, 1.0)
const WHITE: Color = Color(0.95, 0.96, 0.92, 1.0)
const CONCRETE: Color = Color(0.47, 0.48, 0.58, 1.0)
const CONCRETE_DK: Color = Color(0.30, 0.31, 0.42, 1.0)
const GRASS_A: Color = Color(0.27, 0.62, 0.29, 1.0)
const GRASS_B: Color = Color(0.22, 0.54, 0.25, 1.0)
const SKINS: Array[Color] = [
	Color(0.96, 0.80, 0.64), Color(0.85, 0.64, 0.46), Color(0.68, 0.47, 0.32),
	Color(0.50, 0.33, 0.22), Color(0.36, 0.24, 0.17),
]
const HAIRS: Array[Color] = [
	Color(0.10, 0.08, 0.07), Color(0.24, 0.15, 0.09), Color(0.42, 0.27, 0.14),
	Color(0.80, 0.62, 0.30), Color(0.55, 0.55, 0.56),
]
const FUN: Array[Color] = [
	Color(0.98, 0.84, 0.16), Color(0.15, 0.62, 0.32), Color(0.20, 0.45, 0.88),
	Color(0.96, 0.55, 0.18), Color(0.95, 0.45, 0.70), Color(0.96, 0.96, 0.94),
]
const RIVAL_A: Color = Color(0.16, 0.36, 0.80, 1.0)
const RIVAL_B: Color = Color(0.96, 0.96, 0.94, 1.0)
const ADS: Array[Color] = [
	Color(0.85, 0.16, 0.16), Color(0.16, 0.30, 0.76), Color(0.96, 0.80, 0.16), Color(0.10, 0.52, 0.30),
]

# a/b/c = couleurs du time ; flag = motif des bandeirões et des camisas.
const TEAMS: Dictionary = {
	"flamengo": {"a": Color(0.86, 0.10, 0.12), "b": Color(0.11, 0.09, 0.10), "c": Color(0.86, 0.10, 0.12), "flag": "stripes_h"},
	"vasco": {"a": Color(0.11, 0.09, 0.10), "b": Color(0.96, 0.96, 0.94), "c": Color(0.86, 0.14, 0.14), "flag": "sash"},
	"fluminense": {"a": Color(0.55, 0.08, 0.17), "b": Color(0.06, 0.46, 0.28), "c": Color(0.96, 0.96, 0.94), "flag": "tricolor"},
	"botafogo": {"a": Color(0.11, 0.09, 0.10), "b": Color(0.96, 0.96, 0.94), "c": Color(0.96, 0.96, 0.94), "flag": "stripes_v"},
}

enum Pose { IDLE, GOOOL, LEFT, RIGHT, VAMOS, OLA, LAMENT }
enum React { NONE, JUMP, SWAY_L, SWAY_R, PUMP, GROAN }
# Index des COMMANDS du jeu → pose du joueur et réaction de la torcida.
const CMD_POSE: Array[int] = [Pose.GOOOL, Pose.LEFT, Pose.RIGHT, Pose.VAMOS, Pose.OLA]
const CMD_REACT: Array[int] = [React.JUMP, React.SWAY_L, React.SWAY_R, React.PUMP, React.NONE]

var team: Dictionary = TEAMS["flamengo"]
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _far: Node2D
var _near: Node2D
var _fx: Node2D
var _player: Sprite2D
var _pose_tex: Dictionary = {}
var _pose: int = Pose.IDLE
var _pose_t: float = 0.0

var _react: int = React.NONE
var _react_t: float = 0.0
var _ola_t: float = -1.0
var _flash_t: float = 0.0

var _far_fans: Dictionary = {}   # colonne/8 → Array de [Vector2i, Color]
var _lamps: Array[Vector2] = []
var _near_rows: Array = []       # [y, p, fans]
var _near_flags: Array = []      # [row, fan index]
var _smoke: Array = []           # puffs {pos, vel, life, max, col}
var _flares: Array = []          # {pos, life}
var _confetti: Array = []        # {pos, vel, col, ph}
var _ball: Vector2 = Vector2(0.0, 0.5)
var _ball_target: Vector2 = Vector2(0.2, 0.4)
var _players: Array = []         # {pos, home, shirt, shorts, keeper}

const FAR_FLAGS: Array = [
	[Vector2(400, 252), Vector2i(30, 14), "team"],
	[Vector2(1176, 228), Vector2i(34, 16), "brasil"],
	[Vector2(1760, 292), Vector2i(26, 13), "team"],
]

func setup(team_id: String) -> void:
	team = TEAMS.get(team_id, TEAMS["flamengo"])

func _ready() -> void:
	_rng.seed = 1950
	var bg: Sprite2D = Sprite2D.new()
	bg.centered = false
	bg.position = Vector2(X0, Y0)
	bg.scale = Vector2(P, P)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = ImageTexture.create_from_image(_build_static())
	add_child(bg)
	_far = _layer(_draw_far)
	_near = _layer(_draw_near)
	_build_player()
	_fx = _layer(_draw_fx)
	_build_near_crowd()
	_build_pitch_players()

func _layer(cb: Callable) -> Node2D:
	var n: Node2D = Node2D.new()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.draw.connect(cb.bind(n))
	add_child(n)
	return n

# --- API du jeu ---

func react(cmd_idx: int, perfect: bool) -> void:
	_pose = CMD_POSE[cmd_idx]
	_pose_t = 0.75
	if cmd_idx == 4:
		_ola_t = 0.0
	else:
		_react = CMD_REACT[cmd_idx]
		_react_t = 0.8
	if perfect:
		_flash_t = 0.3
		_burst_confetti(70 if cmd_idx != 0 else 110)
		_light_flares(2 if cmd_idx != 0 else 4)

func miss() -> void:
	_pose = Pose.LAMENT
	_pose_t = 0.8
	_react = React.GROAN
	_react_t = 0.8

# --- Boucle ---

func _process(delta: float) -> void:
	_t += delta
	_pose_t = maxf(_pose_t - delta, 0.0)
	if _pose_t <= 0.0:
		_pose = Pose.IDLE
	_react_t = maxf(_react_t - delta, 0.0)
	if _react_t <= 0.0:
		_react = React.NONE
	_flash_t = maxf(_flash_t - delta, 0.0)
	if _ola_t >= 0.0:
		_ola_t += delta / OLA_TIME
		if _ola_t > 1.0:
			_ola_t = -1.0
	_step_pitch(delta)
	_step_particles(delta)
	_update_player()
	_far.queue_redraw()
	_near.queue_redraw()
	_fx.queue_redraw()

func _ola_x() -> float:
	return lerpf(OLA_FROM, OLA_TO, _ola_t) if _ola_t >= 0.0 else -99999.0

func _beat() -> int:
	return int(_t / BEAT)

static func _snap(v: float) -> float:
	return floorf(v / P) * P

static func _u(x: float) -> float:
	return (x - CX) / U_SPAN

static func roof_top(x: float) -> float:
	var u: float = _u(x)
	return 118.0 - 300.0 * u * u

static func roof_front(x: float) -> float:
	var u: float = _u(x)
	return 196.0 - 150.0 * u * u

static func ell_d(x: float, y: float) -> float:
	var dx: float = (x - ELL_C.x) / ELL_R.x
	var dy: float = (y - ELL_C.y) / ELL_R.y
	return dx * dx + dy * dy

static func pitch(fx: float, fy: float) -> Vector2:
	return Vector2(CX + fx * lerpf(FAR_HW, NEAR_HW, fy), lerpf(FAR_Y, NEAR_Y, fy))

# =====================================================================
# Fond statique
# =====================================================================

func _wx(i: int) -> float:
	return float(X0 + i * P) + P * 0.5

func _wy(j: int) -> float:
	return float(Y0 + j * P) + P * 0.5

func _aj(y: float) -> int:
	return int(floorf((y - Y0) / P))

func _ai(x: float) -> int:
	return int(floorf((x - X0) / P))

func _build_static() -> Image:
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	_paint_sky(img)
	_paint_morro(img)
	_paint_bowl(img)
	_paint_fans(img)
	_paint_pitch(img)
	_paint_lines(img)
	_paint_roof_lamps(img)
	return img

func _paint_sky(img: Image) -> void:
	var bands: Array = [[-400.0, Color(0.05, 0.06, 0.17)], [-150.0, Color(0.07, 0.09, 0.23)],
		[-20.0, Color(0.10, 0.13, 0.32)], [60.0, Color(0.15, 0.18, 0.42)]]
	for b in range(bands.size()):
		var j0: int = maxi(_aj(bands[b][0]), 0)
		var j1: int = ART_H if b == bands.size() - 1 else _aj(bands[b + 1][0])
		img.fill_rect(Rect2i(0, j0, ART_W, j1 - j0), bands[b][1])
		# Rangée tramée : la bande suivante mord en damier (pas de dégradé lisse).
		if b < bands.size() - 1:
			for i in range(0, ART_W, 2):
				img.set_pixel(i, j1 - 1, bands[b + 1][1])
	for k in 140:
		var i: int = _rng.randi_range(0, ART_W - 1)
		var j: int = _rng.randi_range(0, _aj(70.0))
		var c: Color = Color(0.95, 0.95, 0.85) if _rng.randf() < 0.3 else Color(0.55, 0.6, 0.8)
		img.set_pixel(i, j, c)

# Corcovado et le Cristo, éclairé, qui dépasse de la marquise.
func _paint_morro(img: Image) -> void:
	var peak_x: float = 1420.0
	var peak_y: float = 52.0
	var rock: Color = Color(0.11, 0.17, 0.24)
	var rim: Color = Color(0.18, 0.27, 0.34)
	for i in ART_W:
		var x: float = _wx(i)
		var dx: float = x - peak_x
		var top: float
		if dx < 0.0:
			top = peak_y + pow(-dx / 300.0, 1.3) * 110.0
		else:
			top = peak_y + pow(dx / 140.0, 1.15) * 90.0
		if top > 200.0:
			continue
		var j0: int = _aj(top)
		img.fill_rect(Rect2i(i, j0, 1, _aj(200.0) - j0), rock)
		img.set_pixel(i, j0, rim)
	var lit: Color = Color(0.94, 0.94, 0.86)
	var shade: Color = Color(0.68, 0.70, 0.76)
	var ci: int = _ai(peak_x) - 1
	var cj: int = _aj(peak_y)
	img.fill_rect(Rect2i(ci - 1, cj - 2, 4, 2), shade)          # socle
	img.fill_rect(Rect2i(ci, cj - 9, 2, 7), lit)                # corps
	img.fill_rect(Rect2i(ci + 1, cj - 9, 1, 7), shade)
	img.fill_rect(Rect2i(ci - 4, cj - 8, 10, 1), lit)           # bras ouverts
	img.fill_rect(Rect2i(ci, cj - 10, 2, 1), lit)               # tête

func _paint_bowl(img: Image) -> void:
	var white: Color = Color(0.96, 0.96, 0.93)
	var beam: Color = Color(0.82, 0.84, 0.89)
	var under: Color = Color(0.60, 0.62, 0.72)
	for i in ART_W:
		var x: float = _wx(i)
		var jt: int = maxi(_aj(roof_top(x)), 0)
		var jf: int = _aj(roof_front(x))
		# Gradins : béton jusqu'en bas (la pelouse et la torcida repassent dessus).
		img.fill_rect(Rect2i(i, jf, 1, ART_H - jf), CONCRETE)
		# Ombre de la marquise sur les rangs du haut.
		img.fill_rect(Rect2i(i, jf, 1, 7), CONCRETE_DK)
		# Marquise : dessus blanc, poutres, sous-face grise, lèvre sombre.
		img.fill_rect(Rect2i(i, jt, 1, jf - jt), white if i % 12 != 0 else beam)
		img.fill_rect(Rect2i(i, jf - 4, 1, 3), under)
		img.set_pixel(i, jf - 1, LINE)
		img.set_pixel(i, jt, Color(0.85, 0.88, 0.96))

func _fan_color(x: float, y: float) -> Color:
	if x < 140.0 and y < ELL_C.y + 60.0:
		return RIVAL_A if _rng.randf() < 0.6 else RIVAL_B
	var r: float = _rng.randf()
	if r < 0.40:
		return team["a"]
	if r < 0.62:
		return team["b"]
	if r < 0.72:
		return team["c"]
	return FUN[_rng.randi() % FUN.size()]

# Foule d'en face en cellules 3×3 : tête, buste, rebord de marche.
func _paint_fans(img: Image) -> void:
	var j_end: int = _aj(NEAR_TOP + 8.0)
	var row: int = 0
	for gj in range(_aj(-80.0), j_end, 3):
		row += 1
		var off: int = row % 3
		for gi in range(-off, ART_W, 3):
			var x: float = _wx(gi + 1)
			var y: float = _wy(gj + 1)
			if y < roof_front(x) + 2.0:
				continue
			if ell_d(x, y) < 1.0 or ell_d(x, _wy(gj + 2)) < 1.0:
				continue
			_put(img, gi, gj + 2, CONCRETE_DK)
			_put(img, gi + 1, gj + 2, CONCRETE_DK)
			_put(img, gi + 2, gj + 2, CONCRETE_DK)
			if _rng.randf() > 0.86:
				continue
			var shirt: Color = _fan_color(x, y)
			var skin: Color = SKINS[_rng.randi() % SKINS.size()]
			if y < roof_front(x) + 30.0:
				shirt = shirt.darkened(0.35)
				skin = skin.darkened(0.35)
			_put(img, gi + 1, gj, skin)
			_put(img, gi, gj + 1, shirt)
			_put(img, gi + 1, gj + 1, shirt)
			_put(img, gi + 2, gj + 1, shirt.darkened(0.2))
			var b: int = gi / 8
			if not _far_fans.has(b):
				_far_fans[b] = []
			_far_fans[b].append([Vector2i(gi, gj), shirt, skin])

func _put(img: Image, i: int, j: int, c: Color) -> void:
	if i >= 0 and j >= 0 and i < ART_W and j < ART_H:
		img.set_pixel(i, j, c)

func _paint_pitch(img: Image) -> void:
	var j0: int = _aj(ELL_C.y - ELL_R.y)
	var j1: int = _aj(ELL_C.y + ELL_R.y)
	for j in range(j0, j1 + 1):
		var y: float = _wy(j)
		var dy: float = (y - ELL_C.y) / ELL_R.y
		if absf(dy) >= 1.0:
			continue
		var half: float = ELL_R.x * sqrt(1.0 - dy * dy)
		var fy: float = (y - FAR_Y) / (NEAR_Y - FAR_Y)
		var hw: float = lerpf(FAR_HW, NEAR_HW, fy)
		for i in range(maxi(_ai(ELL_C.x - half), 0), mini(_ai(ELL_C.x + half) + 1, ART_W)):
			var x: float = _wx(i)
			var d: float = ell_d(x, y)
			if d >= 1.0:
				continue
			var c: Color
			if y < ELL_C.y and d > 0.86:
				c = _ad_pixel(x, y, d)
			elif y >= ELL_C.y and d > 0.93:
				c = Color(0.16, 0.24, 0.20)
			else:
				var k: int = int(floorf(((x - CX) / hw + 1.0) * 9.0))
				c = GRASS_A if posmod(k, 2) == 0 else GRASS_B
				if fy < 0.0 or fy > 1.0 or absf((x - CX) / hw) > 1.0:
					c = c.darkened(0.08)
			img.set_pixel(i, j, c)

# Placas de publicidade autour de la pelouse : aplats + « lettres » blanches.
func _ad_pixel(x: float, y: float, d: float) -> Color:
	var seg: int = posmod(int(floorf(x / 168.0)), ADS.size())
	var local: float = fposmod(x, 168.0) / 168.0
	if d > 0.985 or local < 0.03:
		return LINE
	if d > 0.9 and d < 0.955 and local > 0.18 and local < 0.82 \
			and posmod(int(floorf(x / 8.0)), 4) != 3:
		return WHITE
	return ADS[seg]

func _seg(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var i0: int = _ai(a.x)
	var j0: int = _aj(a.y)
	var i1: int = _ai(b.x)
	var j1: int = _aj(b.y)
	var di: int = absi(i1 - i0)
	var dj: int = -absi(j1 - j0)
	var si: int = 1 if i0 < i1 else -1
	var sj: int = 1 if j0 < j1 else -1
	var err: int = di + dj
	while true:
		_put(img, i0, j0, c)
		if i0 == i1 and j0 == j1:
			break
		var e2: int = 2 * err
		if e2 >= dj:
			err += dj
			i0 += si
		if e2 <= di:
			err += di
			j0 += sj

func _poly(img: Image, pts: Array, c: Color) -> void:
	for k in range(pts.size() - 1):
		_seg(img, pitch(pts[k].x, pts[k].y), pitch(pts[k + 1].x, pts[k + 1].y), c)

func _paint_lines(img: Image) -> void:
	_poly(img, [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, 0)], WHITE)
	_poly(img, [Vector2(0, 0), Vector2(0, 1)], WHITE)
	var circle: Array = []
	for k in 41:
		var a: float = TAU * k / 40.0
		circle.append(Vector2(0.15 * cos(a), 0.5 + 0.2 * sin(a)))
	_poly(img, circle, WHITE)
	for s in [-1.0, 1.0]:
		_poly(img, [Vector2(s, 0.2), Vector2(s * 0.7, 0.2), Vector2(s * 0.7, 0.8), Vector2(s, 0.8)], WHITE)
		_poly(img, [Vector2(s, 0.36), Vector2(s * 0.88, 0.36), Vector2(s * 0.88, 0.64), Vector2(s, 0.64)], WHITE)
		# But : poteaux, barre, filet tramé vers l'extérieur.
		var p0: Vector2 = pitch(s, 0.43)
		var p1: Vector2 = pitch(s, 0.57)
		var ja: int = _aj(p0.y) - 7
		var jb: int = _aj(p1.y)
		for jj in range(ja, jb + 1):
			var base_i: int = _ai(lerpf(p0.x, p1.x, clampf(float(jj - _aj(p0.y)) / maxf(float(jb - _aj(p0.y)), 1.0), 0.0, 1.0)))
			for k in range(1, 4):
				var ii: int = base_i + int(s) * k
				if (ii + jj) % 2 == 0:
					_put(img, ii, jj, Color(0.82, 0.84, 0.86))
		_seg(img, p0, p0 - Vector2(0, 28), WHITE)
		_seg(img, p1, p1 - Vector2(0, 28), WHITE)
		_seg(img, p0 - Vector2(0, 28), p1 - Vector2(0, 28), WHITE)
		for fy in [0.0, 1.0]:
			var cf: Vector2 = pitch(s, fy)
			_put(img, _ai(cf.x), _aj(cf.y) - 1, Color(0.98, 0.85, 0.15))
			_put(img, _ai(cf.x), _aj(cf.y) - 2, Color(0.98, 0.85, 0.15))
	var c0: Vector2 = pitch(0, 0.5)
	_put(img, _ai(c0.x), _aj(c0.y), WHITE)

# Projecteurs alignés sous la lèvre de la marquise.
func _paint_roof_lamps(img: Image) -> void:
	var lamp: Color = Color(1.0, 0.98, 0.78)
	var halo: Color = Color(0.80, 0.80, 0.70)
	for i in range(2, ART_W, 7):
		var x: float = _wx(i)
		var j: int = _aj(roof_front(x)) - 3
		_put(img, i - 1, j, halo)
		_put(img, i + 2, j, halo)
		_put(img, i, j, lamp)
		_put(img, i + 1, j, lamp)
		_put(img, i, j + 1, halo)
		_put(img, i + 1, j + 1, halo)
		_lamps.append(Vector2(X0 + i * P, Y0 + j * P))

# =====================================================================
# Pelouse animée
# =====================================================================

func _build_pitch_players() -> void:
	var home: Array = [Vector2(-0.5, 0.3), Vector2(-0.45, 0.7), Vector2(-0.15, 0.5), Vector2(0.15, 0.25), Vector2(0.2, 0.75)]
	var away: Array = [Vector2(0.5, 0.35), Vector2(0.45, 0.68), Vector2(0.1, 0.5), Vector2(-0.2, 0.3), Vector2(-0.25, 0.72)]
	for h in home:
		_players.append({"pos": h, "home": h, "shirt": team["a"], "shorts": team["b"], "keeper": false})
	for h in away:
		_players.append({"pos": h, "home": h, "shirt": RIVAL_B, "shorts": RIVAL_A, "keeper": false})
	_players.append({"pos": Vector2(-0.96, 0.5), "home": Vector2(-0.96, 0.5), "shirt": Color(0.98, 0.84, 0.16), "shorts": LINE, "keeper": true})
	_players.append({"pos": Vector2(0.96, 0.5), "home": Vector2(0.96, 0.5), "shirt": Color(0.30, 0.80, 0.35), "shorts": LINE, "keeper": true})

func _step_pitch(delta: float) -> void:
	var to: Vector2 = _ball_target - _ball
	if to.length() < 0.02:
		_ball_target = Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(0.1, 0.9))
	else:
		_ball += to.normalized() * minf(0.45 * delta, to.length())
	for pl in _players:
		var goal: Vector2
		if pl["keeper"]:
			goal = Vector2(pl["home"].x, clampf(_ball.y, 0.4, 0.6))
		else:
			goal = pl["home"].lerp(_ball, 0.4) + Vector2(sin(_t * 0.7 + pl["home"].y * 9.0) * 0.05, 0.0)
		var v: Vector2 = goal - pl["pos"]
		pl["pos"] = pl["pos"] + v.limit_length(0.22 * delta)
		pl["moving"] = v.length() > 0.02

func _draw_pitch_players(n: Node2D) -> void:
	var sorted: Array = _players.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)
	var ball_drawn: bool = false
	for pl in sorted:
		if not ball_drawn and pl["pos"].y > _ball.y:
			_draw_ball(n)
			ball_drawn = true
		var w: Vector2 = pitch(pl["pos"].x, pl["pos"].y)
		var x: float = _snap(w.x)
		var y: float = _snap(w.y)
		var step: int = (int(_t * 8.0) % 2) if pl.get("moving", false) else 0
		n.draw_rect(Rect2(x - P, y, P * 4, P), Color(0, 0, 0, 0.3))
		n.draw_rect(Rect2(x - P, y - P * 7, P * 4, P * 7), LINE)
		n.draw_rect(Rect2(x, y - P * 6, P * 2, P * 2), SKINS[2])
		n.draw_rect(Rect2(x, y - P * 6, P * 2, P), HAIRS[0])
		n.draw_rect(Rect2(x, y - P * 4, P * 2, P * 2), pl["shirt"])
		n.draw_rect(Rect2(x, y - P * 2, P * 2, P), pl["shorts"])
		n.draw_rect(Rect2(x + step * P, y - P, P, P), WHITE)
	if not ball_drawn:
		_draw_ball(n)

func _draw_ball(n: Node2D) -> void:
	var b: Vector2 = pitch(_ball.x, _ball.y)
	var x: float = _snap(b.x)
	var y: float = _snap(b.y)
	n.draw_rect(Rect2(x - P, y - P * 2, P * 3, P * 3), LINE)
	n.draw_rect(Rect2(x, y - P, P, P), WHITE)

# =====================================================================
# Couche du fond animée : pelouse, ola d'en face, bandeirões, fumigènes
# =====================================================================

func _draw_far(n: Node2D) -> void:
	_draw_pitch_players(n)
	# Ola : les supporters d'en face se lèvent bras en l'air au passage.
	var ox: float = _ola_x()
	if ox > -9000.0:
		var bi0: int = int(floorf((ox - 90.0 - X0) / (P * 8.0)))
		var bi1: int = int(floorf((ox + 90.0 - X0) / (P * 8.0)))
		for b in range(bi0, bi1 + 1):
			for f in _far_fans.get(b, []):
				var g: Vector2i = f[0]
				var x: float = X0 + g.x * P
				if absf(x - ox) > 90.0:
					continue
				var y: float = Y0 + g.y * P
				n.draw_rect(Rect2(x, y - P * 2, P * 3, P * 3), f[1])
				n.draw_rect(Rect2(x + P, y - P * 3, P, P), f[2])
				n.draw_rect(Rect2(x, y - P * 4, P, P * 2), f[2])
				n.draw_rect(Rect2(x + P * 2, y - P * 4, P, P * 2), f[2])
	for fl in FAR_FLAGS:
		var kind: String = fl[2]
		_draw_flag(n, fl[0], fl[1], P, kind, 1.0)
	# Projecteurs qui flashent sur un PERFECT.
	if _flash_t > 0.0:
		var a: float = 0.85 if _flash_t > 0.15 else 0.45
		for l in _lamps:
			n.draw_rect(Rect2(l.x - P * 2, l.y - P * 2, P * 6, P * 5), Color(1.0, 0.98, 0.8, a * 0.5))
			n.draw_rect(Rect2(l.x - P, l.y - P, P * 4, P * 3), Color(1.0, 1.0, 0.92, a))
	for s in _smoke:
		# La fumée reste sous la marquise.
		if s["pos"].y < roof_front(s["pos"].x) + 24.0:
			continue
		var k: float = s["life"] / s["max"]
		var sz: float = _snap(lerpf(P * 13.0, P * 3.0, k))
		# Fumée opaque en trois tons (bords nets), translucide seulement à la fin.
		var col: Color = s["col"]
		if k < 0.6:
			col = col.lerp(Color(0.78, 0.76, 0.80), 0.5)
		if k < 0.3:
			col = Color(0.72, 0.72, 0.78, 0.45)
		n.draw_rect(Rect2(_snap(s["pos"].x) - sz * 0.5, _snap(s["pos"].y) - sz * 0.5, sz, sz), col)
	for fl in _flares:
		var on: bool = int(_t * 20.0) % 2 == 0
		var p: Vector2 = fl["pos"]
		n.draw_rect(Rect2(_snap(p.x) - P, _snap(p.y) - P, P * 3, P * 3), Color(1.0, 0.35, 0.25, 0.6))
		n.draw_rect(Rect2(_snap(p.x), _snap(p.y), P, P), Color(1, 1, 0.8) if on else Color(1.0, 0.55, 0.3))

# Drapeau qui ondule : colonnes décalées d'un pixel d'art, aplats fusionnés.
func _draw_flag(n: Node2D, pos: Vector2, cells: Vector2i, p: float, kind: String, amp: float) -> void:
	var x0: float = floorf(pos.x / p) * p
	var y0: float = floorf(pos.y / p) * p
	for c in range(-1, cells.x + 1):
		n.draw_rect(Rect2(x0 + c * p, y0 + _flag_wave(c, cells.x, p, amp) - p, p, p * (cells.y + 2)), LINE)
	for c in cells.x:
		var yo: float = _flag_wave(c, cells.x, p, amp)
		var u: float = (c + 0.5) / cells.x
		var r0: int = 0
		var col0: Color = _flag_color(kind, u, 0.5 / cells.y)
		for r in range(1, cells.y + 1):
			var col: Color = col0
			if r < cells.y:
				col = _flag_color(kind, u, (r + 0.5) / cells.y)
			if r == cells.y or col != col0:
				n.draw_rect(Rect2(x0 + c * p, y0 + yo + r0 * p, p, (r - r0) * p), col0)
				r0 = r
				col0 = col

func _flag_wave(c: int, w: int, p: float, amp: float) -> float:
	var cc: float = clampf(float(c), 0.0, float(w - 1))
	return roundf(sin(_t * 4.0 - cc * 0.45) * amp * (0.3 + 0.7 * cc / w)) * p

func _flag_color(kind: String, u: float, v: float) -> Color:
	if kind == "brasil":
		var du: float = absf(u - 0.5) / 0.44
		var dv: float = absf(v - 0.5) / 0.40
		var cu: float = (u - 0.5) * 1.9
		var cv: float = v - 0.5
		if cu * cu + cv * cv < 0.045:
			return Color(0.14, 0.22, 0.60)
		if du + dv < 1.0:
			return Color(0.98, 0.84, 0.14)
		return Color(0.08, 0.58, 0.28)
	match String(team["flag"]):
		"stripes_h":
			return team["a"] if int(v * 6.0) % 2 == 0 else team["b"]
		"sash":
			return team["b"] if absf(u - v) < 0.16 else team["a"]
		"tricolor":
			# Rayures de la camisa tricolor : grená, filet blanc, vert, filet blanc.
			var k: int = int(u * 10.0) % 4
			return team["a"] if k == 0 else (team["b"] if k == 2 else team["c"])
		"stripes_v":
			return team["a"] if int(u * 8.0) % 2 == 0 else team["b"]
	return team["a"]

# =====================================================================
# Torcida du premier plan (de dos, face à la pelouse)
# =====================================================================

func _build_near_crowd() -> void:
	var rows: Array = [[784.0, 5.0], [838.0, 6.0], [902.0, 7.0], [978.0, 8.0], [1066.0, 9.0], [1168.0, 10.0], [1282.0, 11.0]]
	for r in rows.size():
		var p: float = rows[r][1]
		var fans: Array = []
		var x: float = -520.0 + _rng.randf_range(0.0, p * 4.0)
		while x < 2440.0:
			var kind: float = _rng.randf()
			var shirt: Color = team["a"] if kind < 0.45 else (team["b"] if kind < 0.65 else FUN[_rng.randi() % FUN.size()])
			fans.append({
				"x": floorf(x / p) * p,
				"skin": SKINS[_rng.randi() % SKINS.size()],
				"hair": HAIRS[_rng.randi() % HAIRS.size()],
				"shirt": shirt,
				"jersey": kind < 0.3,
				"cap": _rng.randf() < 0.15,
				"group": _rng.randi() % 2,
				"bouncy": _rng.randf() < 0.55,
				"delay": _rng.randf_range(0.0, 0.18),
			})
			x += p * _rng.randf_range(7.5, 9.5)
		_near_rows.append([rows[r][0], p, fans])
	_near_flags = [[2, 0.18], [3, 0.8], [1, 0.55]]

func _draw_near(n: Node2D) -> void:
	n.draw_rect(Rect2(-600, NEAR_TOP, 3200, 900), CONCRETE)
	n.draw_rect(Rect2(-600, NEAR_TOP - 4, 3200, 4), WHITE)
	n.draw_rect(Rect2(-600, NEAR_TOP, 3200, 8), LINE)
	var ox: float = _ola_x()
	for r in _near_rows.size():
		var y: float = _near_rows[r][0]
		var p: float = _near_rows[r][1]
		var fans: Array = _near_rows[r][2]
		for f in fans:
			_draw_fan(n, f, y, p, ox)
		for nf in _near_flags:
			if nf[0] == r:
				var fx: float = floorf(lerpf(-200.0, 2100.0, nf[1]) / p) * p
				n.draw_rect(Rect2(fx, y - p * 22, p, p * 24), LINE)
				n.draw_rect(Rect2(fx, y - p * 21, p * 0.5, p * 22), Color(0.62, 0.45, 0.26))
				_draw_flag(n, Vector2(fx + p, y - p * 21), Vector2i(16, 10), p, "team", 1.2)
		# Marche / dossier devant la rangée.
		n.draw_rect(Rect2(-600, y + p * 7, 3200, p * 3), CONCRETE_DK)
		n.draw_rect(Rect2(-600, y + p * 7, 3200, p), CONCRETE.lightened(0.15))

func _draw_fan(n: Node2D, f: Dictionary, y0: float, p: float, ola_x: float) -> void:
	var x: float = f["x"]
	var y: float = y0
	var arms: int = 0   # 0 bas, 1 levés, 2 poings (pompe), 3 mains sur la tête, 4 gauche, 5 droite
	if f["bouncy"] and (_beat() + int(f["group"])) % 2 == 0:
		y -= p
	var rt: float = 0.8 - _react_t - float(f["delay"])
	if _react != React.NONE and rt >= 0.0:
		match _react:
			React.JUMP:
				y = y0 - p * (3.0 if rt < 0.4 else 1.0)
				arms = 1
			React.SWAY_L:
				x -= p
				arms = 4
			React.SWAY_R:
				x += p
				arms = 5
			React.PUMP:
				arms = 2
				y = y0 - (p if int(rt * 7.0) % 2 == 0 else 0.0)
			React.GROAN:
				arms = 3
				y = y0 + p
	if absf(x - ola_x) < 130.0:
		y = y0 - p * 3.0
		arms = 1
	var shirt: Color = f["shirt"]
	var skin: Color = f["skin"]
	# Bras levés (contour puis peau) — derrière la tête pour garder la silhouette.
	if arms == 1 or arms == 4:
		_arm(n, x - p, y - p * 3, p, skin, shirt)
	if arms == 1 or arms == 5:
		_arm(n, x + p * 6, y - p * 3, p, skin, shirt)
	if arms == 2:
		var up: float = p if int(_t * 7.0) % 2 == 0 else 0.0
		_arm(n, x - p, y + p - up, p, skin, shirt)
		_arm(n, x + p * 6, y + p * 2 - p + up, p, skin, shirt)
	# Silhouette : contour 1 p, buste, tête de dos.
	n.draw_rect(Rect2(x - p, y + p * 3, p * 8, p * 7), LINE)
	n.draw_rect(Rect2(x, y - p, p * 6, p * 5), LINE)
	n.draw_rect(Rect2(x, y + p * 4, p * 6, p * 5), shirt)
	if f["jersey"]:
		_jersey(n, x, y + p * 4, p)
	n.draw_rect(Rect2(x, y + p * 4, p, p * 5), shirt.darkened(0.2))
	n.draw_rect(Rect2(x + p, y, p * 4, p * 4), skin)
	if f["cap"]:
		n.draw_rect(Rect2(x + p, y, p * 4, p * 2), team["a"] if shirt != team["a"] else FUN[0])
	else:
		n.draw_rect(Rect2(x + p, y, p * 4, p * 3), f["hair"])
	n.draw_rect(Rect2(x + p, y + p * 3, p, p), skin.darkened(0.2))
	if arms == 3:
		n.draw_rect(Rect2(x - p, y + p, p * 2, p * 3), LINE)
		n.draw_rect(Rect2(x + p * 5, y + p, p * 2, p * 3), LINE)
		n.draw_rect(Rect2(x, y + p, p, p * 2), skin)
		n.draw_rect(Rect2(x + p * 5, y + p, p, p * 2), skin)

func _arm(n: Node2D, x: float, y: float, p: float, skin: Color, sleeve: Color) -> void:
	# Bras sans contour (sinon des piquets) : avant-bras, main plus large, manche.
	n.draw_rect(Rect2(x, y, p, p * 4), skin.darkened(0.12))
	n.draw_rect(Rect2(x, y - p, p * 2, p * 2), skin)
	n.draw_rect(Rect2(x, y + p * 4, p, p * 2), sleeve)

func _jersey(n: Node2D, x: float, y: float, p: float) -> void:
	var c2: Color = team["b"]
	match String(team["flag"]):
		"stripes_h":
			n.draw_rect(Rect2(x, y + p, p * 6, p), c2)
			n.draw_rect(Rect2(x, y + p * 3, p * 6, p), c2)
		"sash":
			for k in 4:
				n.draw_rect(Rect2(x + p * (4 - k), y + p * k, p * 2, p), c2)
		"tricolor":
			n.draw_rect(Rect2(x + p, y, p, p * 5), c2)
			n.draw_rect(Rect2(x + p * 4, y, p, p * 5), c2)
		"stripes_v":
			n.draw_rect(Rect2(x + p, y, p, p * 5), c2)
			n.draw_rect(Rect2(x + p * 4, y, p, p * 5), c2)

# =====================================================================
# Le joueur, de dos, au premier plan
# =====================================================================

const PADX: int = 4
const PADY: int = 2
const NW: int = 21 + PADX * 2
const NH: int = 32 + PADY

func _build_player() -> void:
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	# Camisa du time ; la couleur claire si la principale est noire (lisible).
	cfg["shirt_color"] = team["a"] if (team["a"] as Color).v > 0.3 else team["b"]
	cfg["shirt_pattern"] = "solid"
	var sheet: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var base: Image = Image.create(NW, NH, false, Image.FORMAT_RGBA8)
	base.fill(Color(0, 0, 0, 0))
	var sc: int = CharacterSpriteFactory.SCALE
	var oy: int = CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H
	for y in 32:
		for x in 21:
			base.set_pixel(x + PADX, y + PADY, sheet.get_pixel(x * sc + 1, oy + y * sc + 1))
	var skin: Color = base.get_pixel(4 + PADX, 19 + PADY)
	var sleeve: Color = base.get_pixel(10 + PADX, 18 + PADY)
	for pose in [Pose.IDLE, Pose.GOOOL, Pose.LEFT, Pose.RIGHT, Pose.VAMOS, Pose.OLA, Pose.LAMENT]:
		var img: Image = base.duplicate()
		if pose != Pose.IDLE:
			_pose_arms(img, pose, skin, sleeve)
		_pose_tex[pose] = ImageTexture.create_from_image(img)
	_player = Sprite2D.new()
	_player.centered = false
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.scale = Vector2(PLAYER_PX, PLAYER_PX)
	_player.texture = _pose_tex[Pose.IDLE]
	add_child(_player)

# Bras par pose, en pixels natifs (bras gauche ; le droit est en miroir).
const ARM_DOWN: Array = [["s", 4, 15, 5, 17], ["k", 4, 18, 4, 20], ["d", 4, 21, 4, 21]]
const ARM_UP: Array = [["s", 3, 13, 5, 15], ["k", 2, 6, 3, 12], ["k", 2, 4, 3, 5]]
const ARM_V: Array = [["s", 4, 14, 5, 16], ["s", 3, 12, 4, 13], ["k", 2, 10, 3, 11], ["k", 1, 7, 2, 9], ["k", 0, 5, 2, 6]]
const ARM_FLEX: Array = [["s", 3, 15, 5, 16], ["k", 1, 15, 2, 16], ["k", 1, 11, 2, 14], ["d", 1, 10, 2, 10]]
const ARM_HEAD: Array = [["s", 3, 13, 5, 15], ["k", 3, 9, 4, 12], ["k", 4, 7, 5, 8]]

func _pose_arms(img: Image, pose: int, skin: Color, sleeve: Color) -> void:
	# Efface les bras d'origine des deux côtés, sans toucher au torse.
	for y in range(14, 23):
		for x in [3, 4, 5, 15, 16, 17]:
			img.set_pixel(x + PADX, y + PADY, Color(0, 0, 0, 0))
	var left: Array = ARM_DOWN
	var right: Array = ARM_DOWN
	match pose:
		Pose.GOOOL:
			left = ARM_V
			right = ARM_V
		Pose.OLA:
			left = ARM_UP
			right = ARM_UP
		Pose.LEFT:
			left = ARM_V
		Pose.RIGHT:
			right = ARM_V
		Pose.VAMOS:
			left = ARM_FLEX
			right = ARM_FLEX
		Pose.LAMENT:
			left = ARM_HEAD
			right = ARM_HEAD
	_paint_arm(img, left, false, skin, sleeve)
	_paint_arm(img, right, true, skin, sleeve)
	_outline(img)

func _paint_arm(img: Image, parts: Array, mirror: bool, skin: Color, sleeve: Color) -> void:
	for part in parts:
		var c: Color = sleeve if part[0] == "s" else (skin if part[0] == "k" else skin.darkened(0.22))
		for y in range(part[2], part[4] + 1):
			for x in range(part[1], part[3] + 1):
				var px: int = (20 - x) if mirror else x
				img.set_pixel(px + PADX, y + PADY, c)

func _outline(img: Image) -> void:
	var edges: Array[Vector2i] = []
	for y in NH:
		for x in NW:
			if img.get_pixel(x, y).a > 0.01:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x < 0 or q.y < 0 or q.x >= NW or q.y >= NH:
					continue
				var nb: Color = img.get_pixel(q.x, q.y)
				if nb.a > 0.01 and not nb.is_equal_approx(LINE):
					edges.append(Vector2i(x, y))
					break
	for e in edges:
		img.set_pixel(e.x, e.y, LINE)

func _update_player() -> void:
	_player.texture = _pose_tex[_pose]
	var lift: float = 0.0
	if _pose == Pose.GOOOL or _pose == Pose.OLA:
		lift = 4.0 if _pose_t > 0.35 else 1.0
	elif _pose == Pose.IDLE:
		lift = 1.0 if _beat() % 2 == 0 else 0.0
	elif _pose == Pose.LAMENT:
		lift = -1.0
	_player.position = Vector2(PLAYER_X - (10.5 + PADX) * PLAYER_PX, PLAYER_FEET - NH * PLAYER_PX - lift * PLAYER_PX)

# =====================================================================
# Fumigènes et confettis
# =====================================================================

func _light_flares(count: int) -> void:
	for k in count:
		var x: float = _rng.randf_range(160.0, 1760.0)
		var top: float = roof_front(x) + 70.0
		var bottom: float = ELL_C.y - ELL_R.y * sqrt(maxf(1.0 - pow((x - ELL_C.x) / ELL_R.x, 2.0), 0.0)) - 20.0
		var pos: Vector2 = Vector2(x, _rng.randf_range(top, maxf(bottom, top + 10.0)))
		var tc: Color = team["a"] if (team["a"] as Color).v > 0.3 else team["b"]
		_flares.append({"pos": pos, "life": 1.8, "col": Color(0.96, 0.34, 0.30) if k % 2 == 0 else tc.lightened(0.15)})

func _burst_confetti(count: int) -> void:
	var cols: Array[Color] = [team["a"], team["b"], team["c"], WHITE, FUN[0], FUN[1]]
	for k in count:
		_confetti.append({
			"pos": Vector2(_rng.randf_range(-200.0, 2120.0), _rng.randf_range(-260.0, -10.0)),
			"vel": Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(140.0, 260.0)),
			"col": cols[_rng.randi() % cols.size()],
			"ph": _rng.randf() * TAU,
		})

func _step_particles(delta: float) -> void:
	for fl in _flares:
		fl["life"] -= delta
		if _rng.randf() < 0.8:
			_smoke.append({"pos": fl["pos"] + Vector2(_rng.randf_range(-8, 8), -6), "vel": Vector2(_rng.randf_range(-24, 24), -40.0),
				"life": 2.2, "max": 2.2, "col": fl["col"]})
	_flares = _flares.filter(func(f: Dictionary) -> bool: return f["life"] > 0.0)
	for s in _smoke:
		s["life"] -= delta
		s["pos"] += s["vel"] * delta
	_smoke = _smoke.filter(func(s: Dictionary) -> bool: return s["life"] > 0.0)
	for c in _confetti:
		c["pos"] += Vector2(c["vel"].x + sin(_t * 5.0 + c["ph"]) * 50.0, c["vel"].y) * delta
	_confetti = _confetti.filter(func(c: Dictionary) -> bool: return c["pos"].y < 1300.0)

func _draw_fx(n: Node2D) -> void:
	for c in _confetti:
		var flip: bool = int(_t * 10.0 + c["ph"] * 3.0) % 2 == 0
		var sz: Vector2 = Vector2(P * 3, P * 2) if flip else Vector2(P * 2, P * 3)
		n.draw_rect(Rect2(_snap(c["pos"].x), _snap(c["pos"].y), sz.x, sz.y), c["col"])
