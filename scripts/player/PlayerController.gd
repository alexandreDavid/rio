class_name PlayerController
extends CharacterBody2D

# Mouvement top-down à la Pokémon. 8 directions (WASD). Collision via CharacterBody2D.

const WALK_SPEED: float = 80.0
const RUN_SPEED: float = 140.0

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var inventory: Node = $Inventory
@onready var stamina: Node = $Stamina
@onready var sprite: Sprite2D = $Visual/Sprite2D

var _facing: Vector2 = Vector2.DOWN
var _active_interactables: Array[Node] = []
var _current_interactable: Node = null
# Véhicule actuellement monté (Rideable). Null si à pied.
var _mounted_vehicle: Node = null

func _ready() -> void:
	add_to_group("player")
	GameManager.register_player(self)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_lost.connect(_on_interaction_lost)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	if camera:
		camera.make_current()
	print("[Player] spawned at ", global_position, " — camera current=", camera != null)

func _exit_tree() -> void:
	GameManager.unregister_player()

func _physics_process(delta: float) -> void:
	# Quand le joueur est sur un véhicule, le Rideable s'occupe du mouvement et
	# replace le joueur sur la selle ; on n'avance pas par nous-mêmes mais on
	# laisse le visual se rafraîchir (animation idle).
	if _mounted_vehicle:
		velocity = Vector2.ZERO
		_update_visual(delta)
		return
	var input: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	if input.length() > 0.01:
		input = input.normalized()
		_facing = input
	var speed: float = RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity = input * speed
	move_and_slide()
	_update_visual(delta)

# Appelé par Rideable.mount/dismount. Désactive la collision pour ne pas pousser
# le véhicule, masque rien (le sprite reste visible sur la selle).
func set_mounted(vehicle: Node) -> void:
	_mounted_vehicle = vehicle
	# Désactive la collision avec le monde tant qu'on est sur un véhicule
	# (le véhicule porte la collision pour les deux).
	collision_layer = 0 if vehicle else 1
	collision_mask = 0 if vehicle else 1
	# Ignore les interactions tant qu'on conduit (sauf le E du Rideable).
	set_process_unhandled_input(vehicle == null)
	if vehicle:
		velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		print("[Player] E pressed — interactable=", _current_interactable)
		if _current_interactable:
			_current_interactable.interact(self)

const ANIM_ROW: Dictionary = {
	"down": 0,
	"up": 1,
	"left": 2,
	"right": 3,
}
const WALK_CYCLE: Array = [0, 1, 2, 3]
const ANIM_FPS: float = 8.0
const TARGET_DISPLAY_SIZE: float = 48.0

var _anim_accum: float = 0.0
var _content_rect: Rect2 = Rect2()
var _cell_w: float = 0.0
var _cell_h: float = 0.0
var _frame_center_x: Array = []
var _char_height: float = 200.0  # hauteur réelle du perso (pas du cell) pour scale
var _frames_scanned: bool = false

