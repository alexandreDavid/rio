class_name SupGame
extends Node2D

# Mini-jeu de stand-up paddle aux Cagarras. Vue top-down. 4 îlots à contourner
# dans l'ordre. Particularité : un courant constant pousse vers l'ouest (-x), il
# faut compenser à la pagaie. Chrono limité ; finir → pourboires de Seu Pedro.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 90.0
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const SUP_RADIUS: float = 16.0
const PADDLE_SPEED: float = 240.0   # plus lent qu'un vélo, plus vite qu'un nageur
const CURRENT: Vector2 = Vector2(-32.0, 0.0)  # dérive vers l'ouest (px/s)
const CHECKPOINT_RADIUS: float = 70.0

# 4 îlots disposés en quinconce, ordre du circuit.
const CHECKPOINTS: Array = [
	Vector2(420, 700),    # 1 — Sud-ouest (départ)
	Vector2(700, 320),    # 2 — Nord-ouest
	Vector2(1300, 280),   # 3 — Nord-est
	Vector2(1500, 700),   # 4 — Sud-est
]

const TIP_BASE: int = 60
const TIP_BONUS_MAX: int = 220   # max si finition < 35 s
const TIP_FAST_TIME: float = 35.0
const TIP_SLOW_TIME: float = 80.0

var _time_left: float = DURATION
var _ended: bool = false
var _sup_pos: Vector2 = CHECKPOINTS[0]
var _next_cp: int = 0  # commence à viser le checkpoint 0 (départ)
var _completion_time: float = -1.0

@onready var arena: Node2D = $Arena
@onready var sup_node: ColorRect = $Arena/Sup
@onready var cp_markers: Node2D = $Arena/Checkpoints
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var progress_label: Label = $UI/Progress
@onready var prompt_label: Label = $UI/Prompt

func _ready() -> void:
	EventBus.minigame_started.emit("cagarras_sup")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_sup_pos = CHECKPOINTS[0]
	if sup_node:
		sup_node.position = _sup_pos - Vector2(SUP_RADIUS, SUP_RADIUS)
	_render_checkpoints()
	# On considère le point 0 atteint d'office (c'est le point de mise à l'eau).
	_next_cp = 1
	if status_label:
		status_label.text = "Contourne les 4 îlots dans l'ordre. Le courant pousse vers l'ouest."
	if prompt_label:
		prompt_label.text = "[WASD / Flèches] pagayer"

func _render_checkpoints() -> void:
	if cp_markers == null:
		return
	for child in cp_markers.get_children():
		child.queue_free()
	for i in range(CHECKPOINTS.size()):
		var cp: Vector2 = CHECKPOINTS[i]
		var ring: ColorRect = ColorRect.new()
		ring.size = Vector2(56, 56)
		ring.position = cp - Vector2(28, 28)
		ring.color = Color(0.95, 0.95, 0.55, 0.5)
		cp_markers.add_child(ring)
		var label: Label = Label.new()
		label.text = str(i + 1)
		label.position = cp - Vector2(8, 38)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
		cp_markers.add_child(label)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game(false)
		return
	_update_sup(delta)
	_check_checkpoint()
	_update_visuals()
	_update_labels()

func _update_sup(delta: float) -> void:
	var input_dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var velocity: Vector2 = input_dir * PADDLE_SPEED + CURRENT
	_sup_pos += velocity * delta
	_sup_pos.x = clamp(_sup_pos.x, SUP_RADIUS, ARENA_W - SUP_RADIUS)
	_sup_pos.y = clamp(_sup_pos.y, SUP_RADIUS, ARENA_H - SUP_RADIUS)
	if sup_node:
		sup_node.position = _sup_pos - Vector2(SUP_RADIUS, SUP_RADIUS)

func _check_checkpoint() -> void:
	if _next_cp >= CHECKPOINTS.size():
		# Tous les îlots faits → on rentre vers le point de départ.
		if _sup_pos.distance_to(CHECKPOINTS[0]) <= CHECKPOINT_RADIUS:
			_completion_time = DURATION - _time_left
			_end_game(true)
		return
	var target: Vector2 = CHECKPOINTS[_next_cp]
	if _sup_pos.distance_to(target) <= CHECKPOINT_RADIUS:
		_next_cp += 1
		if status_label:
			if _next_cp < CHECKPOINTS.size():
				status_label.text = "Îlot %d/4 ✓ — vise le suivant" % _next_cp
			else:
				status_label.text = "Tous les îlots faits ! Reviens au départ."

func _update_visuals() -> void:
	if cp_markers == null:
		return
	var i: int = 0
	for child in cp_markers.get_children():
		if not (child is ColorRect):
			continue
		var rect: ColorRect = child
		if i == _next_cp:
			var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
			rect.color = Color(0.95, 0.85, 0.4, pulse)
		elif i < _next_cp:
			rect.color = Color(0.4, 0.6, 0.4, 0.35)
		else:
			rect.color = Color(0.55, 0.85, 0.95, 0.4)
		i += 1

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if progress_label:
		var done: int = clamp(_next_cp, 0, CHECKPOINTS.size())
		progress_label.text = "Îlots %d / 4" % done

func _compute_tip(qualifies: bool) -> int:
	if not qualifies:
		# Circuit incomplet → tip réduit selon îlots atteints.
		return int(round(TIP_BASE * float(min(_next_cp, 4)) / 4.0 * 0.5))
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
			status_label.text = "Volta complète en %.1fs · R$ %d" % [_completion_time, tip]
		else:
			status_label.text = "Marée tournée · R$ %d" % tip
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("cagarras_sup", {"tip": tip, "time": _completion_time, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)
