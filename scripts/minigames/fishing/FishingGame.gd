class_name FishingGame
extends Node2D

# Mini-jeu de pêche — timing bar en 3 rounds.
# E (ou bouton E sur mobile) quand le curseur est dans la zone verte → poisson pêché.
# Q pour abandonner.

signal match_ended(won: bool, payout: int)

@export var rounds: int = 3
@export var bet_amount: int = 20
@export var price_per_catch: int = 15

@onready var timing_bar: Panel = $UI/TimingBar
@onready var cursor: ColorRect = $UI/TimingBar/Cursor
@onready var target_zone: ColorRect = $UI/TimingBar/TargetZone
@onready var score_label: Label = $UI/Score
@onready var status_label: Label = $UI/Status

const CURSOR_SPEED: float = 0.9  # cycles par seconde

var _cursor_pos: float = 0.0
var _target_start: float = 0.0
var _target_width: float = 0.18
var _round_num: int = 0
var _catches: int = 0
var _ended: bool = false
var _waiting_input: bool = false

func _ready() -> void:
	EventBus.minigame_started.emit("fishing")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_update_score()
	if status_label:
		status_label.text = "Pêche ! E quand la barre est dans le vert"
	await get_tree().create_timer(1.2).timeout
	_next_round()

func _next_round() -> void:
	if _round_num >= rounds:
		_end_game()
		return
	_round_num += 1
	_cursor_pos = 0.0
	_target_start = randf_range(0.35, 0.72)
	_target_width = 0.16 + randf() * 0.08
	_waiting_input = true
	if status_label:
		status_label.text = "Round %d / %d" % [_round_num, rounds]

func _process(delta: float) -> void:
	if _ended or not _waiting_input:
		return
	_cursor_pos += CURSOR_SPEED * delta
	if _cursor_pos > 1.0:
		_cursor_pos = 0.0
	_update_bar()
	# Polling direct en plus de _unhandled_input (au cas où un Control absorbe l'event)
	if Input.is_action_just_pressed("interact"):
		_attempt_catch()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	# Interact (E) = lancer la ligne — accepte aussi InputEventAction (bouton mobile)
	if event.is_action_pressed("interact") and _waiting_input:
		_attempt_catch()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_end_game()
			get_viewport().set_input_as_handled()

func _attempt_catch() -> void:
	_waiting_input = false
	var in_zone: bool = _cursor_pos >= _target_start and _cursor_pos <= _target_start + _target_width
	if in_zone:
		_catches += 1
		if status_label:
			status_label.text = "ATTRAPÉ ! +R$ %d" % price_per_catch
	else:
		if status_label:
			status_label.text = "Raté…"
	_update_score()
	await get_tree().create_timer(0.9).timeout
	_next_round()

func _update_bar() -> void:
	if cursor == null or timing_bar == null:
		return
	var bar_w: float = timing_bar.size.x
	cursor.position.x = bar_w * _cursor_pos - cursor.size.x * 0.5
	if target_zone:
		target_zone.position.x = bar_w * _target_start
		target_zone.size.x = bar_w * _target_width

func _update_score() -> void:
	if score_label:
		score_label.text = "%d prises" % _catches

func _end_game() -> void:
	_ended = true
	_waiting_input = false
	var payout: int = _catches * price_per_catch
	if status_label:
		status_label.text = "Fin — %d prises (+R$ %d)" % [_catches, payout]
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("fishing", {"catches": _catches, "payout": payout, "won": _catches > 0})
	match_ended.emit(_catches > 0, payout)
