class_name SurfGame
extends MinigameBase

# Mini-jeu de surf « lire les vagues ». Les vagues arrivent en séries depuis
# l'horizon et grossissent en approchant : le joueur les lit à l'avance, se
# place sur le pic (bande claire), rame au bon moment (fenêtre de take-off),
# puis tient l'équilibre le plus longtemps possible pendant la ride.
# Score = qualité de vague × durée de ride × bonus de take-off parfait.
# Session de 90 s ; qualifie si score >= QUALIFY_SCORE.
# Contrat conservé : minigame_started/ended("surf", {time_survived, lives,
# qualifies, won}) + signal match_ended(qualifies, time_survived).

signal match_ended(qualifies: bool, time_survived: float)

enum Phase { LINEUP, RIDE, WIPEOUT, ENDED }

const SESSION_TIME: float = 90.0
const QUALIFY_SCORE: float = 250.0
const POINTS_PER_SEC: float = 10.0

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0
const HORIZON_Y: float = 120.0
const BOARD_LINE_Y: float = 840.0     # ligne de take-off (repère blanc à l'écran)

const BOARD_W: float = 60.0
const BOARD_H: float = 120.0
const BOARD_SPEED: float = 520.0
# Inertie de carve : la vitesse glisse vers la cible, la planche dérive quand
# on lâche (~0.37 s pour la pleine vitesse) — c'est ce qui distingue le surf.
const BOARD_ACCEL: float = 1400.0

# --- Vagues & séries ---
const WAVE_SPEED: float = 185.0        # ~3.9 s entre l'horizon et la ligne
const WAVE_INTERVAL: float = 2.6       # espacement des vagues dans une série
const FIRST_SET_DELAY: float = 2.0
const LULL_MIN: float = 4.5            # accalmie entre deux séries
const LULL_MAX: float = 7.0
const SET_MIN: int = 3
const SET_MAX: int = 5
const BOMBA_CHANCE: float = 0.3        # proba que la belle de la série soit une bomba

# 3 qualités de vague : la lecture consiste à laisser passer les marolas
# pour se placer sur la belle de la série.
const TIERS: Array[Dictionary] = [
	{"name": "Marola", "quality": 1.0, "height": 44.0, "ride_max": 4.0,
		"drift": 0.55, "peak_w": 280.0,
		"face": Color(0.55, 0.75, 0.88, 0.85), "crest": Color(0.88, 0.94, 0.98, 0.95)},
	{"name": "Ondulação", "quality": 2.0, "height": 76.0, "ride_max": 8.0,
		"drift": 0.85, "peak_w": 340.0,
		"face": Color(0.3, 0.6, 0.82, 0.92), "crest": Color(0.93, 0.97, 1.0, 1.0)},
	{"name": "Bomba", "quality": 4.0, "height": 118.0, "ride_max": 12.0,
		"drift": 1.25, "peak_w": 420.0,
		"face": Color(0.16, 0.45, 0.72, 0.95), "crest": Color(1.0, 1.0, 1.0, 1.0)},
]

# --- Fenêtres de take-off (distance du front à la ligne, en px ; <0 = au large) ---
const TAKEOFF_PERFECT: float = 45.0    # |d| <= 45 → parfait (~0.24 s)
const TAKEOFF_EARLY: float = 130.0     # d < -130 → trop tôt, la vague passe dessous
const TAKEOFF_LATE: float = 200.0      # 45 < d <= 200 → trop tard, wipeout
const SIGHT_RANGE: float = 420.0       # au-delà, ramer ne cible aucune vague
const SHOULDER_EXTRA: float = 200.0    # marge « épaule » autour du pic

const PERFECT_MULT: float = 1.5
const SHOULDER_QUALITY: float = 0.5    # prendre l'épaule = demi-qualité, ride écourtée
const SHOULDER_RIDE: float = 0.6

# --- Équilibre pendant la ride ---
const PLAYER_CORRECT: float = 2.2      # force de correction joystick (unités de balance/s)
const DRIFT_RAMP: float = 0.08         # la dérive se durcit avec la durée de ride
const DRIFT_RETARGET_MIN: float = 0.6
const DRIFT_RETARGET_MAX: float = 1.1
const KICKOUT_MIN_RIDE: float = 1.0    # évite le double-tap du bouton tactile
const KICKOUT_BONUS: float = 1.1       # sortir proprement = petit bonus de style
const WIPEOUT_BANK: float = 0.4        # chuter ne garde que 40 % des points de la ride
const WIPEOUT_STUN: float = 2.2

# --- Rendu (pixel natif ×3, peintures dans SurfArt.gd) ---
const ART = preload("res://scripts/minigames/surf/SurfArt.gd")
const VIS_SCALE: float = 2.4          # hauteur affichée = TIERS.height × 2,4 à la ligne
const BODY_RATIO: float = 0.45        # hors du pic, la vague est plus basse
const RIDER_H: float = 128.0          # 1 px natif du perso = 4 px monde
const KITE_JUMP_T: float = 1.3        # durée du saut visible au take-off kite

# Une vague vivante dans le line-up.
class Wave:
	var node: Node2D
	var body: Sprite2D
	var peak: Sprite2D
	var foam: Sprite2D
	var tag: Label
	var tier: int = 0
	var y: float = 0.0
	var peak_x: float = 0.0
	var peak_w: float = 0.0
	var missed: bool = false
	var highlight: bool = false

@onready var board: ColorRect = $Board
@onready var wave_layer: Node2D = $WaveLayer
@onready var score_label: Label = $UI/ScoreLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status
@onready var hint_label: Label = $UI/HintLabel
@onready var balance_bar: Control = $UI/BalanceBar
@onready var balance_cursor: ColorRect = $UI/BalanceBar/Cursor
@onready var ride_points_label: Label = $UI/BalanceBar/RidePoints

