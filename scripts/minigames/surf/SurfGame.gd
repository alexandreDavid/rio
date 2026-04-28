class_name SurfGame
extends Node2D

# Mini-jeu de surf : le joueur contrôle une planche qui se déplace en 2D.
# Des vagues déferlent du haut vers le bas avec des trous ; il faut passer
# dans les trous. 3 vies, 45 secondes de survie. Si le joueur tient la durée
# avec au moins 1 vie, il gagne +1 Touristes (plafonné à 3 via la source "surf").

signal match_ended(qualifies: bool, time_survived: float)

const DURATION: float = 45.0
const LIVES_START: int = 3

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0
const ARENA_TOP: float = 0.0
const ARENA_BOTTOM: float = ARENA_H
const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = ARENA_W

const BOARD_W: float = 60.0
const BOARD_H: float = 120.0
const BOARD_SPEED: float = 520.0

const WAVE_H: float = 60.0
const WAVE_START_SPEED: float = 220.0
const WAVE_ACCEL: float = 8.0          # +px/s² de vitesse de vague (difficulté croissante)
const WAVE_SPAWN_INTERVAL_START: float = 2.0
const WAVE_SPAWN_INTERVAL_MIN: float = 0.9
const WAVE_GAPS_MIN: int = 2
const WAVE_GAPS_MAX: int = 3
const WAVE_GAP_WIDTH: float = 260.0
const I_FRAMES: float = 1.0             # invincibilité après un hit, en secondes

@onready var board: ColorRect = $Board
@onready var wave_layer: Node2D = $WaveLayer
@onready var lives_label: Label = $UI/LivesLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status

var _time_left: float = DURATION
var _lives: int = LIVES_START
var _ended: bool = false
var _wave_speed: float = WAVE_START_SPEED
var _spawn_timer: float = 0.5
var _spawn_interval: float = WAVE_SPAWN_INTERVAL_START
var _iframes_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	EventBus.minigame_started.emit("surf")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	if status_label:
		status_label.text = "Esquive les vagues !"
	_update_labels()
	if board:
		board.position = Vector2(ARENA_W * 0.5 - BOARD_W * 0.5, ARENA_BOTTOM - BOARD_H - 80.0)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	_iframes_left = max(0.0, _iframes_left - delta)
	if _time_left <= 0.0:
		_end_game(true)
		return
	# Difficulté qui monte en continu.
	_wave_speed += WAVE_ACCEL * delta
	_spawn_interval = max(WAVE_SPAWN_INTERVAL_MIN, _spawn_interval - 0.01 * delta)
	_move_board(delta)
	_spawn_and_move_waves(delta)
	_check_collisions()
	_update_labels()

func _move_board(delta: float) -> void:
	if board == null:
		return
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	board.position += dir * BOARD_SPEED * delta
	board.position.x = clamp(board.position.x, ARENA_LEFT, ARENA_RIGHT - BOARD_W)
	board.position.y = clamp(board.position.y, ARENA_TOP, ARENA_BOTTOM - BOARD_H)
	# Flash quand on a des i-frames.
	if board:
		board.modulate.a = 0.45 if _iframes_left > 0.0 else 1.0

func _spawn_and_move_waves(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_wave()
		_spawn_timer = _spawn_interval
	# Avance chaque segment de vague, détruit ceux qui sortent de l'arène.
	for child in wave_layer.get_children():
		var seg: ColorRect = child as ColorRect
		if seg == null:
			continue
		seg.position.y += _wave_speed * delta
		if seg.position.y > ARENA_BOTTOM + 10.0:
			seg.queue_free()

func _spawn_wave() -> void:
	# On découpe la largeur de l'arène en segments, en laissant 2-3 trous.
	var gaps: int = _rng.randi_range(WAVE_GAPS_MIN, WAVE_GAPS_MAX)
	var gap_xs: Array[float] = []
	for i in gaps:
		var gx: float = _rng.randf_range(40.0, ARENA_W - WAVE_GAP_WIDTH - 40.0)
		gap_xs.append(gx)
	gap_xs.sort()
	# Construit les segments pleins entre les trous.
	var cursor: float = 0.0
	for gap_x in gap_xs:
		if gap_x > cursor + 10.0:
			_add_wave_segment(cursor, gap_x - cursor)
		cursor = gap_x + WAVE_GAP_WIDTH
	if cursor < ARENA_W - 10.0:
		_add_wave_segment(cursor, ARENA_W - cursor)

func _add_wave_segment(x: float, w: float) -> void:
	var seg: ColorRect = ColorRect.new()
	seg.position = Vector2(x, -WAVE_H)
	seg.size = Vector2(w, WAVE_H)
	seg.color = Color(0.85, 0.95, 1.0, 0.9)
	wave_layer.add_child(seg)

func _check_collisions() -> void:
	if _iframes_left > 0.0 or board == null:
		return
	var brect: Rect2 = Rect2(board.position, Vector2(BOARD_W, BOARD_H))
	for child in wave_layer.get_children():
		var seg: ColorRect = child as ColorRect
		if seg == null:
			continue
		var srect: Rect2 = Rect2(seg.position, seg.size)
		if brect.intersects(srect):
			_take_hit()
			return

func _take_hit() -> void:
	_lives -= 1
	_iframes_left = I_FRAMES
	if status_label:
		status_label.text = "Boum ! Reste %d vies" % _lives
	if _lives <= 0:
		_end_game(false)

func _update_labels() -> void:
	if lives_label:
		lives_label.text = "♥ %d" % _lives
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)

func _end_game(time_up: bool) -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = time_up and _lives > 0
	if status_label:
		if qualifies:
			status_label.text = "Tu as tenu ! (+1 Touristes)"
		elif time_up:
			status_label.text = "Fin — trop de chutes"
		else:
			status_label.text = "Wipe out !"
	var survived: float = DURATION - max(_time_left, 0.0)
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("surf", {"time_survived": survived, "lives": _lives, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, survived)
