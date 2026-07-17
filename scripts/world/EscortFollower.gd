class_name EscortFollower
extends Node2D

# Suiveur d'escorte générique — généralisation de PedrinhoFollower (la
# « résolution incarnée » du prologue) : un personnage marche physiquement
# derrière le joueur tant que `follow_flag` est posé et que `done_flag` ne
# l'est pas. Sert aux cortèges de mission (le Padre qui descend en campagne
# sur le calçadão, D8) — le trajet devient le moment, pas un fondu.
#
# Rendu : CharacterSpriteFactory, même style que les NPCs / spots.

@export var character_seed: int = 1
@export var follow_flag: String = ""      # il apparaît et suit quand ce flag est posé
@export var done_flag: String = ""        # il disparaît quand ce flag est posé
@export var target_height: float = 48.0   # adulte 48 px (gamin ~38)
@export var follow_gap: float = 30.0
@export var follow_speed: float = 82.0

const _Factory: Script = preload("res://scripts/world/CharacterSpriteFactory.gd")

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
	shadow.offset_left = -11.0
	shadow.offset_top = 3.0
	shadow.offset_right = 11.0
	shadow.offset_bottom = 8.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	add_child(shadow)
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "CharSprite"
	spr.texture = _Factory.build_sheet(config)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, _Factory.CELL_W, ch)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s: float = target_height / float(ch)
	spr.scale = Vector2(s, s)
	spr.position = Vector2(0, -target_height * 0.5)
	add_child(spr)

func _process(delta: float) -> void:
	var active: bool = follow_flag != "" and CampaignManager.has_flag(follow_flag) \
			and (done_flag == "" or not CampaignManager.has_flag(done_flag))
	visible = active
	if not active:
		_joined = false
		return
	var player: Node = GameManager.player
	if player == null or not is_instance_valid(player):
		return
	var pp: Vector2 = (player as Node2D).global_position
	# Il « rejoint » le joueur là où le cortège commence, puis marche derrière.
	if not _joined:
		global_position = pp + Vector2(0, follow_gap)
		_joined = true
		return
	if global_position.distance_to(pp) > follow_gap:
		global_position = global_position.move_toward(pp, follow_speed * delta)
	var spr: Sprite2D = get_node_or_null("CharSprite") as Sprite2D
	if spr:
		spr.flip_h = pp.x < global_position.x
