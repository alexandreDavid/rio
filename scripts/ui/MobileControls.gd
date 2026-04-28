extends Control

# Gère l'overlay de contrôles mobile : bouton E qui envoie l'action "interact",
# joystick auto-géré. Masque les contrôles pendant les dialogues.

@onready var interact_button: Button = $InteractButton
@onready var joystick: VirtualJoystick = $Joystick

func _ready() -> void:
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)

func _on_interact_pressed() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_dialogue_started(_npc_id: String) -> void:
	visible = false

func _on_dialogue_ended(_npc_id: String) -> void:
	visible = true
