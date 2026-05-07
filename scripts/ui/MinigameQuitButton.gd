extends CanvasLayer

# Overlay touch réutilisable pour mini-jeux : bouton "✕ Sair" en haut à droite.
# Émet `quit_pressed` quand le joueur tape. À instancier dans chaque scène de
# mini-jeu et connecter au _end_game (ou équivalent) du script.

signal quit_pressed

@onready var button: Button = $Button

func _ready() -> void:
	if button:
		button.pressed.connect(_on_pressed)

func _on_pressed() -> void:
	quit_pressed.emit()
