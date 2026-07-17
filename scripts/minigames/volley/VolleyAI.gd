class_name VolleyAI
extends CharacterBody2D

# Blob IA avec vrai temps de réaction : elle ne « regarde » la balle qu'à
# intervalles (_reaction) et court vers le point de chute prédit entre deux
# regards — une frappe tendue croisée quand elle est à l'opposé marque.
# À la touche, elle lit la qualité de la frappe reçue : balle molle → punition
# tendue vers le coin le plus loin du joueur ; frappe parfaite → simple
# sauvetage en cloche (balle facile à contre-attaquer).
# set_difficulty() la fait monter légèrement au fil des points joués.

@export var ball: VolleyBall
@export var speed: float = 150.0
@export var jump_strength: float = 460.0
@export var gravity: float = 1200.0
@export var team: int = 1
@export var side_sign: int = 1
@export var court_min_x: float = 10.0
@export var court_max_x: float = 250.0
# Hauteur (y) en dessous de laquelle l'IA tente de sauter pour intercepter.
@export var jump_threshold_y: float = -40.0

const BOUNCE_COOLDOWN: float = 0.25
# Hauteurs de passage au filet (cf. VolleyPlayer) : tendue quand elle punit,
# cloche défensive quand elle encaisse une frappe parfaite.
const PASS_Y_PUNISH: float = -122.0
const PASS_Y_NORMAL: float = -170.0
const PASS_Y_DEFENSE: float = -225.0

var _bounce_cooldown: float = 0.0
var _speed_now: float = 150.0
var _reaction: float = 0.34    # s entre deux « regards » sur la balle
var _aim_error: float = 46.0   # imprécision de visée (px)
var _reaction_timer: float = 0.0
var _target_x: float = 130.0

func _ready() -> void:
	if ball == null:
		ball = get_parent().get_node_or_null("Ball") as VolleyBall
	var sensor: Area2D = get_node_or_null("BallSensor") as Area2D
	if sensor:
		sensor.body_entered.connect(_on_ball_entered)
	_speed_now = speed
	_target_x = (court_min_x + court_max_x) * 0.5

# Montée en difficulté légère avec le nombre de points joués dans le match.
func set_difficulty(points_played: int) -> void:
	_speed_now = minf(speed + float(points_played) * 7.0, 225.0)
	_reaction = maxf(0.16, 0.34 - float(points_played) * 0.022)
	_aim_error = maxf(10.0, 46.0 - float(points_played) * 4.5)

func _physics_process(delta: float) -> void:
	_bounce_cooldown = maxf(0.0, _bounce_cooldown - delta)
	if ball == null:
		return
	_reaction_timer -= delta
	if _reaction_timer <= 0.0:
		_reaction_timer = _reaction
		_target_x = _decide_target_x()
	var dx: float = _target_x - global_position.x
	velocity.x = signf(dx) * _speed_now if absf(dx) > 2.0 else 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		# Saut quand la balle arrive haute et proche en x.
		if _ball_incoming() and ball.global_position.y < global_position.y + jump_threshold_y \
				and absf(ball.global_position.x - global_position.x) < 45.0:
			velocity.y = -jump_strength
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

func _ball_incoming() -> bool:
	if ball.freeze:
		return false
	var on_our_side: bool = ball.global_position.x * float(side_sign) > 0.0
	return on_our_side or ball.linear_velocity.x * float(side_sign) > 0.0

func _decide_target_x() -> float:
	if not _ball_incoming():
		return (court_min_x + court_max_x) * 0.5
	return clampf(_predict_landing_x(), court_min_x, court_max_x)

# Point de chute prédit (balistique simple, sans rebonds filet/mur).
func _predict_landing_x() -> float:
	var g: float = ball.gravity_scale * float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var p: Vector2 = ball.global_position
	var v: Vector2 = ball.linear_velocity
	var disc: float = v.y * v.y + 2.0 * g * (0.0 - p.y)
	if g <= 0.0 or disc <= 0.0:
		return p.x
	var t: float = (-v.y + sqrt(disc)) / g
	return p.x + v.x * t

func _on_ball_entered(body: Node) -> void:
	if body != ball or _bounce_cooldown > 0.0:
		return
	_bounce_cooldown = BOUNCE_COOLDOWN
	# Camp adverse : de l'autre côté du filet par rapport à side_sign.
	var opp_far: float = -float(side_sign) * 235.0
	var opp_near: float = -float(side_sign) * 35.0
	var target_x: float
	var pass_y: float
	match ball.last_hit_quality:
		VolleyBall.QUALITY_PERFECT:
			# Frappe parfaite : elle sauve en cloche — balle facile à attaquer.
			target_x = -float(side_sign) * randf_range(80.0, 170.0) + randf_range(-_aim_error, _aim_error)
			pass_y = PASS_Y_DEFENSE
		VolleyBall.QUALITY_GOOD:
			target_x = -float(side_sign) * randf_range(70.0, 215.0)
			pass_y = PASS_Y_NORMAL
		_:
			# Balle molle (ou dérive de réception) : punition vers le coin le
			# plus loin du joueur — fond de court ou amortie près du filet.
			var px: float = _player_x()
			target_x = opp_far if absf(opp_far - px) > absf(opp_near - px) else opp_near
			target_x += randf_range(-_aim_error, _aim_error) * 0.5
			pass_y = PASS_Y_PUNISH
	var lo: float = minf(opp_far, opp_near) - 10.0
	var hi: float = maxf(opp_far, opp_near) + 10.0
	ball.linear_velocity = ball.velocity_through(pass_y, Vector2(clampf(target_x, lo, hi), 0.0))
	ball.last_hit_quality = VolleyBall.QUALITY_GOOD
	ball.hit_by.emit(team)

func _player_x() -> float:
	var p: Node2D = get_parent().get_node_or_null("Player") as Node2D
	return p.global_position.x if p else -float(side_sign) * 130.0
