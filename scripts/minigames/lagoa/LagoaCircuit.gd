class_name LagoaCircuit
extends MinigameBase

# Volta da Lagoa à vélo de course, en pseudo-3D vue de derrière (route en
# bandes horizontales projetées, virages par décalage latéral cumulé, collines).
# Contre-la-montre arcade : chaque checkpoint rallonge le temps restant ; il faut
# boucler LAPS tours avant zéro. Accélération automatique, FREIO pour les épingles :
# trop vite dans un virage, la force centrifuge pousse vers l'extérieur.

signal match_ended(qualifies: bool, tips: int)

# --- Projection ---
const SEG_LEN: float = 200.0
const ROAD_W: float = 1400.0          # demi-largeur de la ciclovia (unités monde)
const CAM_H: float = 1000.0
const FOCAL: float = 806.0            # distance focale en px écran
const HORIZON_Y: float = 430.0
const CX: float = 960.0
const PLAYER_Z: float = 1400.0        # le vélo est devant la caméra
const DRAW_DIST: int = 150
const NEAR_Z: float = 160.0
const RUMBLE_LEN: int = 3
const PIX: float = 4.0                # bandes calées sur 4 px : rendu « pixel »
const RUMBLE_W: float = 1.12
const SHORE: float = 2.6              # l'eau commence à 2,6 demi-largeurs à gauche

# --- Conduite ---
const MAX_SPEED: float = 7500.0
const ACCEL: float = MAX_SPEED / 4.5
const BRAKE: float = MAX_SPEED * 1.1
# Pédale relâchée : roue libre, on perd doucement de la vitesse.
const COAST: float = MAX_SPEED * 0.25
const STEER: float = 2.4
const CENTRIFUGAL: float = 0.3
const OFFROAD_LIMIT: float = MAX_SPEED * 0.3
const OFFROAD_DECEL: float = MAX_SPEED * 1.2
const X_LIMIT: float = 2.0
const PLAYER_HALF: float = 0.12
const RIVAL_HIT: float = 0.24
const HIT_COOLDOWN: float = 0.8
const KMH_AT_MAX: float = 42.0

# --- Course ---
const LAPS: int = 2
const CP_PER_LAP: int = 3
const TIME_START: float = 22.0
const TIME_EXTEND: float = 13.0
const COUNTDOWN: float = 3.0
const RIVAL_COUNT: int = 14

# Caixinha du loueur (max 100 R$) : deux tours sous ~64 s = le max.
const TIP_BASE: int = 25
const TIP_BONUS_MAX: int = 75
const TIP_FAST_TIME: float = 64.0
const TIP_SLOW_TIME: float = 86.0

const HELP: String = "Tiens PEDALA pour avancer · joystick pour guider · FREIO avant les virages"

# Tracé d'un tour : [entrée, tenue, sortie, courbure, dénivelé en segments].
const TRACK: Array = [
	[0, 60, 0, 0.0, 0.0],
	[20, 40, 20, -2.0, 0.0],
	[10, 30, 10, 0.0, 6.0],
	[20, 30, 20, 4.0, -6.0],
	[0, 40, 0, 0.0, 0.0],
	[25, 60, 25, -6.0, 0.0],
	[0, 60, 0, 0.0, 5.0],
	[15, 25, 15, 3.0, 0.0],
	[15, 25, 15, -3.0, -5.0],
	[0, 50, 0, 0.0, 0.0],
	[20, 50, 20, -4.0, 0.0],
	[10, 25, 10, 0.0, 8.0],
	[10, 25, 10, 0.0, -8.0],
	[25, 40, 25, 6.0, 0.0],
	[0, 50, 0, 0.0, 0.0],
	[20, 60, 20, -5.0, 0.0],
	[0, 70, 0, 0.0, 0.0],
]
const CP_NAMES: Array = ["VOLTA DA LAGOA", "CATACUMBA", "ESTÁDIO DE REMO"]

enum Prop { PALM, TREE, KIOSK, SWAN }
const PROP_HALF: Array = [0.1, 0.13, 0.55, 0.0]

# --- Palette (aplats chauds) ---
const SKY: Array = [
	Color(0.33, 0.60, 0.86), Color(0.42, 0.68, 0.90), Color(0.55, 0.76, 0.92),
	Color(0.72, 0.82, 0.90), Color(0.93, 0.84, 0.72), Color(0.98, 0.76, 0.55),
]
const CLOUD: Color = Color(0.99, 0.97, 0.93)
const FAR_HAZE: Color = Color(0.64, 0.64, 0.80)
const FAR_ROCK: Color = Color(0.42, 0.46, 0.64)
const CRISTO: Color = Color(0.97, 0.95, 0.88)
const MID_GREEN: Color = Color(0.22, 0.45, 0.32)
const MID_GREEN_B: Color = Color(0.27, 0.52, 0.35)
const BUILD_COLS: Array = [
	Color(0.94, 0.89, 0.78), Color(0.96, 0.80, 0.70), Color(0.86, 0.86, 0.84), Color(0.98, 0.92, 0.70),
]
const WINDOW: Color = Color(0.35, 0.40, 0.48)
const LAKE: Color = Color(0.28, 0.55, 0.76)
const LAKE_SHINE: Color = Color(0.70, 0.86, 0.94)
const GRASS_A: Color = Color(0.42, 0.66, 0.30)
const GRASS_B: Color = Color(0.38, 0.61, 0.27)
const WATER_A: Color = Color(0.24, 0.53, 0.74)
const WATER_B: Color = Color(0.27, 0.57, 0.78)
const SHORE_COL: Color = Color(0.86, 0.78, 0.58)
const RUMBLE_A: Color = Color(0.84, 0.22, 0.18)
const RUMBLE_B: Color = Color(0.96, 0.94, 0.88)
const ROAD_A: Color = Color(0.70, 0.34, 0.25)
const ROAD_B: Color = Color(0.66, 0.31, 0.23)
const LINE_COL: Color = Color(0.98, 0.95, 0.85)
const CHECK_DARK: Color = Color(0.12, 0.12, 0.14)
const TRUNK: Color = Color(0.55, 0.38, 0.22)
const TRUNK_D: Color = Color(0.45, 0.30, 0.17)
const LEAF: Color = Color(0.20, 0.55, 0.25)
const LEAF_D: Color = Color(0.14, 0.42, 0.20)
const COCO: Color = Color(0.45, 0.32, 0.15)
const TIRE: Color = Color(0.10, 0.10, 0.12)
const RIM: Color = Color(0.55, 0.55, 0.58)
const BAR: Color = Color(0.20, 0.20, 0.24)
const GRIP: Color = Color(0.85, 0.25, 0.20)
const REFLECTOR: Color = Color(0.95, 0.20, 0.15)
const SHADOW: Color = Color(0, 0, 0, 0.25)
const POLE: Color = Color(0.92, 0.90, 0.84)
const BANNER_CP: Color = Color(0.16, 0.55, 0.36)
const BANNER_TEXT: Color = Color(1.0, 0.95, 0.70)
const GOLD: Color = Color(1.0, 0.86, 0.35)
const ALERT: Color = Color(1.0, 0.38, 0.30)

