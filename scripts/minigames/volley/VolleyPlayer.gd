class_name VolleyPlayer
extends Node2D

# Joueur de beach-volley : physique arcade codée à la main (pas de corps
# physique) pour un jeu lisible et déterministe. `position` = les pieds, posés
# sur le sable à y = 0 ; la balle rebondit sur le cercle `head_center()`.
# VolleyMatch remplit input_axis / input_jump puis appelle step() à pas fixe.

# Zone de frappe calée sur la silhouette mesurée du sprite de profil (104 px de
# haut, pieds à y=0) : la tête = cercle (centre à 79 px, rayon 19), le corps =
# gélule fine du cou aux chevilles. La balle rebondit là où on la VOIT toucher.
const RADIUS: float = 19.0
const HEAD_Y: float = 79.0
const BODY_TOP: float = 58.0
const BODY_BOTTOM: float = 14.0
const BODY_RADIUS: float = 14.0
# Personnage pixel-art (même usine que le monde) : hauteur affichée.
const CHAR_HEIGHT: float = 104.0
const STEP_TIME: float = 0.14
const SPEED: float = 270.0
const JUMP_SPEED: float = 500.0
const GRAVITY: float = 1500.0
# Saut tenu = gravité réduite en montée : tap = petit bond, appui long = smash.
const HOLD_GRAVITY: float = 0.6
const PIXEL: float = 3.0

@export var side_sign: int = -1

var vel: Vector2 = Vector2.ZERO
var on_ground: bool = true
var input_axis: float = 0.0
var input_jump: bool = false
var min_x: float = -410.0
var max_x: float = -34.0
# Une touche n'est comptée qu'une fois par contact (la balle peut frotter).
var touch_cooldown: float = 0.0

var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _squash: float = 0.0
var _char_scale: float = 1.0
var _step_t: float = 0.0
# Apparence : vide = celle du joueur ; le rival reçoit un tirage aléatoire.
var char_config: Dictionary = {}

func _ready() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = VolleyBall.ellipse_texture(18, 4, Color(0.25, 0.18, 0.08, 0.3))
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.scale = Vector2(PIXEL, PIXEL)
	_shadow.z_index = -1
	add_child(_shadow)
	# Un vrai personnage de profil, tourné vers le filet (le rival en miroir).
	var cfg: Dictionary = char_config
	if cfg.is_empty():
		cfg = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	_sprite = Sprite2D.new()
	_sprite.texture = CharacterSpriteFactory.build_sheet(cfg)
	_sprite.region_enabled = true
	_sprite.region_rect = _frame(0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0.0, -float(CharacterSpriteFactory.CELL_H) * 0.5)
	_sprite.flip_h = side_sign == 1
	_char_scale = CHAR_HEIGHT / float(CharacterSpriteFactory.CELL_H)
	_sprite.scale = Vector2(_char_scale, _char_scale)
	add_child(_sprite)

func _frame(col: int) -> Rect2:
	return Rect2(col * CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.DIR_RIGHT * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)

func head_center() -> Vector2:
	return position + Vector2(0.0, -HEAD_Y)

# Partie du corps la plus proche de `p` : [point d'ancrage, rayon] — la tête
# (cercle) ou le corps (gélule verticale). Sert au rebond de la balle.
func hit_shape(p: Vector2) -> Array:
	var head: Vector2 = head_center()
	var gap_head: float = p.distance_to(head) - RADIUS
	var a: Vector2 = position + Vector2(0.0, -BODY_TOP)
	var b: Vector2 = position + Vector2(0.0, -BODY_BOTTOM)
	var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
	var gap_body: float = p.distance_to(q) - BODY_RADIUS
	return [head, RADIUS] if gap_head <= gap_body else [q, BODY_RADIUS]

func reset_at(x: float) -> void:
	position = Vector2(x, 0.0)
	vel = Vector2.ZERO
	on_ground = true
	input_axis = 0.0
	input_jump = false
	touch_cooldown = 0.0

func step(delta: float) -> void:
	touch_cooldown = maxf(touch_cooldown - delta, 0.0)
	vel.x = clampf(input_axis, -1.0, 1.0) * SPEED
	# Saut tenu = rebond automatique à l'atterrissage, comme le genre le veut.
	if on_ground and input_jump:
		vel.y = -JUMP_SPEED
		on_ground = false
		_squash = -0.16
	if not on_ground:
		var g: float = GRAVITY
		if input_jump and vel.y < 0.0:
			g *= HOLD_GRAVITY
		vel.y += g * delta
		position.y += vel.y * delta
		if position.y >= 0.0:
			position.y = 0.0
			vel.y = 0.0
			on_ground = true
			_squash = 0.18
	var nx: float = clampf(position.x + vel.x * delta, min_x, max_x)
	if not is_equal_approx(nx, position.x + vel.x * delta):
		vel.x = 0.0
	position.x = nx

# Petit écrasement quand la balle rebondit sur le blob.
func bump() -> void:
	_squash = 0.12

func _process(delta: float) -> void:
	if _sprite == null:
		return
	_squash = move_toward(_squash, 0.0, delta * 1.1)
	_sprite.scale = Vector2(_char_scale * (1.0 + _squash * 0.5), _char_scale * (1.0 - _squash * 0.5))
	# Pas de course au sol, pose fixe en l'air.
	if on_ground and absf(vel.x) > 1.0:
		_step_t += delta
		_sprite.region_rect = _frame(1 + int(_step_t / STEP_TIME) % 2)
	else:
		_step_t = 0.0
		_sprite.region_rect = _frame(0)
	# L'ombre reste au sol et rétrécit avec la hauteur du saut.
	_shadow.position.y = -position.y
	var k: float = clampf(1.0 + position.y / 300.0, 0.45, 1.0)
	_shadow.scale = Vector2(PIXEL * k, PIXEL)

