extends Node2D

# Rendu du basket de l'Aterro (aucune règle ici) : terrain en perspective face
# à la baie de Guanabara, Pão de Açúcar et Morro da Urca, grillage, panier
# détaillé, joueur de dos qui tire, ballon en cloche, figurants qui vibrent au
# swish. Tout est peint en pixels natifs (1 px = 3 px monde, le joueur ×9) et
# affiché en NEAREST.

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const PX: int = 3
const PLAYER_PX: int = 9
const INK: Color = Color(0.13, 0.10, 0.12)

# Perspective du terrain (mètres) : caméra derrière le tireur, horizon = mer.
const HORIZON_Y: float = 300.0
const CAM_Z: float = 9.0
const CAM_H: float = 3.0
const VIEW_L: float = -480.0
const VIEW_R: float = 2400.0
const GROUND_TOP: float = 372.0
const GROUND_BOTTOM: float = 1500.0
const SKY_TOP: float = -420.0
const FENCE_TOP: float = 330.0
const FENCE_BASE: float = 462.0
const COURT_HALF_W: float = 7.5
const KEY_HALF_W: float = 2.45
const FT_Z: float = 5.8
const LINE_W: float = 0.06

const HOOP_X: float = 960.0
const HOOP_ORIGIN: Vector2 = Vector2(810, 150)
const HOOP_CX: int = 50
const RIM_ROW: int = 63
const RIM_RX: int = 20
const RIM_RY: int = 4
const RIM_Y: float = 339.0
const SHOOTER_FEET: Vector2 = Vector2(960, 867)
# Ballon dans les mains (pose « armée ») : centre relatif aux pieds.
const HOLD_OFFSET: Vector2 = Vector2(6, -282)

const BALL_HAND_D: int = 22
const BALL_RIM_D: int = 14
const FLIGHT_UP: float = 0.42
const FLIGHT_END: float = 1.0

const BALL_COLOR: Color = Color(0.93, 0.50, 0.16)
const COURT_COLOR: Color = Color(0.22, 0.42, 0.63)
const KEY_COLOR: Color = Color(0.76, 0.33, 0.25)
const APRON_COLOR: Color = Color(0.36, 0.56, 0.44)
const LINE_COLOR: Color = Color(0.96, 0.95, 0.90)
const GRASS_COLOR: Color = Color(0.40, 0.68, 0.30)
const BAY_COLOR: Color = Color(0.24, 0.58, 0.70)
const FLAMENGO_RED: Color = Color(0.80, 0.16, 0.14)

const SWISH: int = 0
const RIM: int = 1
const AIRBALL: int = 2

var _t: float = 0.0
var _since_shot: float = 99.0
var _sea: Sprite2D = null
var _far: Node2D = null
var _player: Sprite2D = null
var _player_shadow: Sprite2D = null
var _poses: Array[Texture2D] = []
var _hold: Sprite2D = null
var _fly: Sprite2D = null
var _fly_shadow: Sprite2D = null
var _shadow_big: Texture2D = null
var _shadow_small: Texture2D = null
var _ball_tex: Dictionary = {}
var _net: Sprite2D = null
var _net_frames: Array[Texture2D] = []
var _net_seq: PackedInt32Array = PackedInt32Array()
var _net_t: float = 0.0
var _fans: Array[Sprite2D] = []
var _fan_base: Array[Vector2] = []
var _fan_rows: Array[int] = []
var _cheer: float = 0.0
var _kind: int = -1
var _flight_t: float = 0.0
var _side: float = 1.0
var _short: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func build(game: Node) -> void:
	_rng.seed = 1965
	_layer(_paint_sky(), Vector2(VIEW_L, SKY_TOP), -12)
	_build_morros()
	_build_sea()
	_far = Node2D.new()
	_far.z_index = -9
	_far.draw.connect(_draw_far)
	add_child(_far)
	_layer(_paint_ground(), Vector2(VIEW_L, GROUND_TOP), -8)
	_layer(_paint_lamps(), Vector2(VIEW_L, SKY_TOP), -7)
	for p: Vector3 in [Vector3(-170, 438, 255), Vector3(140, 447, 225), Vector3(462, 432, 198),
			Vector3(1734, 441, 240), Vector3(2055, 432, 270), Vector3(2330, 447, 220)]:
		var spr: Sprite2D = PropSprites.spawn(self, PropSprites.palm_region_at(Vector2(p.x, p.y)), Vector2(p.x, p.y), p.z)
		spr.z_index = -7
	# Promeneurs de l'Aterro, derrière le grillage.
	for f: Vector3 in [Vector3(585, 456, 11), Vector3(642, 459, 12), Vector3(1293, 455, 13), Vector3(-60, 458, 14)]:
		_add_fan(Vector2(f.x, f.y), 1.0, CharacterSpriteFactory.DIR_DOWN, false, int(f.z), -7)
	_layer(_paint_fence(), Vector2(VIEW_L, FENCE_TOP), -6)
	# Le banc de touche : ceux qui attendent la prochaine.
	for f: Vector3 in [Vector3(165, 567, 21), Vector3(60, 612, 22), Vector3(-110, 590, 23),
			Vector3(1755, 567, 24), Vector3(1860, 615, 25), Vector3(2030, 588, 26)]:
		_add_fan(Vector2(f.x, f.y), 5.0 / 3.0, CharacterSpriteFactory.DIR_RIGHT, f.x > HOOP_X, int(f.z), -1)
	_build_hoop()
	_build_player()
	_build_ball()
	_style_meter(game)


# --- Boucle ---