# Décor lointain (répété tous les FAR_W px, y négatif = au-dessus de l'horizon).
const FAR_W: float = 2600.0
const MID_W: float = 2000.0
const LAKE_H: float = 28.0
const FAR_HAZE_POLY: Array = [
	Vector2(0, 0), Vector2(0, -120), Vector2(300, -150), Vector2(520, -110), Vector2(800, -170),
	Vector2(1100, -130), Vector2(1400, -160), Vector2(1800, -120), Vector2(2100, -150),
	Vector2(2400, -110), Vector2(2600, -120), Vector2(2600, 0),
]
const FAR_ROCK_POLYS: Array = [
	# Corcovado (le Cristo est posé au sommet)
	[Vector2(500, 0), Vector2(640, -120), Vector2(760, -250), Vector2(830, -330), Vector2(870, -345),
		Vector2(905, -330), Vector2(950, -250), Vector2(1060, -150), Vector2(1250, -60), Vector2(1350, 0)],
	# Dois Irmãos
	[Vector2(1500, 0), Vector2(1620, -140), Vector2(1680, -230), Vector2(1720, -210), Vector2(1760, -160),
		Vector2(1800, -245), Vector2(1840, -260), Vector2(1880, -200), Vector2(2000, -90), Vector2(2100, 0)],
	# Pedra da Gávea
	[Vector2(2150, 0), Vector2(2220, -150), Vector2(2260, -235), Vector2(2400, -245), Vector2(2440, -200),
		Vector2(2520, -90), Vector2(2600, 0)],
]
const CLOUDS: Array = [Rect2(200, -330, 220, 34), Rect2(1150, -290, 300, 40), Rect2(1900, -360, 180, 30)]
const MID_HILLS: Array = [
	[Vector2(0, 0), Vector2(0, -70), Vector2(200, -110), Vector2(380, -80), Vector2(520, -40), Vector2(600, 0)],
	[Vector2(1100, 0), Vector2(1250, -90), Vector2(1400, -120), Vector2(1550, -80), Vector2(1700, 0)],
]
const MID_BUILDINGS: Array = [
	Rect2(620, -70, 60, 70), Rect2(690, -110, 70, 110), Rect2(770, -85, 55, 85), Rect2(835, -130, 80, 130),
	Rect2(925, -95, 60, 95), Rect2(995, -75, 70, 75), Rect2(1720, -90, 70, 90), Rect2(1800, -125, 60, 125),
	Rect2(1870, -80, 80, 80), Rect2(1960, -60, 40, 60),
]
const LEAF_ANGLES: Array = [-3.0, -2.5, -2.0, -1.2, -0.6, -0.1, 0.35, 2.8]

class PropItem:
	var kind: int = 0
	var offset: float = 0.0
	var variant: int = 0

class Rival:
	var z: float = 0.0
	var offset: float = 0.0
	var target: float = 0.0
	var speed: float = 0.0
	var bike: bool = true
	var tex: Texture2D = null
	var anim: float = 0.0
	var retarget: float = 0.0

# Piste
var _curve: PackedFloat32Array = PackedFloat32Array()
var _hy: PackedFloat32Array = PackedFloat32Array()   # hauteur en fin de segment
var _props: Array = []                                # Array[Array[PropItem]] par segment
var _banner_seg: Dictionary = {}                      # segment -> index CP_NAMES
var _n: int = 0
var _track_len: float = 1.0

# Projection de la frame (indexée par n = distance en segments)
var _pj_seg: PackedInt32Array = PackedInt32Array()
var _pj_x1: PackedFloat32Array = PackedFloat32Array()
var _pj_y1: PackedFloat32Array = PackedFloat32Array()
var _pj_s1: PackedFloat32Array = PackedFloat32Array()
var _pj_x2: PackedFloat32Array = PackedFloat32Array()
var _pj_y2: PackedFloat32Array = PackedFloat32Array()
var _pj_s2: PackedFloat32Array = PackedFloat32Array()
var _pj_clip: PackedFloat32Array = PackedFloat32Array()
var _far_polys: Array = []
var _mid_polys: Array = []
var _haze_poly: PackedVector2Array = PackedVector2Array()

# État
var _dist: float = 0.0          # distance parcourue par la caméra (jamais repliée)
var _px: float = 0.0            # position latérale, ±1 = bords de la route
var _speed: float = 0.0
var _lean: float = 0.0
var _pedal: float = 0.0
var _shake: Vector2 = Vector2.ZERO
var _was_off: bool = false
var _hit_cd: float = 0.0
var _far_off: float = 0.0
var _mid_off: float = 0.0
var _t: float = 0.0
var _rivals: Array = []         # Array[Rival]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player_tex: Texture2D = null
var _font: Font = null
var _view: Rect2 = Rect2(0, 0, 1920, 1080)

