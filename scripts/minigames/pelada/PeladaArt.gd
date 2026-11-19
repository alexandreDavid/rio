extends Node2D

# Rendu de la pelada (aucune règle ici) : campo society en gazon synthétique
# rayé (granulés de caoutchouc, usure devant les buts), lignes blanches,
# alambrado tout autour, buts à filet, projecteurs, et le morro avec ses
# maisons derrière le grillage. Peint une fois en pixels natifs ×3, NEAREST.

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const PX: int = 3
const ORIGIN: Vector2 = Vector2(-360, -420)
const W_END: float = 2560.0
const H_END: float = 1000.0
const INK: Color = Color(0.13, 0.10, 0.12)

const TURF_A: Color = Color(0.20, 0.55, 0.25)
const TURF_B: Color = Color(0.25, 0.62, 0.30)
const TURF_OUT: Color = Color(0.17, 0.46, 0.23)
const LINE: Color = Color(0.95, 0.96, 0.91)
const RUBBER: Color = Color(0.10, 0.16, 0.10)
const WORN: Color = Color(0.46, 0.60, 0.30)
const MESH: Color = Color(0.78, 0.80, 0.80, 0.62)
const POST: Color = Color(0.32, 0.40, 0.36)
const NET: Color = Color(0.96, 0.96, 0.94, 0.7)

const FENCE_BASE: float = -36.0
const FENCE_TOP: float = -186.0
const SIDE_FENCE: float = 120.0

static var _cache: Dictionary = {}

var _actors: Node2D = null
var _ball: Node2D = null
var _ball_spr: Sprite2D = null
var _ball_shadow: Sprite2D = null
var _ball_frames: Array[Texture2D] = []
var _overlay: Node2D = null
var _game: Node = null
var _t: float = 0.0
var _roll: float = 0.0
var _nets: Array[Sprite2D] = []
var _net_shake: Array[float] = [0.0, 0.0]
var _fence: Sprite2D = null
var _fence_shake: float = 0.0
var _fans: Array[Sprite2D] = []
var _fan_base: Array[Vector2] = []
var _cheer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shadow_tex: Texture2D = null


func build(game: Node) -> void:
	_game = game
	_rng.seed = 2014
	var fw: float = float(game.get("FIELD_W"))
	var fh: float = float(game.get("FIELD_H"))
	var gh: float = float(game.get("GOAL_HALF"))
	var setting: String = String(game.get("setting"))
	if setting == "morro":
		_layer(_cached("back_morro", func() -> Image: return _paint_back()), -12)
	else:
		_layer(_cached("back_aterro", func() -> Image: return _paint_back_aterro()), -12)
	# Torcida de la grade : ceux qui attendent « a próxima ».
	for f: Vector3 in [Vector3(300, -52, 11), Vector3(372, -48, 12), Vector3(860, -54, 13),
			Vector3(1500, -50, 14), Vector3(1566, -54, 15), Vector3(1980, -50, 16)]:
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(int(f.z) * 37))
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
		spr.position = Vector2(f.x, f.y)
		spr.z_index = -11
		add_child(spr)
		_fans.append(spr)
		_fan_base.append(spr.position)
	_layer(_cached("ground", func() -> Image: return _paint_ground(fw, fh, gh)), -10)
	_fence = _layer(_cached("fence", func() -> Image: return _paint_fence(fw)), -9)
	for left: bool in [true, false]:
		var net: Sprite2D = _layer_at(_cached("net_l" if left else "net_r", func() -> Image: return _paint_goal(left, gh)),
				Vector2(-96.0 if left else fw, float(game.get("CENTER").y) - gh - 120.0), -7)
		_nets.append(net)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_shadow_tex = _ellipse(9, 3, Color(0.05, 0.12, 0.06, 0.45))
	_build_ball()
	_layer(_cached("front", func() -> Image: return _paint_front(fw, fh)), 30)
	_overlay = Node2D.new()
	_overlay.z_index = 40
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func shadow_texture() -> Texture2D:
	return _shadow_tex


func add_actor(p: Node2D) -> void:
	_actors.add_child(p)


