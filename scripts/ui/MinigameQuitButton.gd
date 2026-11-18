extends CanvasLayer

# Bouton « ✕ Sair » commun à tous les mini-jeux (posé par MinigameBase si la
# scène n'en a pas). Émet `quit_pressed` une seule fois : tap, B manette ou
# Échap. Le bouton ne prend jamais le focus (A manette reste l'action du jeu).

signal quit_pressed

@onready var button: Button = $Button

var _fired: bool = false

func _ready() -> void:
	if button:
		button.pressed.connect(_on_pressed)
		button.focus_mode = Control.FOCUS_NONE
		SafeArea.apply(button)

func _input(event: InputEvent) -> void:
	if _fired or not event.is_pressed() or event.is_echo():
		return
	var quit: bool = false
	if event is InputEventJoypadButton:
		quit = (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	elif event is InputEventKey:
		quit = (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if quit:
		get_viewport().set_input_as_handled()
		_on_pressed()

func _on_pressed() -> void:
	if _fired:
		return
	_fired = true
	if button:
		button.disabled = true
	quit_pressed.emit()
