extends Node2D

# Un joueur de la pelada : état physique + sprite animé. Aucune décision ici,
# PeladaGame pilote (joystick ou IA) en écrivant `vel` et les minuteurs.

enum Role { GK, FIXO, ALA_E, ALA_D }

var team: int = 0
var role: int = Role.FIXO
var home: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var speed: float = 290.0
var stun: float = 0.0        # au sol / sonné : ne bouge pas, ne touche pas le ballon
var slide: float = 0.0       # carrinho en cours
var slide_hit: bool = false
var tackle_cd: float = 0.0
var pickup_cd: float = 0.0
var hold_t: float = 0.0      # gardien : temps balle en main
var dive: float = 0.0        # gardien : plongeon (anim)
var dive_dir: float = 0.0
var cheer: float = 0.0       # célébration après un but
var pass_target: bool = false

var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _anim_t: float = 0.0
var _dir: int = CharacterSpriteFactory.DIR_RIGHT
var _flip: bool = false


func setup(cfg: Dictionary, shadow_tex: Texture2D) -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = shadow_tex
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.position = Vector2(0, 2)
	_shadow.z_index = -1
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = CharacterSpriteFactory.build_sheet(cfg)
	_sprite.region_enabled = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5 + 6)
	add_child(_sprite)
	_set_cell(CharacterSpriteFactory.DIR_RIGHT, 0)


func is_free() -> bool:
	return stun <= 0.0 and slide <= 0.0 and dive <= 0.0


func tick_timers(delta: float) -> void:
	stun = maxf(stun - delta, 0.0)
	tackle_cd = maxf(tackle_cd - delta, 0.0)
	pickup_cd = maxf(pickup_cd - delta, 0.0)
	cheer = maxf(cheer - delta, 0.0)
	dive = maxf(dive - delta, 0.0)


func animate(delta: float) -> void:
	_anim_t += delta
	var moving: bool = vel.length() > 30.0
	if vel.length() > 30.0 and slide <= 0.0 and stun <= 0.0:
		facing = vel.normalized()
	# Direction de la feuille : la dominante du regard.
	if absf(facing.x) >= absf(facing.y) * 0.8:
		_dir = CharacterSpriteFactory.DIR_RIGHT
		_flip = facing.x < 0.0
	else:
		_dir = CharacterSpriteFactory.DIR_DOWN if facing.y > 0.0 else CharacterSpriteFactory.DIR_UP
		_flip = false
	var frame: int = 0
	if moving and stun <= 0.0:
		frame = 1 + int(_anim_t * (9.0 if vel.length() > 250.0 else 6.0)) % 2
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	if slide > 0.0:
		# Carrinho : couché vers l'avant, au ras du sol.
		_sprite.rotation = (1.25 if not _flip else -1.25)
		_sprite.position = Vector2(0, -10)
		frame = 1
	elif stun > 0.0:
		_sprite.rotation = (1.45 if not _flip else -1.45)
		_sprite.position = Vector2(0, -12)
		frame = 0
	elif dive > 0.0:
		_sprite.rotation = 1.3 * signf(dive_dir) if dive_dir != 0.0 else 0.0
		_sprite.position = Vector2(dive_dir * 18.0, -26)
		frame = 2
	elif cheer > 0.0:
		# Pula de alegria.
		_sprite.position = Vector2(0, -absf(sin(_anim_t * 9.0)) * 22.0)
		_dir = CharacterSpriteFactory.DIR_DOWN
		_flip = false
		frame = 1 + int(_anim_t * 6.0) % 2
	_sprite.position = _sprite.position.snapped(Vector2(3, 3))
	_set_cell(_dir, frame)


func _set_cell(dir: int, frame: int) -> void:
	_sprite.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, dir * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_sprite.flip_h = _flip