func goal_net(left: bool) -> void:
	_net_shake[0 if left else 1] = 0.6
	_cheer = 2.2


func shake_fence(_pos: Vector2) -> void:
	_fence_shake = 0.18


func sync(game: Node, delta: float) -> void:
	_t += delta
	var bp: Vector2 = game.get("ball_pos")
	var bz: float = float(game.get("ball_z"))
	var bv: Vector2 = game.get("ball_vel")
	_roll += bv.length() * delta
	_ball.position = bp
	_ball_spr.position = Vector2(0, -bz - 9.0).snapped(Vector2(PX, PX))
	_ball_spr.texture = _ball_frames[int(_roll / 22.0) % _ball_frames.size()]
	var k: float = clampf(1.0 - bz / 260.0, 0.45, 1.0)
	_ball_shadow.scale = Vector2(PX * k, PX * k)
	# Filets qui tremblent, grillage qui vibre.
	for i in 2:
		_net_shake[i] = maxf(_net_shake[i] - delta, 0.0)
		var base_x: float = -96.0 if i == 0 else float(game.get("FIELD_W"))
		_nets[i].position.x = base_x + (snappedf(sin(_t * 50.0) * 3.0, PX) * (1.0 if _net_shake[i] > 0.0 else 0.0)) * (-1.0 if i == 0 else 1.0)
	_fence_shake = maxf(_fence_shake - delta, 0.0)
	_fence.position.y = ORIGIN.y + (PX if _fence_shake > 0.0 and int(_t * 30.0) % 2 == 0 else 0.0)
	_cheer = maxf(_cheer - delta, 0.0)
	for i in _fans.size():
		var hop: float = 0.0
		if _cheer > 0.0:
			hop = snappedf(absf(sin(_t * 9.0 + i)) * 15.0, PX)
		elif fmod(_t * 0.7 + i * 0.37, 3.0) < 0.2:
			hop = PX
		_fans[i].position = _fan_base[i] - Vector2(0, hop)
	_overlay.queue_redraw()


# Repère du joueur dirigé, jauge de frappe, cible de passe.
func _draw_overlay() -> void:
	var c: Node2D = _game.get("controlled")
	if c == null or bool(_game.get("autoplay")):
		return
	var p: Vector2 = c.position
	var bob: float = snappedf(absf(sin(_t * 5.0)) * 6.0, PX)
	var tip: Vector2 = p + Vector2(0, -108 - bob)
	_overlay.draw_colored_polygon(PackedVector2Array([tip + Vector2(-21, -24), tip + Vector2(21, -24), tip]), INK)
	_overlay.draw_colored_polygon(PackedVector2Array([tip + Vector2(-14, -20), tip + Vector2(14, -20), tip + Vector2(0, -5)]), Color(1.0, 0.86, 0.3))
	var charge: float = float(_game.call("charge_value"))
	if charge > 0.0:
		var r: Rect2 = Rect2(p + Vector2(-40, -150 - bob), Vector2(80, 14))
		_overlay.draw_rect(r.grow(3), INK)
		var col: Color = Color(1.0, 0.85, 0.25).lerp(Color(0.95, 0.25, 0.18), charge)
		_overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * charge, r.size.y)), col)
	for q in _game.get("players"):
		if q.pass_target and q.team == 0:
			_overlay.draw_arc(q.position + Vector2(0, 2), 26.0, 0.0, TAU, 20, Color(1.0, 0.86, 0.3, 0.8), 4.0)


# --- Ballon ---

func _build_ball() -> void:
	_ball = Node2D.new()
	_actors.add_child(_ball)
	_ball_shadow = Sprite2D.new()
	_ball_shadow.texture = _ellipse(6, 3, Color(0.05, 0.12, 0.06, 0.5))
	_ball_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_shadow.z_index = -1
	_ball_shadow.scale = Vector2(PX, PX)
	_ball.add_child(_ball_shadow)
	for f in 2:
		_ball_frames.append(_ball_texture(f))
	_ball_spr = Sprite2D.new()
	_ball_spr.texture = _ball_frames[0]
	_ball_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_spr.scale = Vector2(PX, PX)
	_ball.add_child(_ball_spr)