var _phase: Phase = Phase.LINEUP
var _time_left: float = SESSION_TIME
var _score: float = 0.0
var _total_ride_time: float = 0.0
var _wipeouts: int = 0
var _perfect_takeoffs: int = 0
var _waves_ridden: int = 0

var _board_vel: Vector2 = Vector2.ZERO
var _interact_cd: float = 0.0          # anti double-tap après changement de phase

var _waves: Array[Wave] = []
var _pending_set: Array[Dictionary] = []   # {tier, star} restant à faire déferler
var _set_timer: float = FIRST_SET_DELAY
var _wave_timer: float = 0.0

var _ride_wave: Wave = null
var _ride_time: float = 0.0
var _ride_max: float = 0.0
var _ride_quality: float = 0.0
var _takeoff_mult: float = 1.0
var _takeoff_x: float = 0.0
var _balance: float = 0.0
var _drift_target: float = 0.0
var _drift_timer: float = 0.0
var _stun_left: float = 0.0

var _interact_button: Button = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Identité EventBus de la session : "surf" par défaut, "kitesurf" quand la
# scène est réutilisée par KiteLauncher — les récompenses (ActivityRewards)
# et les objectifs MINIJEU des quêtes filtrent sur cet id.
@export var minigame_id: String = "surf"

# --- Mode kite (Barra) : même mer, autre geste. Pas de rame : l'aile tire.
# Stick ↑ borde l'aile (la puissance monte), relâché elle choque ; les rafales
# la secouent. On SAUTE sur le front de vague, aile dans la zone verte :
# trop molle = pas de décollage, trop bordée = l'aile t'arrache (wipeout).
# Plus l'aile tire (dans le vert), plus le saut paie.
const KITE_BAND_MIN: float = 0.62
const KITE_BAND_MAX: float = 0.9
const KITE_SHEET_RATE: float = 0.55   # montée/s stick ↑
const KITE_EASE_RATE: float = 0.35    # retombée/s relâché
const KITE_GUST: float = 0.22
var _kite: bool = false
var _kite_power: float = 0.4
var _kite_gust: float = 0.0
var _kite_gust_t: float = 0.0
var _kite_node: Sprite2D = null
var _kite_line: Line2D = null
var _kite_line2: Line2D = null
var _kite_gauge: TextureRect = null
var _kite_fill: ColorRect = null
var _kite_fill_in: ColorRect = null
var _kite_jump_h: float = 0.0

# Art du rider : posé en enfant de Board (le ColorRect logique est transparent).
var _art: Node2D = null
var _rider: Sprite2D = null
var _board_spr: Sprite2D = null
var _rider_scale: float = 1.0
var _facing: float = 1.0
var _ride_dir: float = 1.0
var _anim_t: float = 0.0
var _ride_foam_key: Vector3i = Vector3i.ZERO
var _last_phase: Phase = Phase.LINEUP
var _fx: Node2D = null
var _wake: Array[Vector3] = []          # x, y, âge
var _drops: Array[Dictionary] = []      # embruns {p, v, age, life, s}
var _streaks: Array[Vector3] = []       # kite : traits de vent x, y, longueur

func _ready() -> void:
	EventBus.minigame_started.emit(minigame_id)
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	_interact_button = get_node_or_null("TouchControls/InteractButton") as Button
	_kite = minigame_id == "kitesurf"
	if board:
		board.pivot_offset = Vector2(BOARD_W * 0.5, BOARD_H * 0.5)
		board.position = Vector2(ARENA_W * 0.5 - BOARD_W * 0.5, BOARD_LINE_Y - BOARD_H * 0.5)
	_build_scene_art()
	if balance_bar:
		balance_bar.visible = false
		_dress_balance_bar()
	_dress_labels()
	if _kite:
		_build_kite()
		_set_status("Vento nordeste — borde l'aile et saute sur les vagues", Color(1, 0.95, 0.8))
	else:
		_set_status("Lis la série — place-toi sur le pic clair", Color(1, 0.95, 0.8))
	if hint_label:
		hint_label.text = _lineup_hint()
	if _interact_button:
		_interact_button.text = _lineup_verb()
	_update_labels()

func _lineup_hint() -> String:
	if _kite:
		return "Stick ↑ : border l'aile · SALTA sur le front, aile dans le vert"
	return "RAME quand le front touche la ligne blanche"

func _lineup_verb() -> String:
	return "Salta !" if _kite else "Rame !"

func _build_kite() -> void:
	for i in 2:
		var ln: Line2D = Line2D.new()
		ln.width = 2.0
		ln.default_color = Color(0.96, 0.96, 0.92, 0.85)
		add_child(ln)
		if i == 0:
			_kite_line = ln
		else:
			_kite_line2 = ln
	_kite_node = ART.sprite(ART.kite_wing())
	add_child(_kite_node)
	# Jauge de puissance (à gauche) dans un cadre pixel du thème ; zone verte
	# = fenêtre de saut, rouge = l'aile arrache.
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var frame: Panel = Panel.new()
	frame.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	frame.position = Vector2(52, -214)
	frame.size = Vector2(76, 428)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(frame)
	var cap: Label = Label.new()
	cap.text = "Aile"
	cap.add_theme_font_size_override("font_size", 24)
	cap.position = Vector2(0, -46)
	cap.size = Vector2(76, 32)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(cap)
	frame.add_child(cap)
	_kite_gauge = TextureRect.new()
	_kite_gauge.texture = ART.kite_strip(KITE_BAND_MIN, KITE_BAND_MAX)
	_kite_gauge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_kite_gauge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kite_gauge.stretch_mode = TextureRect.STRETCH_SCALE
	_kite_gauge.position = Vector2(16, 14)
	_kite_gauge.size = Vector2(44, 400)
	_kite_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_kite_gauge)
	_kite_fill = ColorRect.new()
	_kite_fill.color = ART.OUTLINE
	_kite_fill.size = Vector2(56, 15)
	_kite_gauge.add_child(_kite_fill)
	_kite_fill_in = ColorRect.new()
	_kite_fill_in.position = Vector2(3, 3)
	_kite_fill_in.size = Vector2(50, 9)
	_kite_fill.add_child(_kite_fill_in)

