class_name VolleyBall
extends RigidBody2D

signal touched_ground(side_is_player: bool)
signal hit_by(team: int)

# Qualité de la dernière frappe — posée par le frappeur, lue par l'IA pour
# choisir entre punir (balle molle) et sauver en cloche (frappe parfaite).
const QUALITY_NONE: int = 0
const QUALITY_SOFT: int = 1
const QUALITY_GOOD: int = 2
const QUALITY_PERFECT: int = 3

@export var net_x: float = 0.0
@export var x_bound: float = 280.0       # au-delà = sortie de terrain
@export var y_bound_bottom: float = 100.0 # sous le niveau du sol
@export var y_bound_top: float = -500.0   # plafond (éviter les balles envoyées à l'infini)

var last_hit_quality: int = QUALITY_NONE

var _grounded: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	contact_monitor = true
	if max_contacts_reported < 4:
		max_contacts_reported = 4

func reset_to(pos: Vector2) -> void:
	global_position = pos
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	last_hit_quality = QUALITY_NONE
	_grounded = false

func freeze_ball() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

func unfreeze_ball() -> void:
	freeze = false

func apply_hit(direction: Vector2, power: float, team: int) -> void:
	# Conservé pour rétrocompatibilité (anciens callers). Les blobs Player/AI
	# modifient directement `linear_velocity` (via velocity_through) sans passer ici.
	linear_velocity = direction.normalized() * power
	hit_by.emit(team)

# Vélocité balistique pour une trajectoire qui passe à (net_x, pass_y) puis
# retombe sur `target`. C'est la hauteur de passage qui fait la qualité :
# raser le filet = balle tendue et rapide, passer haut = cloche lente.
# La vitesse découle de la géométrie (contact haut → frappe naturellement
# plus tendue : sauter pour smasher paie tout seul).
func velocity_through(pass_y: float, target: Vector2) -> Vector2:
	var g: float = gravity_scale * float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var a: float = 0.5 * g
	var p0: Vector2 = global_position
	var dx_net: float = net_x - p0.x
	var dx_tgt: float = target.x - p0.x
	# Géométrie dégénérée (contact collé au filet, cible du mauvais côté…) :
	# cloche de secours vers la cible.
	if absf(dx_net) < 4.0 or signf(dx_net) != signf(dx_tgt) or absf(dx_tgt) <= absf(dx_net):
		return Vector2(signf(dx_tgt) * 160.0, -380.0)
	var k: float = dx_tgt / dx_net
	var d1: float = pass_y - p0.y
	var d2: float = target.y - p0.y
	var t1_sq: float = (d2 - k * d1) / (a * k * (k - 1.0))
	if t1_sq <= 0.0:
		return Vector2(signf(dx_tgt) * 160.0, -380.0)
	var t1: float = sqrt(t1_sq)
	var vel: Vector2 = Vector2(dx_net / t1, (d1 - a * t1_sq) / t1)
	# Garde-fou : jamais de balle supersonique (contact quasi collé au filet).
	if vel.length() > 900.0:
		vel = vel.normalized() * 900.0
	return vel

func _physics_process(_delta: float) -> void:
	if _grounded:
		return
	var pos: Vector2 = global_position
	# Sortie de terrain (trop loin latéralement, trop haut, trop bas)
	if abs(pos.x) > x_bound or pos.y > y_bound_bottom or pos.y < y_bound_top:
		_grounded = true
		var side_is_player: bool = pos.x < net_x
		print("[VolleyBall] OUT OF BOUNDS pos=%s side_is_player=%s" % [pos, side_is_player])
		touched_ground.emit(side_is_player)

func _on_body_entered(body: Node) -> void:
	if _grounded:
		return
	if body.is_in_group("ground"):
		_grounded = true
		var side_is_player: bool = global_position.x < net_x
		print("[VolleyBall] TOUCHED GROUND side_is_player=%s" % side_is_player)
		touched_ground.emit(side_is_player)
