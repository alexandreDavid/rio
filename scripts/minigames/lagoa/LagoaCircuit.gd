class_name LagoaCircuit
extends Node2D

# Mini-jeu de circuit vélo autour de la Lagoa Rodrigo de Freitas. Vue top-down,
# 4 checkpoints (N, E, S, O) à toucher dans l'ordre clockwise. Timer 60 s.
# Plus tu finis vite, plus le tip est élevé.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 60.0
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const BIKE_RADIUS: float = 14.0
const BIKE_SPEED: float = 320.0
const CHECKPOINT_RADIUS: float = 60.0

# Checkpoints autour du lac (centre 960,540), ordre clockwise.
const CHECKPOINTS: Array = [
	Vector2(960, 200),    # 1 — Nord (départ)
	Vector2(1500, 540),   # 2 — Est
	Vector2(960, 880),    # 3 — Sud
	Vector2(420, 540),    # 4 — Ouest
	Vector2(960, 200),    # 5 — Retour Nord (boucle bouclée)
]

const TIP_BASE: int = 40
const TIP_BONUS_MAX: int = 130  # max si finition < 20 s
const TIP_FAST_TIME: float = 20.0  # bonus max si fini en moins de ce temps
const TIP_SLOW_TIME: float = 55.0  # bonus 0 si fini après ce temps

var _time_left: float = DURATION
var _ended: bool = false
var _bike_pos: Vector2 = CHECKPOINTS[0]
var _next_cp: int = 1  # index du prochain checkpoint à atteindre
var _laps_completed: int = 0
var _completion_time: float = -1.0  # temps écoulé à la finition (s)

@onready var arena: Node2D = $Arena
@onready var bike_node: ColorRect = $Arena/Bike
@onready var cp_markers: Node2D = $Arena/Checkpoints
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var progress_label: Label = $UI/Progress
@onready var prompt_label: Label = $UI/Prompt

func _ready() -> void:
	EventBus.minigame_started.emit("lagoa_circuit")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_render_checkpoints()
	if status_label:
		status_label.text = "Boucle clockwise : Nord → Est → Sud → Ouest → Nord."
	if prompt_label:
		prompt_label.text = "[WASD / Flèches] pédaler"

func _render_checkpoints() -> void:
	if cp_markers == null:
		return
	# Reset les enfants
	for child in cp_markers.get_children():
		child.queue_free()
	# 4 checkpoints visibles (N, E, S, O — pas le doublon CP1 final).
	for i in range(4):
		var cp: Vector2 = CHECKPOINTS[i]
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(48, 48)
		dot.position = cp - Vector2(24, 24)
		dot.color = Color(0.55, 0.95, 0.55, 0.55)
		cp_markers.add_child(dot)
		var label: Label = Label.new()
		label.text = str(i + 1)
		label.position = cp - Vector2(8, 36)
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		cp_markers.add_child(label)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game(false)
		return
	_update_bike(delta)
	_check_checkpoint()
	_update_visuals()
	_update_labels()

func _update_bike(delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	_bike_pos += dir * BIKE_SPEED * delta
	_bike_pos.x = clamp(_bike_pos.x, BIKE_RADIUS, ARENA_W - BIKE_RADIUS)
	_bike_pos.y = clamp(_bike_pos.y, BIKE_RADIUS, ARENA_H - BIKE_RADIUS)
	if bike_node:
		bike_node.position = _bike_pos - Vector2(BIKE_RADIUS, BIKE_RADIUS)

func _check_checkpoint() -> void:
	if _next_cp >= CHECKPOINTS.size():
		return
	var target: Vector2 = CHECKPOINTS[_next_cp]
	if _bike_pos.distance_to(target) <= CHECKPOINT_RADIUS:
		_next_cp += 1
		if _next_cp >= CHECKPOINTS.size():
			# Tour terminé
			_laps_completed = 1
			_completion_time = DURATION - _time_left
			_end_game(true)
		else:
			if status_label:
				status_label.text = "Checkpoint %d/4 ✓" % (_next_cp - 1 + 1)

func _update_visuals() -> void:
	if cp_markers == null:
		return
	# Met en évidence le checkpoint courant (si pas le 5ème = retour Nord).
	var current_idx: int = _next_cp if _next_cp < 4 else 0
	var i: int = 0
	for child in cp_markers.get_children():
		if not (child is ColorRect):
			continue
		var rect: ColorRect = child
		if i == current_idx:
			# Pulse pour le prochain.
			var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
			rect.color = Color(0.95, 0.85, 0.4, pulse)
		elif i < current_idx or _next_cp >= 4:
			# Déjà passé, plus pâle (sauf si on revient au Nord, alors le N redevient cible).
			if _next_cp >= 4 and i == 0:
				var pulse2: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
				rect.color = Color(0.95, 0.4, 0.55, pulse2)
			else:
				rect.color = Color(0.4, 0.6, 0.4, 0.35)
		else:
			rect.color = Color(0.55, 0.95, 0.55, 0.4)
		i += 1

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if progress_label:
		var done: int = clamp(_next_cp, 0, 4)
		progress_label.text = "Checkpoints %d / 4" % done

func _compute_tip(qualifies: bool) -> int:
	if not qualifies:
		# Tour incomplet → tip partiel selon checkpoints atteints.
		return int(round(TIP_BASE * float(min(_next_cp, 4)) / 4.0 * 0.5))
	# Bonus selon temps de finition.
	var t: float = _completion_time
	var ratio: float = clamp((TIP_SLOW_TIME - t) / (TIP_SLOW_TIME - TIP_FAST_TIME), 0.0, 1.0)
	return TIP_BASE + int(round(TIP_BONUS_MAX * ratio))

func _end_game(qualifies: bool) -> void:
	if _ended:
		return
	_ended = true
	var tip: int = _compute_tip(qualifies)
	if status_label:
		if qualifies:
			status_label.text = "Tour bouclé en %.1fs · R$ %d" % [_completion_time, tip]
		else:
			status_label.text = "Temps écoulé · R$ %d" % tip
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("lagoa_circuit", {"tip": tip, "time": _completion_time, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)