func tick(delta: float, ready_to_shoot: bool) -> void:
	_t += delta
	_since_shot += delta
	if _sea:
		var r: Rect2 = _sea.region_rect
		r.position.x = float(GroundPainter.BIG * (int(_t / 0.6) % GroundPainter.SEA_FRAMES))
		_sea.region_rect = r
	_far.queue_redraw()
	_tick_flight(delta)
	_tick_player(ready_to_shoot)
	_tick_net(delta)
	_tick_fans(delta)


func shoot(kind: int) -> void:
	_kind = kind
	_flight_t = 0.0
	_since_shot = 0.0
	_side = -1.0 if _rng.randf() < 0.5 else 1.0
	_short = _rng.randf() < 0.5
	_fly.visible = true
	_fly_shadow.visible = true
	if kind == SWISH:
		_cheer = 1.1


func _tick_player(ready_to_shoot: bool) -> void:
	var pose: int = 0
	var lift: float = 0.0
	if _since_shot < 0.5:
		pose = 2
		lift = sin(clampf(_since_shot / 0.38, 0.0, 1.0) * PI) * 36.0
	elif ready_to_shoot and _kind < 0:
		pose = 1
	_player.texture = _poses[pose]
	# Genoux qui fléchissent en armant le tir : le corps respire d'un pixel.
	var bob: float = 0.0
	if pose == 1 and fmod(_t, 0.9) < 0.45:
		bob = float(PX)
	_player.position = SHOOTER_FEET + Vector2(0, snappedf(-lift, PX) + bob)
	var k: float = 1.0 - lift / 90.0
	_player_shadow.scale = Vector2(PX * k, PX * k)
	_hold.visible = pose == 1
	_hold.position = _player.position + HOLD_OFFSET


func _tick_flight(delta: float) -> void:
	if _kind < 0:
		return
	_flight_t += delta
	var t: float = _flight_t
	if t >= FLIGHT_END:
		_kind = -1
		_fly.visible = false
		_fly_shadow.visible = false
		return
	var start: Vector2 = SHOOTER_FEET + HOLD_OFFSET + Vector2(0, -24)
	var rim: Vector2 = Vector2(HOOP_X, RIM_Y - 9)
	var pos: Vector2 = Vector2.ZERO
	var d: float = float(BALL_RIM_D)
	var front: bool = true
	var ground: Vector2 = Vector2(HOOP_X, 498)
	if _kind == AIRBALL:
		# Raté court (le ballon meurt sous le cercle) ou large (à côté de la planche).
		var miss: Vector2 = Vector2(HOOP_X + _side * 36.0, RIM_Y + 48) if _short else Vector2(HOOP_X + _side * 230.0, RIM_Y + 24)
		ground = Vector2(HOOP_X + _side * (60.0 if _short else 290.0), 510 if _short else 492)
		if t < FLIGHT_UP:
			pos = _arc(start, miss, t / FLIGHT_UP, 210.0)
		else:
			pos = _bounce_fall(miss, ground, (t - FLIGHT_UP) / (FLIGHT_END - FLIGHT_UP))
	else:
		var entry: Vector2 = rim if _kind == SWISH else Vector2(HOOP_X + _side * 51.0, RIM_Y - 12)
		var drop_at: float = FLIGHT_UP if _kind == SWISH else 0.6
		if t < FLIGHT_UP:
			pos = _arc(start, entry, t / FLIGHT_UP, 210.0)
		elif t < drop_at:
			# Rim-in : le ballon tape le cercle, saute et retombe au centre.
			pos = _arc(entry, rim, (t - FLIGHT_UP) / (drop_at - FLIGHT_UP), 42.0)
			front = false
		else:
			front = false
			var u: float = (t - drop_at) / (FLIGHT_END - drop_at)
			pos = _bounce_fall(rim, ground, u)
			if t - delta < drop_at:
				_play_net(PackedInt32Array([1, 1, 2, 2, 3, 0]) if _kind == SWISH else PackedInt32Array([1, 3, 0]))
	if t < FLIGHT_UP:
		var u2: float = t / FLIGHT_UP
		d = lerpf(float(BALL_HAND_D), float(BALL_RIM_D), u2)
		front = u2 < 0.7 or _kind == AIRBALL
	_fly.texture = _ball_texture(int(round(d / 2.0)) * 2, int(t * 18.0) % 4)
	_fly.position = pos.snapped(Vector2(PX, PX))
	_fly.z_index = 6 if front else 2
	# Ombre au sol : du pied du tireur vers le point de chute.
	var g: float = clampf(t / 0.7, 0.0, 1.0)
	_fly_shadow.position = Vector2(pos.x, lerpf(SHOOTER_FEET.y + 6.0, ground.y + 6.0, g)).snapped(Vector2(PX, PX))
	_fly_shadow.texture = _shadow_big if g < 0.5 else _shadow_small


func _arc(a: Vector2, b: Vector2, u: float, h: float) -> Vector2:
	var p: Vector2 = a.lerp(b, u)
	p.y -= h * 4.0 * u * (1.0 - u)
	return p


# Chute jusqu'au sol puis petit rebond (u = 0..1).
func _bounce_fall(a: Vector2, g: Vector2, u: float) -> Vector2:
	if u < 0.6:
		var v: float = u / 0.6
		return Vector2(lerpf(a.x, g.x, v), lerpf(a.y, g.y, v * v))
	var w: float = (u - 0.6) / 0.4
	return Vector2(g.x, g.y - 40.0 * 4.0 * w * (1.0 - w))


func _play_net(seq: PackedInt32Array) -> void:
	_net_seq = seq
	_net_t = 0.0


