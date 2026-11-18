class_name VolleyBall
extends Node2D

# Balle du beach-volley : simple état (position/vitesse) intégré par
# VolleyMatch — pas de RigidBody2D, pour une physique arcade déterministe.
# Gravité légère : la balle « flotte », on a le temps de lire sa course.

const RADIUS: float = 12.0
const GRAVITY: float = 520.0
const WALL_DAMP: float = 0.9
const NET_DAMP: float = 0.75
# 1 pixel natif = 3 px monde, comme les personnages et props du jeu.
const PIXEL: float = 3.0

const C_OUTLINE: Color = Color(0.22, 0.2, 0.26, 1)
const C_WHITE: Color = Color(0.98, 0.97, 0.92, 1)
const C_YELLOW: Color = Color(0.98, 0.78, 0.2, 1)
const C_BLUE: Color = Color(0.2, 0.45, 0.85, 1)

var vel: Vector2 = Vector2.ZERO
# Gelée = suspendue au-dessus du serveur jusqu'à sa première touche.
var frozen: bool = true

var _sprite: Sprite2D = null
var _spin: float = 0.0
var _bob_t: float = 0.0

func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture = _build_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PIXEL, PIXEL)
	add_child(_sprite)

func place(pos: Vector2) -> void:
	position = pos
	vel = Vector2.ZERO
	frozen = true
	_spin = 0.0

func _process(delta: float) -> void:
	if _sprite == null:
		return
	if frozen:
		# Léger flottement visuel du ballon en attente de service.
		_bob_t += delta
		_sprite.position.y = roundf(sin(_bob_t * 3.0) * 2.0)
	else:
		_sprite.position.y = 0.0
		_spin += vel.x * delta / RADIUS
	# Rotation par quarts de tour : le pixel-art reste net.
	_sprite.rotation = snappedf(_spin, PI * 0.5)

# Abscisse où la balle croisera, en descendant, la hauteur `level` — murs et
# filet compris. Sert à l'IA ; simulation pas à pas bornée à 4 s.
func predict_x_at(level: float, court_half: float, net_half_w: float, net_top: float) -> float:
	if frozen:
		return position.x
	var p: Vector2 = position
	var v: Vector2 = vel
	var dt: float = 1.0 / 60.0
	for i in 240:
		var prev_x: float = p.x
		v.y += GRAVITY * dt
		p += v * dt
		if p.x - RADIUS < -court_half:
			p.x = -court_half + RADIUS
			v.x = absf(v.x) * WALL_DAMP
		elif p.x + RADIUS > court_half:
			p.x = court_half - RADIUS
			v.x = -absf(v.x) * WALL_DAMP
		if p.y > net_top and absf(p.x) < net_half_w + RADIUS:
			var s: float = -1.0 if prev_x < 0.0 else 1.0
			p.x = s * (net_half_w + RADIUS)
			v.x = -v.x * NET_DAMP
		if v.y > 0.0 and p.y >= level:
			return p.x
	return p.x

func _build_texture() -> ImageTexture:
	var n: int = 8
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			if not _in_ball(x, y):
				continue
			var col: Color = C_WHITE
			if not (_in_ball(x - 1, y) and _in_ball(x + 1, y) and _in_ball(x, y - 1) and _in_ball(x, y + 1)):
				col = C_OUTLINE
			elif x + y == 7:
				col = C_BLUE
			elif x - y == 2 or x - y == -3:
				col = C_YELLOW
			img.set_pixel(x, y, col)
	img.set_pixel(2, 2, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _in_ball(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x > 7 or y > 7:
		return false
	return Vector2(float(x), float(y)).distance_to(Vector2(3.5, 3.5)) <= 4.0

# Ellipse pleine pixel-art (ombres au sol).
static func ellipse_texture(w: int, h: int, color: Color) -> ImageTexture:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(float(w) * 0.5, float(h) * 0.5)
	for y in h:
		for x in w:
			var fx: float = (float(x) + 0.5 - c.x) / c.x
			var fy: float = (float(y) + 0.5 - c.y) / c.y
			if fx * fx + fy * fy <= 1.0:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