var _countdown: float = COUNTDOWN
var _last_beat: int = 4
var _time_left: float = TIME_START
var _last_tick: int = 99
var _elapsed: float = 0.0
var _lap: int = 1
var _lap_time: float = 0.0
var _next_cp: int = 1
var _completion_time: float = -1.0
var _ended: bool = false
var _banner_t: float = 0.0
var _status_t: float = 0.0
var _fingers: Dictionary = {}   # index du doigt -> position
var _touch_brake: bool = false
var _touch_gas: bool = false

@onready var time_label: Label = $UI/Time
@onready var lap_label: Label = $UI/Lap
@onready var clock_label: Label = $UI/LapClock
@onready var speed_label: Label = $UI/Speed
@onready var status_label: Label = $UI/Status
@onready var banner_label: Label = $UI/Banner
@onready var banner_sub: Label = $UI/BannerSub
@onready var brake_btn: Button = $UI/Brake
@onready var gas_btn: Button = $UI/Gas

func _ready() -> void:
	EventBus.minigame_started.emit("lagoa_circuit")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 4242
	_font = PixelFont.ui_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_player_tex = CharacterSpriteFactory.build_sheet(
		CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices()))
	_build_track()
	_build_props()
	_spawn_rivals()
	_cache_backdrop()
	# Les Packed*Array se copient : on les dimensionne un par un.
	_pj_x1.resize(DRAW_DIST)
	_pj_y1.resize(DRAW_DIST)
	_pj_s1.resize(DRAW_DIST)
	_pj_x2.resize(DRAW_DIST)
	_pj_y2.resize(DRAW_DIST)
	_pj_s2.resize(DRAW_DIST)
	_pj_clip.resize(DRAW_DIST)
	_pj_seg.resize(DRAW_DIST)
	for c in [time_label, lap_label, clock_label, speed_label, status_label, brake_btn, gas_btn]:
		if c:
			SafeArea.apply(c as Control)
	if status_label:
		status_label.text = HELP
	_show_banner("3", "%d voltas · chaque checkpoint rallonge le temps" % LAPS, COUNTDOWN)
	_update_view()
	_update_hud()

# --- Construction de la piste ---

func _add_road(enter: int, hold: int, leave: int, curve: float, hill: float) -> void:
	var start_y: float = 0.0 if _hy.is_empty() else _hy[_hy.size() - 1]
	var end_y: float = start_y + hill * SEG_LEN
	var total: float = float(enter + hold + leave)
	var k: int = 0
	for i in enter:
		_curve.append(_ease_in(0.0, curve, float(i) / float(enter)))
		k += 1
		_hy.append(_ease_in_out(start_y, end_y, float(k) / total))
	for i in hold:
		_curve.append(curve)
		k += 1
		_hy.append(_ease_in_out(start_y, end_y, float(k) / total))
	for i in leave:
		_curve.append(_ease_in_out(curve, 0.0, float(i) / float(leave)))
		k += 1
		_hy.append(_ease_in_out(start_y, end_y, float(k) / total))

func _ease_in(a: float, b: float, p: float) -> float:
	return a + (b - a) * p * p

func _ease_in_out(a: float, b: float, p: float) -> float:
	return a + (b - a) * (0.5 - cos(p * PI) * 0.5)

func _build_track() -> void:
	for s in TRACK:
		var sec: Array = s
		_add_road(int(sec[0]), int(sec[1]), int(sec[2]), float(sec[3]), float(sec[4]))
	_n = _curve.size()
	_hy[_n - 1] = 0.0   # la boucle se referme à plat
	_track_len = float(_n) * SEG_LEN
	for k in CP_PER_LAP:
		var z: float = _track_len * float(k) / float(CP_PER_LAP) + PLAYER_Z
		_banner_seg[int(z / SEG_LEN) % _n] = k

func _near_banner(i: int) -> bool:
	for b in _banner_seg.keys():
		var d: int = absi(int(b) - i)
		if mini(d, _n - d) <= 3:
			return true
	return false

func _put(i: int, kind: int, offset: float) -> void:
	var p: PropItem = PropItem.new()
	p.kind = kind
	p.offset = offset
	p.variant = _rng.randi_range(0, 2)
	(_props[i] as Array).append(p)

func _build_props() -> void:
	_props.clear()
	for i in _n:
		_props.append([])
	for i in _n:
		if _near_banner(i):
			continue
		if i % 6 == 0:
			_put(i, Prop.PALM, _rng.randf_range(1.45, 2.0))
		if i % 9 == 4:
			_put(i, Prop.PALM, -_rng.randf_range(1.45, 1.95))
		if i % 7 == 3 and _rng.randf() < 0.7:
			_put(i, Prop.TREE, _rng.randf_range(2.4, 3.6))
		if i % 23 == 11:
			_put(i, Prop.SWAN, -_rng.randf_range(3.6, 6.0))
	for i in [130, 420, 700, 985]:
		var seg: int = int(i) % _n
		if not _near_banner(seg):
			_put(seg, Prop.KIOSK, 2.6)

func _spawn_rivals() -> void:
	_rivals.clear()
	for k in RIVAL_COUNT:
		var r: Rival = Rival.new()
		r.bike = k % 5 != 2 and k % 5 != 4
		r.z = 6000.0 + (_track_len - 9000.0) * float(k) / float(RIVAL_COUNT)
		r.offset = _rng.randf_range(-0.7, 0.7)
		r.target = r.offset
		r.speed = MAX_SPEED * (_rng.randf_range(0.42, 0.6) if r.bike else _rng.randf_range(0.16, 0.24))
		r.retarget = _rng.randf_range(1.0, 4.0)
		r.anim = _rng.randf() * 2.0
		r.tex = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(9100 + k * 37))
		_rivals.append(r)

func _cache_backdrop() -> void:
	_haze_poly = PackedVector2Array(FAR_HAZE_POLY)
	_far_polys.clear()
	for p in FAR_ROCK_POLYS:
		_far_polys.append(PackedVector2Array(p as Array))
	_mid_polys.clear()
	for p in MID_HILLS:
		_mid_polys.append(PackedVector2Array(p as Array))

