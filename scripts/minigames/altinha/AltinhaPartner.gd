class_name AltinhaPartner
extends Node2D

# Visuel + petits gestes d'un parceiro de roda : personnage CharacterSpriteFactory
# en pixels natifs ×3 (poses de touche repeintes par AltinhaArt), qui se tourne
# vers la balle, ginga sur place, flamme pixel et aura quand il est "quente"
# (celui à qui une passe Perfeito déclenche un geste técnico), et une pose de
# touche à la réception.

const Art := preload("res://scripts/minigames/altinha/AltinhaArt.gd")

@export var character_seed: int = 1000
@export var display_height: float = 96.0

const TECNICO_TEXTS: Array[String] = ["Bicicleta!", "Chapéu!", "Rabona!", "Lambreta!"]
const TOUCH_KEYS: Array[String] = ["down_knee", "down_head", "right_kick"]

var is_hot: bool = false

var _sprite: Sprite2D = null
var _poses: Dictionary = {}
var _flame: Sprite2D = null
var _flames: Array[Texture2D] = []
var _aura: Node2D = null
var _t: float = 0.0
var _touch_t: float = 0.0
var _touch_key: String = ""
var _look_x: float = 0.0
var _look_side: bool = false

func _ready() -> void:
	_t = float(character_seed % 7) * 0.37
	_build_visual()

func _build_visual() -> void:
	var config: Dictionary = CharacterSpriteFactory.random_config(character_seed)
	_poses = Art.poses(config)
	var k: float = display_height / float(CharacterSpriteFactory.CELL_H)
	_aura = Node2D.new()
	_aura.name = "Aura"
	_aura.z_index = -1
	_aura.visible = false
	_aura.draw.connect(_draw_aura)
	add_child(_aura)
	var shadow: Sprite2D = Art.shadow_sprite(9)
	shadow.scale *= k
	add_child(shadow)
	_sprite = Art.body_sprite(_poses, "down_0")
	_sprite.scale *= k
	add_child(_sprite)
	_flames = Art.flame_frames()
	_flame = Sprite2D.new()
	_flame.name = "Flame"
	_flame.texture = _flames[0]
	_flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flame.scale = Vector2(Art.PX, Art.PX)
	_flame.position = Vector2(0.0, -display_height - 20.0)
	_flame.visible = false
	add_child(_flame)

func _process(delta: float) -> void:
	_t += delta
	if _sprite == null:
		return
	if _touch_t > 0.0:
		_touch_t -= delta
		_sprite.texture = _poses[_touch_key]
		return
	if _look_side:
		_sprite.texture = _poses["right_0"]
		_sprite.flip_h = _look_x < position.x
	else:
		var seq: Array[int] = [0, 1, 0, 2]
		_sprite.texture = _poses["down_%d" % seq[int(_t * 3.0) % 4]]
		_sprite.flip_h = false
	if is_hot:
		_flame.texture = _flames[int(_t * 9.0) % _flames.size()]
		_flame.position.y = -display_height - 20.0 - (Art.PX if int(_t * 4.0) % 2 == 0 else 0.0)
		_aura.queue_redraw()

# Regarde la balle : de face quand elle vient vers lui ou vers le joueur, de
# profil quand elle file chez l'autre parceiro.
func look_toward(x: float, side: bool) -> void:
	_look_x = x
	_look_side = side

func set_hot(value: bool) -> void:
	is_hot = value
	if _flame:
		_flame.visible = value
	if _aura:
		_aura.visible = value

# Réception : pose de touche (genou / tête / pied) + petit squash.
func bounce() -> void:
	if _sprite == null:
		return
	_touch_key = TOUCH_KEYS[randi() % TOUCH_KEYS.size()]
	_touch_t = 0.28
	_sprite.flip_h = position.x > 0.0
	var base: Vector2 = Vector2(Art.PX, Art.PX) * display_height / float(CharacterSpriteFactory.CELL_H)
	_sprite.scale = base
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "scale", base * Vector2(1.0, 0.94), 0.06)
	tw.tween_property(_sprite, "scale", base, 0.12)

# Label flottant du geste técnico (bicicleta/chapéu…), déclenché par une passe
# Perfeito visée sur ce parceiro pendant qu'il est "quente".
func show_tecnico() -> void:
	_touch_key = "down_head"
	_touch_t = 0.45
	var label: Label = Label.new()
	label.text = TECNICO_TEXTS[randi() % TECNICO_TEXTS.size()]
	label.z_index = 25
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.04, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = Vector2(-70.0, -display_height - 30.0)
	label.pivot_offset = Vector2(70.0, 14.0)
	label.scale = Vector2(0.4, 0.4)
	var tw: Tween = create_tween()
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(label, "scale", Vector2.ONE, 0.08)
	tw.tween_property(label, "position:y", label.position.y - 26.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.tween_callback(label.queue_free)

# Aura du "quente" : anneau orange qui pulse sous les pieds.
func _draw_aura() -> void:
	var pulse: int = int(_t * 6.0) % 2
	var rx: int = 11 + pulse
	var ry: float = float(rx) * 0.4
	var px: float = Art.PX
	var seen: Dictionary = {}
	var n: int = rx * 8
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var q: Vector2i = Vector2i(int(round(cos(a) * float(rx))), int(round(sin(a) * ry)))
		if seen.has(q):
			continue
		seen[q] = true
		var c: Color = Color(1.0, 0.55, 0.12, 0.85) if (q.x + q.y + pulse) % 3 != 0 else Color(1.0, 0.88, 0.3, 0.9)
		_aura.draw_rect(Rect2(Vector2(q) * px - Vector2(px, px) * 0.5, Vector2(px, px)), c)
