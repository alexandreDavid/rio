class_name VolleyAI
extends CharacterBody2D

# Blob IA : se positionne sous la balle quand elle vient sur son terrain, saute
# si elle arrive haut. Même Area2D BallSensor que le joueur — le rebond se fait
# au contact, pas via un `try_hit` manuel.

@export var ball: VolleyBall
@export var speed: float = 160.0
@export var jump_strength: float = 460.0
@export var gravity: float = 1200.0
@export var team: int = 1
@export var side_sign: int = 1
@export var court_min_x: float = 10.0
@export var court_max_x: float = 250.0
@export var bounce_power: float = 360.0
@export var velocity_intent: float = 0.35
# Hauteur (y) en dessous de laquelle l'IA tente de sauter pour intercepter.
@export var jump_threshold_y: float = -40.0

const BOUNCE_COOLDOWN: float = 0.12
var _bounce_cooldown: float = 0.0

func _ready() -> void:
	if ball == null:
		ball = get_parent().get_node_or_null("Ball") as VolleyBall
	var sensor: Area2D = get_node_or_null("BallSensor") as Area2D
	if sensor:
		sensor.body_entered.connect(_on_ball_entered)

func _physics_process(delta: float) -> void:
	_bounce_cooldown = max(0.0, _bounce_cooldown - delta)
	if ball == null:
		return
	var ball_on_our_side: bool = (side_sign > 0 and ball.global_position.x > 0.0) \
		or (side_sign < 0 and ball.global_position.x < 0.0)
	var target_x: float = ball.global_position.x if ball_on_our_side else (court_min_x + court_max_x) * 0.5
	target_x = clamp(target_x, court_min_x, court_max_x)
	var dx: float = target_x - global_position.x
	velocity.x = sign(dx) * speed if abs(dx) > 2.0 else 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		# Saut quand la balle est au-dessus + proche en x + en train de descendre.
		if ball_on_our_side and ball.global_position.y < global_position.y + jump_threshold_y \
				and abs(ball.global_position.x - global_position.x) < 45.0:
			velocity.y = -jump_strength
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

func _on_ball_entered(body: Node) -> void:
	if body != ball or _bounce_cooldown > 0.0:
		return
	_bounce_cooldown = BOUNCE_COOLDOWN
	var to_ball: Vector2 = (ball.global_position - global_position)
	if to_ball.length() < 0.1:
		to_ball = Vector2(-side_sign, -1)
	var dir: Vector2 = to_ball.normalized()
	# Bias vers l'adversaire (-side_sign) pour renvoyer côté joueur.
	var lateral_bias: float = -side_sign * 0.4
	var bounce_vel: Vector2 = (dir + Vector2(lateral_bias, -0.6)).normalized() * bounce_power \
			+ Vector2(velocity.x * velocity_intent, 0)
	if bounce_vel.y > -150.0:
		bounce_vel.y = -200.0
	ball.linear_velocity = bounce_vel
	ball.hit_by.emit(team)