func _seg_index(z: float) -> int:
	return int(fposmod(z, _track_len) / SEG_LEN) % _n

func _seg_y1(i: int) -> float:
	return _hy[(i - 1 + _n) % _n]

# --- Boucle ---

func _process(delta: float) -> void:
	_update_view()
	_t += delta
	_tick_banner(delta)
	if _ended:
		_speed = move_toward(_speed, 0.0, MAX_SPEED * 0.6 * delta)
		_dist += _speed * delta
		_update_rivals(delta)
		queue_redraw()
		return
	if _countdown > 0.0:
		_tick_countdown(delta)
		queue_redraw()
		return
	_elapsed += delta
	_lap_time += delta
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_hud()
		sfx("mg_miss", 0.7)
		_end_game(false)
		return
	_tick_warning()
	_update_player(delta)
	_update_rivals(delta)
	_check_rivals()
	_check_checkpoints()
	_update_parallax(delta)
	_update_hud()
	queue_redraw()

func _update_view() -> void:
	var vp: Viewport = get_viewport()
	var vis: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vis
	_view = Rect2(a, b - a)

func _tick_countdown(delta: float) -> void:
	_countdown -= delta
	var beat: int = ceili(_countdown)
	if beat != _last_beat:
		_last_beat = beat
		if beat > 0:
			sfx("checkpoint", 0.7)
			_show_banner(str(beat), banner_sub.text if banner_sub else "", 1.2)
		else:
			sfx("whistle", 1.3)
			_show_banner("VAI!", "", 0.8)

func _tick_warning() -> void:
	var sec: int = ceili(_time_left)
	if sec <= 5 and sec != _last_tick:
		sfx("mg_hit", 1.8)
	_last_tick = sec

func _steer_input() -> float:
	# Joystick virtuel (analogique : on dose le virage), stick, croix ou clavier.
	return clampf(Input.get_axis("move_left", "move_right"), -1.0, 1.0)

# Pédaler : bouton PEDALA, A manette (E), ↑ / W au clavier.
func _gas_input() -> bool:
	return _touch_gas or Input.is_action_pressed("move_forward") or Input.is_action_pressed("interact")

func _brake_input() -> bool:
	return _touch_brake or Input.is_action_pressed("move_back") or Input.is_action_pressed("jump")