func _ball_texture(frame: int) -> Texture2D:
	var img: Image = Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 7:
		for x in 7:
			var dx: float = float(x) - 3.0
			var dy: float = float(y) - 3.0
			var r: float = dx * dx + dy * dy
			if r <= 10.5:
				img.set_pixel(x, y, INK if r > 7.0 else Color(0.97, 0.97, 0.95))
	# Pentagones noirs : deux poses pour que le ballon roule.
	var spots: Array = [[3, 3], [1, 2], [5, 4]] if frame == 0 else [[3, 2], [2, 4], [5, 2]]
	for s: Array in spots:
		img.set_pixel(int(s[0]), int(s[1]), INK)
	img.set_pixel(2, 1, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


func _ellipse(rx: int, ry: int, c: Color) -> Texture2D:
	var img: Image = Image.create(rx * 2, ry * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in ry * 2:
		for x in rx * 2:
			var dx: float = (float(x) + 0.5 - rx) / rx
			var dy: float = (float(y) + 0.5 - ry) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Peinture ---

func _cached(key: String, painter: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(painter.call())
	return _cache[key]


func _layer(tex: Texture2D, z: int) -> Sprite2D:
	return _layer_at(tex, ORIGIN, z)


func _layer_at(tex: Texture2D, origin: Vector2, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = origin
	s.scale = Vector2(PX, PX)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	add_child(s)
	return s


func _nw() -> int:
	return int((W_END - ORIGIN.x) / PX)


func _nh() -> int:
	return int((H_END - ORIGIN.y) / PX)


func _nx(wx: float) -> int:
	return int(floor((wx - ORIGIN.x) / PX))


func _ny(wy: float) -> int:
	return int(floor((wy - ORIGIN.y) / PX))


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0: int = maxi(x, 0)
	var y0: int = maxi(y, 0)
	var x1: int = mini(x + w, img.get_width())
	var y1: int = mini(y + h, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	if c.a >= 0.999:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
		return
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(c))


func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c) if c.a < 0.999 else c)


# Ciel, morro vert et maisons de la favela, petit muret au pied de la grade.
func _paint_back() -> Image:
	var w: int = _nw()
	var h: int = _ny(FENCE_BASE) + 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var u: float = float(y) / float(h)
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.42, 0.68, 0.92).lerp(Color(0.80, 0.90, 0.96), u))
	# Morro : silhouette ondulée, mata foncée.
	var ridge: PackedInt32Array = PackedInt32Array()
	for x in w:
		var fx: float = float(x)
		ridge.append(maxi(2, 18 + int(14.0 * sin(fx * 0.011 + 0.6) + 7.0 * sin(fx * 0.037) + 3.0 * sin(fx * 0.13))))
	for x in w:
		for y in range(ridge[x], h):
			var c: Color = Color(0.20, 0.40, 0.22)
			if (x * 7 + y * 13) % 11 == 0:
				c = c.lightened(0.12)
			elif (x * 5 + y * 3) % 13 == 0:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	# Maisons empilées sur la pente (tijolo, couleurs vives, laje, caixa d'água).
	var houses: int = 0
	var y_row: int = h - 46
	while y_row > 26 and houses < 400:
		var x: int = _rng.randi_range(-6, 10)
		while x < w:
			var hw: int = _rng.randi_range(12, 22)
			var hh: int = _rng.randi_range(9, 15)
			if y_row - hh > ridge[clampi(x + hw / 2, 0, w - 1)] + 2 and _rng.randf() < 0.86:
				_house(img, x, y_row - hh, hw, hh)
				houses += 1
			x += hw + _rng.randi_range(0, 3)
		y_row -= _rng.randi_range(9, 13)
	# Muret de béton au pied du grillage.
	var wy: int = h - 9
	_fill(img, 0, wy, w, 9, Color(0.70, 0.68, 0.62))
	_fill(img, 0, wy, w, 1, Color(0.82, 0.80, 0.74))
	_fill(img, 0, h - 2, w, 2, Color(0.50, 0.48, 0.44))
	# Grafite sur le muret.
	for gx: int in [140, 470, 790]:
		for i in 26:
			_dot(img, gx + i, wy + 3 + int(2.0 * sin(i * 0.7)), [Color(0.9, 0.3, 0.5), Color(0.3, 0.6, 0.9), Color(0.95, 0.75, 0.2)][gx % 3])
	return img


