class_name VolleyPlayer
extends CharacterBody2D

# Blobby Volley + frappe active :
# - le contact automatique (BallSensor) n'est plus qu'une RÉCEPTION molle : la
#   balle remonte côté joueur et dérive lentement vers le filet. Ne rien faire
#   finit par donner une balle cadeau que l'IA punit dans les coins.
# - la vraie attaque passe par try_hit() (bouton FRAPPER) : fenêtre de timing
#   selon la distance balle → point de frappe au moment de l'appui, visée par
#   l'axe gauche/droite tenu pendant la frappe. Frapper en l'air relève le
#   point de contact → trajectoire naturellement plus tendue (smash).

@export var ball: VolleyBall
@export var speed: float = 200.0
@export var jump_strength: float = 480.0
@export var gravity: float = 1200.0
@export var side_sign: int = -1
@export var court_min_x: float = -250.0
@export var court_max_x: float = -10.0

# Fenêtres de timing : distance balle → point de frappe (px monde) à l'appui.
const HIT_PERFECT_DIST: float = 30.0
const HIT_GOOD_DIST: float = 60.0
const HIT_SOFT_DIST: float = 95.0
# Point de frappe : un peu au-dessus du centre du blob (les « bras »).
const HIT_ORIGIN_OFFSET: Vector2 = Vector2(0, -26)
# Frapper dans le vide verrouille la frappe : le spam ne remplace pas le timing.
const HIT_LOCK: float = 0.35
const BOUNCE_COOLDOWN: float = 0.30

# Hauteur de passage au-dessus du filet selon la qualité (y monde ; haut du
# filet = -110, balle r=8). Parfaite = rase le filet, molle = grosse cloche.
const PASS_Y_PERFECT: float = -126.0
const PASS_Y_GOOD: float = -165.0
const PASS_Y_SOFT: float = -215.0
# Cibles de visée dans le camp adverse (x monde, camp IA = 10..250).
const TARGET_SHORT_X: float = 55.0
const TARGET_CENTER_X: float = 140.0
const TARGET_DEEP_X: float = 230.0

# Axe posé par les boutons tactiles ◀ ▶ (VolleyMatch) ; le clavier reste prioritaire.
var touch_axis: float = 0.0

var _bounce_cooldown: float = 0.0
var _hit_lock: float = 0.0

func _ready() -> void:
	if ball == null:
		ball = get_parent().get_node_or_null("Ball") as VolleyBall
	var sensor: Area2D = get_node_or_null("BallSensor") as Area2D
	if sensor:
		sensor.body_entered.connect(_on_ball_entered)

func _physics_process(delta: float) -> void:
	_bounce_cooldown = maxf(0.0, _bounce_cooldown - delta)
	_hit_lock = maxf(0.0, _hit_lock - delta)
	velocity.x = move_axis() * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_strength
	move_and_slide()
	global_position.x = clamp(global_position.x, court_min_x, court_max_x)

# Axe de déplacement/visée : clavier (bonus dev) sinon boutons tactiles.
func move_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	return axis if absf(axis) >= 0.05 else touch_axis

# Appelé aussi par le bouton tactile SAUTER (BeachVolley.tscn).
func try_jump() -> void:
	if is_on_floor():
		velocity.y = -jump_strength

# Frappe active. Retourne la qualité (VolleyBall.QUALITY_*) ou -1 si raté.
func try_hit() -> int:
	if ball == null or ball.freeze:
		return -1
	if _hit_lock > 0.0:
		return -1
	var origin: Vector2 = global_position + HIT_ORIGIN_OFFSET
	var dist: float = origin.distance_to(ball.global_position)
	# Trop loin, ou balle déjà de l'autre côté du filet : fouetté dans le vide.
	if dist > HIT_SOFT_DIST or ball.global_position.x > 20.0:
		_hit_lock = HIT_LOCK
		return -1
	var quality: int = VolleyBall.QUALITY_SOFT
	if dist <= HIT_PERFECT_DIST:
		quality = VolleyBall.QUALITY_PERFECT
	elif dist <= HIT_GOOD_DIST:
		quality = VolleyBall.QUALITY_GOOD
	var target_x: float
	var pass_y: float
	match quality:
		VolleyBall.QUALITY_PERFECT:
			target_x = _aimed_target_x()
			pass_y = PASS_Y_PERFECT
		VolleyBall.QUALITY_GOOD:
			target_x = _aimed_target_x() + randf_range(-22.0, 22.0)
			pass_y = PASS_Y_GOOD
		_:
			# Molle : cloche centrale sans contrôle de visée — cadeau pour l'IA.
			target_x = randf_range(95.0, 150.0)
			pass_y = PASS_Y_SOFT
	ball.linear_velocity = ball.velocity_through(pass_y, Vector2(clampf(target_x, 30.0, 245.0), 0.0))
	ball.last_hit_quality = quality
	ball.hit_by.emit(0)
	# La réception automatique ne doit pas doubler la frappe si la trajectoire
	# repasse par le sensor.
	_bounce_cooldown = BOUNCE_COOLDOWN
	return quality

# Zone visée selon l'axe tenu à l'appui : ◀ amorti près du filet, ▶ long de
# ligne au fond, neutre = centre.
func _aimed_target_x() -> float:
	var axis: float = move_axis()
	if axis < -0.3:
		return TARGET_SHORT_X
	if axis > 0.3:
		return TARGET_DEEP_X
	return TARGET_CENTER_X

func _on_ball_entered(body: Node) -> void:
	if body != ball or _bounce_cooldown > 0.0:
		return
	_bounce_cooldown = BOUNCE_COOLDOWN
	# Réception : remonte la balle côté joueur, avec une dérive vers le filet
	# (l'intention de course du blob module la direction).
	ball.linear_velocity = Vector2(velocity.x * 0.3 - float(side_sign) * 45.0, -430.0)
	ball.last_hit_quality = VolleyBall.QUALITY_SOFT
	ball.hit_by.emit(0)
