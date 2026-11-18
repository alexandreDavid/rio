class_name MaracanaTorcida
extends MinigameBase

# Mini-jeu réactif au stade Maracanã. Un prompt apparaît au centre (GOOOL!, OLA!,
# BRAÇO ESQUERDO, etc.). Le joueur doit appuyer sur la touche correspondante
# avant la deadline. Plus c'est rapide, plus c'est PERFECT. Distinct du DJ : ici
# c'est réactif et test du temps de réponse, pas de la prédiction.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 60.0
const EVENT_MIN_GAP: float = 1.4
const EVENT_MAX_GAP: float = 2.4
# La torcida s'emballe : la fenêtre se resserre de 1,6 s à 1,0 s sur le match.
const REACTION_WINDOW_START: float = 1.6
const REACTION_WINDOW_END: float = 1.0
const PERFECT_WINDOW_START: float = 0.55
const PERFECT_WINDOW_END: float = 0.4
# Qualifié = ~2/3 des ordres suivis proprement.
const QUALIFY_SCORE: int = 170
# Geste : au-delà de ce déplacement (px écran), c'est un balayage, sinon un tap.
const SWIPE_MIN: float = 60.0
const POINTS_PERFECT: int = 14
const POINTS_GOOD: int = 7
const TIP_DIVISOR: float = 2.5

# Commandes possibles. Chaque entrée : action Godot, libellé, couleur.
const COMMANDS: Array = [
	{"action": "ui_up",     "label": "↑ GOOOL!",          "color": Color(0.55, 0.95, 0.55, 1)},
	{"action": "ui_left",   "label": "← BRAÇO ESQUERDO",  "color": Color(0.95, 0.85, 0.4, 1)},
	{"action": "ui_right",  "label": "BRAÇO DIREITO →",   "color": Color(0.95, 0.85, 0.4, 1)},
	{"action": "ui_down",   "label": "↓ VAMOS!",          "color": Color(0.4, 0.65, 0.95, 1)},
	{"action": "ui_accept", "label": "• OLA! (tape)",     "color": Color(0.95, 0.55, 0.85, 1)},
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
var _touch_start: Vector2 = Vector2.ZERO
var _touch_down: bool = false

func _progress() -> float:
	return clampf(1.0 - _time_left / DURATION, 0.0, 1.0)

func _reaction_window() -> float:
	return lerpf(REACTION_WINDOW_START, REACTION_WINDOW_END, _progress())

func _perfect_window() -> float:
	return lerpf(PERFECT_WINDOW_START, PERFECT_WINDOW_END, _progress())

@onready var prompt_label: Label = $UI/PromptLabel
@onready var prompt_bar: ColorRect = $UI/PromptBar/Fill
@onready var prompt_bar_root: Control = $UI/PromptBar
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo
@onready var action_button: Button = $UI/ActionButton

func _ready() -> void:
	EventBus.minigame_started.emit("maracana_torcida")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	# Au doigt, chaque ordre a son geste (balayer ↑ ← → ↓, taper = OLA) : le
	# bouton n'affiche plus que l'ordre, il ne répond plus à tout.
	if action_button:
		action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_button.focus_mode = Control.FOCUS_NONE
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
		_state_until = elapsed + _reaction_window()
		_show_prompt(COMMANDS[_current_idx])
	else:
		# PROMPTING timeout sans réponse → miss.
		_misses += 1
		_set_status("MISS")
		sfx("mg_miss")
		_to_waiting(elapsed)

func _to_waiting(elapsed: float) -> void:
	_state = State.WAITING
	_state_until = elapsed + randf_range(EVENT_MIN_GAP, EVENT_MAX_GAP)
	_current_idx = -1
	_clear_prompt()

# Gestes : glisser ↑ GOOOL, ← / → braços, ↓ VAMOS, taper OLA (index COMMANDS).
func _gesture_index(delta: Vector2) -> int:
	if delta.length() < SWIPE_MIN:
		return 4
	if absf(delta.x) > absf(delta.y):
		return 1 if delta.x < 0.0 else 2
	return 0 if delta.y < 0.0 else 3

func _answer(idx: int) -> void:
	if _ended or _state != State.PROMPTING or _current_idx < 0:
		return
	if idx == _current_idx:
		_score_correct_press()
		return
	_misses += 1
	_set_status("ERROU O GESTO")
	sfx("mg_miss")
	_to_waiting(DURATION - _time_left)

func _unhandled_input(event: InputEvent) -> void:
	# Doigt (ou souris réelle ; on ignore la souris émulée depuis le tactile).
	var pointer_pressed: int = -1  # -1 rien, 1 appui, 0 relâché
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pointer_pressed = 1 if event.pressed else 0
		pos = event.position
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pointer_pressed = 1 if event.pressed else 0
		pos = event.position
	if pointer_pressed == 1:
		_touch_down = true
		_touch_start = pos
		return
	if pointer_pressed == 0 and _touch_down:
		_touch_down = false
		_answer(_gesture_index(pos - _touch_start))
		return
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
	# A manette (= E) fait la OLA, comme Espace.
	if pressed_idx < 0 and event.is_action_pressed("interact"):
		pressed_idx = 4
	if pressed_idx < 0:
		return
	if pressed_idx != _current_idx:
		# Mauvaise touche → miss.
		var elapsed: float = DURATION - _time_left
		_misses += 1
		_set_status("MAUVAISE TOUCHE")
		sfx("mg_miss")
		_to_waiting(elapsed)
		return
	_score_correct_press()

# Logique de presse correcte sur le prompt courant. Appelée depuis le bouton
# mobile (presse unique) ou depuis le clavier (après vérif que la bonne touche).
func _score_correct_press() -> void:
	var elapsed: float = DURATION - _time_left
	var time_since: float = elapsed - _current_spawn
	if time_since <= _perfect_window():
		_score += POINTS_PERFECT
		_perfects += 1
		_set_status("PERFECT!")
		sfx("torcida_cheer")
		pulse(0.4, 0.08)
	else:
		_score += POINTS_GOOD
		_goods += 1
		_set_status("GOOD")
		sfx("mg_good")
	_to_waiting(elapsed)

func _show_prompt(cmd: Dictionary) -> void:
	if prompt_label:
		prompt_label.text = cmd.label
		prompt_label.modulate = cmd.color
		prompt_label.visible = true
	if prompt_bar_root:
		prompt_bar_root.visible = true
	if action_button:
		action_button.text = cmd.label
		action_button.modulate = cmd.color
		action_button.visible = true

func _clear_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false
	if prompt_bar_root:
		prompt_bar_root.visible = false
	if action_button:
		action_button.visible = false

func _update_prompt_bar(elapsed: float) -> void:
	if _state != State.PROMPTING or prompt_bar == null:
		return
	# Barre qui se vide au fur et à mesure de la fenêtre de réaction.
	var window: float = _state_until - _current_spawn
	var time_left_in_window: float = _state_until - elapsed
	var ratio: float = clamp(time_left_in_window / maxf(window, 0.01), 0.0, 1.0)
	prompt_bar.size.x = 360.0 * ratio
	# Couleur : verte si encore dans la fenêtre PERFECT, jaune sinon.
	var time_since: float = elapsed - _current_spawn
	if time_since <= _perfect_window():
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
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if status_label:
		status_label.text = "Fim do jogo · %d perfects · R$ %d em pourboires" % [_perfects, tips]
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("maracana_torcida", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
