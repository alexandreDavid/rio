class_name NPCPatrol
extends Node

# Composant à placer comme enfant d'un CharacterBody2D.
# Le parent patrouille entre point_a et point_b, avec pause aux extrémités.
# Se fige pendant les dialogues pour ne pas que les NPCs s'enfuient.

@export var point_a: Vector2
@export var point_b: Vector2
@export var speed: float = 30.0
@export var pause_seconds: float = 1.2

var _target: Vector2
var _paused_until: float = 0.0
var _body: CharacterBody2D
var _frozen: bool = false
var _sprite: Sprite2D = null
var _bob_phase: float = 0.0
var _sprite_base_y: float = 0.0
var _has_walk_sheet: bool = false  # parent NPC dispose d'un sprite-sheet 3×3 avec play_walk
var _is_walking: bool = false      # patrouille en mouvement (vs paused)
var _last_dir_x: float = 0.0       # détecte les changements de direction

func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("NPCPatrol doit être enfant d'un CharacterBody2D")
		return
	if point_a == Vector2.ZERO:
		point_a = _body.global_position
	if point_b == Vector2.ZERO:
		point_b = point_a + Vector2(80, 0)
	_target = point_b
	_body.collision_mask = 0
	_sprite = _body.get_node_or_null("Sprite2D") as Sprite2D
	if _sprite:
		_sprite_base_y = _sprite.position.y
		# Si le sprite a une grille (chargé depuis un walk-sheet par NPC.try_load_sprite),
		# on délègue l'animation à play_walk/stop_walk du parent NPC.
		_has_walk_sheet = _sprite.hframes > 1 and _body.has_method("play_walk")
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	print("[NPCPatrol:%s] ready — from %s to %s, walk_sheet=%s" % [_body.name, point_a, point_b, _has_walk_sheet])

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	if _frozen:
		_body.velocity = Vector2.ZERO
		_stop_anim(delta)
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _paused_until:
		_body.velocity = Vector2.ZERO
		_stop_anim(delta)
		return
	var to_target: Vector2 = _target - _body.global_position
	if to_target.length() < 4.0:
		_target = point_a if _target == point_b else point_b
		_paused_until = now + pause_seconds
		_body.velocity = Vector2.ZERO
		_stop_anim(delta)
		return
	var dir: Vector2 = to_target.normalized()
	_body.velocity = dir * speed
	_body.move_and_slide()
	# Animation : walk-sheet si dispo, sinon fallback flip+bob.
	if _has_walk_sheet:
		# play_walk uniquement quand la direction change, pour ne pas relancer le tween.
		var dx_sign: float = sign(dir.x)
		if dx_sign != _last_dir_x:
			var npc_dir: int = 2 if dx_sign > 0 else 3  # NPC.Direction.RIGHT / LEFT
			_body.call("play_walk", npc_dir)
			_last_dir_x = dx_sign
			_is_walking = true
	else:
		if _sprite:
			if abs(dir.x) > 0.1:
				_sprite.flip_h = dir.x < 0
			_bob_phase += delta * 12.0
			_sprite.position.y = _sprite_base_y + sin(_bob_phase) * 2.5

func _stop_anim(delta: float) -> void:
	if _has_walk_sheet:
		if _is_walking and _body.has_method("stop_walk"):
			_body.call("stop_walk")
		_is_walking = false
		_last_dir_x = 0.0
	elif _sprite:
		_sprite.position.y = lerp(_sprite.position.y, _sprite_base_y, 12.0 * delta)
		_bob_phase = 0.0

func _on_dialogue_started(_id: String) -> void:
	_frozen = true
	if _body:
		_body.velocity = Vector2.ZERO
	_stop_anim(0.0)

func _on_dialogue_ended(_id: String) -> void:
	_frozen = false