func _update_kite(delta: float) -> void:
	_kite_gust_t -= delta
	if _kite_gust_t <= 0.0:
		_kite_gust_t = _rng.randf_range(1.2, 2.6)
		_kite_gust = _rng.randf_range(-KITE_GUST, KITE_GUST)
	var sheet: float = -Input.get_axis("move_forward", "move_back")
	if sheet > 0.2:
		_kite_power += KITE_SHEET_RATE * sheet * delta
	else:
		_kite_power -= KITE_EASE_RATE * delta
	_kite_power = clampf(_kite_power + _kite_gust * delta, 0.0, 1.0)
	if _kite_fill:
		_kite_fill.position = Vector2(-6, roundf(400.0 * (1.0 - _kite_power) - 7.0))
		var in_band: bool = _kite_power >= KITE_BAND_MIN and _kite_power <= KITE_BAND_MAX
		_kite_fill_in.color = Color(0.5, 1, 0.55, 1) if in_band else (Color(1, 0.4, 0.35, 1) if _kite_power > KITE_BAND_MAX else Color(1, 0.9, 0.35, 1))

# L'aile suit les mains du rider (saut compris) ; bordée, elle monte au zénith.
func _place_kite() -> void:
	if board == null or _kite_node == null or _art == null:
		return
	var hands: Vector2 = board.get_transform() * (_art.position + Vector2(_facing * 10.0, -66.0))
	var off: Vector2 = Vector2((180.0 - 120.0 * _kite_power) * _facing, -260.0 - 140.0 * _kite_power)
	var kite_pos: Vector2 = (hands + off).snapped(Vector2(3, 3))
	# Jamais sous la jauge d'équilibre (haut d'écran) ni dans le ciel du HUD.
	kite_pos.y = maxf(kite_pos.y, 330.0)
	_kite_node.position = kite_pos
	_kite_node.rotation = (0.25 - 0.4 * _kite_power) * _facing + sin(_anim_t * 2.3) * 0.04
	var tip: Vector2 = Vector2(66, 22).rotated(_kite_node.rotation)
	var tip2: Vector2 = Vector2(-66, 22).rotated(_kite_node.rotation)
	_kite_line.points = PackedVector2Array([hands, kite_pos + tip])
	_kite_line2.points = PackedVector2Array([hands, kite_pos + tip2])

func _process(delta: float) -> void:
	if _phase == Phase.ENDED:
		return
	_time_left -= delta
	_interact_cd = maxf(0.0, _interact_cd - delta)
	if _kite:
		_update_kite(delta)
	_move_waves(delta)
	match _phase:
		Phase.LINEUP:
			if _time_left <= 0.0:
				_end_session()
				return
			_process_sets(delta)
			_move_board(delta)
			if _interact_cd <= 0.0 and Input.is_action_just_pressed("interact"):
				_try_takeoff()
		Phase.RIDE:
			_process_ride(delta)
		Phase.WIPEOUT:
			if _time_left <= 0.0:
				_end_session()
				return
			_stun_left -= delta
			if board:
				board.modulate.a = 0.35 + 0.3 * sin(_stun_left * 18.0)
			if _stun_left <= 0.0:
				if board:
					board.modulate.a = 1.0
				_enter_lineup("De volta au line-up !")
	_update_art(delta)
	_update_labels()

# --- Line-up : positionnement horizontal avec inertie de carve ---

func _move_board(delta: float) -> void:
	if board == null:
		return
	var dir_x: float = Input.get_axis("move_left", "move_right")
	_board_vel = _board_vel.move_toward(Vector2(dir_x * BOARD_SPEED, 0.0), BOARD_ACCEL * delta)
	board.position.x = clampf(board.position.x + _board_vel.x * delta, 0.0, ARENA_W - BOARD_W)

# --- Séries : génération et déferlement ---

func _process_sets(delta: float) -> void:
	if _pending_set.size() > 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			var next: Dictionary = _pending_set.pop_front()
			_spawn_wave(int(next.tier), bool(next.star))
			_wave_timer = WAVE_INTERVAL
	else:
		_set_timer -= delta
		if _set_timer <= 0.0:
			_roll_set()
			_set_timer = _rng.randf_range(LULL_MIN, LULL_MAX)

func _roll_set() -> void:
	var size: int = _rng.randi_range(SET_MIN, SET_MAX)
	# La belle de la série n'est jamais la première : on laisse le temps de lire.
	var star_idx: int = _rng.randi_range(1, size - 1)
	var star_tier: int = 2 if _rng.randf() < BOMBA_CHANCE else 1
	_pending_set.clear()
	for i in size:
		if i == star_idx:
			_pending_set.append({"tier": star_tier, "star": true})
		else:
			_pending_set.append({"tier": 1 if _rng.randf() < 0.35 else 0, "star": false})
	_wave_timer = 0.0
	if star_tier == 2:
		_set_status("Série ! %d vagues — une BOMBA arrive…" % size, Color(1, 0.8, 0.4))
	else:
		_set_status("Série au large — %d vagues" % size, Color(0.85, 0.95, 1))