func _tick_net(delta: float) -> void:
	if _net_seq.is_empty():
		return
	_net_t += delta
	var i: int = int(_net_t / 0.07)
	if i >= _net_seq.size():
		_net.texture = _net_frames[0]
		_net_seq = PackedInt32Array()
		return
	_net.texture = _net_frames[_net_seq[i]]


func _tick_fans(delta: float) -> void:
	_cheer = maxf(_cheer - delta, 0.0)
	for i in _fans.size():
		var spr: Sprite2D = _fans[i]
		var hop: float = 0.0
		var col: int = 0
		if _cheer > 0.0:
			hop = absf(sin((_t + float(i) * 0.37) * 11.0)) * 18.0 * minf(_cheer * 2.0, 1.0)
			col = 1 + (int(_t * 8.0 + float(i)) % 2)
		elif fmod(_t * 0.5 + float(i) * 0.61, 4.0) < 0.25:
			col = 1 + i % 2
		spr.region_rect = Rect2(col * CharacterSpriteFactory.CELL_W, _fan_rows[i] * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		spr.position = _fan_base[i] - Vector2(0, snappedf(hop, PX))


# --- Construction ---

func _layer(img: Image, origin: Vector2, z: int, scale_px: int = PX) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(scale_px, scale_px)
	s.position = origin
	s.z_index = z
	add_child(s)
	return s


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _col(wx: float) -> int:
	return int(floor((wx - VIEW_L) / float(PX)))


func _native_w() -> int:
	return int((VIEW_R - VIEW_L) / float(PX))


# Ciel en bandes tramées, nuages pixel, collines de Niterói à l'horizon.
func _paint_sky() -> Image:
	var w: int = _native_w()
	var h: int = int((HORIZON_Y + 6.0 - SKY_TOP) / float(PX))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bands: Array[Color] = [Color(0.33, 0.58, 0.88), Color(0.40, 0.66, 0.92), Color(0.49, 0.74, 0.95),
		Color(0.60, 0.81, 0.97), Color(0.74, 0.88, 0.98)]
	var limits: Array[float] = [-90.0, 60.0, 170.0, 250.0]
	for r in h:
		var wy: float = SKY_TOP + float(r * PX)
		var b: int = 0
		while b < limits.size() and wy >= limits[b]:
			b += 1
		_fill(img, 0, r, w, 1, bands[b])
		if b < limits.size():
			var left: int = int((limits[b] - wy) / float(PX))
			if left <= 3:
				var step: int = 2 if left <= 1 else 4
				var off: int = (r % 2) * (step / 2)
				for x in range(off, w, step):
					img.set_pixel(x, r, bands[b + 1])
	for c: Vector3 in [Vector3(140, -40, 34), Vector3(690, 70, 22), Vector3(1080, -120, 40),
			Vector3(1880, 30, 28), Vector3(2260, -60, 20), Vector3(-330, 90, 24)]:
		_cloud(img, _col(c.x), int((c.y - SKY_TOP) / float(PX)), int(c.z))
	# Niterói : collines bleutées et poussière de ville au bord de l'eau.
	var hz: int = int((HORIZON_Y - SKY_TOP) / float(PX))
	var hill: Color = Color(0.55, 0.64, 0.78)
	var hill_hi: Color = Color(0.66, 0.74, 0.86)
	var town: Color = Color(0.82, 0.85, 0.92)
	for x in w:
		var wx: float = VIEW_L + float(x * PX)
		var hh: float = 0.0
		if wx < 900.0:
			hh = 9.0 + 5.0 * sin(wx * 0.007) + 4.0 * sin(wx * 0.019 + 1.3) + 2.0 * sin(wx * 0.05)
			hh *= clampf((900.0 - wx) / 260.0, 0.0, 1.0)
		elif wx > 1660.0:
			hh = (5.0 + 3.0 * sin(wx * 0.011) + 2.0 * sin(wx * 0.031)) * clampf((wx - 1660.0) / 200.0, 0.0, 1.0)
		var top: int = hz - int(hh)
		if hh >= 1.0:
			_fill(img, x, top, 1, hz - top + 2, hill)
			_dot(img, x, top, hill_hi)
	for i in 70:
		var x2: int = _rng.randi_range(0, _col(820.0))
		var bh: int = _rng.randi_range(1, 4)
		_fill(img, x2, hz - bh, _rng.randi_range(1, 3), bh, town)
	return img


func _cloud(img: Image, cx: int, cy: int, wn: int) -> void:
	var white: Color = Color(1, 1, 1)
	var under: Color = Color(0.84, 0.90, 0.97)
	_fill(img, cx - wn / 2, cy, wn, 2, white)
	_fill(img, cx - wn / 2 + 2, cy + 2, wn - 4, 1, under)
	_fill(img, cx - wn / 3, cy - 2, wn / 3, 2, white)
	_fill(img, cx - wn / 10, cy - 4, wn / 3, 4, white)
	_fill(img, cx - wn / 20, cy - 5, wn / 5, 1, white)
	_fill(img, cx + wn / 4, cy - 2, wn / 5, 2, white)


# Pão de Açúcar (derrière) et Morro da Urca (devant), plantés dans la baie.
func _build_morros() -> void:
	var rock: Color = Color(0.58, 0.58, 0.62)
	var veg: Color = Color(0.27, 0.48, 0.36)
	for m: Array in [[60, 80, 1500.0, 3], [96, 40, 1260.0, 5]]:
		var tex: ImageTexture = GroundPainter.dome(int(m[0]), int(m[1]), rock, veg, int(m[3]))
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(PX, PX)
		s.position = Vector2(float(m[2]) - float(int(m[0]) / 2 * PX), HORIZON_Y + 6.0 - float(int(m[1]) * PX))
		s.z_index = -11
		add_child(s)


func _build_sea() -> void:
	_sea = Sprite2D.new()
	_sea.texture = GroundPainter.sea(BAY_COLOR, 7)
	_sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sea.region_enabled = true
	_sea.region_rect = Rect2(0, 0, _native_w(), int((GROUND_TOP - HORIZON_Y) / float(PX)) + 1)
	_sea.centered = false
	_sea.scale = Vector2(PX, PX)
	_sea.position = Vector2(VIEW_L, HORIZON_Y)
	_sea.z_index = -10
	add_child(_sea)


# Horizon, voiliers et bondinho (redessinés chaque image, bougent lentement).
func _draw_far() -> void:
	var span: float = VIEW_R - VIEW_L
	_far.draw_rect(Rect2(VIEW_L, HORIZON_Y, span, PX), BAY_COLOR.lightened(0.35))
	_far.draw_rect(Rect2(VIEW_L, GROUND_TOP - PX, span, PX), BAY_COLOR.darkened(0.25))
	for b: Vector4 in [Vector4(260, 318, 7, 0), Vector4(1020, 333, -5, 1), Vector4(1830, 312, 4, 0), Vector4(-200, 340, -6, 1)]:
		var x: float = VIEW_L + fposmod(b.x - VIEW_L + _t * b.z, span)
		x = snappedf(x, PX)
		var y: float = b.y
		_far.draw_rect(Rect2(x - 6, y, 18, PX), Color(0.22, 0.18, 0.2))
		var sail: Color = Color(0.98, 0.97, 0.94) if b.w < 0.5 else Color(0.98, 0.82, 0.3)
		for i in 5:
			_far.draw_rect(Rect2(x + 3 - float(i / 2 * PX), y - PX * (5 - i), float((i / 2 + 1) * PX), PX), sail)
	# Bondinho : câble Urca → Pão de Açúcar, cabine en va-et-vient.
	var a: Vector2 = Vector2(1293, 189)
	var b2: Vector2 = Vector2(1482, 81)
	var cable: Color = Color(0.25, 0.25, 0.3)
	var steps: int = int(a.distance_to(b2) / float(PX))
	for i in steps + 1:
		var p: Vector2 = a.lerp(b2, float(i) / float(steps)).snapped(Vector2(PX, PX))
		_far.draw_rect(Rect2(p, Vector2(PX, PX)), cable)
	var u: float = pingpong(_t * 0.07, 1.0)
	var c: Vector2 = a.lerp(b2, u).snapped(Vector2(PX, PX))
	_far.draw_rect(Rect2(c.x, c.y, PX, 6), cable)
	_far.draw_rect(Rect2(c.x - 6, c.y + 6, 15, 9), Color(0.96, 0.78, 0.3))
	_far.draw_rect(Rect2(c.x - 3, c.y + 9, 9, PX), Color(0.2, 0.3, 0.45))


# Profondeur (m depuis la ligne de fond) d'une ordonnée écran du terrain.
func _z_raw(wy: float) -> float:
	return CAM_Z - CAM_H * 600.0 / maxf(wy - HORIZON_Y, 0.001)


func _scale_at(wy: float) -> float:
	return (wy - HORIZON_Y) / CAM_H


# Quai de granit, gazon de l'Aterro, allée, bordure, puis terrain peint en
# perspective (raquette, lignes, arc à 3 points, cercle de lancer franc).
func _paint_ground() -> Image:
	var w: int = _native_w()
	var h: int = int((GROUND_BOTTOM - GROUND_TOP) / float(PX))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var prev_l: int = -1
	var prev_r: int = -1
	var prev_al: int = -1
	var prev_ar: int = -1
	for r in h:
		var wy0: float = GROUND_TOP + float(r * PX)
		var wc: float = wy0 + 1.5
		if wc < 375.0:
			_fill(img, 0, r, w, 1, Color(0.80, 0.77, 0.70))
			continue
		if wc < 381.0:
			_fill(img, 0, r, w, 1, Color(0.56, 0.53, 0.50))
			for x in range(r * 5 % 11, w, 11):
				img.set_pixel(x, r, Color(0.42, 0.40, 0.38))
			continue
		if wc < FENCE_BASE:
			var stripe: bool = (r / 3) % 2 == 0
			_fill(img, 0, r, w, 1, GRASS_COLOR if stripe else GRASS_COLOR.darkened(0.08))
			if wc >= 411.0 and wc < 426.0:
				# Allée de l'Aterro : pierre claire, petits joints sombres.
				_fill(img, 0, r, w, 1, Color(0.86, 0.83, 0.75))
				if wc < 414.0 or wc >= 423.0:
					_fill(img, 0, r, w, 1, Color(0.70, 0.67, 0.60))
				else:
					for x in range((r % 2) * 3, w, 6):
						img.set_pixel(x, r, Color(0.74, 0.71, 0.64))
			continue
		if wc < FENCE_BASE + 6.0:
			_fill(img, 0, r, w, 1, Color(0.84, 0.82, 0.76) if wc < FENCE_BASE + 3.0 else Color(0.60, 0.58, 0.54))
			continue
		_fill(img, 0, r, w, 1, APRON_COLOR)
		var z0: float = _z_raw(wy0)
		var z1: float = _z_raw(wy0 + float(PX))
		var z: float = _z_raw(wc)
		var s: float = _scale_at(wc)
		# Joints de dalle du pourtour, fuyant vers le point de fuite.
		for jx: float in [-15.5, -12.0, -9.5, 9.5, 12.0, 15.5]:
			_xline(img, r, jx, s, APRON_COLOR.darkened(0.12))
		for jz: float in [-0.7, 3.0, 6.2]:
			if z0 <= jz and z1 >= jz:
				_fill(img, 0, r, w, 1, APRON_COLOR.darkened(0.12))
		if z < 0.0:
			continue
		_span(img, r, -COURT_HALF_W, COURT_HALF_W, s, COURT_COLOR)
		if z <= FT_Z:
			_span(img, r, -KEY_HALF_W, KEY_HALF_W, s, KEY_COLOR)
		# Lignes horizontales : fond et lancer franc (au moins 1 px natif).
		if z0 <= LINE_W and z1 >= 0.0:
			_span(img, r, -COURT_HALF_W, COURT_HALF_W, s, LINE_COLOR)
		if z0 <= FT_Z + LINE_W and z1 >= FT_Z:
			_span(img, r, -KEY_HALF_W, KEY_HALF_W, s, LINE_COLOR)
		for sx: float in [-1.0, 1.0]:
			_xline(img, r, sx * COURT_HALF_W, s, LINE_COLOR)
			if z <= FT_Z:
				_xline(img, r, sx * KEY_HALF_W, s, LINE_COLOR)
			if z <= 2.99:
				_xline(img, r, sx * 6.6, s, LINE_COLOR)
		# Arc à 3 points (rayon 6,75 m autour du panier).
		if z > 2.99:
			var dz: float = z - 1.575
			if absf(dz) < 6.75:
				var ax: float = sqrt(6.75 * 6.75 - dz * dz)
				var cl: int = _col(HOOP_X - ax * s)
				var cr: int = _col(HOOP_X + ax * s)
				_link(img, r, cl, prev_al, s)
				_link(img, r, cr, prev_ar, s)
				prev_al = cl
				prev_ar = cr
		# Cercle de lancer franc (moitié intérieure en pointillés).
		var cz: float = z - FT_Z
		if absf(cz) < 1.8:
			var cx: float = sqrt(1.8 * 1.8 - cz * cz)
			var l: int = _col(HOOP_X - cx * s)
			var rr: int = _col(HOOP_X + cx * s)
			if cz >= 0.0 or (r / 2) % 2 == 0:
				_link(img, r, l, prev_l, s)
				_link(img, r, rr, prev_r, s)
			prev_l = l
			prev_r = rr
	_paint_shadows(img)
	_paint_wear(img)
	return img


func _span(img: Image, r: int, x0: float, x1: float, s: float, c: Color) -> void:
	var a: int = _col(HOOP_X + x0 * s)
	var b: int = _col(HOOP_X + x1 * s)
	_fill(img, a, r, b - a + 1, 1, c)


func _xline(img: Image, r: int, x: float, s: float, c: Color) -> void:
	var a: int = _col(HOOP_X + (x - LINE_W * 0.5) * s)
	var b: int = maxi(a, _col(HOOP_X + (x + LINE_W * 0.5) * s))
	_fill(img, a, r, b - a + 1, 1, c)


# Trait courbe continu : relie la colonne de la rangée précédente.
func _link(img: Image, r: int, c: int, prev: int, s: float) -> void:
	var thick: int = maxi(1, int(LINE_W * s / float(PX)))
	var a: int = c if prev < 0 else mini(prev, c)
	var b: int = c if prev < 0 else maxi(prev, c)
	_fill(img, a - thick / 2, r, b - a + thick, 1, LINE_COLOR)


func _darken(img: Image, x0: int, y0: int, x1: int, y1: int, k: float) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(k))


