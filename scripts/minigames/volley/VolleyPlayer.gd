class_name VolleyPlayer
extends CharacterBody2D

# Style Blobby Volley : déplacement gauche/droite + saut. La balle rebondit
# automatiquement quand elle touche le blob (Area2D enfant `BallSensor`).
# Le joueur ne `frappe` plus à la main — il se positionne, il saute, il oriente
# son mouvement pour donner la direction du rebond.

@export var ball: VolleyBall
@export var speed: float = 200.0
@export var jump_strength: float = 480.0
@export var gravity: float = 1200.0
@export var side_sign: int = -1
@export var court_min_x: float = -250.0
@export var court_max_x: float = -10.0
# Force du rebond : plus haut = balle envoyée plus loin.
@export var bounce_power: float = 360.0
# Multiplicateur de la vélocité horizontale du blob ajoutée à la balle (intent
# de direction : si tu cours vers la droite quand tu sautes, la balle part plus
# à droite).
@export var velocity_intent: float = 0.45
# Anti-spam : on n'autorise pas deux bounces dans la même milliseconde sinon
# la balle peut osciller dans l'aire d'overlap.
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
	var input_x: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_strength
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

# Appelé aussi par le bouton tactile JUMP (BeachVolley.tscn).
func try_jump() -> void:
	if is_on_floor():
		velocity.y = -jump_strength

func _on_ball_entered(body: Node) -> void:
	if body != ball or _bounce_cooldown > 0.0:
		return
	_bounce_cooldown = BOUNCE_COOLDOWN
	var to_ball: Vector2 = (ball.global_position - global_position)
	if to_ball.length() < 0.1:
		to_ball = Vector2(-side_sign, -1)
	var dir: Vector2 = to_ball.normalized()
	# Bias vers le haut pour passer le filet, plus l'intent de direction.
	var bounce_vel: Vector2 = dir * bounce_power + Vector2(velocity.x * velocity_intent, 0)
	# Force vers le haut (jamais d'enfoncer la balle dans le sol).
	if bounce_vel.y > -120.0:
		bounce_vel.y = -180.0
	ball.linear_velocity = bounce_vel
	ball.hit_by.emit(0)
