class_name MaracanaTorcida
extends Node2D

# Mini-jeu réactif au stade Maracanã. Un prompt apparaît au centre (GOOOL!, OLA!,
# BRAÇO ESQUERDO, etc.). Le joueur doit appuyer sur la touche correspondante
# avant la deadline. Plus c'est rapide, plus c'est PERFECT. Distinct du DJ : ici
# c'est réactif et test du temps de réponse, pas de la prédiction.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 60.0
const EVENT_MIN_GAP: float = 1.4
const EVENT_MAX_GAP: float = 2.4
const REACTION_WINDOW: float = 1.6
const PERFECT_WINDOW: float = 0.55
const POINTS_PERFECT: int = 14
const POINTS_GOOD: int = 7
const TIP_DIVISOR: float = 2.0

# Commandes possibles. Chaque entrée : action Godot, libellé, couleur.
const COMMANDS: Array = [
	{"action": "ui_up",     "label": "GOOOL!",            "color": Color(0.55, 0.95, 0.55, 1)},
	{"action": "ui_left",   "label": "BRAÇO ESQUERDO ←",  "color": Color(0.95, 0.85, 0.4, 1)},
	{"action": "ui_right",  "label": "BRAÇO DIREITO →",   "color": Color(0.95, 0.85, 0.4, 1)},
	{"action": "ui_down",   "label": "VAMOS!",            "color": Color(0.4, 0.65, 0.95, 1)},
	{"action": "ui_accept", "label": "OLA!",              "color": Color(0.95, 0.55, 0.85, 1)},
]

enum State { WAITING, PROMPTING }

var _time_left: float = DURATION
var _ended: bool = false
var _score: int = 0
var _perfects: int = 0
var _goods: int = 0
var _misses: int = 0

var _state: int = State.WAITING
var _state_until: float = 0.4  # 1ère prompt après ~0.4 s
var _current_idx: int = -1
var _current_spawn: float = 0.0

@onready var prompt_label: Label = $UI/PromptLabel
@onready var prompt_bar: ColorRect = $UI/PromptBar/Fill
@onready var prompt_bar_root: Control = $UI/PromptBar
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo

func _ready() -> void:
	EventBus.minigame_started.emit("maracana_torcida")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_clear_prompt()
	if status_label:
		status_label.text = "Suis les ordres de la torcida !"

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	var elapsed: float = DURATION - _time_left
	if elapsed >= _state_until:
		_state_transition(elapsed)
	_update_prompt_bar(elapsed)
	_update_labels()

func _state_transition(elapsed: float) -> void:
	if _state == State.WAITING:
		# Spawne un nouveau prompt aléatoire.
		_current_idx = randi() % COMMANDS.size()
		_current_spawn = elapsed
		_state = State.PROMPTING
		_state_until = elapsed + REACTION_WINDOW
		_show_prompt(COMMANDS[_current_idx])
	else:
		# PROMPTING timeout sans réponse → miss.
		_misses += 1
		_set_status("MISS")
		_to_waiting(elapsed)

func _to_waiting(elapsed: float) -> void:
	_state = State.WAITING
	_state_until = elapsed + randf_range(EVENT_MIN_GAP, EVENT_MAX_GAP)
	_current_idx = -1
	_clear_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if _ended or _state != State.PROMPTING or _current_idx < 0:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Détecte quelle commande a été pressée.
	var pressed_idx: int = -1
	for i in range(COMMANDS.size()):
		if Input.is_action_pressed(COMMANDS[i].action):
			pressed_idx = i
			break
	if pressed_idx < 0:
		return
	var elapsed: float = DURATION - _time_left
	if pressed_idx != _current_idx:
		# Mauvaise touche → miss.
		_misses += 1
		_set_status("MAUVAISE TOUCHE")
		_to_waiting(elapsed)
		return
	var time_since: float = elapsed - _current_spawn
	if time_since <= PERFECT_WINDOW:
		_score += POINTS_PERFECT
		_perfects += 1
		_set_status("PERFECT!")
	else:
		_score += POINTS_GOOD
		_goods += 1
		_set_status("GOOD")
	_to_waiting(elapsed)

func _show_prompt(cmd: Dictionary) -> void:
	if prompt_label:
		prompt_label.text = cmd.label
		prompt_label.modulate = cmd.color
		prompt_label.visible = true
	if prompt_bar_root:
		prompt_bar_root.visible = true

func _clear_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false
	if prompt_bar_root:
		prompt_bar_root.visible = false

func _update_prompt_bar(elapsed: float) -> void:
	if _state != State.PROMPTING or prompt_bar == null:
		return
	# Barre qui se vide au fur et à mesure de la fenêtre de réaction.
	var time_left_in_window: float = (_current_spawn + REACTION_WINDOW) - elapsed
	var ratio: float = clamp(time_left_in_window / REACTION_WINDOW, 0.0, 1.0)
	prompt_bar.size.x = 360.0 * ratio
	# Couleur : verte si encore dans la fenêtre PERFECT, jaune sinon.
	var time_since: float = elapsed - _current_spawn
	if time_since <= PERFECT_WINDOW:
		prompt_bar.color = Color(0.55, 0.95, 0.55, 1)
	else:
		prompt_bar.color = Color(0.95, 0.85, 0.4, 1)

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if score_label:
		score_label.text = "Score : %d" % _score
	if combo_label:
		combo_label.text = "★ %d  ✓ %d  ✗ %d" % [_perfects, _goods, _misses]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var tips: int = int(round(_score / TIP_DIVISOR))
	if status_label:
		status_label.text = "Fim do jogo · %d perfects · R$ %d em pourboires" % [_perfects, tips]
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("maracana_torcida", {"score": _score, "tips": tips, "qualifies": tips > 0})
	match_ended.emit(tips > 0, tips)
