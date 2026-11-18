extends Control

# Gère l'overlay de contrôles mobile : bouton E qui envoie l'action "interact",
# joystick auto-géré. Masque les contrôles pendant les dialogues et les mini-jeux
# (chaque mini-jeu offre ses propres boutons à l'écran, le 📱 deviendrait redondant).

const SAND_CHECK_INTERVAL: float = 0.25

@onready var interact_button: Button = $InteractButton
@onready var altinha_button: Button = $AltinhaButton
@onready var run_button: Button = $RunButton
@onready var joystick: VirtualJoystick = $Joystick

var _sand_check_accum: float = 0.0
var _hidden_by_context: bool = false  # dialogue ou mini-jeu en cours

func _ready() -> void:
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
	if altinha_button:
		altinha_button.pressed.connect(func(): EventBus.altinha_requested.emit())
	# Bouton sprint à bascule : le sprint devient compatible avec une direction
	# fine au joystick (le seuil de déflexion 0.85 reste en alternative). La
	# stamina garde le dernier mot (essoufflé = marche forcée, la bascule reste).
	if run_button:
		run_button.toggled.connect(_on_run_toggled)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.minigame_started.connect(_on_minigame_started)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	GamepadBridge.no_focus.call_deferred(self)
	SafeArea.apply(self)
	# À la manette, les commandes tactiles s'effacent (et reviennent au doigt).
	Gamepad.mode_changed.connect(_on_input_mode_changed)

func _on_run_toggled(pressed: bool) -> void:
	if joystick:
		joystick.external_run_hold = pressed
	if pressed:
		Input.action_press("run")
	else:
		Input.action_release("run")

# Coupe la bascule sprint (dialogue, mini-jeu : l'action "run" ne doit pas
# rester coincée pendant que les contrôles sont masqués).
func _release_run() -> void:
	if run_button and run_button.button_pressed:
		run_button.button_pressed = false  # déclenche toggled(false)
	elif joystick:
		joystick.external_run_hold = false
		Input.action_release("run")

func _process(delta: float) -> void:
	_sand_check_accum += delta
	if _sand_check_accum < SAND_CHECK_INTERVAL:
		return
	_sand_check_accum = 0.0
	if altinha_button:
		altinha_button.visible = _altinha_available()

func _altinha_available() -> bool:
	return BeachZone.altinha_here()

func _on_interact_pressed() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_dialogue_started(_npc_id: String) -> void:
	_release_run()
	_hidden_by_context = true
	visible = false

func _on_dialogue_ended(_npc_id: String) -> void:
	_hidden_by_context = false
	visible = not GamepadBridge.active

func _on_minigame_started(_minigame_id: String) -> void:
	_release_run()
	_hidden_by_context = true
	visible = false

func _on_minigame_ended(_minigame_id: String, _result: Dictionary) -> void:
	_hidden_by_context = false
	visible = not GamepadBridge.active

func _on_input_mode_changed(gamepad: bool) -> void:
	if gamepad:
		_release_run()
	visible = not gamepad and not _hidden_by_context
