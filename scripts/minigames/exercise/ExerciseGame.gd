class_name ExerciseGame
extends Node2D

# Mini-jeu de musculation : tap E rapidement pour remplir la barre
# qui redescend toute seule. Chaque fois que la barre est pleine = 1 rep.
# Durée fixe. Récompense = +1 Charisma si le joueur atteint MIN_REPS_FOR_CHARISMA,
# plafonné à CHARISMA_CAP via la source "gym" (voir ExerciseLauncher).

signal match_ended(won: bool, reps: int)

@export var duration: float = 30.0

const BAR_MAX: float = 100.0
const PRESS_GAIN: float = 9.0
const DECAY_PER_SECOND: float = 34.0
const MIN_REPS_FOR_CHARISMA: int = 4

@onready var bar: ProgressBar = $UI/Bar
@onready var rep_label: Label = $UI/RepLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status

var _value: float = 0.0
var _reps: int = 0
var _time_left: float = 0.0
var _ended: bool = false

func _ready() -> void:
	EventBus.minigame_started.emit("exercise")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_time_left = duration
	if status_label:
		status_label.text = "Tape E vite pour remplir la barre !"
	_update_labels()

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	_value = max(0.0, _value - DECAY_PER_SECOND * delta)
	if Input.is_action_just_pressed("interact"):
		_value += PRESS_GAIN
		if _value >= BAR_MAX:
			_reps += 1
			_value = 0.0
			if status_label:
				status_label.text = "REP ! (%d)" % _reps
	_update_labels()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_end_game()
			get_viewport().set_input_as_handled()

func _update_labels() -> void:
	if bar:
		bar.value = _value
	if rep_label:
		rep_label.text = "Reps: %d" % _reps
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _reps >= MIN_REPS_FOR_CHARISMA
	if status_label:
		if qualifies:
			status_label.text = "Fin — %d reps (+1 Charisma)" % _reps
		else:
			status_label.text = "Fin — %d reps (min. %d pour +Charisma)" % [_reps, MIN_REPS_FOR_CHARISMA]
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("exercise", {"reps": _reps, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, _reps)
