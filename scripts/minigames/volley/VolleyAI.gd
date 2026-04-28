class_name VolleyAI
extends CharacterBody2D

@export var ball: VolleyBall
@export var speed: float = 100.0
@export var team: int = 1
@export var hit_range: float = 50.0
@export var hit_power: float = 380.0
@export var reaction_delay: float = 0.3
@export var side_sign: int = 1
@export var court_min_x: float = 10.0
@export var court_max_x: float = 220.0

var _hit_cooldown: float = 0.0

func _ready() -> void:
	if ball == null:
		ball = get_parent().get_node_or_null("Ball") as VolleyBall

func _physics_process(delta: float) -> void:
	_hit_cooldown -= delta
	if ball == null:
		return
	var ball_on_our_side: bool = (side_sign > 0 and ball.global_position.x > 0.0) \
		or (side_sign < 0 and ball.global_position.x < 0.0)
	var target_x: float
	if ball_on_our_side:
		target_x = ball.global_position.x
	else:
		target_x = (court_min_x + court_max_x) * 0.5
	target_x = clamp(target_x, court_min_x, court_max_x)
	var dx: float = target_x - global_position.x
	velocity.x = sign(dx) * speed if abs(dx) > 2.0 else 0.0
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

	if ball_on_our_side and _hit_cooldown <= 0.0 \
		and ball.global_position.distance_to(global_position) < hit_range:
		# Cloche haute vers le camp adverse
		var x_component: float = -side_sign * 0.7
		var dir: Vector2 = Vector2(x_component, -1.5).normalized()
		ball.apply_hit(dir, hit_power, team)
		_hit_cooldown = 1.5
