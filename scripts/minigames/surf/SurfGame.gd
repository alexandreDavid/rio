class_name SurfGame
extends Node2D

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

# Une vague vivante dans le line-up.
class Wave:
	var node: Node2D
	var face: ColorRect
	var crest: ColorRect
	var peak_rect: ColorRect
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

func _ready() -> void:
	EventBus.minigame_started.emit("surf")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	_interact_button = get_node_or_null("TouchControls/InteractButton") as Button
	if board:
		board.pivot_offset = Vector2(BOARD_W * 0.5, BOARD_H * 0.5)
		board.position = Vector2(ARENA_W * 0.5 - BOARD_W * 0.5, BOARD_LINE_Y - BOARD_H * 0.5)
	if balance_bar:
		balance_bar.visible = false
	_set_status("Lis la série — place-toi sur le pic clair", Color(1, 0.95, 0.8))
	if hint_label:
		hint_label.text = "RAME quand le front touche la ligne blanche"
	_update_labels()

func _process(delta: float) -> void:
	if _phase == Phase.ENDED:
		return
	_time_left -= delta
	_interact_cd = maxf(0.0, _interact_cd - delta)
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
	w.face = ColorRect.new()
	w.face.color = t.face
	w.node.add_child(w.face)
	w.crest = ColorRect.new()
	w.crest.color = t.crest
	w.node.add_child(w.crest)
	w.peak_rect = ColorRect.new()
	w.peak_rect.color = Color(1, 1, 0.85, 1)
	w.node.add_child(w.peak_rect)
	w.tag = Label.new()
	w.tag.text = ("★ " + String(t.name)) if star else String(t.name)
	w.tag.add_theme_font_size_override("font_size", 24)
	w.tag.add_theme_color_override("font_color", Color(1, 0.9, 0.5) if star else Color(1, 1, 1, 0.8))
	w.tag.position = Vector2(w.peak_x - 120.0, -44.0)
	w.tag.size = Vector2(240.0, 32.0)
	w.tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.node.add_child(w.tag)
	wave_layer.add_child(w.node)
	_update_wave_visual(w)
	_waves.append(w)

func _update_wave_visual(w: Wave) -> void:
	# La silhouette grossit en approchant : c'est la lecture de vague.
	var t: Dictionary = TIERS[w.tier]
	var prog: float = clampf((w.y - HORIZON_Y) / (BOARD_LINE_Y - HORIZON_Y), 0.0, 1.0)
	var h: float = float(t.height) * lerpf(0.35, 1.0, prog)
	var crest_h: float = maxf(8.0, h * 0.22)
	w.crest.position = Vector2(0.0, 0.0)
	w.crest.size = Vector2(ARENA_W, crest_h)
	w.face.position = Vector2(0.0, crest_h)
	w.face.size = Vector2(ARENA_W, h)
	w.peak_rect.position = Vector2(w.peak_x - w.peak_w * 0.5, -4.0)
	w.peak_rect.size = Vector2(w.peak_w, crest_h + 4.0)

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
	_takeoff_x = board.position.x
	_balance = 0.0
	_drift_target = 0.0
	_drift_timer = 0.0
	# La vague ridée se cale sous la planche, pleine hauteur.
	w.y = BOARD_LINE_Y + 6.0
	w.node.position.y = w.y
	w.tag.visible = false
	_update_wave_visual(w)
	if perfect:
		_perfect_takeoffs += 1
		_set_status("TAKE-OFF PARFAIT ! ×%.1f" % PERFECT_MULT, Color(1, 0.95, 0.4))
		if board:
			board.modulate = Color(1.6, 1.6, 1.4)
			var tw: Tween = create_tween()
			tw.tween_property(board, "modulate", Color.WHITE, 0.5)
	elif shoulder:
		_set_status("Sur l'épaule… ride écourtée", Color(0.9, 0.85, 0.7))
	else:
		_set_status("Debout ! Tiens l'équilibre", Color(0.8, 1, 0.8))
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
		balance_cursor.color = Color(0.4, 1, 0.5).lerp(Color(1, 0.3, 0.25), absf(_balance))
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
	_set_status(msg, Color(1, 0.6, 0.5))

func _enter_lineup(msg: String) -> void:
	_phase = Phase.LINEUP
	_interact_cd = 0.4
	if msg != "":
		_set_status(msg, Color(0.85, 0.95, 1))
	if hint_label:
		hint_label.text = "RAME quand le front touche la ligne blanche"
	if _interact_button:
		_interact_button.text = "Rame !"

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

func _end_session() -> void:
	if _phase == Phase.ENDED:
		return
	_phase = Phase.ENDED
	var qualifies: bool = _score >= QUALIFY_SCORE
	if balance_bar:
		balance_bar.visible = false
	if qualifies:
		_set_status("Session validée — %d pts ! Lucas approuve" % int(_score), Color(0.6, 1, 0.6))
	else:
		_set_status("Fin de session — %d pts (il en faut %d)" % [int(_score), int(QUALIFY_SCORE)],
			Color(1, 0.85, 0.7))
	if hint_label:
		hint_label.text = "%d vagues, %d take-off parfaits, %d wipeouts" \
			% [_waves_ridden, _perfect_takeoffs, _wipeouts]
	await get_tree().create_timer(2.2).timeout
	# Clés historiques conservées (ActivityRewards lit `qualifies`) ; `lives`
	# est gardée pour compat, dérivée des wipeouts.
	EventBus.minigame_ended.emit("surf", {
		"time_survived": _total_ride_time,
		"lives": maxi(0, 3 - _wipeouts),
		"qualifies": qualifies,
		"won": qualifies,
		"score": int(_score),
		"waves_ridden": _waves_ridden,
		"perfect_takeoffs": _perfect_takeoffs,
	})
	match_ended.emit(qualifies, _total_ride_time)