func _spawn_wave(tier: int, star: bool) -> void:
	var t: Dictionary = TIERS[tier]
	var w: Wave = Wave.new()
	w.tier = tier
	w.highlight = star
	w.y = HORIZON_Y
	w.peak_w = float(t.peak_w)
	w.peak_x = _rng.randf_range(w.peak_w * 0.5 + 80.0, ARENA_W - w.peak_w * 0.5 - 80.0)
	w.node = Node2D.new()
	w.node.position = Vector2(0.0, w.y)
	w.body = _wave_sprite()
	w.node.add_child(w.body)
	w.peak = _wave_sprite()
	w.node.add_child(w.peak)
	w.foam = _wave_sprite()
	w.foam.visible = false
	w.node.add_child(w.foam)
	w.tag = Label.new()
	w.tag.text = ("★ " + String(t.name)) if star else String(t.name)
	w.tag.add_theme_font_size_override("font_size", 24)
	w.tag.add_theme_color_override("font_color", Color(1, 0.88, 0.4) if star else Color(1, 1, 1, 0.92))
	_outline(w.tag)
	w.tag.position = Vector2(w.peak_x - 120.0, -44.0)
	w.tag.size = Vector2(240.0, 32.0)
	w.tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.node.add_child(w.tag)
	wave_layer.add_child(w.node)
	_update_wave_visual(w)
	_waves.append(w)

func _wave_sprite() -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.centered = false
	s.region_enabled = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.scale = Vector2(ART.D, ART.D)
	return s

# Pose une texture de vague ancrée par le pied (origine du nœud = pied).
func _set_wave_tex(s: Sprite2D, tex: Texture2D, x: float, w_native: int) -> void:
	s.texture = tex
	var th: int = tex.get_height()
	s.region_rect = Rect2(0, 0, w_native, th)
	s.position = Vector2(floorf(x / ART.D) * ART.D, -th * ART.D)
	s.visible = true

func _update_wave_visual(w: Wave) -> void:
	# La silhouette grossit en approchant : c'est la lecture de vague. Au
	# large une houle ronde, puis la crête fume, puis la lèvre déferle sur la
	# ligne ; passée la ligne, il ne reste qu'une barre de mousse vers le sable.
	var t: Dictionary = TIERS[w.tier]
	var full: float = float(t.height) * VIS_SCALE
	var base_y: float = w.y
	var h: float = full
	var stage: int = 2
	var broken: bool = false
	if w == _ride_wave:
		# Vague ridée : pleine hauteur, le rider calé à mi-face.
		base_y = BOARD_LINE_Y + full * 0.45
	else:
		var prog: float = clampf((w.y - HORIZON_Y) / (BOARD_LINE_Y - HORIZON_Y), 0.0, 1.0)
		h = full * lerpf(0.12, 1.0, pow(prog, 1.15))
		w.tag.visible = prog > 0.12
		stage = 0 if prog < 0.55 else (1 if prog < 0.88 else 2)
		var past: float = w.y - BOARD_LINE_Y - 40.0
		if past > 0.0:
			broken = true
			h = full * 0.5 * clampf(1.0 - past / (ART.SHORE_Y - BOARD_LINE_Y - 40.0), 0.0, 1.0)
	w.node.position = Vector2(0.0, floorf(base_y / ART.D) * ART.D)
	# Vague perdue : teinte éteinte opaque (l'alpha ferait voir le pic à travers le corps).
	if w.missed:
		w.node.modulate = Color(0.66, 0.76, 0.88, 1.0)
	var hn: int = maxi(1, int(round(h / ART.D)))
	var hb: int = maxi(1, int(round(float(hn) * BODY_RATIO)))
	var span: int = int(ART.BG_RECT.size.x) / ART.D
	var pw: int = int(round(w.peak_w / ART.D))
	if broken:
		w.peak.visible = false
		w.foam.visible = false
		w.tag.visible = false
		if h < 4.0:
			w.body.visible = false
		else:
			_set_wave_tex(w.body, ART.whitewater(hb), ART.BG_RECT.position.x, span)
		return
	_set_wave_tex(w.body, ART.wave_body(w.tier, hb, mini(stage, 1)), ART.BG_RECT.position.x, span)
	# Vague ridée : le pic fume seulement, la mousse qui déroule fait le reste.
	var pstage: int = 1 if w == _ride_wave else stage
	_set_wave_tex(w.peak, ART.wave_peak(w.tier, hn, hb, pw, pstage), w.peak_x - pw * ART.D, pw * 2)
	w.tag.position = Vector2(w.peak_x - 120.0, -(hn + ART.SPRAY_ROOM) * ART.D - 34.0)
	if w == _ride_wave:
		# La vague déroule derrière le rider et finit par fermer sur lui.
		var frac: float = clampf(_ride_time / maxf(_ride_max, 0.1), 0.0, 1.0)
		var rx: float = board.position.x + BOARD_W * 0.5 if board else w.peak_x
		var start: float = w.peak_x - _ride_dir * w.peak_w
		var front: float = lerpf(w.peak_x + _ride_dir * 30.0, rx + _ride_dir * 90.0, pow(frac, 1.2))
		var x0: float = floorf(minf(start, front) / 18.0) * 18.0
		var wn: int = maxi(8, int((maxf(start, front) - x0) / ART.D) / 6 * 6)
		var off: int = int(round((x0 - w.peak_x) / ART.D))
		var key: Vector3i = Vector3i(hn, off, wn)
		if key != _ride_foam_key:
			_ride_foam_key = key
			_set_wave_tex(w.foam, ART.ride_foam(hn, hb, pw, off, wn), x0, wn)
	else:
		w.foam.visible = false