# Ombre du poteau et de la planche, soleil de l'après-midi venu de gauche.
func _paint_shadows(img: Image) -> void:
	var gy: int = int((475.0 - GROUND_TOP) / float(PX))
	var px: int = _col(HOOP_X)
	for i in 8:
		_darken(img, px + 1 + i * 2, gy - i, px + 5 + i * 2, gy - i + 1, 0.25)
	var by: int = int((503.0 - GROUND_TOP) / float(PX))
	for i in 5:
		_darken(img, _col(HOOP_X + 30.0) + i * 2, by + i, _col(HOOP_X + 230.0) + i * 2, by + i + 1, 0.2)


# Usure du béton peint : taches, fissures, éclats de peinture.
func _paint_wear(img: Image) -> void:
	var top: int = int((FENCE_BASE + 6.0 - GROUND_TOP) / float(PX))
	var w: int = img.get_width()
	var h: int = img.get_height()
	for i in 3200:
		var x: int = _rng.randi_range(0, w - 1)
		var y: int = _rng.randi_range(top, h - 1)
		var c: Color = img.get_pixel(x, y)
		img.set_pixel(x, y, c.darkened(0.07) if _rng.randf() < 0.6 else c.lightened(0.06))
	for i in 16:
		var x2: int = _rng.randi_range(0, w - 1)
		var y2: int = _rng.randi_range(top + 4, h - 1)
		for k in _rng.randi_range(4, 12):
			_dot(img, x2, y2, img.get_pixel(clampi(x2, 0, w - 1), clampi(y2, 0, h - 1)).darkened(0.22))
			x2 += _rng.randi_range(-1, 1)
			y2 += 1 if _rng.randf() < 0.4 else 0
			x2 += 1


