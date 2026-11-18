class_name SupGame
extends MinigameBase

# Mini-jeu de stand-up paddle aux Cagarras. Vue top-down. 4 îlots à contourner
# dans l'ordre. Particularité : un courant constant pousse vers l'ouest (-x), il
# faut compenser à la pagaie. Chrono limité ; finir → pourboires de Seu Pedro.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 90.0
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const SUP_RADIUS: float = 16.0
const PADDLE_SPEED: float = 240.0   # plus lent qu'un vélo, plus vite qu'un nageur
# Le courant des Cagarras tourne : il change de cap et de force toutes les
# 5-8 s (annoncé par les flèches), jusqu'à la moitié de la vitesse de pagaie.
const CURRENT_MIN: float = 50.0
const CURRENT_MAX: float = 125.0
const CURRENT_SHIFT_MIN: float = 5.0
const CURRENT_SHIFT_MAX: float = 8.0
const CHECKPOINT_RADIUS: float = 70.0
# Deux tours des 4 îlots, puis retour au départ.
const LAPS: int = 2

# 4 îlots disposés en quinconce, ordre du circuit.
const CHECKPOINTS: Array = [
	Vector2(420, 700),    # 1 — Sud-ouest (départ)
	Vector2(700, 320),    # 2 — Nord-ouest
	Vector2(1300, 280),   # 3 — Nord-est
	Vector2(1500, 700),   # 4 — Sud-est
]

# Location de SUP : petite caixinha du Pedro (max 120 R$), pas une planche à billets.
const TIP_BASE: int = 30
const TIP_BONUS_MAX: int = 90    # max si finition < 40 s
const TIP_FAST_TIME: float = 40.0
const TIP_SLOW_TIME: float = 80.0

var _time_left: float = DURATION
var _ended: bool = false
var _sup_pos: Vector2 = CHECKPOINTS[0]
var _next_cp: int = 0  # index global : tour * 4 + îlot
var _current: Vector2 = Vector2(-60.0, 0.0)
var _current_shift_in: float = 3.0
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
		status_label.text = "Deux tours des 4 îlots, puis retour au départ. Le courant tourne !"
	if prompt_label:
		prompt_label.text = "Joystick : pagayer — le courant tourne, suis les flèches"

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
	_update_current(delta)
	_update_sup(delta)
	_check_checkpoint()
	_update_visuals()
	_update_labels()

func _update_current(delta: float) -> void:
	_current_shift_in -= delta
	if _current_shift_in > 0.0:
		return
	_current_shift_in = randf_range(CURRENT_SHIFT_MIN, CURRENT_SHIFT_MAX)
	var angle: float = randf() * TAU
	_current = Vector2.from_angle(angle) * randf_range(CURRENT_MIN, CURRENT_MAX)
	var arrow: String = _arrow_for(_current)
	var strong: bool = _current.length() > 95.0
	for n in ["Arena/CurrentArrow1", "Arena/CurrentArrow2"]:
		var l: Label = get_node_or_null(n) as Label
		if l:
			l.text = "  ".join([arrow, arrow, arrow]) if strong else "%s  %s" % [arrow, arrow]
	if status_label:
		status_label.text = "O mar virou — courant %s %s" % [arrow, "fort !" if strong else "léger"]
	sfx("splash", 0.7)
	pulse(0.25, 0.1)

static func _arrow_for(v: Vector2) -> String:
	var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var idx: int = int(round(fposmod(v.angle(), TAU) / (TAU / 8.0))) % 8
	return arrows[idx]

func _update_sup(delta: float) -> void:
	var input_dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var velocity: Vector2 = input_dir * PADDLE_SPEED + _current
	_sup_pos += velocity * delta
	_sup_pos.x = clamp(_sup_pos.x, SUP_RADIUS, ARENA_W - SUP_RADIUS)
	_sup_pos.y = clamp(_sup_pos.y, SUP_RADIUS, ARENA_H - SUP_RADIUS)
	if sup_node:
		sup_node.position = _sup_pos - Vector2(SUP_RADIUS, SUP_RADIUS)

func _check_checkpoint() -> void:
	var total: int = CHECKPOINTS.size() * LAPS
	if _next_cp >= total:
		# Tous les îlots faits → on rentre vers le point de départ.
		if _sup_pos.distance_to(CHECKPOINTS[0]) <= CHECKPOINT_RADIUS:
			_completion_time = DURATION - _time_left
			sfx("mg_perfect")
			_end_game(true)
		return
	var target: Vector2 = CHECKPOINTS[_next_cp % CHECKPOINTS.size()]
	if _sup_pos.distance_to(target) <= CHECKPOINT_RADIUS:
		_next_cp += 1
		sfx("checkpoint")
		pulse(0.25, 0.05)
		if status_label:
			if _next_cp < total:
				status_label.text = "Îlot %d/%d ✓ — vise le suivant" % [_next_cp, total]
			else:
				status_label.text = "Volta completa ! Reviens au départ."

func _update_visuals() -> void:
	if cp_markers == null:
		return
	var total: int = CHECKPOINTS.size() * LAPS
	var target: int = _next_cp % CHECKPOINTS.size() if _next_cp < total else 0
	var i: int = 0
	for child in cp_markers.get_children():
		if not (child is ColorRect):
			continue
		var rect: ColorRect = child
		if i == target:
			var glow: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
			rect.color = Color(0.95, 0.85, 0.4, glow)
		elif i < target:
			rect.color = Color(0.4, 0.6, 0.4, 0.35)
		else:
			rect.color = Color(0.55, 0.85, 0.95, 0.4)
		i += 1

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if progress_label:
		var total: int = CHECKPOINTS.size() * LAPS
		progress_label.text = "Îlots %d / %d" % [clampi(_next_cp, 0, total), total]

func _compute_tip(qualifies: bool) -> int:
	if not qualifies:
		# Circuit incomplet → tip réduit selon îlots atteints.
		return 0 if forfeited else int(round(TIP_BASE * float(min(_next_cp, CHECKPOINTS.size() * LAPS)) / float(CHECKPOINTS.size() * LAPS) * 0.5))
	var t: float = _completion_time
	var ratio: float = clamp((TIP_SLOW_TIME - t) / (TIP_SLOW_TIME - TIP_FAST_TIME), 0.0, 1.0)
	return TIP_BASE + int(round(TIP_BONUS_MAX * ratio))

func quit_game() -> void:
	_end_game(false)

func _end_game(qualifies: bool) -> void:
	if _ended:
		return
	_ended = true
	qualifies = final_qualifies(qualifies)
	var tip: int = _compute_tip(qualifies)
	if status_label:
		if qualifies:
			status_label.text = "Volta complète en %.1fs · R$ %d" % [_completion_time, tip]
		else:
			status_label.text = "Marée tournée · R$ %d" % tip
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("cagarras_sup", {"tip": tip, "time": _completion_time, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)