func _move_waves(delta: float) -> void:
	var gone: Array[Wave] = []
	for w in _waves:
		w.y += WAVE_SPEED * delta
		w.node.position.y = w.y
		_update_wave_visual(w)
		var d: float = w.y - BOARD_LINE_Y
		if d > TAKEOFF_LATE and not w.missed:
			w.missed = true
			w.node.modulate.a = 0.45
			if w.highlight and _phase == Phase.LINEUP:
				_set_status("La belle est passée… attends la prochaine série", Color(1, 0.7, 0.6))
		if w.y > ARENA_H + 80.0:
			gone.append(w)
	for w in gone:
		w.node.queue_free()
		_waves.erase(w)

# --- Take-off : fenêtre de timing + placement sur le pic ---

func _try_takeoff() -> void:
	var best: Wave = null
	var best_d: float = INF
	for w in _waves:
		if w.missed:
			continue
		var d: float = w.y - BOARD_LINE_Y
		if d < -SIGHT_RANGE or d > TAKEOFF_LATE:
			continue
		if absf(d) < absf(best_d):
			best = w
			best_d = d
	if best == null:
		_set_status("Rien à ramer pour l'instant…", Color(0.8, 0.85, 0.9))
		return
	if best_d < -TAKEOFF_EARLY:
		# Trop tôt : la vague passe dessous, elle est perdue.
		best.missed = true
		best.node.modulate.a = 0.45
		_set_status("Trop tôt — elle passe dessous !", Color(1, 0.7, 0.5))
		return
	if best_d > TAKEOFF_PERFECT:
		# Trop tard : la lèvre te croque.
		_start_wipeout("Trop tard — la lèvre te croque !")
		return
	# Placement : pic plein, épaule, ou trop loin.
	var board_cx: float = board.position.x + BOARD_W * 0.5
	var dx: float = absf(board_cx - best.peak_x)
	var shoulder: bool = false
	if dx > best.peak_w * 0.5 + SHOULDER_EXTRA:
		_set_status("Trop loin du pic !", Color(1, 0.8, 0.6))
		return
	if dx > best.peak_w * 0.5:
		shoulder = true
	var perfect: bool = absf(best_d) <= TAKEOFF_PERFECT
	if _kite:
		if _kite_power < KITE_BAND_MIN:
			best.missed = true
			best.node.modulate.a = 0.45
			_set_status("Aile molle — pas de décollage. Borde !", Color(1, 0.8, 0.6))
			sfx("mg_miss")
			return
		if _kite_power > KITE_BAND_MAX:
			_start_wipeout("Rafale ! L'aile t'arrache de la planche")
			return
	_start_ride(best, perfect, shoulder)

func _start_ride(w: Wave, perfect: bool, shoulder: bool) -> void:
	var t: Dictionary = TIERS[w.tier]
	_phase = Phase.RIDE
	_interact_cd = 0.4
	_ride_wave = w
	_waves.erase(w)
	_ride_time = 0.0
	_ride_quality = float(t.quality) * (SHOULDER_QUALITY if shoulder else 1.0)
	_ride_max = float(t.ride_max) * (SHOULDER_RIDE if shoulder else 1.0)
	_takeoff_mult = PERFECT_MULT if perfect else 1.0
	if _kite:
		# Un saut bien bordé (haut de la zone verte) paie jusqu'à ×1,6 en plus.
		_takeoff_mult *= 1.0 + 2.0 * (_kite_power - KITE_BAND_MIN)
	_takeoff_x = board.position.x
	_ride_foam_key = Vector3i.ZERO
	_ride_dir = 1.0 if board.position.x + BOARD_W * 0.5 >= w.peak_x else -1.0
	_kite_jump_h = 90.0 + 300.0 * (_kite_power - KITE_BAND_MIN)
	_balance = 0.0
	_drift_target = 0.0
	_drift_timer = 0.0
	# La vague ridée se cale sous la planche, pleine hauteur.
	w.y = BOARD_LINE_Y + 6.0
	w.node.position.y = w.y
	w.tag.visible = false
	_update_wave_visual(w)
	sfx("splash")
	if perfect:
		sfx("mg_perfect")
		pulse(0.45, 0.08)
		_perfect_takeoffs += 1
		_set_status(("SALTO PERFEITO ! ×%.1f" if _kite else "TAKE-OFF PARFAIT ! ×%.1f") % _takeoff_mult, Color(1, 0.95, 0.4))
		if board:
			board.modulate = Color(1.6, 1.6, 1.4)
			var tw: Tween = create_tween()
			tw.tween_property(board, "modulate", Color.WHITE, 0.5)
	elif shoulder:
		_set_status("Sur l'épaule… ride écourtée", Color(0.9, 0.85, 0.7))
	else:
		_set_status("No ar ! Tiens la réception" if _kite else "Debout ! Tiens l'équilibre", Color(0.8, 1, 0.8))
	if hint_label:
		hint_label.text = "Joystick ←→ pour recentrer le curseur"
	if balance_bar:
		balance_bar.visible = true
	if _interact_button:
		_interact_button.text = "Sortir"

# --- Ride : curseur d'équilibre qui dérive, à recentrer ---

