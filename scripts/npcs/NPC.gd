class_name NPC
extends CharacterBody2D

@export var data: NPCData
@export var interactable: Interactable

# Constantes d'animation d'interaction.
const PUNCH_SCALE: float = 1.12
const PUNCH_DURATION: float = 0.18

# Si un PNG individuel est trouvé à res://assets/sprites/npcs/<id>.png, on l'utilise
# à la place de la région de l'atlas. Le sprite est alors auto-redimensionné pour
# faire SPRITE_TARGET_HEIGHT pixels de haut à l'écran — calé sur la taille du joueur
# (sprite player 256×256 × scale 0.1875 = 48 px) pour des proportions homogènes.
const SPRITE_TARGET_HEIGHT: float = 48.0
const NPC_SPRITES_DIR: String = "res://assets/sprites/npcs/"

# Sprite-sheet 3 colonnes × 3 lignes (9 cellules) :
#   Colonne 0 = idle (stoppé dans la direction)
#   Colonne 1 = pas (gauche)
#   Colonne 2 = pas (droite)
#   Ligne 0 = DOWN (face caméra) / 1 = UP (de dos) / 2 = RIGHT
# La direction LEFT est obtenue en flippant horizontalement la ligne RIGHT.
enum Direction { DOWN = 0, UP = 1, RIGHT = 2, LEFT = 3 }
const FRAMES_PER_DIRECTION: int = 3
const SHEET_ROWS: int = 3  # 3 directions stockées (LEFT = flip de RIGHT)
const WALK_FRAME_DURATION: float = 0.18

var _sprite: Node = null
var _sprite_base_scale: Vector2 = Vector2.ONE
var _has_walk_sheet: bool = false
var _facing: int = Direction.DOWN
var _walk_tween: Tween = null

func _ready() -> void:
	# Fallback si @export n'a pas résolu (hérédité de scène + script override).
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = "Parler"
		interactable.interacted.connect(_on_interacted)
	else:
		push_error("[NPC:%s] PAS D'INTERACTABLE — l'enfant 'Interactable' est introuvable" % name)
	# Positionnement dynamique : si le NPC a un id déclaré, il est piloté par le scheduler.
	if data and data.id != "":
		NPCScheduler.register(data.id, self)
	_setup_visual_polish()
	_setup_quest_indicator()

# --- Indicateur de quête style Pokemon ("!" au-dessus de la tête) ---

const QI_FONT_SIZE: int = 22
const QI_OFFSET_Y: float = -52.0
const QI_BOB_AMPLITUDE: float = 2.5
const QI_VISIBLE_DISTANCE: float = 140.0
const QI_CHECK_INTERVAL: float = 0.4   # throttle : check distance + état tous les 0.4s

var _qi_label: Label = null
var _qi_has_available: bool = false
var _qi_last_check: float = 0.0

func _setup_quest_indicator() -> void:
	# Un seul Label visuel, créé en code pour ne pas modifier la scène NPC.
	_qi_label = Label.new()
	_qi_label.name = "QuestIndicator"
	_qi_label.text = "!"
	_qi_label.position = Vector2(-6.0, QI_OFFSET_Y)
	_qi_label.add_theme_font_size_override("font_size", QI_FONT_SIZE)
	_qi_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1))
	_qi_label.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.05, 0.95))
	_qi_label.add_theme_constant_override("outline_size", 3)
	_qi_label.z_index = 100
	_qi_label.visible = false
	add_child(_qi_label)
	# Refresh sur les transitions d'état des quêtes (accept/complete).
	EventBus.quest_accepted.connect(_qi_refresh_availability)
	EventBus.quest_completed.connect(_qi_refresh_availability)
	EventBus.act_changed.connect(_qi_refresh_availability_from_act)
	_qi_refresh_availability("")

func _qi_refresh_availability(_quest_id: String) -> void:
	if data == null or data.id == "":
		_qi_has_available = false
		return
	# Cherche une quête disponible dont le NPC est le giver.
	_qi_has_available = false
	for q in QuestManager._quests.values():
		if q is Quest and (q as Quest).giver_npc_id == data.id and QuestManager.is_available((q as Quest).id):
			_qi_has_available = true
			break

func _qi_refresh_availability_from_act(_act: int) -> void:
	# Les quêtes peuvent devenir disponibles au passage d'acte (gating required_act).
	_qi_refresh_availability("")

