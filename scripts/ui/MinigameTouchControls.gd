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
		interact_button.pressed.connect(_on_interact_pressed)
		interact_button.button_down.connect(_on_interact_pressed)

func _on_interact_pressed() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