func _update_player(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	var sp: float = _speed / MAX_SPEED
	var steer: float = _steer_input()
	var pseg: int = _seg_index(_dist + PLAYER_Z)
	var dx: float = delta * STEER * sp
	_px += steer * dx
	# Force centrifuge : vers l'extérieur du virage, au carré de la vitesse.
	_px -= dx * sp * _curve[pseg] * CENTRIFUGAL
	_px = clampf(_px, -X_LIMIT, X_LIMIT)
	var off_road: bool = absf(_px) > 1.0
	var force: float = -COAST
	if _brake_input():
		force = -BRAKE
	elif _gas_input():
		force = ACCEL
	var s: float = _speed + force * delta
	if off_road and s > OFFROAD_LIMIT:
		s = minf(s, maxf(OFFROAD_LIMIT, _speed - OFFROAD_DECEL * delta))
	_speed = clampf(s, 0.0, MAX_SPEED)
	if off_road and not _was_off and _speed > OFFROAD_LIMIT * 0.5:
		sfx("mg_miss", 0.85)
		pulse(0.35, 0.12)
		_flash_status("Fora da ciclovia! Reviens sur le rouge.")
	_was_off = off_road
	_shake = Vector2(randf_range(-3.0, 3.0), randf_range(-5.0, 0.0)) if off_road and _speed > 400.0 else Vector2.ZERO
	if off_road:
		_check_props(pseg)
	_lean = lerpf(_lean, steer * 0.16 + _curve[pseg] * sp * 0.02, clampf(delta * 8.0, 0.0, 1.0))
	_pedal += delta * (2.0 + sp * 8.0)
	_dist += _speed * delta

func _check_props(pseg: int) -> void:
	if _hit_cd > 0.0:
		return
	var hit: bool = false
	for p in _props[pseg]:
		var item: PropItem = p
		var half: float = float(PROP_HALF[item.kind])
		if half > 0.0 and absf(_px - item.offset) < PLAYER_HALF + half:
			hit = true
	if _banner_seg.has(pseg) and absf(absf(_px) - 1.3) < PLAYER_HALF:
		hit = true
	if hit:
		_speed = minf(_speed, MAX_SPEED * 0.1)
		_px = move_toward(_px, 0.0, 0.3)
		_crash("Aïe ! Le décor ne se double pas.")

func _crash(msg: String) -> void:
	_hit_cd = HIT_COOLDOWN
	sfx("mg_drop")
	pulse(0.7, 0.18)
	_flash_status(msg)

func _update_rivals(delta: float) -> void:
	for o in _rivals:
		var r: Rival = o
		r.z = fposmod(r.z + r.speed * delta, _track_len)
		r.anim += delta * (6.0 if r.bike else 7.0)
		r.retarget -= delta
		if r.retarget <= 0.0:
			r.retarget = _rng.randf_range(2.0, 5.0)
			r.target = _rng.randf_range(-0.75, 0.75)
		r.offset = move_toward(r.offset, r.target, 0.25 * delta)

func _check_rivals() -> void:
	var pz: float = fposmod(_dist + PLAYER_Z, _track_len)
	for o in _rivals:
		var r: Rival = o
		var dz: float = wrapf(r.z - pz, -_track_len * 0.5, _track_len * 0.5)
		if dz < -80.0 or dz > 160.0 or _speed <= r.speed:
			continue
		if absf(_px - r.offset) >= RIVAL_HIT:
			continue
		# Choc : on reste derrière lui, à sa vitesse amputée.
		_speed = r.speed * 0.6
		_dist += dz - 180.0
		if _hit_cd <= 0.0:
			_crash("Opa! Contourne-le par l'autre côté." if r.bike else "Opa! Cuidado com o corredor.")

func _check_checkpoints() -> void:
	var section: float = _track_len / float(CP_PER_LAP)
	if _dist < float(_next_cp) * section:
		return
	var k: int = _next_cp
	_next_cp += 1
	if k >= LAPS * CP_PER_LAP:
		_completion_time = _elapsed
		_update_hud()
		sfx("mg_perfect")
		pulse(0.4, 0.12)
		_end_game(true)
		return
	_time_left += TIME_EXTEND
	sfx("checkpoint")
	pulse(0.25, 0.06)
	if k % CP_PER_LAP == 0:
		var lap_done: float = _lap_time
		_lap += 1
		_lap_time = 0.0
		_show_banner("VOLTA %d/%d" % [_lap, LAPS], "%s · TEMPO EXTRA +%d s" % [_fmt(lap_done), int(TIME_EXTEND)], 1.8)
	else:
		_show_banner("TEMPO EXTRA!", "+%d s · %s" % [int(TIME_EXTEND), String(CP_NAMES[k % CP_PER_LAP])], 1.6)

func _update_parallax(delta: float) -> void:
	var c: float = _curve[_seg_index(_dist + PLAYER_Z)]
	var sp: float = _speed / MAX_SPEED
	_far_off += c * sp * 16.0 * delta
	_mid_off += c * sp * 40.0 * delta

# --- HUD ---

func _fmt(t: float) -> String:
	var m: int = int(t) / 60
	return "%d:%04.1f" % [m, t - float(m) * 60.0]

func _update_hud() -> void:
	if time_label:
		time_label.text = "TEMPO %d" % ceili(_time_left)
		time_label.add_theme_color_override("font_color", ALERT if _time_left < 6.0 else GOLD)
	if lap_label:
		lap_label.text = "VOLTA %d/%d" % [mini(_lap, LAPS), LAPS]
	if clock_label:
		clock_label.text = _fmt(_lap_time)
	if speed_label:
		speed_label.text = "%d km/h" % int(round(_speed / MAX_SPEED * KMH_AT_MAX))

func _show_banner(text: String, sub: String, dur: float) -> void:
	_banner_t = dur
	if banner_label:
		banner_label.text = text
		banner_label.visible = true
	if banner_sub:
		banner_sub.text = sub
		banner_sub.visible = sub != ""

func _tick_banner(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0 and not _ended:
			if banner_label:
				banner_label.visible = false
			if banner_sub:
				banner_sub.visible = false
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0 and status_label and not _ended:
			status_label.text = HELP

func _flash_status(msg: String) -> void:
	_status_t = 1.6
	if status_label:
		status_label.text = msg

# --- FREIO tactile suivi au doigt : on freine en tenant le joystick ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_fingers[st.index] = st.position
		else:
			_fingers.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _fingers.has(sd.index):
			_fingers[sd.index] = sd.position
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_fingers[-1] = mb.position
		else:
			_fingers.erase(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if not _fingers.has(-1):
			return
		_fingers[-1] = (event as InputEventMouseMotion).position
	else:
		return
	_touch_brake = _held(brake_btn)
	_touch_gas = _held(gas_btn)

func _held(btn: Button) -> bool:
	if btn == null or not btn.is_visible_in_tree():
		return false
	var rect: Rect2 = btn.get_global_rect()
	var on: bool = false
	for f in _fingers.values():
		if rect.has_point(f as Vector2):
			on = true
	btn.button_pressed = on
	return on

# --- Fin ---

func _compute_tip(qualifies: bool) -> int:
	if forfeited:
		return 0
	if not qualifies:
		var progress: float = float(_next_cp - 1) / float(LAPS * CP_PER_LAP)
		return int(round(TIP_BASE * progress * 0.5))
	var ratio: float = clampf((TIP_SLOW_TIME - _completion_time) / (TIP_SLOW_TIME - TIP_FAST_TIME), 0.0, 1.0)
	return TIP_BASE + int(round(TIP_BONUS_MAX * ratio))

func quit_game() -> void:
	_end_game(false)

func _end_game(qualifies: bool) -> void:
	if _ended:
		return
	_ended = true
	qualifies = final_qualifies(qualifies)
	var tip: int = _compute_tip(qualifies)
	if not forfeited:
		if qualifies:
			_show_banner("CHEGADA!", "%s · R$ %d" % [_fmt(_completion_time), tip], 99.0)
		else:
			_show_banner("FIM DO TEMPO", "R$ %d" % tip, 99.0)
	if status_label:
		status_label.text = "Volta da Lagoa bouclée !" if qualifies else "Le loueur te fait signe de rentrer."
	await get_tree().create_timer(0.4 if forfeited else 2.4).timeout
	EventBus.minigame_ended.emit("lagoa_circuit", {"tip": tip, "time": _completion_time, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)

# --- Rendu ---

func _draw() -> void:
	var vl: float = _view.position.x - 4.0
	var vr: float = _view.end.x + 4.0
	var vt: float = _view.position.y - 4.0
	var vb: float = _view.end.y + 4.0
	_draw_sky(vl, vr, vt)
	_draw_far(vl, vr)
	_draw_mid(vl, vr)
	draw_rect(Rect2(vl, HORIZON_Y, vr - vl, vb - HORIZON_Y), GRASS_A)
	var last: int = _draw_road(vl, vr, vb)
	_draw_sprites(last)

func _tile_starts(vl: float, vr: float, off: float, w: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var x: float = -fposmod(off, w)
	while x > vl:
		x -= w
	while x < vr:
		out.append(x)
		x += w
	return out

func _draw_sky(vl: float, vr: float, vt: float) -> void:
	var h: float = HORIZON_Y - vt
	var bands: int = SKY.size()
	for k in bands:
		var y0: float = snappedf(vt + h * float(k) / float(bands), PIX)
		var y1: float = snappedf(vt + h * float(k + 1) / float(bands), PIX)
		draw_rect(Rect2(vl, y0, vr - vl, y1 - y0 + 1.0), SKY[k])
	for x0 in _tile_starts(vl, vr, _far_off * 0.5 + _t * 6.0, FAR_W):
		for c in CLOUDS:
			var r: Rect2 = c
			var base: Vector2 = Vector2(x0 + r.position.x, HORIZON_Y + r.position.y)
			draw_rect(Rect2(base, r.size), CLOUD)
			draw_rect(Rect2(base + Vector2(r.size.x * 0.2, -r.size.y * 0.6), Vector2(r.size.x * 0.5, r.size.y * 0.6)), CLOUD)

func _draw_far(vl: float, vr: float) -> void:
	for x0 in _tile_starts(vl, vr, _far_off, FAR_W):
		draw_set_transform(Vector2(x0, HORIZON_Y - LAKE_H + 4.0))
		draw_colored_polygon(_haze_poly, FAR_HAZE)
		for p in _far_polys:
			draw_colored_polygon(p as PackedVector2Array, FAR_ROCK)
		# Cristo Redentor au sommet du Corcovado
		draw_rect(Rect2(878, -351, 18, 8), CRISTO)
		draw_rect(Rect2(882, -395, 10, 46), CRISTO)
		draw_rect(Rect2(864, -386, 46, 8), CRISTO)
		draw_rect(Rect2(884, -403, 6, 8), CRISTO)
	draw_set_transform(Vector2.ZERO)

func _draw_mid(vl: float, vr: float) -> void:
	var base_y: float = HORIZON_Y - LAKE_H + 2.0
	for x0 in _tile_starts(vl, vr, _mid_off, MID_W):
		draw_set_transform(Vector2(x0, base_y))
		for i in _mid_polys.size():
			draw_colored_polygon(_mid_polys[i] as PackedVector2Array, MID_GREEN if i % 2 == 0 else MID_GREEN_B)
		for i in MID_BUILDINGS.size():
			var b: Rect2 = MID_BUILDINGS[i]
			draw_rect(b, BUILD_COLS[i % BUILD_COLS.size()])
			var wy: float = b.position.y + 8.0
			while wy < -10.0:
				var wx: float = b.position.x + 8.0
				while wx < b.end.x - 10.0:
					draw_rect(Rect2(wx, wy, 6, 6), WINDOW)
					wx += 14.0
				wy += 16.0
	draw_set_transform(Vector2.ZERO)
	# La Lagoa elle-même, entre l'autre rive et nous
	draw_rect(Rect2(vl, HORIZON_Y - LAKE_H, vr - vl, LAKE_H), LAKE)
	for k in 9:
		var sx: float = fposmod(float(k) * 431.0 - _mid_off * 1.3 + sin(_t * 0.7 + float(k)) * 20.0, vr - vl) + vl
		draw_rect(Rect2(sx, HORIZON_Y - LAKE_H + 6.0 + float(k % 3) * 7.0, 40.0 + float(k % 4) * 16.0, 3.0), LAKE_SHINE)

func _quad(xa1: float, xb1: float, y1: float, xa2: float, xb2: float, y2: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(xa1, y1), Vector2(xb1, y1), Vector2(xb2, y2), Vector2(xa2, y2)])
	draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())

# Route de l'avant vers l'horizon ; chaque bande ne peint que ce qui dépasse
# encore (maxy), ce qui cache la route derrière les bosses.
func _draw_road(vl: float, vr: float, vb: float) -> int:
	var cam_z: float = fposmod(_dist, _track_len)
	var base_seg: int = _seg_index(_dist)
	var base_pct: float = fposmod(_dist, SEG_LEN) / SEG_LEN
	var pz: float = _dist + PLAYER_Z
	var pseg: int = _seg_index(pz)
	var ppct: float = fposmod(pz, SEG_LEN) / SEG_LEN
	var cam_y: float = lerpf(_seg_y1(pseg), _hy[pseg], ppct) + CAM_H
	var cam_x: float = _px * ROAD_W
	var maxy: float = vb
	var x: float = 0.0
	var dx: float = -_curve[base_seg] * base_pct
	var last: int = 0
	for n in DRAW_DIST:
		var i: int = (base_seg + n) % _n
		var z1: float = float(base_seg + n) * SEG_LEN - cam_z
		var z2: float = z1 + SEG_LEN
		var rx1: float = x - cam_x
		var rx2: float = x + dx - cam_x
		x += dx
		dx += _curve[i]
		_pj_seg[n] = -1
		if z1 <= NEAR_Z:
			continue
		var s1: float = FOCAL / z1
		var s2: float = FOCAL / z2
		var x1: float = CX + s1 * rx1
		var x2: float = CX + s2 * rx2
		var y1: float = HORIZON_Y - s1 * (_seg_y1(i) - cam_y)
		var y2: float = HORIZON_Y - s2 * (_hy[i] - cam_y)
		_pj_seg[n] = i
		_pj_x1[n] = x1
		_pj_y1[n] = y1
		_pj_s1[n] = s1
		_pj_x2[n] = x2
		_pj_y2[n] = y2
		_pj_s2[n] = s2
		_pj_clip[n] = maxy
		last = n
		var qy1: float = snappedf(y1, PIX)
		var qy2: float = snappedf(y2, PIX)
		if qy2 >= qy1 or qy2 >= maxy:
			continue
		var w1: float = s1 * ROAD_W
		var w2: float = s2 * ROAD_W
		if qy1 > maxy:
			# Bande à moitié cachée par la bosse d'avant : on la rogne.
			var t: float = (maxy - qy2) / (qy1 - qy2)
			x1 = lerpf(x2, x1, t)
			w1 = lerpf(w2, w1, t)
			qy1 = maxy
		_draw_segment(i, vl, vr, x1, qy1, w1, x2, qy2, w2)
		maxy = qy2
	return last

func _draw_segment(i: int, vl: float, vr: float, x1: float, y1: float, w1: float, x2: float, y2: float, w2: float) -> void:
	var alt: bool = (i / RUMBLE_LEN) % 2 == 0
	draw_rect(Rect2(vl, y2, vr - vl, y1 - y2), GRASS_A if alt else GRASS_B)
	# Lagoa à gauche, bordée d'une berge de pierre
	var wx1: float = x1 - w1 * SHORE
	var wx2: float = x2 - w2 * SHORE
	if maxf(wx1, wx2) > vl:
		var left: float = minf(vl, minf(wx1, wx2)) - 2.0
		_quad(left, wx1, y1, left, wx2, y2, WATER_A if alt else WATER_B)
		_quad(wx1, wx1 + w1 * 0.14, y1, wx2, wx2 + w2 * 0.14, y2, SHORE_COL)
	_quad(x1 - w1 * RUMBLE_W, x1 + w1 * RUMBLE_W, y1, x2 - w2 * RUMBLE_W, x2 + w2 * RUMBLE_W, y2,
		RUMBLE_A if alt else RUMBLE_B)
	if _banner_seg.has(i) or _banner_seg.has((i - 1 + _n) % _n):
		# Ligne en damier (départ) ou blanche (checkpoint)
		var start: bool = _banner_seg.get(i, _banner_seg.get((i - 1 + _n) % _n, 1)) == 0
		if start:
			var cells: int = 8
			for c in cells:
				var fa: float = -1.0 + 2.0 * float(c) / float(cells)
				var fb: float = fa + 2.0 / float(cells)
				var dark: bool = (c + i) % 2 == 0
				_quad(x1 + w1 * fa, x1 + w1 * fb, y1, x2 + w2 * fa, x2 + w2 * fb, y2, CHECK_DARK if dark else LINE_COL)
		else:
			_quad(x1 - w1, x1 + w1, y1, x2 - w2, x2 + w2, y2, LINE_COL)
		return
	_quad(x1 - w1, x1 + w1, y1, x2 - w2, x2 + w2, y2, ROAD_A if alt else ROAD_B)
	if alt and w2 > 6.0:
		_quad(x1 - w1 * 0.03, x1 + w1 * 0.03, y1, x2 - w2 * 0.03, x2 + w2 * 0.03, y2, LINE_COL)

# Décor et coureurs de l'horizon vers nous ; le vélo du joueur s'intercale à sa profondeur.
func _draw_sprites(last: int) -> void:
	var buckets: Dictionary = {}
	for o in _rivals:
		var r: Rival = o
		var si: int = int(r.z / SEG_LEN) % _n
		if not buckets.has(si):
			buckets[si] = []
		(buckets[si] as Array).append(r)
	var player_n: int = int((fposmod(_dist, SEG_LEN) + PLAYER_Z) / SEG_LEN)
	var player_drawn: bool = false
	for n in range(last, -1, -1):
		if n < player_n and not player_drawn:
			_draw_player()
			player_drawn = true
		var i: int = _pj_seg[n]
		if i < 0:
			continue
		var clip: float = _pj_clip[n]
		if buckets.has(i):
			for o in buckets[i]:
				var r: Rival = o
				var pct: float = fposmod(r.z, SEG_LEN) / SEG_LEN
				var s: float = lerpf(_pj_s1[n], _pj_s2[n], pct)
				var bx: float = lerpf(_pj_x1[n], _pj_x2[n], pct) + s * r.offset * ROAD_W
				var by: float = lerpf(_pj_y1[n], _pj_y2[n], pct)
				if by - s * 640.0 >= clip or s * 640.0 < 2.0:
					continue
				var frame: int = 1 + int(r.anim) % 2
				draw_set_transform(Vector2(bx, by), 0.0, Vector2(s, s))
				_shape_rider(r.tex, frame, r.bike)
		var s1: float = _pj_s1[n]
		var x1: float = _pj_x1[n]
		var y1: float = _pj_y1[n]
		if _banner_seg.has(i) and y1 - s1 * 1560.0 < clip:
			draw_set_transform(Vector2(x1, y1), 0.0, Vector2(s1, s1))
			_shape_banner(int(_banner_seg[i]))
		for p in _props[i]:
			var item: PropItem = p
			var h: float = 2200.0 if item.kind != Prop.SWAN else 800.0
			if y1 - s1 * h >= clip or s1 * h < 2.0:
				continue
			var flip: float = -1.0 if item.offset < 0.0 else 1.0
			draw_set_transform(Vector2(x1 + s1 * item.offset * ROAD_W, y1), 0.0, Vector2(s1 * flip, s1))
			match item.kind:
				Prop.PALM:
					_shape_palm(item.variant)
				Prop.TREE:
					_shape_tree(item.variant)
				Prop.KIOSK:
					draw_set_transform(Vector2(x1 + s1 * item.offset * ROAD_W, y1), 0.0, Vector2(s1, s1))
					_shape_kiosk()
				Prop.SWAN:
					draw_set_transform(Vector2(x1 + s1 * item.offset * ROAD_W, y1 + sin(_t * 1.5 + float(i)) * s1 * 30.0), 0.0, Vector2(s1, s1))
					_shape_swan()
	if not player_drawn:
		_draw_player()
	draw_set_transform(Vector2.ZERO)

func _draw_player() -> void:
	var s: float = FOCAL / PLAYER_Z
	var base: Vector2 = Vector2(CX, HORIZON_Y + FOCAL * CAM_H / PLAYER_Z) + _shake
	var frame: int = 0 if _speed < 200.0 else 1 + int(_pedal) % 2
	draw_set_transform(base, _lean, Vector2(s, s))
	_shape_rider(_player_tex, frame, true)
	# Feu arrière qui clignote : on se repère dans la foule
	if int(_t * 3.0) % 2 == 0:
		draw_rect(Rect2(-26, -236, 52, 30), Color(1.0, 0.3, 0.2))
	draw_set_transform(Vector2.ZERO)

# Formes en unités monde, origine au pied (transformation posée par l'appelant).

func _shape_rider(tex: Texture2D, frame: int, bike: bool) -> void:
	var src: Rect2 = Rect2(frame * CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	draw_rect(Rect2(-200, -24, 400, 40), SHADOW)
	if bike:
		draw_rect(Rect2(-30, -300, 60, 300), TIRE)
		draw_rect(Rect2(-10, -290, 20, 70), RIM)
		draw_rect(Rect2(-200, -470, 400, 28), BAR)
		draw_rect(Rect2(-232, -482, 52, 48), GRIP)
		draw_rect(Rect2(180, -482, 52, 48), GRIP)
		if tex:
			draw_texture_rect_region(tex, Rect2(-160, -640, 320, 480), src)
		draw_rect(Rect2(-20, -200, 40, 26), REFLECTOR)
	elif tex:
		draw_texture_rect_region(tex, Rect2(-180, -540, 360, 540), src)

func _shape_palm(v: int) -> void:
	var h: float = 1800.0 + float(v) * 150.0
	for k in 6:
		var t: float = float(k) / 6.0
		var bend: float = t * t * 220.0
		draw_rect(Rect2(-45.0 + bend, -h * (t + 1.0 / 6.0), 90.0 - float(k) * 6.0, h / 6.0 + 4.0),
			TRUNK if k % 2 == 0 else TRUNK_D)
	var top: Vector2 = Vector2(220.0, -h)
	for a in LEAF_ANGLES:
		var dir: Vector2 = Vector2.from_angle(float(a))
		var tip: Vector2 = top + dir * 700.0 + Vector2(0, 260)
		var mid: Vector2 = top + dir * 380.0 + Vector2(0, -60)
		var nrm: Vector2 = Vector2(-dir.y, dir.x) * 70.0
		draw_colored_polygon(PackedVector2Array([top, mid + nrm, tip, mid - nrm]),
			LEAF if dir.y < -0.2 else LEAF_D)
	draw_rect(Rect2(top + Vector2(-60, -10), Vector2(56, 56)), COCO)
	draw_rect(Rect2(top + Vector2(4, 0), Vector2(56, 56)), COCO)

func _shape_tree(v: int) -> void:
	var wide: float = 1.0 + float(v) * 0.12
	draw_rect(Rect2(-60, -720, 120, 720), TRUNK_D)
	draw_rect(Rect2(-600 * wide, -1020, 1200 * wide, 240), LEAF_D)
	draw_rect(Rect2(-520 * wide, -1260, 1040 * wide, 260), LEAF_D)
	draw_rect(Rect2(-420 * wide, -1420, 840 * wide, 180), LEAF)
	draw_rect(Rect2(-380 * wide, -1220, 500 * wide, 140), LEAF)
	draw_rect(Rect2(-240 * wide, -1480, 420 * wide, 80), LEAF)

func _shape_kiosk() -> void:
	draw_rect(Rect2(-700, -600, 1400, 600), Color(0.95, 0.93, 0.86))
	draw_rect(Rect2(-700, -330, 1400, 70), Color(0.30, 0.55, 0.62))
	draw_rect(Rect2(-560, -560, 380, 200), Color(0.30, 0.36, 0.42))
	draw_rect(Rect2(180, -560, 380, 200), Color(0.30, 0.36, 0.42))
	for k in 8:
		draw_rect(Rect2(-800 + k * 200, -820, 200, 220), Color(0.95, 0.55, 0.20) if k % 2 == 0 else Color(0.98, 0.95, 0.88))
	draw_rect(Rect2(-760, -900, 1520, 80), Color(0.20, 0.50, 0.35))
	draw_rect(Rect2(-500, -1100, 1000, 190), Color(0.98, 0.84, 0.30))
	if _font:
		draw_string(_font, Vector2(-500, -960), "COCO GELADO", HORIZONTAL_ALIGNMENT_CENTER, 1000, 110, Color(0.45, 0.20, 0.12))
	# Coco posé sur le comptoir
	draw_rect(Rect2(-80, -420, 120, 110), Color(0.35, 0.60, 0.25))

func _shape_swan() -> void:
	draw_rect(Rect2(-560, -30, 1120, 50), Color(0.18, 0.42, 0.62))
	draw_rect(Rect2(-500, -280, 1000, 260), Color(0.98, 0.98, 0.95))
	draw_rect(Rect2(-560, -360, 160, 120), Color(0.98, 0.98, 0.95))
	draw_rect(Rect2(-260, -420, 420, 140), Color(0.85, 0.30, 0.25))
	draw_rect(Rect2(260, -700, 120, 440), Color(0.98, 0.98, 0.95))
	draw_rect(Rect2(260, -780, 260, 120), Color(0.98, 0.98, 0.95))
	draw_rect(Rect2(520, -750, 100, 50), Color(0.98, 0.60, 0.15))
	draw_rect(Rect2(400, -750, 30, 30), Color(0.1, 0.1, 0.1))

func _shape_banner(kind: int) -> void:
	var px: float = ROAD_W * 1.3
	draw_rect(Rect2(-px - 40.0, -1500, 80, 1500), POLE)
	draw_rect(Rect2(px - 40.0, -1500, 80, 1500), POLE)
	var col: Color = CHECK_DARK if kind == 0 else BANNER_CP
	draw_rect(Rect2(-px - 60.0, -1580, 2.0 * px + 120.0, 320), col)
	if kind == 0:
		var cells: int = 28
		var cw: float = (2.0 * px + 120.0) / float(cells)
		for c in cells:
			draw_rect(Rect2(-px - 60.0 + float(c) * cw, -1580, cw, 50), LINE_COL if c % 2 == 0 else CHECK_DARK)
			draw_rect(Rect2(-px - 60.0 + float(c) * cw, -1310, cw, 50), CHECK_DARK if c % 2 == 0 else LINE_COL)
	if _font:
		draw_string(_font, Vector2(-px, -1360), String(CP_NAMES[kind]), HORIZONTAL_ALIGNMENT_CENTER, 2.0 * px, 150, BANNER_TEXT)