# Aterro do Flamengo : baie de Guanabara, Pão de Açúcar et Urca, palmiers.
func _paint_back_aterro() -> Image:
	var w: int = _nw()
	var h: int = _ny(FENCE_BASE) + 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var u: float = float(y) / float(h)
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.40, 0.66, 0.92).lerp(Color(0.86, 0.92, 0.95), u))
	var sea_y: int = h - 34
	# Niterói au loin, mer, puis la pelouse de l'Aterro.
	for x in w:
		var r: int = sea_y - 4 - int(3.0 + 3.0 * sin(float(x) * 0.02) + 2.0 * sin(float(x) * 0.07))
		_fill(img, x, r, 1, sea_y - r, Color(0.50, 0.62, 0.66))
	_fill(img, 0, sea_y, w, 18, Color(0.24, 0.56, 0.68))
	for i in 140:
		var sx: int = _rng.randi_range(0, w - 6)
		var sy: int = _rng.randi_range(sea_y + 2, sea_y + 15)
		_fill(img, sx, sy, _rng.randi_range(2, 5), 1, Color(0.62, 0.82, 0.88))
	_fill(img, 0, sea_y + 18, w, h - sea_y - 18, Color(0.36, 0.62, 0.30))
	# Morro da Urca puis Pão de Açúcar, posés sur l'eau.
	var urca: Image = GroundPainter.dome(64, 34, Color(0.52, 0.50, 0.50), Color(0.24, 0.44, 0.26), 7).get_image()
	var pao: Image = GroundPainter.dome(46, 64, Color(0.56, 0.55, 0.56), Color(0.26, 0.46, 0.28), 11).get_image()
	var ux: int = int(w * 0.62)
	img.blend_rect(urca, Rect2i(Vector2i.ZERO, urca.get_size()), Vector2i(ux, sea_y + 2 - urca.get_height()))
	img.blend_rect(pao, Rect2i(Vector2i.ZERO, pao.get_size()), Vector2i(ux + 70, sea_y + 2 - pao.get_height()))
	# Bondinho : le câble entre les deux sommets.
	var c0: Vector2 = Vector2(ux + 32, sea_y - 31)
	var c1: Vector2 = Vector2(ux + 93, sea_y - 61)
	for i in 90:
		var t: float = float(i) / 89.0
		var q: Vector2 = c0.lerp(c1, t) + Vector2(0, 5.0 * sin(t * PI))
		_dot(img, int(q.x), int(q.y), INK)
	# Palmiers de l'Aterro devant la baie.
	for px: int in range(18, w, 74):
		var base: int = sea_y + 20
		var top: int = base - 30
		_fill(img, px, top, 2, base - top, Color(0.45, 0.32, 0.20))
		for k in 7:
			var a: float = -PI * 0.9 + float(k) * PI * 0.3
			for d in 9:
				_dot(img, px + 1 + int(cos(a) * d), top + int(sin(a) * d * 0.6) + int(d * d * 0.05), Color(0.20, 0.48, 0.20))
	# Muret de béton au pied du grillage.
	var wy: int = h - 9
	_fill(img, 0, wy, w, 9, Color(0.70, 0.68, 0.62))
	_fill(img, 0, wy, w, 1, Color(0.82, 0.80, 0.74))
	_fill(img, 0, h - 2, w, 2, Color(0.50, 0.48, 0.44))
	return img


