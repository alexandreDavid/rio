class_name PlayerController
extends CharacterBody2D

# Mouvement top-down à la Pokémon. 8 directions (WASD). Collision via CharacterBody2D.

const WALK_SPEED: float = 80.0
const RUN_SPEED: float = 140.0

# Sprint sous stamina : courir draine, marcher récupère. À sec → essoufflé
# (forcé de marcher) jusqu'à re-remplir un quart de la jauge. C'est ce qui rend
# les courses-poursuites (cobrador) et livraisons chronométrées tendues.
const RUN_DRAIN_PER_SEC: float = 7.0
const STAMINA_RECOVER_PER_SEC: float = 14.0
const WINDED_RECOVER_RATIO: float = 0.25
var _winded: bool = false

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
	var dust: FootDust = FootDust.new()
	dust.name = "FootDust"
	add_child(dust)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_lost.connect(_on_interaction_lost)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.altinha_requested.connect(_on_altinha_requested)
	# Sécurité : si une save a été faite pendant un freeze (cutscene ou
	# dialogue interrompu), au reload on s'assure que le joueur est éveillé.
	if SaveSystem.has_signal("save_loaded"):
		SaveSystem.save_loaded.connect(_on_save_loaded)
	if camera:
		camera.make_current()
	apply_appearance()

func _on_save_loaded() -> void:
	# Si aucun dialogue/cutscene n'est actif au reload, on force l'éveil pour
	# parer aux saves faites pendant un freeze.
	# L'apparence restaurée par la save doit re-render le sprite.
	apply_appearance()
	if not DialogueBridge.is_active() and not CutsceneRunner.is_running():
		set_physics_process(true)
		set_process_unhandled_input(true)
		velocity = Vector2.ZERO

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
	var stam: Stamina = stamina as Stamina
	if _winded and stam and stam.ratio() >= WINDED_RECOVER_RATIO:
		_winded = false
	var running: bool = Input.is_action_pressed("run") and input.length() > 0.01 \
		and not _winded and (stam == null or not stam.is_exhausted())
	if stam:
		if running:
			stam.drain(RUN_DRAIN_PER_SEC * delta)
			if stam.is_exhausted():
				_winded = true
		else:
			stam.recover(STAMINA_RECOVER_PER_SEC * delta)
	var speed: float = RUN_SPEED if running else WALK_SPEED
	velocity = input * speed
	move_and_slide()
	_update_visual(delta)
	# Footsteps : AudioManager accumule la distance et émet un step toutes les ~24 px.
	AudioManager.notify_player_position(global_position, _current_surface())

# Surface dominante par district pour choisir le bon SFX de pas. Heuristique
# simple par district — pas de détection par tile y, on garde ça léger.
func _current_surface() -> String:
	var d: String = DistrictManager.current()
	match d:
		"copacabana", "zona_sul":
			return "sand"
		"corcovado", "aterro_flamengo":
			return "grass"
		_:
			return "road"

# Appelé par Rideable.mount/dismount. Désactive la collision pour ne pas pousser
# le véhicule, masque rien (le sprite reste visible sur la selle).
func set_mounted(vehicle: Node) -> void:
	_mounted_vehicle = vehicle
	# Désactive la collision avec le monde tant qu'on est sur un véhicule
	# (le véhicule porte la collision pour les deux).
	collision_layer = 0 if vehicle else 1
	# Couche 1 = murs/bâtiments ; couche 3 (bit 4) = surfaces d'eau navigables
	# au SUP uniquement. À pied, on bloque sur les deux. Sur véhicule, plus
	# rien (le véhicule porte sa propre collision).
	collision_mask = 0 if vehicle else (1 | 4)
	# Ignore les interactions tant qu'on conduit (sauf le E du Rideable).
	set_process_unhandled_input(vehicle == null)
	if vehicle:
		velocity = Vector2.ZERO

func is_mounted() -> bool:
	return _mounted_vehicle != null

# Altinha : le bouton ⚽ (MobileControls, visible sur le sable) lance le
# mini-jeu en scène additive — même pattern que les launchers (VolleyLauncher),
# mais sans prop dans le monde : la plage entière est le launcher.
const ALTINHA_SCENE_PATH: String = "res://scenes/minigames/Altinha.tscn"
var _altinha_game: Node = null
var _altinha_world_cache: Node = null
var _altinha_ui_cache: Node = null

