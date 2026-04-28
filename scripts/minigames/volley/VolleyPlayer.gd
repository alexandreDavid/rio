class_name VolleyPlayer
extends CharacterBody2D

# Vue de côté. Cooldown de frappe pour éviter le spam de la balle au sol.

@export var ball: VolleyBall
@export var speed: float = 180.0
@export var hit_range: float = 55.0
@export var hit_power: float = 500.0
@export var hit_cooldown_seconds: float = 0.4
@export var side_sign: int = -1
@export var court_min_x: float = -220.0
@export var court_max_x: float = -10.0

var _hit_cooldown: float = 0.0

func _ready() -> void:
	if ball == null:
		ball = get_parent().get_node_or_null("Ball") as VolleyBall

func _physics_process(delta: float) -> void:
	_hit_cooldown = max(0.0, _hit_cooldown - delta)
	var input_x: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * speed
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

	if Input.is_action_just_pressed("jump") and ball and _hit_cooldown <= 0.0:
		var dist: float = ball.global_position.distance_to(global_position)
		if dist < hit_range:
			# Cloche haute : ratio y/x = 2 pour passer au-dessus du filet
			var x_component: float = -side_sign * 0.7
			var dir: Vector2 = Vector2(x_component, -1.5).normalized()
			ball.apply_hit(dir, hit_power, 0)
			_hit_cooldown = hit_cooldown_seconds