func _process_ride(delta: float) -> void:
	_ride_time += delta
	_drift_timer -= delta
	if _drift_timer <= 0.0:
		_drift_target = _rng.randf_range(-1.0, 1.0)
		_drift_timer = _rng.randf_range(DRIFT_RETARGET_MIN, DRIFT_RETARGET_MAX)
	var t: Dictionary = TIERS[_ride_wave.tier]
	var drift_force: float = _drift_target * float(t.drift) * (1.0 + _ride_time * DRIFT_RAMP)
	var input_x: float = Input.get_axis("move_left", "move_right")
	_balance = clampf(_balance + (drift_force + input_x * PLAYER_CORRECT) * delta, -1.05, 1.05)
	# Visuel : la planche s'incline et glisse avec le déséquilibre.
	if board:
		board.rotation = _balance * 0.5
		board.position.x = clampf(_takeoff_x + _balance * 140.0, 0.0, ARENA_W - BOARD_W)
	if balance_cursor:
		var half: float = balance_bar.size.x * 0.5 - 20.0
		balance_cursor.position.x = balance_bar.size.x * 0.5 - balance_cursor.size.x * 0.5 + _balance * half
		balance_cursor.modulate = Color(1, 1, 1).lerp(Color(1, 0.45, 0.4), absf(_balance))
	if ride_points_label:
		ride_points_label.text = "+%d" % int(_ride_points())
	if absf(_balance) >= 1.0:
		_end_ride(WIPEOUT_BANK, true, "Wipeout ! Tu gardes une partie des points")
		return
	if _ride_time >= _ride_max:
		_end_ride(1.0, false, "La vague ferme — bien tenu !")
		return
	if _interact_cd <= 0.0 and _ride_time >= KICKOUT_MIN_RIDE \
			and Input.is_action_just_pressed("interact"):
		_end_ride(KICKOUT_BONUS, false, "Saída limpa ! Bonus de style")

func _ride_points() -> float:
	return _ride_quality * _takeoff_mult * _ride_time * POINTS_PER_SEC

func _end_ride(bank_mult: float, wipeout: bool, msg: String) -> void:
	var pts: float = _ride_points() * bank_mult
	_score += pts
	_total_ride_time += _ride_time
	_waves_ridden += 1
	if _ride_wave:
		_ride_wave.node.queue_free()
		_ride_wave = null
	if balance_bar:
		balance_bar.visible = false
	if board:
		board.rotation = 0.0
	_set_status("%s  (+%d pts)" % [msg, int(pts)],
		Color(1, 0.7, 0.6) if wipeout else Color(0.7, 1, 0.7))
	if wipeout:
		sfx("splash", 0.8)
		pulse(0.7, 0.2)
	else:
		sfx("mg_good")
	if _time_left <= 0.0:
		_end_session()
		return
	if wipeout:
		_wipeouts += 1
		_phase = Phase.WIPEOUT
		_stun_left = WIPEOUT_STUN
	else:
		_enter_lineup("")
	_interact_cd = 0.4

func _start_wipeout(msg: String) -> void:
	_wipeouts += 1
	_phase = Phase.WIPEOUT
	_stun_left = WIPEOUT_STUN
	_interact_cd = 0.4
	sfx("splash", 0.8)
	pulse(0.7, 0.2)
	_set_status(msg, Color(1, 0.6, 0.5))

func _enter_lineup(msg: String) -> void:
	_phase = Phase.LINEUP
	_interact_cd = 0.4
	if msg != "":
		_set_status(msg, Color(0.85, 0.95, 1))
	if hint_label:
		hint_label.text = _lineup_hint()
	if _interact_button:
		_interact_button.text = _lineup_verb()

# --- Habillage : décor, rider, effets ---

func _build_scene_art() -> void:
	var bg: Sprite2D = ART.sprite(ART.backdrop(_kite), false)
	bg.position = ART.BG_RECT.position
	add_child(bg)
	move_child(bg, 0)
	if wave_layer:
		# Les vagues proches passent devant les lointaines.
		wave_layer.y_sort_enabled = true
	var after: int = wave_layer.get_index() + 1 if wave_layer else get_child_count()
	if not _kite:
		var rock: Sprite2D = ART.sprite(ART.arpoador_rock(), false)
		rock.position = ART.ROCK_ORIGIN
		add_child(rock)
		move_child(rock, after)
		after += 1
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	move_child(_fx, after)
	if board == null:
		return
	_art = Node2D.new()
	_art.position = Vector2(BOARD_W * 0.5, BOARD_H * 0.5)
	board.add_child(_art)
	var col: Color = ART.BOARD_COLORS[1] if _kite else ART.BOARD_COLORS[0]
	_board_spr = ART.sprite(ART.board_back(col))
	_art.add_child(_board_spr)
	_rider = char_sprite(RIDER_H)
	_rider_scale = _rider.scale.x
	_art.add_child(_rider)
	if _kite:
		for i in 14:
			_streaks.append(Vector3(_rng.randf_range(-300, 2250), _rng.randf_range(-100, 1000), _rng.randf_range(40, 140)))
	_pose(true)

func _dress_balance_bar() -> void:
	var frame: Panel = Panel.new()
	frame.position = Vector2(-16, -16)
	frame.size = Vector2(672, 92)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_bar.add_child(frame)
	balance_bar.move_child(frame, 0)
	var strip: TextureRect = TextureRect.new()
	strip.texture = ART.balance_strip()
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.size = Vector2(640, 60)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_bar.add_child(strip)
	balance_bar.move_child(strip, 1)
	if balance_cursor:
		var icon: TextureRect = TextureRect.new()
		icon.texture = ART.cursor_board()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = balance_cursor.size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		balance_cursor.add_child(icon)
	if ride_points_label:
		ride_points_label.position.y = -64.0
		_outline(ride_points_label)

func _outline(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.12, 0.22, 1))

func _dress_labels() -> void:
	for l in [score_label, timer_label, status_label, hint_label]:
		if l:
			_outline(l)