func _on_altinha_requested() -> void:
	if _mounted_vehicle != null or _altinha_game != null:
		return
	var packed: PackedScene = load(ALTINHA_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[Player] scène altinha introuvable : " + ALTINHA_SCENE_PATH)
		return
	_altinha_game = packed.instantiate()
	var root: Node = get_tree().current_scene
	_altinha_world_cache = root.get_node_or_null("World")
	_altinha_ui_cache = root.get_node_or_null("UI")
	if _altinha_world_cache:
		_altinha_world_cache.visible = false
		_altinha_world_cache.process_mode = Node.PROCESS_MODE_DISABLED
	if _altinha_ui_cache:
		_altinha_ui_cache.visible = false
	root.add_child(_altinha_game)
	if _altinha_game.has_signal("match_ended"):
		_altinha_game.match_ended.connect(_on_altinha_ended)

func _on_altinha_ended(_qualifies: bool, _score: int) -> void:
	if _altinha_game:
		_altinha_game.queue_free()
		_altinha_game = null
	if _altinha_world_cache:
		_altinha_world_cache.visible = true
		_altinha_world_cache.process_mode = Node.PROCESS_MODE_INHERIT
		_altinha_world_cache = null
	if _altinha_ui_cache:
		_altinha_ui_cache.visible = true
		_altinha_ui_cache = null
	if camera:
		camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _current_interactable:
			_current_interactable.interact(self)

# Rendu via CharacterSpriteFactory : feuille 3×3 (lignes DOWN/UP/RIGHT, LEFT
# en miroir ; colonnes idle/stepL/stepR), cellule 16×24. Personnalisable via
# l'éditeur de perso (GameManager.player_appearance).
# Synchronisé avec la factory : si la résolution de cellule change, le joueur
# suit automatiquement (pas de double source de vérité).
const FACTORY_CELL_W: int = CharacterSpriteFactory.CELL_W
const FACTORY_CELL_H: int = CharacterSpriteFactory.CELL_H
const FACTORY_ROW_DOWN: int = 0
const FACTORY_ROW_UP: int = 1
const FACTORY_ROW_RIGHT: int = 2
# Cycle de marche 4 phases mappé sur les 3 colonnes (idle, stepL, idle, stepR).
const FACTORY_WALK_CYCLE: Array[int] = [0, 1, 0, 2]
const ANIM_FPS: float = 8.0
const TARGET_DISPLAY_SIZE: float = 48.0

var _anim_accum: float = 0.0

# (Re)construit la feuille du joueur depuis l'apparence courante et l'applique
# au Sprite2D. Appelé à _ready, après un load (save_loaded), et live par
# l'éditeur de perso (via GameManager.set_player_appearance).
func apply_appearance() -> void:
	if sprite == null:
		return
	var config: Dictionary = CharacterSpriteFactory.config_from_indices(GameManager.effective_appearance())
	sprite.texture = CharacterSpriteFactory.build_sheet(config)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, FACTORY_CELL_W, FACTORY_CELL_H)
	sprite.hframes = 1
	sprite.vframes = 1
	# NEAREST : pixel-art natif (style GBA) — les texels restent nets.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Cellule réduite à TARGET_DISPLAY_SIZE px de haut à l'écran.
	var sf: float = TARGET_DISPLAY_SIZE / float(FACTORY_CELL_H)
	sprite.scale = Vector2(sf, sf)
	_update_visual(0.0)

func _update_visual(delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var dir_name: String = _direction_name()
	var moving: bool = velocity.length() > 10.0
	if moving:
		_anim_accum += delta * ANIM_FPS
	else:
		_anim_accum = 0.0
	var col: int = 0
	if moving:
		col = FACTORY_WALK_CYCLE[int(_anim_accum) % FACTORY_WALK_CYCLE.size()]
	var row: int = FACTORY_ROW_DOWN
	match dir_name:
		"up":    row = FACTORY_ROW_UP
		"down":  row = FACTORY_ROW_DOWN
		"right": row = FACTORY_ROW_RIGHT
		"left":  row = FACTORY_ROW_RIGHT  # miroir horizontal
	sprite.flip_h = (dir_name == "left")
	sprite.region_rect = Rect2(
		col * FACTORY_CELL_W,
		row * FACTORY_CELL_H,
		FACTORY_CELL_W,
		FACTORY_CELL_H
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
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)

func _on_dialogue_ended(_npc_id: String) -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
