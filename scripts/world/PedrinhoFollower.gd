class_name PedrinhoFollower
extends Node2D

# Pedrinho retrouvé : il suit le joueur dans le morro jusqu'à ce qu'on le
# rende à sa mère (VizinhaSpot, variante prologue_reunion). Apparaît quand le
# flag `pedrinho_following` est posé (par PedrinhoSpot à la citerne) et
# disparaît une fois le prologue terminé (il est rentré).
#
# Rendu : CharacterSpriteFactory, même style que les NPCs / spots (un gamin).

@export var character_seed: int = 70407

const _Factory: Script = preload("res://scripts/world/CharacterSpriteFactory.gd")

# Distance à laquelle il trotte derrière le joueur (il « reste derrière »).
const FOLLOW_GAP: float = 26.0
const FOLLOW_SPEED: float = 78.0

var _joined: bool = false

func _ready() -> void:
	_build_sprite()
	visible = false
	set_process(true)

func _build_sprite() -> void:
	if get_node_or_null("CharSprite") != null:
		return
	var config: Dictionary = _Factory.random_config(character_seed)
	var ch: int = _Factory.CELL_H
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "CharShadow"
	shadow.offset_left = -10.0
	shadow.offset_top = 3.0
	shadow.offset_right = 10.0
	shadow.offset_bottom = 8.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	add_child(shadow)
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "CharSprite"
	spr.texture = _Factory.build_sheet(config)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, _Factory.CELL_W, ch)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Gamin : un peu plus petit que les adultes (~38 px de haut).
	var s: float = 38.0 / float(ch)
	spr.scale = Vector2(s, s)
	spr.position = Vector2(0, -19.0)
	add_child(spr)

func _process(delta: float) -> void:
	var active: bool = CampaignManager.has_flag("pedrinho_following") \
			and not QuestManager.is_completed("prologue_pedrinho")
	visible = active
	if not active:
		_joined = false
		return
	var player: Node = GameManager.player
	if player == null or not is_instance_valid(player):
		return
	var pp: Vector2 = (player as Node2D).global_position
	# Il « rejoint » le joueur là où on l'a trouvé, puis trotte derrière.
	if not _joined:
		global_position = pp + Vector2(0, FOLLOW_GAP)
		_joined = true
		return
	if global_position.distance_to(pp) > FOLLOW_GAP:
		global_position = global_position.move_toward(pp, FOLLOW_SPEED * delta)
	var spr: Sprite2D = get_node_or_null("CharSprite") as Sprite2D
	if spr:
		spr.flip_h = pp.x < global_position.x