# Lampadaires géants de l'Aterro (les « postes » de Burle Marx).
func _paint_lamps() -> Image:
	var w: int = _native_w()
	var h: int = int((FENCE_BASE - SKY_TOP) / float(PX))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for lx: float in [330.0, 1840.0]:
		var x: int = _col(lx)
		var base: int = int((436.0 - SKY_TOP) / float(PX))
		var top: int = int((66.0 - SKY_TOP) / float(PX))
		_fill(img, x - 1, top, 4, base - top, INK)
		_fill(img, x, top, 1, base - top, Color(0.74, 0.76, 0.8))
		_fill(img, x + 1, top, 1, base - top, Color(0.5, 0.52, 0.58))
		_fill(img, x - 8, top - 2, 18, 3, INK)
		_fill(img, x - 7, top - 1, 16, 1, Color(0.6, 0.62, 0.68))
		for k in 4:
			var lx2: int = x - 7 + k * 5
			_fill(img, lx2 - 1, top + 1, 4, 4, INK)
			_fill(img, lx2, top + 1, 2, 2, Color(1.0, 0.95, 0.75))
	return img


# Grillage losangé, poteaux galvanisés, main courante en haut.
func _paint_fence() -> Image:
	var w: int = _native_w()
	var h: int = int((FENCE_BASE - FENCE_TOP) / float(PX))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mesh: Color = Color(0.16, 0.2, 0.22, 0.55)
	var glint: Color = Color(0.85, 0.88, 0.9, 0.5)
	for y in range(2, h):
		for x in w:
			if (x + y) % 5 == 0 or (x - y + 1000) % 5 == 0:
				img.set_pixel(x, y, glint if (x + y) % 15 == 0 else mesh)
	_fill(img, 0, 0, w, 1, Color(0.8, 0.82, 0.85))
	_fill(img, 0, 1, w, 1, Color(0.48, 0.5, 0.55))
	for x in range(18, w, 64):
		_fill(img, x - 1, 0, 1, h, INK)
		_fill(img, x, 0, 1, h, Color(0.82, 0.84, 0.87))
		_fill(img, x + 1, 0, 1, h, Color(0.5, 0.52, 0.57))
		_fill(img, x + 2, 0, 1, h, INK)
	return img