func _process(_delta: float) -> void:
	if _qi_label == null:
		return
	# Throttle des checks : 2-3 fois par seconde suffit pour le visuel.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _qi_last_check >= QI_CHECK_INTERVAL:
		_qi_last_check = now
		var should_show: bool = _qi_has_available and _qi_player_nearby()
		if should_show != _qi_label.visible:
			_qi_label.visible = should_show
	# Bob vertical pour attirer l'œil quand visible.
	if _qi_label.visible:
		_qi_label.position.y = QI_OFFSET_Y + sin(now * 5.0) * QI_BOB_AMPLITUDE

func _qi_player_nearby() -> bool:
	if GameManager.player == null:
		return false
	return global_position.distance_to(GameManager.player.global_position) <= QI_VISIBLE_DISTANCE

# Si vrai, tous les NPCs utilisent le sprite procédural pixel-art généré par
# PokemonSpriteFactory (config explicite par id, fallback aléatoire stable).
# Cohérence visuelle : même style que les wanderers.
const USE_PROCEDURAL_NPC_SPRITES: bool = true

func _setup_visual_polish() -> void:
	# Repère le sprite principal pour le scale-punch d'interaction.
	_sprite = get_node_or_null("Sprite2D")
	# Mode procédural : génère le sprite via la factory.
	if USE_PROCEDURAL_NPC_SPRITES and _sprite is Sprite2D and data and data.id != "":
		_setup_procedural_sprite()
	else:
		# Sinon : tente de charger un PNG individuel (fallback historique).
		_try_load_individual_sprite()
	if _sprite is Node2D:
		_sprite_base_scale = (_sprite as Node2D).scale
	_spawn_shadow()

# Génère et applique un sprite pixel-art via PokemonSpriteFactory. Le NPC
# affiche par défaut sa cellule DOWN/idle (1ère colonne, 1ère ligne).
const PROCEDURAL_CELL_W: int = 16
const PROCEDURAL_CELL_H: int = 24

func _setup_procedural_sprite() -> void:
	var spr: Sprite2D = _sprite as Sprite2D
	var factory: GDScript = preload("res://scripts/world/PokemonSpriteFactory.gd")
	var config: Dictionary = factory.config_for_npc(data.id)
	var sheet: ImageTexture = factory.build_sheet(config)
	spr.texture = sheet
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, PROCEDURAL_CELL_W, PROCEDURAL_CELL_H)
	# Scale pour matcher SPRITE_TARGET_HEIGHT (48 px) : 24 px source × 2 = 48.
	var s: float = SPRITE_TARGET_HEIGHT / float(PROCEDURAL_CELL_H)
	spr.scale = Vector2(s, s)
	# Désactive le filtrage pour garder le pixel chunky (pixel-perfect look).
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Helper static : charge un sprite individuel (idle ou walk-sheet 3×3) depuis
# assets/sprites/npcs/<id>.png ou <id>_walk.png et l'applique au Sprite2D fourni.
# Renvoie true si une texture a été chargée, false sinon (pas de fichier).
# Utilisable depuis n'importe quel script (PMPatrol, Customer…).
static func try_load_sprite(sprite: Sprite2D, npc_id: String, target_height: float = 48.0) -> bool:
	if sprite == null or npc_id == "":
		return false
	var walk_path: String = "%s%s_walk.png" % [NPC_SPRITES_DIR, npc_id]
	var idle_path: String = "%s%s.png" % [NPC_SPRITES_DIR, npc_id]
	var path: String = ""
	var is_walk_sheet: bool = false
	if ResourceLoader.exists(walk_path):
		path = walk_path
		is_walk_sheet = true
	elif ResourceLoader.exists(idle_path):
		path = idle_path
	else:
		return false
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return false
	sprite.texture = tex
	sprite.region_enabled = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_walk_sheet:
		sprite.hframes = FRAMES_PER_DIRECTION
		sprite.vframes = SHEET_ROWS
		sprite.frame = 0
	else:
		sprite.hframes = 1
		sprite.vframes = 1
	var cell_h: float = float(tex.get_height()) / (float(SHEET_ROWS) if is_walk_sheet else 1.0)
	if cell_h > 0.0:
		var s: float = target_height / cell_h
		sprite.scale = Vector2(s, s)
	return true