func _house(img: Image, x: int, y: int, w: int, h: int) -> void:
	var colors: Array = Cfg.FAVELA_COLORS
	var c: Color = colors[_rng.randi() % colors.size()]
	if _rng.randf() < 0.35:
		c = Color(0.72, 0.42, 0.30)  # tijolo nu
	_fill(img, x, y, w, h, c)
	_fill(img, x, y, w, 1, c.lightened(0.25))
	_fill(img, x + w - 2, y, 2, h, c.darkened(0.18))
	if c.r > 0.7 and c.g < 0.5 and c.b < 0.35:
		# Briques : joints.
		for yy in range(y + 2, y + h, 2):
			for xx in range(x + ((yy / 2) % 2) * 2, x + w, 4):
				_dot(img, xx, yy, c.darkened(0.2))
	for wx in range(x + 2, x + w - 3, 5):
		_fill(img, wx, y + 3, 2, 3, Color(0.16, 0.18, 0.24))
	if _rng.randf() < 0.3:
		_fill(img, x + 2, y - 3, 4, 3, Color(0.25, 0.42, 0.75))
	elif _rng.randf() < 0.3:
		_fill(img, x + w / 2, y - 5, 1, 5, Color(0.3, 0.3, 0.32))


# Synthétique rayé, granulés, usure, lignes, bande hors-jeu sombre.
func _paint_ground(fw: float, fh: float, gh: float) -> Image:
	var w: int = _nw()
	var h: int = _nh()
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top: int = _ny(FENCE_BASE)
	var bottom: int = _ny(fh + 40.0)
	var left: int = _nx(-SIDE_FENCE)
	var right: int = _nx(fw + SIDE_FENCE)
	var fx0: int = _nx(0.0)
	var fx1: int = _nx(fw)
	var fy0: int = _ny(0.0)
	var fy1: int = _ny(fh)
	var cy: int = _ny(fh * 0.5)
	for y in range(top, bottom):
		for x in range(left, right):
			var inside: bool = x >= fx0 and x < fx1 and y >= fy0 and y < fy1
			var c: Color = TURF_OUT
			if inside:
				c = TURF_A if ((x - fx0) / 22) % 2 == 0 else TURF_B
			var n: int = (x * 73856093) ^ (y * 19349663)
			var r: int = absi(n) % 100
			if r < 4:
				c = RUBBER.lerp(c, 0.35)
			elif r < 12:
				c = c.lightened(0.07)
			elif r < 18:
				c = c.darkened(0.06)
			# Usure : devant chaque but et au rond central, le gazon pelé.
			if inside:
				var wear: float = 0.0
				for gx: int in [fx0, fx1]:
					var dx: float = float(x - gx) / 34.0
					var dy: float = float(y - cy) / 22.0
					wear = maxf(wear, 1.0 - (dx * dx + dy * dy))
				var dxc: float = float(x - (fx0 + fx1) / 2) / 26.0
				var dyc: float = float(y - cy) / 18.0
				wear = maxf(wear, (1.0 - (dxc * dxc + dyc * dyc)) * 0.7)
				if wear > 0.0 and absi(n >> 3) % 100 < int(wear * 70.0):
					c = WORN if r > 30 else RUBBER.lerp(WORN, 0.5)
			img.set_pixel(x, y, c)
	# Lignes.
	var lw: int = 2
	_fill(img, fx0, fy0, fx1 - fx0, lw, LINE)
	_fill(img, fx0, fy1 - lw, fx1 - fx0, lw, LINE)
	_fill(img, fx0, fy0, lw, fy1 - fy0, LINE)
	_fill(img, fx1 - lw, fy0, lw, fy1 - fy0, LINE)
	var mx: int = (fx0 + fx1) / 2
	_fill(img, mx - 1, fy0, lw, fy1 - fy0, LINE)
	_ring(img, mx, cy, 46, LINE)
	_fill(img, mx - 2, cy - 2, 4, 4, LINE)
	var bd: int = int(300.0 / PX)
	var bh: int = int(200.0 / PX)
	for side in 2:
		var bx: int = fx0 if side == 0 else fx1 - bd
		_fill(img, bx, cy - bh, bd, lw, LINE)
		_fill(img, bx, cy + bh - lw, bd, lw, LINE)
		var ex: int = fx0 + bd - lw if side == 0 else fx1 - bd
		_fill(img, ex, cy - bh, lw, bh * 2, LINE)
		var px: int = fx0 + 70 if side == 0 else fx1 - 72
		_fill(img, px, cy - 1, 3, 3, LINE)
	# Pieds de l'alambrado latéral (ombre au sol).
	for x: int in [left, right - 2]:
		_fill(img, x, top, 2, bottom - top, Color(0.10, 0.20, 0.12, 0.6))
	return img


