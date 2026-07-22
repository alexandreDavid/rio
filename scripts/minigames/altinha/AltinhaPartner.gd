class_name AltinhaPartner
extends Node2D

# Visuel + petits gestes d'un parceiro de roda : silhouette détaillée via
# CharacterSpriteFactory (cf. préférence art > pixel-art chunky), indicateur
# "quente" 🔥 (celui à qui une passe Perfeito déclenche un geste técnico), et
# une petite animation de réception pour le feedback juteux.

@export var character_seed: int = 1000
@export var display_height: float = 46.0

const TECNICO_TEXTS: Array[String] = ["Bicicleta!", "Chapéu!", "Rabona!", "Lambreta!"]

var is_hot: bool = false

var _sprite: Sprite2D = null
var _hot_icon: Label = null

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var config: Dictionary = CharacterSpriteFactory.random_config(character_seed)
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.offset_left = -11.0
	shadow.offset_top = 2.0
	shadow.offset_right = 11.0
	shadow.offset_bottom = 8.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.name = "CharSprite"
	_sprite.texture = CharacterSpriteFactory.build_sheet(config)
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s: float = display_height / float(CharacterSpriteFactory.CELL_H)
	_sprite.scale = Vector2(s, s)
	_sprite.position = Vector2(0.0, -display_height * 0.5)
	add_child(_sprite)
	_hot_icon = Label.new()
	_hot_icon.text = "🔥"
	_hot_icon.add_theme_font_size_override("font_size", 22)
	_hot_icon.position = Vector2(-12.0, -display_height - 26.0)
	_hot_icon.visible = false
	_hot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hot_icon)

func set_hot(value: bool) -> void:
	is_hot = value
	if _hot_icon:
		_hot_icon.visible = value

# Petit squash-stretch à la réception — le geste "j'ai la balle".
func bounce() -> void:
	if _sprite == null:
		return
	var base: Vector2 = Vector2(display_height / float(CharacterSpriteFactory.CELL_H), display_height / float(CharacterSpriteFactory.CELL_H))
	_sprite.scale = base
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "scale", base * Vector2(1.18, 0.82), 0.08)
	tw.tween_property(_sprite, "scale", base, 0.14)

# Label flottant du geste técnico (bicicleta/chapéu…), déclenché par une passe
# Perfeito visée sur ce parceiro pendant qu'il est "quente".
func show_tecnico() -> void:
	var label: Label = Label.new()
	label.text = TECNICO_TEXTS[randi() % TECNICO_TEXTS.size()]
	label.z_index = 25
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = Vector2(-40.0, -display_height - 46.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 26.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)
