class_name VolleyBall
extends RigidBody2D

signal touched_ground(side_is_player: bool)
signal hit_by(team: int)

@export var net_x: float = 0.0
@export var x_bound: float = 280.0       # au-delà = sortie de terrain
@export var y_bound_bottom: float = 100.0 # sous le niveau du sol
@export var y_bound_top: float = -500.0   # plafond (éviter les balles envoyées à l'infini)

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
	_grounded = false

func freeze_ball() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

func unfreeze_ball() -> void:
	freeze = false

func apply_hit(direction: Vector2, power: float, team: int) -> void:
	linear_velocity = direction.normalized() * power
	hit_by.emit(team)

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