func _scan_content_bounds() -> void:
	if sprite == null or sprite.texture == null:
		return
	var image: Image = sprite.texture.get_image()
	if image == null:
		return
	var img_w: int = image.get_width()
	var img_h: int = image.get_height()
	# Boîte globale
	var g_min_x: int = img_w
	var g_min_y: int = img_h
	var g_max_x: int = 0
	var g_max_y: int = 0
	for y in img_h:
		for x in img_w:
			if image.get_pixel(x, y).a > 0.05:
				if x < g_min_x: g_min_x = x
				if y < g_min_y: g_min_y = y
				if x > g_max_x: g_max_x = x
				if y > g_max_y: g_max_y = y
	if g_max_x < g_min_x or g_max_y < g_min_y:
		return
	_content_rect = Rect2(g_min_x, g_min_y, g_max_x - g_min_x + 1, g_max_y - g_min_y + 1)
	_cell_w = _content_rect.size.x / 4.0
	_cell_h = _content_rect.size.y / 4.0

	# Scan per-frame : centre X + hauteur réelle du perso
	_frame_center_x.clear()
	var max_char_height: int = 0
	for row in 4:
		for col in 4:
			var cell_x: int = int(_content_rect.position.x + col * _cell_w)
			var cell_y: int = int(_content_rect.position.y + row * _cell_h)
			var cell_w_i: int = int(_cell_w)
			var cell_h_i: int = int(_cell_h)
			var min_x: int = cell_x + cell_w_i
			var max_x: int = cell_x
			var min_y: int = cell_y + cell_h_i
			var max_y: int = cell_y
			for y in range(cell_y, cell_y + cell_h_i):
				for x in range(cell_x, cell_x + cell_w_i):
					if image.get_pixel(x, y).a > 0.05:
						if x < min_x: min_x = x
						if x > max_x: max_x = x
						if y < min_y: min_y = y
						if y > max_y: max_y = y
			var char_cx: float
			if max_x >= min_x:
				char_cx = (min_x + max_x) / 2.0
			else:
				char_cx = cell_x + _cell_w / 2.0
			_frame_center_x.append(char_cx)
			if max_y >= min_y:
				var h: int = max_y - min_y + 1
				if h > max_char_height:
					max_char_height = h
	if max_char_height > 0:
		_char_height = float(max_char_height)
	_frames_scanned = true
	print("[Player] content=%s cells=%sx%s char_height=%s" % [_content_rect, _cell_w, _cell_h, _char_height])

func _update_visual(delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	if not _frames_scanned:
		_scan_content_bounds()
		if not _frames_scanned:
			return
		# Scale basé sur la hauteur RÉELLE du perso (pas le cell), pour coller à la taille des NPCs
		var target_scale: float = TARGET_DISPLAY_SIZE / _char_height
		sprite.scale = Vector2(target_scale, target_scale)
	var dir_name: String = _direction_name()
	var moving: bool = velocity.length() > 10.0
	if moving:
		_anim_accum += delta * ANIM_FPS
	else:
		_anim_accum = 0.0
	var cycle_pos: int = int(_anim_accum) % WALK_CYCLE.size()
	var frame_idx: int = WALK_CYCLE[cycle_pos]
	var row: int = ANIM_ROW.get(dir_name, 0)
	# Utilise le centre X réel du perso dans cette frame (compense le stride AI)
	var frame_i: int = row * 4 + frame_idx
	var char_cx: float = _frame_center_x[frame_i] if frame_i < _frame_center_x.size() else _content_rect.position.x + frame_idx * _cell_w + _cell_w / 2.0
	sprite.region_rect = Rect2(
		char_cx - _cell_w / 2.0,
		_content_rect.position.y + row * _cell_h,
		_cell_w,
		_cell_h
	)

func _direction_name() -> String:
	if abs(_facing.x) > abs(_facing.y):
		return "right" if _facing.x > 0 else "left"
	return "down" if _facing.y > 0 else "up"

func _on_interaction_available(node: Node) -> void:
	if node and not _active_interactables.has(node):
		_active_interactables.append(node)
	_refresh_current()

func _on_interaction_lost(node: Node) -> void:
	_active_interactables.erase(node)
	_refresh_current()

func _on_interaction_unavailable() -> void:
	_active_interactables.clear()
	_refresh_current()

func _refresh_current() -> void:
	# Purge les références invalides (nodes freed) puis prend la plus récente.
	for i in range(_active_interactables.size() - 1, -1, -1):
		if not is_instance_valid(_active_interactables[i]):
			_active_interactables.remove_at(i)
	_current_interactable = _active_interactables.back() if _active_interactables.size() > 0 else null

func _on_dialogue_started(_npc_id: String) -> void:
	print("[Player] _on_dialogue_started → freeze")
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)

func _on_dialogue_ended(_npc_id: String) -> void:
	print("[Player] _on_dialogue_ended → unfreeze")
	set_physics_process(true)
	set_process_unhandled_input(true)
