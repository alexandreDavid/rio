class_name AmbientWanderer
extends Node2D

# Passant ambiant qui boucle entre 2 ou 3 points dans un district. Aucune
# interaction, aucun dialogue — juste de la vie d'arrière-plan. Le sprite est
# composé en code (tête + cheveux + buste + 2 jambes animées) à partir de la
# couleur principale et d'une teinte de peau configurable. Les jambes sont
# décalées en sens opposé pendant la marche, ce qui donne un cycle de pas
# crédible avec très peu de données.

@export var color: Color = Color(0.85, 0.55, 0.4, 1)
@export var skin_color: Color = Color(0.92, 0.78, 0.62, 1)
@export var hair_color: Color = Color(0.18, 0.12, 0.08, 1)
@export var size: Vector2 = Vector2(10, 18)
@export var path: Array[Vector2] = []
@export var speed: float = 28.0
@export var pause_at_waypoints: float = 1.4
@export var bob_strength: float = 1.2
@export var hat: bool = false
@export var hat_color: Color = Color(0.85, 0.85, 0.4, 1)

var _current: int = 0
var _state: int = 0  # 0 = move, 1 = pause
var _pause_until: float = 0.0
var _local_target: Vector2 = Vector2.ZERO
var _bob_t: float = 0.0
var _walk_t: float = 0.0
var _facing: int = 1  # 1 = right, -1 = left

@onready var sprite: Node2D = $Sprite
@onready var body: ColorRect = $Sprite/Body
@onready var head: ColorRect = $Sprite/Head
@onready var hair: ColorRect = $Sprite/Hair
@onready var hat_rect: ColorRect = $Sprite/Hat
@onready var leg_l: ColorRect = $Sprite/LegL
@onready var leg_r: ColorRect = $Sprite/LegR
@onready var arm_l: ColorRect = $Sprite/ArmL
@onready var arm_r: ColorRect = $Sprite/ArmR
@onready var shadow: ColorRect = $Shadow

func _ready() -> void:
	_layout_sprite()
	if path.is_empty():
		path = [Vector2(-30, 0), Vector2(30, 0)]
	_local_target = path[_current]

func _layout_sprite() -> void:
	# Toutes les pièces sont positionnées par rapport à un sprite de hauteur `size.y`.
	# Body occupe les 55 % du bas (hors jambes), tête les 30 % du haut.
	var w: float = size.x
	var h: float = size.y
	var leg_h: float = h * 0.20
	var body_h: float = h * 0.42
	var head_h: float = h * 0.28
	var hair_h: float = h * 0.10
	var head_w: float = w * 0.78
	var leg_w: float = w * 0.32
	var arm_w: float = w * 0.18
	var arm_h: float = h * 0.30
	# Body
	if body:
		body.size = Vector2(w, body_h)
		body.position = Vector2(-w / 2.0, head_h - h / 2.0)
		body.color = color
	# Head
	if head:
		head.size = Vector2(head_w, head_h)
		head.position = Vector2(-head_w / 2.0, hair_h - h / 2.0)
		head.color = skin_color
	# Hair (sliver au-dessus de la tête)
	if hair:
		hair.size = Vector2(head_w, hair_h)
		hair.position = Vector2(-head_w / 2.0, -h / 2.0)
		hair.color = hair_color
		hair.visible = hair_color.a > 0.0
	# Hat (optionnel — recouvre les cheveux)
	if hat_rect:
		hat_rect.size = Vector2(head_w * 1.05, hair_h * 1.4)
		hat_rect.position = Vector2(-head_w * 0.525, -h / 2.0 - hair_h * 0.4)
		hat_rect.color = hat_color
		hat_rect.visible = hat
	# Bras (pendent depuis le haut du buste)
	var arm_y: float = head_h - h / 2.0
	if arm_l:
		arm_l.size = Vector2(arm_w, arm_h)
		arm_l.position = Vector2(-w / 2.0 - arm_w * 0.3, arm_y)
		arm_l.color = color
	if arm_r:
		arm_r.size = Vector2(arm_w, arm_h)
		arm_r.position = Vector2(w / 2.0 - arm_w * 0.7, arm_y)
		arm_r.color = color
	# Jambes (sous le buste, légèrement plus foncées)
	var leg_y: float = head_h + body_h - h / 2.0
	var dark_color: Color = color.darkened(0.35)
	if leg_l:
		leg_l.size = Vector2(leg_w, leg_h)
		leg_l.position = Vector2(-leg_w - w * 0.05, leg_y)
		leg_l.color = dark_color
	if leg_r:
		leg_r.size = Vector2(leg_w, leg_h)
		leg_r.position = Vector2(w * 0.05, leg_y)
		leg_r.color = dark_color
	# Ombre (ellipse simulée par un rect aplati)
	if shadow:
		shadow.size = Vector2(w * 1.25, h * 0.18)
		shadow.position = Vector2(-shadow.size.x / 2.0, h / 2.0 - shadow.size.y * 0.4)
		shadow.color = Color(0, 0, 0, 0.32)

func _process(delta: float) -> void:
	_bob_t += delta * 4.0
	# Bob vertical général de tout le sprite (un peu de vie quand stationnaire).
	if sprite:
		sprite.position.y = sin(_bob_t) * bob_strength
	# Avance + cycle de pas si en train de bouger.
	if _state == 1:
		# Pause : jambes alignées, bras au repos.
		_idle_pose()
		if Time.get_ticks_msec() / 1000.0 >= _pause_until:
			_state = 0
		return
	var to_target: Vector2 = _local_target - position
	var dist: float = to_target.length()
	if dist < 1.5:
		_advance()
		return
	var step: float = min(speed * delta, dist)
	position += to_target.normalized() * step
	# Direction visuelle.
	if to_target.x < -0.1:
		_facing = -1
	elif to_target.x > 0.1:
		_facing = 1
	if sprite:
		sprite.scale.x = _facing
	# Cycle de pas — fréquence proportionnelle à la vitesse.
	_walk_t += delta * (speed / 18.0)
	_walk_pose()

func _walk_pose() -> void:
	if leg_l == null or leg_r == null:
		return
	var swing: float = sin(_walk_t * 2.0 * PI / 0.6) * 1.6
	# Décalage vertical opposé : une jambe avance pendant que l'autre recule.
	var base_y: float = size.y * 0.28 + size.y * 0.42 - size.y / 2.0
	leg_l.position.y = base_y - swing
	leg_r.position.y = base_y + swing
	# Bras : opposition des jambes (style marche naturelle).
	if arm_l:
		arm_l.position.y = (size.y * 0.28 - size.y / 2.0) + swing * 0.6
	if arm_r:
		arm_r.position.y = (size.y * 0.28 - size.y / 2.0) - swing * 0.6

func _idle_pose() -> void:
	if leg_l == null or leg_r == null:
		return
	var base_y: float = size.y * 0.28 + size.y * 0.42 - size.y / 2.0
	leg_l.position.y = base_y
	leg_r.position.y = base_y
	if arm_l:
		arm_l.position.y = size.y * 0.28 - size.y / 2.0
	if arm_r:
		arm_r.position.y = size.y * 0.28 - size.y / 2.0

func _advance() -> void:
	_state = 1
	_pause_until = Time.get_ticks_msec() / 1000.0 + pause_at_waypoints
	_current = (_current + 1) % path.size()
	_local_target = path[_current]
