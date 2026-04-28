class_name Rideable
extends CharacterBody2D

# Véhicule conduisible : vélo, voiture, ou SUP. Le joueur "monte" via E quand il
# est dans la zone d'interaction. Pendant la conduite, sa physique est désactivée
# mais son sprite reste visible (PlayerSeat). E à nouveau pour descendre.

@export var vehicle_id: String = "bike"
@export var max_speed: float = 180.0
@export var acceleration: float = 420.0
@export var friction: float = 240.0
@export var drift: Vector2 = Vector2.ZERO  # courant constant (SUP)
@export var prompt_mount: String = "Monter (E)"
@export var prompt_dismount: String = "Descendre (E)"
@export var stamina_drain: float = 0.0  # /s
# Si > 0, modifie l'angle de rotation visuelle vers le déplacement (pour la voiture).
@export var rotate_visual: bool = false
@export var rotate_speed: float = 6.0

@onready var interactable: Interactable = $Interactable
@onready var seat: Marker2D = $PlayerSeat
@onready var dismount_point: Marker2D = $DismountPoint
@onready var visual: Node2D = $Visual

var _ridden_by: Node = null
# Frame d'application du mount, pour empêcher le même press E de redéclencher
# un dismount immédiat (l'event passe par le Player puis arrive ici).
var _mount_frame: int = -1

func _ready() -> void:
	if interactable:
		interactable.prompt = prompt_mount
		interactable.interacted.connect(_on_interact)
	set_physics_process(false)

func is_ridden() -> bool:
	return _ridden_by != null

func _on_interact(by: Node) -> void:
	if _ridden_by:
		return
	mount(by)

# --- Mount / dismount ---

func mount(player: Node) -> void:
	if _ridden_by or player == null:
		return
	if not (player is CharacterBody2D):
		return
	_ridden_by = player
	if seat:
		player.global_position = seat.global_position
	if player.has_method("set_mounted"):
		player.set_mounted(self)
	if interactable:
		interactable.prompt = prompt_dismount
	_mount_frame = Engine.get_process_frames()
	set_physics_process(true)

func dismount() -> void:
	if _ridden_by == null:
		return
	var player: Node = _ridden_by
	_ridden_by = null
	if dismount_point and player is CharacterBody2D:
		(player as CharacterBody2D).global_position = dismount_point.global_position
	if player.has_method("set_mounted"):
		player.set_mounted(null)
	if interactable:
		interactable.prompt = prompt_mount
	velocity = Vector2.ZERO
	set_physics_process(false)

# --- Conduite ---

func _physics_process(delta: float) -> void:
	if _ridden_by == null:
		return
	var input: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var target: Vector2 = input * max_speed
	if input.length() > 0.01:
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	velocity += drift * delta
	move_and_slide()
	# Le joueur suit la selle.
	if _ridden_by is CharacterBody2D and seat:
		(_ridden_by as CharacterBody2D).global_position = seat.global_position
	# Rotation visuelle vers la direction (voiture).
	if rotate_visual and visual and velocity.length() > 5.0:
		var target_angle: float = velocity.angle()
		visual.rotation = lerp_angle(visual.rotation, target_angle, rotate_speed * delta)
	# Drain de stamina.
	if stamina_drain > 0.0 and _ridden_by:
		var stam: Stamina = _ridden_by.get_node_or_null("Stamina") as Stamina
		if stam:
			stam.drain(stamina_drain * delta)

func _unhandled_input(event: InputEvent) -> void:
	if _ridden_by == null:
		return
	# Ignore le E de la frame de montée — sinon le même press déclenche aussi le dismount.
	if Engine.get_process_frames() == _mount_frame:
		return
	if event.is_action_pressed("interact"):
		dismount()
