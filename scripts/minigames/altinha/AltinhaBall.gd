class_name AltinhaBall
extends Node2D

# Balle d'altinha : trajectoire parabolique simulée (hauteur = v0*t - 0.5*g*t²),
# pas de RigidBody — un seul vecteur `kick_velocity` fixe à la fois l'arc et sa
# durée (v0 haut = arc haut et lent = passe "mole" ; v0 bas = tir tendu et
# rapide). Le nœud lui-même reste toujours à (0,0) : from/to/ground/world sont
# exprimés dans l'espace local du parent (AltinhaGame), pas via les transforms.
#
# Rendu pixel (1 px natif = 3 px monde) : ballon de futevôlei qui tourne,
# ombre au sol, et au point de chute un cercle de réception en perspective —
# anneau intérieur = zone Perfeito, pointillé = zone Boa, anneau de timing qui
# se resserre jusqu'au moment idéal ; la couleur suit `hint` (posé par le jeu).

const GRAVITY: float = 340.0
const RADIUS: float = 7.0

const PX: float = 3.0
const BALL_D: int = 6
const RING_PERFECT: int = 8
const RING_GOOD: int = 16
const RING_TIMER_START: int = 26
const RING_SQUASH: float = 0.42

const HINT_NONE: int = -1
const HINT_SOFT: int = 0
const HINT_GOOD: int = 1
const HINT_PERFECT: int = 2

var show_marker: bool = true
var marker_color: Color = Color(1.0, 1.0, 1.0, 0.55)
# Qualité qu'aurait une touche maintenant (visuel seulement, posé par le jeu).
var hint: int = HINT_NONE
# Hauteur du contact idéal (pour l'anneau de timing).
var contact_height: float = 30.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _total: float = 1.0
var _v0: float = 220.0
var _height: float = 0.0
var _grounded: bool = true

var _ground_fx: Node2D = null
var _frames: Array[Texture2D] = []
var _blink: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	_ground_fx = Node2D.new()
	_ground_fx.name = "GroundFx"
	_ground_fx.z_as_relative = false
	_ground_fx.z_index = -1
	_ground_fx.draw.connect(_draw_ground)
	add_child(_ground_fx)
	for f in 4:
		_frames.append(_ball_texture(f))

# Lance un nouveau vol depuis `from` vers `to`. `kick_velocity` détermine à la
# fois la hauteur de l'arc et sa durée (physiquement lié : un tir plus haut
# reste plus longtemps en l'air).
func launch(from: Vector2, to: Vector2, kick_velocity: float) -> void:
	_from = from
	_to = to
	_v0 = maxf(kick_velocity, 40.0)
	_total = 2.0 * _v0 / GRAVITY
	_elapsed = 0.0
	_height = 0.0
	_grounded = false
	_redraw()

# Avance la simulation d'un pas. Renvoie true si la balle vient de toucher
# sa cible CE frame (fin de vol naturelle, sans intervention du joueur).
func advance(delta: float) -> bool:
	if _grounded:
		return false
	_elapsed += delta
	_blink += delta
	_height = _v0 * _elapsed - 0.5 * GRAVITY * _elapsed * _elapsed
	_redraw()
	if _height <= 0.0 and _elapsed > 0.03:
		_height = 0.0
		_grounded = true
		_redraw()
		return true
	return false

# Position au sol (projection), interpolée du départ vers la cible.
func ground_pos() -> Vector2:
	var t: float = clampf(_elapsed / _total, 0.0, 1.0) if _total > 0.0 else 1.0
	return _from.lerp(_to, t)

# Position visible de la balle (sol moins la hauteur simulée).
func world_pos() -> Vector2:
	return ground_pos() - Vector2(0.0, _height)

func height() -> float:
	return _height

func is_grounded() -> bool:
	return _grounded

func target() -> Vector2:
	return _to

func _redraw() -> void:
	queue_redraw()
	if _ground_fx:
		_ground_fx.queue_redraw()

# Avancement 0→1 jusqu'au moment idéal (balle qui redescend à contact_height).
func _timing_progress() -> float:
	var disc: float = _v0 * _v0 - 2.0 * GRAVITY * contact_height
	var t_contact: float = (_v0 + sqrt(maxf(disc, 0.0))) / GRAVITY
	return clampf(_elapsed / maxf(t_contact, 0.01), 0.0, 1.0)

func _draw() -> void:
	if _grounded:
		return
	var p: Vector2 = world_pos()
	var frame: int = int(_elapsed * 14.0) % _frames.size()
	var size: float = float(BALL_D) * PX
	draw_texture_rect(_frames[frame], Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)), false)