func _add_fan(pos: Vector2, k: float, dir: int, flip: bool, seed_value: int, z: int) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(seed_value * 7919))
	s.region_enabled = true
	s.region_rect = Rect2(0, dir * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = Vector2(-30, -96)
	s.scale = Vector2(k, k)
	s.flip_h = flip
	s.position = pos
	s.z_index = z
	add_child(s)
	var sh: Sprite2D = Sprite2D.new()
	sh.texture = _ellipse(int(14.0 * k), maxi(2, int(3.0 * k)), Color(0.05, 0.08, 0.1, 0.3))
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sh.scale = Vector2(PX, PX)
	sh.position = pos
	sh.z_index = z
	add_child(sh)
	move_child(sh, s.get_index())
	_fans.append(s)
	_fan_base.append(pos)
	_fan_rows.append(dir)


# Poteau, planche avec carré, cercle (moitié arrière) ; filet + moitié avant
# du cercle au-dessus du ballon qui rentre.
func _build_hoop() -> void:
	_layer(_paint_hoop_back(), HOOP_ORIGIN, 1)
	for f: Vector3 in [Vector3(22, 11, 0), Vector3(28, 8, 0), Vector3(18, 14, 0), Vector3(22, 11, 1)]:
		_net_frames.append(ImageTexture.create_from_image(_paint_hoop_front(int(f.x), int(f.y), int(f.z))))
	_net = _layer(Image.create(1, 1, false, Image.FORMAT_RGBA8), HOOP_ORIGIN, 3)
	_net.texture = _net_frames[0]


func _paint_hoop_back() -> Image:
	var img: Image = Image.create(100, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: int = HOOP_CX
	var steel: Color = Color(0.28, 0.34, 0.44)
	# Poteau.
	_fill(img, cx - 4, 30, 9, 79, INK)
	_fill(img, cx - 3, 30, 7, 78, steel)
	_fill(img, cx - 3, 30, 2, 78, steel.lightened(0.25))
	_fill(img, cx + 2, 30, 2, 78, steel.darkened(0.3))
	# Protection rubro-negra (on est à Flamengo).
	_fill(img, cx - 6, 82, 13, 18, INK)
	_fill(img, cx - 5, 83, 11, 16, FLAMENGO_RED)
	_fill(img, cx - 5, 83, 2, 16, FLAMENGO_RED.lightened(0.2))
	for yy: int in [87, 93]:
		_fill(img, cx - 5, yy, 11, 2, Color(0.1, 0.09, 0.1))
	# Platine au sol.
	_fill(img, cx - 8, 106, 17, 3, INK)
	_fill(img, cx - 7, 106, 15, 1, Color(0.5, 0.5, 0.52))
	# Planche : cadre rouge, fond blanc, carré de visée.
	var white: Color = Color(0.96, 0.96, 0.93)
	_fill(img, 10, 10, 80, 51, INK)
	_fill(img, 11, 11, 78, 49, FLAMENGO_RED)
	_fill(img, 11, 11, 78, 1, FLAMENGO_RED.lightened(0.25))
	_fill(img, 13, 13, 74, 45, white)
	_fill(img, 13, 13, 74, 1, Color(1, 1, 1))
	_fill(img, 86, 13, 1, 45, Color(0.8, 0.82, 0.85))
	_fill(img, 13, 57, 74, 1, Color(0.8, 0.82, 0.85))
	_fill(img, 37, 40, 26, 18, INK)
	_fill(img, 39, 42, 22, 16, white)
	_fill(img, 39, 57, 22, 1, Color(0.8, 0.82, 0.85))
	for b: Vector2i in [Vector2i(15, 15), Vector2i(84, 15), Vector2i(15, 55), Vector2i(84, 55)]:
		img.set_pixel(b.x, b.y, Color(0.45, 0.45, 0.5))
	for i in 40:
		var gx: int = _rng.randi_range(14, 85)
		var gy: int = _rng.randi_range(30, 56)
		if gx < 37 or gx > 62:
			img.set_pixel(gx, gy, Color(0.84, 0.84, 0.82))
	# Pixo discret dans le coin (le terrain vit).
	for p: Vector2i in [Vector2i(17, 50), Vector2i(18, 49), Vector2i(19, 50), Vector2i(20, 49), Vector2i(21, 50), Vector2i(22, 48), Vector2i(22, 49), Vector2i(22, 50)]:
		img.set_pixel(p.x, p.y, Color(0.2, 0.2, 0.25))
	# Fixation du cercle.
	_fill(img, cx - 5, 59, 11, 4, INK)
	_fill(img, cx - 4, 59, 9, 2, Color(0.4, 0.4, 0.44))
	_rim(img, true)
	return img


func _rim(img: Image, back: bool) -> void:
	var orange: Color = Color(0.98, 0.47, 0.13)
	var deep: Color = Color(0.62, 0.24, 0.07)
	for i in 160:
		var a: float = PI * float(i) / 159.0 + (0.0 if back else PI)
		var x: int = HOOP_CX + int(round(cos(a) * float(RIM_RX)))
		var y: int = RIM_ROW - int(round(sin(a) * float(RIM_RY)))
		_dot(img, x, y, orange)
		_dot(img, x, y + 1, deep)
	if not back:
		for i in 160:
			var a2: float = PI + PI * float(i) / 159.0
			var x2: int = HOOP_CX + int(round(cos(a2) * float(RIM_RX)))
			var y2: int = RIM_ROW - int(round(sin(a2) * float(RIM_RY)))
			_dot(img, x2, y2 + 2, INK)
			_dot(img, x2, y2 - 1, Color(1.0, 0.7, 0.4) if x2 < HOOP_CX else orange)


# Filet losangé : longueur, demi-largeur du bas et balancement (pixels natifs).
func _paint_hoop_front(length: int, bottom: int, sway: int) -> Image:
	var img: Image = Image.create(100, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white: Color = Color(0.97, 0.97, 0.95)
	var grey: Color = Color(0.72, 0.75, 0.8)
	for k in range(1, length + 1):
		var v: float = float(k) / float(length)
		var hw: float = lerpf(float(RIM_RX) - 1.0, float(bottom), v)
		var cx: float = float(HOOP_CX) + float(sway) * sin(v * PI) * 2.0
		var x0: int = int(round(cx - hw))
		var x1: int = int(round(cx + hw))
		var thr: float = 4.0 / maxf(hw, 1.0)
		for x in range(x0, x1 + 1):
			var u: float = (float(x) - cx) / maxf(hw, 1.0)
			var a: float = fposmod(u * 3.0 + float(k) * 0.28, 1.0)
			var b: float = fposmod(u * 3.0 - float(k) * 0.28, 1.0)
			var on: bool = a < thr or b < thr or x == x0 or x == x1
			if k == length and (x % 2 == 0):
				on = true
			if on:
				_dot(img, x, RIM_ROW + 1 + k, grey if u > 0.35 else white)
	_rim(img, false)
	return img


func _build_player() -> void:
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var sheet: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var skin: Color = cfg.get("skin", Color(0.92, 0.78, 0.62))
	var shirt: Color = cfg.get("shirt_color", Color(0.85, 0.55, 0.4))
	for pose in 3:
		_poses.append(ImageTexture.create_from_image(_player_pose(sheet, pose, skin, shirt)))
	_player_shadow = Sprite2D.new()
	_player_shadow.texture = _ellipse(40, 8, Color(0.05, 0.08, 0.12, 0.35))
	_player_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_shadow.scale = Vector2(PX, PX)
	_player_shadow.position = SHOOTER_FEET + Vector2(6, 0)
	add_child(_player_shadow)
	_player = Sprite2D.new()
	_player.texture = _poses[1]
	_player.centered = false
	_player.offset = Vector2(-10, -40)
	_player.scale = Vector2(PLAYER_PX, PLAYER_PX)
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.position = SHOOTER_FEET
	add_child(_player)


# Personnage de dos (rangée DIR_UP) ramené en natif 21×32, posé 8 rangées
# plus bas sur une toile 21×40 pour laisser la place aux bras levés.
# pose 0 = bras le long du corps, 1 = ballon armé au-dessus de la tête,
# 2 = bras tendus (lâcher).
func _player_pose(sheet: Image, pose: int, skin: Color, shirt: Color) -> Image:
	const O: int = 8
	var img: Image = Image.create(21, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 21:
			var c: Color = sheet.get_pixel(x * 3 + 1, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H + y * 3 + 1)
			if c.a > 0.01:
				img.set_pixel(x, y + O, c)
	if pose == 0:
		return img
	# Efface les bras pendants avant de les redessiner levés.
	for y in range(14 + O, 23 + O):
		for x: int in [2, 3, 4, 5, 15, 16, 17, 18]:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	var skin_sh: Color = skin.darkened(0.22)
	var shirt_sh: Color = shirt.darkened(0.24)
	for side in 2:
		var m: Callable = func(x: int) -> int: return x if side == 0 else 20 - x
		# Manche courte sur l'épaule.
		_dot(img, m.call(5), 15 + O, shirt_sh)
		_dot(img, m.call(4), 15 + O, shirt)
		_dot(img, m.call(5), 14 + O, shirt)
		_dot(img, m.call(4), 14 + O, shirt)
		if pose == 1:
			# Coudes ouverts, avant-bras qui remontent tenir le ballon.
			for y in range(18 + O, 22 + O):
				_dot(img, m.call(2 if y < 21 + O else 3), y, skin if side == 0 else skin_sh)
				_dot(img, m.call(1 if y < 21 + O else 2), y, skin_sh if side == 0 else skin)
			_dot(img, m.call(1), 17 + O, skin_sh)
			_dot(img, m.call(2), 17 + O, skin)
			for y in range(11 + O, 17 + O):
				var cx: int = 2 + (16 + O - y) / 2
				_dot(img, m.call(cx), y, skin_sh if side == 0 else skin)
				_dot(img, m.call(cx + 1), y, skin if side == 0 else skin_sh)
			_dot(img, m.call(5), 10 + O, skin)
			_dot(img, m.call(6), 10 + O, skin)
			_dot(img, m.call(6), 11 + O, skin_sh)
		else:
			# Bras tendus : le geste suit le ballon vers le cercle.
			for y in range(5 + O, 14 + O):
				_dot(img, m.call(4), y, skin if side == 0 else skin_sh)
				_dot(img, m.call(5), y, skin_sh if side == 0 else skin)
			_dot(img, m.call(5), 4 + O, skin)
			_dot(img, m.call(6), 4 + O, skin)
	_outline(img)
	return img


func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.01:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px: int = x + o.x
				var py: int = y + o.y
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				var n: Color = src.get_pixel(px, py)
				if n.a > 0.01 and not n.is_equal_approx(CharacterSpriteFactory.LINE_COLOR):
					img.set_pixel(x, y, CharacterSpriteFactory.LINE_COLOR)
					break


func _build_ball() -> void:
	_shadow_big = _ellipse(12, 4, Color(0.05, 0.08, 0.12, 0.35))
	_shadow_small = _ellipse(8, 3, Color(0.05, 0.08, 0.12, 0.3))
	_hold = _ball_sprite(_ball_texture(BALL_HAND_D, 0), 5)
	_fly = _ball_sprite(_ball_texture(BALL_RIM_D, 0), 6)
	_fly.visible = false
	_fly_shadow = _ball_sprite(_shadow_big, -1)
	_fly_shadow.visible = false


func _ball_sprite(tex: Texture2D, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PX, PX)
	s.z_index = z
	add_child(s)
	return s


# Ballon pixel : orange modelé, coutures qui tournent (4 frames), contour.
func _ball_texture(d: int, frame: int) -> Texture2D:
	var key: String = "%d_%d" % [d, frame]
	if _ball_tex.has(key):
		return _ball_tex[key]
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r: float = float(d) * 0.5
	var seam: Color = Color(0.22, 0.10, 0.05)
	for y in d:
		for x in d:
			var dx: float = float(x) + 0.5 - r
			var dy: float = float(y) + 0.5 - r
			var dd: float = sqrt(dx * dx + dy * dy)
			if dd > r:
				continue
			var c: Color = BALL_COLOR
			if dx + dy > r * 0.5:
				c = BALL_COLOR.darkened(0.2)
			if dx + dy < -r * 0.75:
				c = BALL_COLOR.lightened(0.25)
			if dd > r - 1.0:
				c = INK
			img.set_pixel(x, y, c)
	var off: float = (float(frame) / 4.0 - 0.375) * r * 1.6
	for y in d:
		var dy2: float = float(y) + 0.5 - r
		var k: float = sqrt(maxf(1.0 - dy2 * dy2 / (r * r), 0.0))
		for o: float in [off, off + r * 1.6 * (1.0 if off < 0.0 else -1.0)]:
			var x2: int = int(floor(r + o * k))
			if x2 > 0 and x2 < d - 1 and img.get_pixel(x2, y).a > 0.0 and img.get_pixel(x2, y) != INK:
				img.set_pixel(x2, y, seam)
	for x in range(1, d - 1):
		var mid: int = int(r)
		if img.get_pixel(x, mid) != INK:
			img.set_pixel(x, mid, seam)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_ball_tex[key] = tex
	return tex


func _ellipse(w: int, h: int, c: Color) -> Texture2D:
	var img: Image = Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Jauge : relief pixel (arête claire, pied sombre) et graduation centrale.
func _style_meter(game: Node) -> void:
	for path: String in ["UI/Meter/Bg", "UI/Meter/RimZone", "UI/Meter/SwishZone"]:
		var z: ColorRect = game.get_node_or_null(path) as ColorRect
		if z == null:
			continue
		for spec: Array in [[0.0, 6.0, z.color.lightened(0.3)], [-6.0, 0.0, z.color.darkened(0.3)]]:
			var band: ColorRect = ColorRect.new()
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.anchor_right = 1.0
			band.anchor_top = 0.0 if float(spec[0]) >= 0.0 else 1.0
			band.anchor_bottom = band.anchor_top
			band.offset_top = float(spec[0])
			band.offset_bottom = float(spec[1])
			band.color = spec[2]
			z.add_child(band)
	var meter: Control = game.get_node_or_null("UI/Meter") as Control
	var cursor: Node = game.get_node_or_null("UI/Meter/Cursor")
	if meter and cursor:
		var tick: ColorRect = ColorRect.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.position = Vector2(258.0, 6.0)
		tick.size = Vector2(4, 36)
		tick.color = Color(1, 1, 1, 0.6)
		meter.add_child(tick)
		meter.move_child(cursor, -1)