func _ring(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for i in 360:
		var a: float = deg_to_rad(float(i))
		for k in 2:
			_dot(img, cx + int(round(cos(a) * float(r - k))), cy + int(round(sin(a) * float(r - k) * 0.9)), c)


# Alambrado du fond (losanges, poteaux, lisse) et projecteurs.
func _paint_fence(fw: float) -> Image:
	var w: int = _nw()
	var h: int = _ny(FENCE_BASE) + 1
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var y0: int = _ny(FENCE_TOP)
	var y1: int = h - 1
	var x0: int = _nx(-SIDE_FENCE)
	var x1: int = _nx(fw + SIDE_FENCE)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if (x + y) % 5 == 0 or (x - y + 1000) % 5 == 0:
				_dot(img, x, y, MESH)
	for x in range(x0, x1 + 1, 30):
		_fill(img, x, y0 - 3, 2, y1 - y0 + 3, POST)
		_fill(img, x, y0 - 3, 1, y1 - y0 + 3, POST.lightened(0.25))
	_fill(img, x0, y0 - 3, x1 - x0, 2, POST)
	_fill(img, x0, y0 + 24, x1 - x0, 1, POST.darkened(0.1))
	# Projecteurs aux coins.
	for px: int in [x0 + 8, x1 - 10]:
		_fill(img, px, 0, 3, y1, Color(0.42, 0.44, 0.46))
		_fill(img, px - 6, 2, 15, 6, Color(0.22, 0.22, 0.25))
		for k in 3:
			_fill(img, px - 5 + k * 5, 3, 3, 4, Color(1.0, 0.96, 0.78))
	return img


# But : filet en volume (fond + côtés), cadre blanc. Le cadre est vu de 3/4 :
# poteaux debout, barre transversale au-dessus de la ligne.
func _paint_goal(left: bool, gh: float) -> Image:
	var depth: int = 32
	var hn: int = int((gh * 2.0 + 120.0) / PX) + 4
	var img: Image = Image.create(depth + 4, hn, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bar_h: int = 35
	var mouth_top: int = int(120.0 / PX)
	var mouth_bot: int = mouth_top + int(gh * 2.0 / PX)
	var front: int = depth if left else 0
	var back: int = 2 if left else depth
	# Filet : mailles carrées sur le fond et le toit.
	for y in range(mouth_top - bar_h, mouth_bot):
		for x in range(mini(front, back), maxi(front, back) + 1):
			if (x % 3 == 0 or y % 3 == 0):
				_dot(img, x, y, NET)
	# Ombre du filet au sol.
	_fill(img, mini(front, back), mouth_bot - 2, absi(front - back), 2, Color(0.05, 0.12, 0.06, 0.35))
	# Montants du fond.
	_fill(img, back - 1, mouth_top - bar_h + 6, 2, mouth_bot - mouth_top + bar_h - 6, Color(0.82, 0.82, 0.80))
	# Cadre : barre (en haut) + poteaux debout, contour encre.
	var fx: int = front - 2 if left else front
	_fill(img, fx - 1, mouth_top - bar_h - 1, 5, mouth_bot - mouth_top + bar_h + 2, INK)
	_fill(img, fx, mouth_top - bar_h, 3, mouth_bot - mouth_top + bar_h, LINE)
	_fill(img, fx + (2 if left else 0), mouth_top - bar_h, 1, mouth_bot - mouth_top + bar_h, Color(0.75, 0.76, 0.74))
	return img


# Premier plan : muret bas et grillage court devant la caméra.
func _paint_front(fw: float, fh: float) -> Image:
	var w: int = _nw()
	var h: int = _nh()
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var y0: int = _ny(fh + 40.0)
	_fill(img, 0, y0, w, h - y0, Color(0.62, 0.60, 0.55))
	_fill(img, 0, y0, w, 1, Color(0.80, 0.78, 0.72))
	_fill(img, 0, y0 + 1, w, 1, INK)
	for x in range(0, w, 38):
		_fill(img, x, y0 + 4, 20, 2, Color(0.52, 0.50, 0.46))
	return img
