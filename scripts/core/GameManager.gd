extends Node

# Global game state and references. Autoload name: GameManager.

var player: Node = null
var current_world: Node = null
var is_paused: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

func register_player(node: Node) -> void:
	player = node

func unregister_player() -> void:
	player = null
