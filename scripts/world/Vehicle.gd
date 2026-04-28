class_name Vehicle
extends Node2D

# Véhicule qui roule horizontalement. Flip du sprite selon la direction.

@export var speed_x: float = 100.0

const MIN_X: float = -250.0
const MAX_X: float = 2650.0

func _ready() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite and speed_x < 0:
		sprite.flip_h = true

func _physics_process(delta: float) -> void:
	position.x += speed_x * delta
	if position.x < MIN_X or position.x > MAX_X:
		queue_free()