# Rangée de la planche de perso (DIR_DOWN 0 / UP 1 / RIGHT 2), colonne
# idle/stepL/stepR ; `rows` coupe le bas (assis : jusqu'à la taille).
func _rider_cell(dir: int, frame: int, rows: int = 96) -> void:
	_rider.region_rect = Rect2(frame * 64, dir * 96, 64, rows)
	_rider.offset = Vector2(0, -rows * 0.5)

# Pose du rider selon la phase : assis de dos au line-up (surf), debout de
# profil en ride et au kite, la tête hors de l'eau après une chute.
func _pose(lineup: bool) -> void:
	if _rider == null:
		return
	_rider.rotation = 0.0
	_rider.scale = Vector2(_rider_scale, _rider_scale)
	_board_spr.rotation = 0.0
	_board_spr.position = Vector2.ZERO
	var col: Color = ART.BOARD_COLORS[1] if _kite else ART.BOARD_COLORS[0]
	if lineup and not _kite:
		# Assis à califourchon, les jambes dans l'eau.
		_rider_cell(2, 0, 69)
		_rider.position = Vector2(-6, 4)
		_rider.flip_h = _facing < 0.0
		_board_spr.texture = ART.board_side(col)
		_board_spr.flip_h = _rider.flip_h
		_board_spr.position = Vector2(0, 6)
	else:
		_rider_cell(2, 1)
		_rider.position = Vector2(0, 2)
		_board_spr.texture = ART.board_side(col, _kite)
		_board_spr.position = Vector2(0, 3)

func _update_art(delta: float) -> void:
	if _art == null:
		return
	_anim_t += delta
	if _phase != _last_phase:
		_on_phase_art(_last_phase, _phase)
		_last_phase = _phase
	var feet: Vector2 = board.position + _art.position
	match _phase:
		Phase.LINEUP:
			if absf(_board_vel.x) > 40.0:
				_facing = signf(_board_vel.x)
			# La planche monte sur chaque houle qui passe dessous.
			var lift: float = 0.0
			for w in _waves:
				var d: float = absf(w.y - BOARD_LINE_Y)
				if d < 90.0:
					var h: float = float(TIERS[w.tier].height) * VIS_SCALE * BODY_RATIO
					lift = maxf(lift, h * 0.35 * (1.0 - d / 90.0))
			var bob: float = sin(_anim_t * 2.2) * 3.0
			_art.position = Vector2(BOARD_W * 0.5, roundf(BOARD_H * 0.5 - lift + bob))
			if _kite:
				_rider.flip_h = _facing < 0.0
				_board_spr.flip_h = _rider.flip_h
				_rider.rotation = -0.12 * _facing
				if absf(_board_vel.x) > 60.0:
					_wake_at(feet + Vector2(-_facing * 50.0, 6.0))
					if _rng.randf() < 0.4:
						_drop(feet + Vector2(-_facing * 50.0, 0), Vector2(-_facing * _rng.randf_range(40, 140), -_rng.randf_range(80, 200)), 0.5)
			else:
				# Il rame : les bras alternent tant qu'il se déplace.
				var paddling: bool = absf(_board_vel.x) > 40.0
				_rider_cell(2, (1 + int(_anim_t * 5.0) % 2) if paddling else 0, 69)
				_rider.flip_h = _facing < 0.0
				_board_spr.flip_h = _rider.flip_h
				_rider.position.x = -6.0 * _facing
				if paddling and _rng.randf() < 0.5:
					_wake_at(feet + Vector2(_rng.randf_range(-24, 24), 30.0))
		Phase.RIDE:
			_rider.flip_h = _ride_dir < 0.0
			_board_spr.flip_h = _rider.flip_h
			var y: float = BOARD_H * 0.5
			if _kite and _ride_time < KITE_JUMP_T:
				# Le saut : parabole, l'aile tient le rider en l'air.
				var u: float = _ride_time / KITE_JUMP_T
				y -= _kite_jump_h * 4.0 * u * (1.0 - u)
				_rider.rotation = sin(u * PI) * 0.25 * _ride_dir
				_board_spr.rotation = sin(u * PI) * -0.3 * _ride_dir
			else:
				_rider.rotation = 0.0
				_board_spr.rotation = 0.0
				# Take-off : il se relève de la planche, puis fléchit sur la face.
				var up: float = clampf(_ride_time / 0.3, 0.0, 1.0) if not _kite else 1.0
				var crouch: float = lerpf(0.62, 0.94 + 0.04 * sin(_anim_t * 7.0), up)
				_rider.scale = Vector2(_rider_scale, _rider_scale * crouch)
				y += sin(_anim_t * 3.1) * 2.0
				_wake_at(feet + Vector2(-_ride_dir * 60.0, 8.0))
				if _rng.randf() < 0.7:
					_drop(feet + Vector2(-_ride_dir * 56.0, 4.0), Vector2(-_ride_dir * _rng.randf_range(80, 220), -_rng.randf_range(160, 320)), 0.6)
			_art.position = Vector2(BOARD_W * 0.5, roundf(y))
			if _ride_wave:
				_update_wave_visual(_ride_wave)
		Phase.WIPEOUT:
			_art.position = Vector2(BOARD_W * 0.5, roundf(BOARD_H * 0.5 + 18.0 + sin(_anim_t * 4.0) * 3.0))
			_board_spr.rotation += delta * 4.0 * _facing
	if _kite:
		_place_kite()
	_tick_fx(delta)

