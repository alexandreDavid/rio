extends CanvasLayer

# Overlay tactile pour les mini-jeux : joystick (déplacement) et bouton Action.
# Le joystick injecte les actions move_*, le bouton injecte "interact".
# Inactif sur desktop : le joystick et le bouton restent réactifs à la souris,
# mais le clavier WASD/Flèches/E continue à fonctionner en parallèle.

@export var show_interact: bool = true
@export var interact_label: String = "Action"

@onready var interact_button: Button = $InteractButton

func _ready() -> void:
	if interact_button:
		interact_button.visible = show_interact
		interact_button.text = interact_label
		interact_button.button_down.connect(_send_interact.bind(true))
		interact_button.button_up.connect(_send_interact.bind(false))

# Appui ET relâché : sans le relâché, "interact" reste pressé pour toujours et
# les mini-jeux qui lisent is_action_just_pressed ne voient plus aucun tap.
func _send_interact(pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = pressed
	Input.parse_input_event(ev)

# Un bouton masqué ou retiré pendant l'appui n'émet jamais button_up.
func _exit_tree() -> void:
	if Input.is_action_pressed("interact"):
		_send_interact(false)