func _try_load_individual_sprite() -> void:
	if data == null or data.id == "" or not (_sprite is Sprite2D):
		return
	# Priorité : sprite-sheet de marche, sinon sprite idle simple.
	var walk_path: String = "%s%s_walk.png" % [NPC_SPRITES_DIR, data.id]
	var idle_path: String = "%s%s.png" % [NPC_SPRITES_DIR, data.id]
	var path: String = ""
	var is_walk_sheet: bool = false
	if ResourceLoader.exists(walk_path):
		path = walk_path
		is_walk_sheet = true
	elif ResourceLoader.exists(idle_path):
		path = idle_path
	else:
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.texture = tex
	sprite.region_enabled = false
	# NEAREST : garde les pixels nets quand on scale (sinon Godot floute par défaut).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sheet 3 cols × 3 rows : on cale hframes/vframes et on démarre en idle face caméra.
	if is_walk_sheet:
		sprite.hframes = FRAMES_PER_DIRECTION  # 3
		sprite.vframes = SHEET_ROWS            # 3
		sprite.frame = int(Direction.DOWN) * FRAMES_PER_DIRECTION
		_has_walk_sheet = true
	else:
		sprite.hframes = 1
		sprite.vframes = 1
	# Redimensionne pour matcher la hauteur cible : cellule = tex.height / SHEET_ROWS.
	var cell_h: float = float(tex.get_height()) / (float(SHEET_ROWS) if is_walk_sheet else 1.0)
	if cell_h > 0.0:
		var s: float = SPRITE_TARGET_HEIGHT / cell_h
		sprite.scale = Vector2(s, s)

func _spawn_shadow() -> void:
	# Ombre ovale plate sous le NPC pour l'ancrer au sol.
	if get_node_or_null("Shadow") != null:
		return
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.offset_left = -14.0
	shadow.offset_top = 6.0
	shadow.offset_right = 14.0
	shadow.offset_bottom = 12.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	# Ajouté en premier pour passer SOUS les autres enfants visuels.
	add_child(shadow)
	move_child(shadow, 0)

func _punch_scale() -> void:
	if not (_sprite is Node2D):
		return
	var node: Node2D = _sprite as Node2D
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", _sprite_base_scale * PUNCH_SCALE, PUNCH_DURATION * 0.4)
	t.tween_property(node, "scale", _sprite_base_scale, PUNCH_DURATION * 0.6)

# --- API d'animation walk-sheet (no-op si <id>_walk.png absent) ---

# Renvoie la ligne stockée + le flip nécessaire pour afficher une direction.
# LEFT n'est pas dessiné : on prend la ligne RIGHT et on flippe horizontalement.
func _row_and_flip_for(dir: int) -> Array:
	if dir == Direction.LEFT:
		return [Direction.RIGHT, true]
	return [dir, false]

# Tourne le NPC vers une direction, sans le faire marcher.
func face(dir: int) -> void:
	if not _has_walk_sheet or not (_sprite is Sprite2D):
		return
	stop_walk()
	_facing = dir
	var info: Array = _row_and_flip_for(dir)
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.flip_h = info[1]
	sprite.frame = int(info[0]) * FRAMES_PER_DIRECTION

# Boucle l'animation de marche dans la direction donnée jusqu'à un stop_walk().
# Cycle : pas-gauche → idle → pas-droit → idle (mouvement à 4 temps avec 3 frames).
func play_walk(dir: int) -> void:
	if not _has_walk_sheet or not (_sprite is Sprite2D):
		return
	stop_walk()
	_facing = dir
	var info: Array = _row_and_flip_for(dir)
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.flip_h = info[1]
	var base: int = int(info[0]) * FRAMES_PER_DIRECTION
	var idle_f: int = base + 0
	var step_l: int = base + 1
	var step_r: int = base + 2
	_walk_tween = create_tween().set_loops()
	_walk_tween.tween_callback(func(): sprite.frame = step_l)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = idle_f)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = step_r)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = idle_f)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)

# Stoppe l'animation de marche et revient sur la frame idle de la direction courante.
func stop_walk() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()
	_walk_tween = null
	if _has_walk_sheet and _sprite is Sprite2D:
		var info: Array = _row_and_flip_for(_facing)
		var sprite: Sprite2D = _sprite as Sprite2D
		sprite.flip_h = info[1]
		sprite.frame = int(info[0]) * FRAMES_PER_DIRECTION

func _exit_tree() -> void:
	stop_walk()
	if data and data.id != "":
		NPCScheduler.unregister(data.id)

func _on_interacted(_by: Node) -> void:
	print("[NPC:%s] _on_interacted" % name)
	_punch_scale()
	if data == null or data.ink_knot == "":
		push_warning("NPC %s: no data or ink_knot" % name)
		return
	DialogueBridge.start_dialogue(data.id, data.ink_knot)