func _on_phase_art(from: Phase, to: Phase) -> void:
	var feet: Vector2 = board.position + Vector2(BOARD_W * 0.5, BOARD_H * 0.5)
	match to:
		Phase.LINEUP:
			_pose(true)
		Phase.RIDE:
			_facing = _ride_dir
			_pose(false)
			_splash(feet, 14, 260.0)
		Phase.WIPEOUT:
			_pose(false)
			# La tête hors de l'eau, la planche qui tournoie à côté.
			_rider_cell(0, 0, 45)
			_rider.flip_h = false
			_board_spr.position = Vector2(_facing * 70.0, -20.0)
			_board_spr.rotation = 0.6
			_splash(feet, 26, 380.0)

# --- Effets : sillage, embruns, vent ---

func _wake_at(p: Vector2) -> void:
	_wake.append(Vector3(p.x + _rng.randf_range(-6, 6), p.y + _rng.randf_range(-3, 3), 0.0))

func _drop(p: Vector2, v: Vector2, life: float) -> void:
	if _drops.size() > 160:
		return
	_drops.append({"p": p, "v": v, "age": 0.0, "life": life, "s": 3.0 if _rng.randf() < 0.6 else 6.0})

func _splash(p: Vector2, n: int, power: float) -> void:
	for i in n:
		var a: float = _rng.randf_range(PI * 1.1, PI * 1.9)
		_drop(p, Vector2(cos(a), sin(a)) * _rng.randf_range(power * 0.4, power), _rng.randf_range(0.5, 0.9))

func _tick_fx(delta: float) -> void:
	var i: int = _wake.size() - 1
	while i >= 0:
		var w: Vector3 = _wake[i]
		w.z += delta
		if w.z > 0.9:
			_wake.remove_at(i)
		else:
			_wake[i] = w
		i -= 1
	i = _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i]
		d.age = float(d.age) + delta
		if float(d.age) > float(d.life):
			_drops.remove_at(i)
		else:
			d.v = Vector2(d.v) + Vector2(0, 800.0 * delta)
			d.p = Vector2(d.p) + Vector2(d.v) * delta
		i -= 1
	for k in _streaks.size():
		var s: Vector3 = _streaks[k]
		s.x -= 900.0 * delta
		if s.x + s.z < -330.0:
			s = Vector3(2250.0 + _rng.randf_range(0, 400), _rng.randf_range(-100, 1000), _rng.randf_range(40, 140))
		_streaks[k] = s
	if _fx:
		_fx.queue_redraw()

func _draw_fx() -> void:
	# Ligne de take-off : pointillé d'écume (le repère « ligne blanche »).
	var x: float = ART.BG_RECT.position.x
	while x < ART.BG_RECT.end.x:
		_fx.draw_rect(Rect2(x, BOARD_LINE_Y - 3.0, 18.0, 3.0), Color(1, 1, 1, 0.55))
		x += 36.0
	for w in _wake:
		var a: float = 1.0 - w.z / 0.9
		var sz: float = 6.0 if w.z < 0.3 else 3.0
		_fx.draw_rect(Rect2(Vector2(w.x, w.y).snapped(Vector2(3, 3)), Vector2(sz, sz * 0.5 + 1.5)), Color(1, 1, 1, 0.85 * a))
	for d in _drops:
		var a2: float = 1.0 - float(d.age) / float(d.life)
		var s: float = float(d.s)
		_fx.draw_rect(Rect2(Vector2(d.p).snapped(Vector2(3, 3)), Vector2(s, s)), Color(0.96, 0.99, 1.0, 0.95 * a2))
	for s2 in _streaks:
		_fx.draw_rect(Rect2(Vector2(s2.x, s2.y).snapped(Vector2(3, 3)), Vector2(s2.z, 3.0)), Color(1, 1, 1, 0.28))

# --- UI & fin de session ---

func _set_status(text: String, color: Color) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	status_label.modulate = Color(1.5, 1.5, 1.5)
	var tw: Tween = create_tween()
	tw.tween_property(status_label, "modulate", Color.WHITE, 0.4)

func _update_labels() -> void:
	if score_label:
		score_label.text = "%d pts" % int(_score)
		score_label.add_theme_color_override("font_color",
			Color(0.5, 1, 0.6) if _score >= QUALIFY_SCORE else Color(1, 1, 1))
	if timer_label:
		timer_label.text = "%.0fs" % maxf(_time_left, 0.0)

func quit_game() -> void:
	_end_session()

func _end_session() -> void:
	if _phase == Phase.ENDED:
		return
	_phase = Phase.ENDED
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if balance_bar:
		balance_bar.visible = false
	if qualifies:
		_set_status("Session validée — %d pts ! %s" % [int(_score), "Lucas approuve" if minigame_id == "surf" else "A Barra te salue"], Color(0.6, 1, 0.6))
	else:
		_set_status("Fin de session — %d pts (il en faut %d)" % [int(_score), int(QUALIFY_SCORE)],
			Color(1, 0.85, 0.7))
	if hint_label:
		hint_label.text = "%d vagues, %d take-off parfaits, %d wipeouts" \
			% [_waves_ridden, _perfect_takeoffs, _wipeouts]
	await get_tree().create_timer(2.2).timeout
	# Clés historiques conservées (ActivityRewards lit `qualifies`) ; `lives`
	# est gardée pour compat, dérivée des wipeouts.
	EventBus.minigame_ended.emit(minigame_id, {
		"time_survived": _total_ride_time,
		"lives": maxi(0, 3 - _wipeouts),
		"qualifies": qualifies,
		"won": qualifies,
		"score": int(_score),
		"waves_ridden": _waves_ridden,
		"perfect_takeoffs": _perfect_takeoffs,
	})
	match_ended.emit(qualifies, _total_ride_time)