func _draw_ground() -> void:
	if _grounded:
		return
	if show_marker:
		_draw_target()
	# Ombre : rétrécit et pâlit quand la balle monte.
	var g: Vector2 = ground_pos().snapped(Vector2(PX, PX))
	var k: float = clampf(1.0 - _height / 220.0, 0.35, 1.0)
	_fill_ellipse(g, maxi(2, int(4.0 * k)), maxi(1, int(2.0 * k)), Color(0.25, 0.16, 0.06, 0.45 * k))

func _draw_target() -> void:
	var c: Vector2 = _to.snapped(Vector2(PX, PX))
	var base: Color = Color(0.99, 0.97, 0.88)
	var col: Color = Color(base, 0.65)
	match hint:
		HINT_SOFT:
			col = Color(1.0, 0.78, 0.32)
		HINT_GOOD:
			col = Color(0.42, 0.92, 0.46)
		HINT_PERFECT:
			col = Color(1.0, 0.86, 0.18) if int(_blink * 14.0) % 2 == 0 else Color(1.0, 1.0, 0.92)
	if hint == HINT_PERFECT:
		_fill_ellipse(c, RING_PERFECT, int(float(RING_PERFECT) * RING_SQUASH), Color(1.0, 0.85, 0.2, 0.28))
	elif hint == HINT_GOOD:
		_fill_ellipse(c, RING_GOOD, int(float(RING_GOOD) * RING_SQUASH), Color(0.4, 0.9, 0.45, 0.16))
	# Zone Boa (pointillés) puis zone Perfeito (anneau plein, liseré sombre).
	_ring(c, RING_GOOD, Color(col, 0.7), 2)
	_ring(c, RING_PERFECT + 1, Color(0.15, 0.10, 0.08, 0.35), 0)
	_ring(c, RING_PERFECT, col, 0)
	_ring(c, RING_PERFECT - 1, col, 0)
	# Anneau de timing : se referme sur la zone Perfeito au bon moment.
	var u: float = _timing_progress()
	var r: int = int(round(lerpf(float(RING_TIMER_START), float(RING_PERFECT), u)))
	if r > RING_PERFECT:
		_ring(c, r, Color(1.0, 1.0, 1.0, 0.35 + 0.5 * u), 0)

# Anneau pixel en perspective (ellipse aplatie), rayon en pixels natifs ;
# dash > 0 = un pixel sur `dash`.
func _ring(center: Vector2, rx: int, c: Color, dash: int) -> void:
	var ry: float = maxf(2.0, float(rx) * RING_SQUASH)
	var seen: Dictionary = {}
	var n: int = rx * 8
	var i: int = 0
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var q: Vector2i = Vector2i(int(round(cos(a) * float(rx))), int(round(sin(a) * ry)))
		if seen.has(q):
			continue
		seen[q] = true
		i += 1
		if dash > 0 and i % dash != 0:
			continue
		_ground_fx.draw_rect(Rect2(center + Vector2(q) * PX - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), c)

func _fill_ellipse(center: Vector2, rx: int, ry: int, c: Color) -> void:
	for y in range(-ry, ry + 1):
		var fy: float = float(y) / float(maxi(ry, 1))
		var hw: int = int(round(float(rx) * sqrt(maxf(0.0, 1.0 - fy * fy))))
		if hw <= 0:
			continue
		_ground_fx.draw_rect(Rect2(center + Vector2(-hw, y) * PX - Vector2(0, PX * 0.5), Vector2(float(hw * 2) * PX, PX)), c)

# Ballon de futevôlei : panneaux jaune / bleu / vert qui tournent (4 frames).
func _ball_texture(frame: int) -> Texture2D:
	var d: int = BALL_D
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink: Color = Color(0.13, 0.10, 0.12)
	var cols: Array[Color] = [Color(1.0, 0.86, 0.15), Color(0.18, 0.40, 0.85), Color(0.25, 0.70, 0.35), Color(0.98, 0.98, 0.95)]
	var r: float = float(d) * 0.5
	for y in d:
		for x in d:
			var dx: float = float(x) + 0.5 - r
			var dy: float = float(y) + 0.5 - r
			var dd: float = sqrt(dx * dx + dy * dy)
			if dd > r:
				continue
			if dd > r - 0.9:
				img.set_pixel(x, y, ink)
				continue
			var band: int = (int(floor((dx + dy + 6.0) * 0.6)) + frame) % cols.size()
			var c: Color = cols[band]
			if dx + dy > 1.0:
				c = c.darkened(0.18)
			img.set_pixel(x, y, c)
	img.set_pixel(2, 1, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)
