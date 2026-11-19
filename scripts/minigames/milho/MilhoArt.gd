extends Node2D

# Décor et animations de la Hora do rush (1 px natif = 3 px monde, NEAREST) :
# Copacabana vue de derrière la carrocinha de Zé — la mer, le Leme et le Pão
# de Açúcar au loin, le calçadão en vagues, la panela qui fume, les fregueses
# en file avec leur bulle de commande. L'état vient de MilhoGame (sync) ; ici
# on ne fait que le montrer.

const D: int = 3
const LEFT: float = -1260.0
const RIGHT: float = 1260.0
const TOP: float = -560.0
const BOTTOM: float = 560.0
const HORIZON: float = -264.0
const SHORE: float = -180.0
const CURB: float = -108.0
const INK: Color = Color(0.13, 0.10, 0.12)
const PAPER: Color = Color(0.99, 0.96, 0.87)

const CLIENT_X: Array[float] = [-560.0, 0.0, 560.0]
const FEET_Y: float = 40.0     # derrière le comptoir : on les voit jusqu'aux cuisses
const CLIENT_SCALE: float = 3.0
const COB_SCALE: float = 4.0
const POT_X: Array[float] = [-270.0, 0.0, 270.0]
const POT_L: float = -450.0
const POT_R: float = 450.0
const POT_TOP: float = 36.0
const WATER_Y: float = 78.0     # ligne d'eau : le bas des épis disparaît dessous
const TRAY_Y: float = 206.0
const CART_L: float = -660.0
const CART_R: float = 660.0
const HAND_POS: Vector2 = Vector2(-485.0, 282.0)
const BUBBLE_TOP: float = -446.0
const BUBBLE_BOTTOM: float = -262.0
const BUBBLE_HALF_W: float = 200.0
const PATIENCE_MAX: float = 22.0

const SKY_BANDS: Array[Color] = [Color(0.33, 0.58, 0.88), Color(0.40, 0.66, 0.92), Color(0.49, 0.74, 0.95),
	Color(0.60, 0.81, 0.97), Color(0.75, 0.88, 0.98)]
const SEA_COLOR: Color = Color(0.22, 0.60, 0.78)
const SAND_COLOR: Color = Color(0.95, 0.86, 0.58)
const PAVE_W: Color = Color(0.92, 0.90, 0.84)
const PAVE_B: Color = Color(0.25, 0.24, 0.26)
const STEEL: Color = Color(0.74, 0.76, 0.79)
const WOOD: Color = Color(0.62, 0.42, 0.25)
const CART_RED: Color = Color(0.80, 0.20, 0.17)
const CART_YELLOW: Color = Color(0.98, 0.80, 0.22)
const ZE_BLUE: Color = Color(0.17, 0.42, 0.78)

# Couleurs de l'épi selon la cuisson (Cook : EMPTY, CRU, PONTO, PASSADO, DESMANCHOU).
const COB_COLORS: Array[Color] = [Color(0, 0, 0, 0), Color(0.93, 0.90, 0.60), Color(1.0, 0.80, 0.22),
	Color(0.86, 0.56, 0.20), Color(0.60, 0.52, 0.38)]

var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pot: Array = []
var _queue: Array = []
var _hand: Dictionary = {}

var client_sprites: Array[Sprite2D] = []
var _occupied: Array[bool] = [false, false, false]
var _arrive_t: Array[float] = [9.0, 9.0, 9.0]
var _arrive_from: Array[float] = [0.0, 0.0, 0.0]
var _pending_mood: Array[String] = ["", "", ""]
var _cob_sprites: Array[Sprite2D] = []
var _pot_labels: Array[Label] = []
var _splash_t: Array[float] = [9.0, 9.0, 9.0]
var _name_labels: Array[Label] = []
var _line_labels: Array[Label] = []
var _ask_labels: Array[Label] = []
var _hand_sprite: Sprite2D
var _napkin: Sprite2D
var _far: Node2D
var _bubbles: Node2D
var _fx: Node2D
var _icons: Dictionary = {}
var _cob_cache: Dictionary = {}

# --- Construction ---

func build() -> void:
	_rng.seed = 2207
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer(_paint_sky(), Vector2(LEFT, TOP), -20)
	_build_sea()
	var rock: Color = Color(0.56, 0.56, 0.60)
	var veg: Color = Color(0.26, 0.47, 0.33)
	# Pão de Açúcar derrière le Morro do Leme, qui plonge dans la mer à l'est.
	_dome(GroundPainter.dome(34, 64, rock, veg, 3), Vector2(-730.0, SHORE - 30.0), -18)
	_dome(GroundPainter.dome(150, 52, rock.darkened(0.05), veg, 5), Vector2(-990.0, SHORE + 6.0), -17)
	_build_sand()
	_far = _draw_layer(-15, _draw_far)
	_build_bathers()
	_layer(_paint_calcadao(), Vector2(LEFT, CURB), -13)
	for p: Vector3 in [Vector3(-1220, 330, 0), Vector3(-400, 300, 1), Vector3(290, 320, 0),
			Vector3(860, 345, 1), Vector3(1200, 300, 0)]:
		var palm: Sprite2D = PropSprites.spawn(self, PropSprites.PALM_REGIONS[int(p.z)], Vector2(p.x, CURB + 6.0), p.y)
		palm.z_index = -12
	for i in 3:
		var s: Sprite2D = Sprite2D.new()
		s.region_enabled = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
		s.scale = Vector2(CLIENT_SCALE, CLIENT_SCALE)
		s.position = Vector2(CLIENT_X[i], FEET_Y)
		s.visible = false
		add_child(s)
		client_sprites.append(s)
	_layer(_paint_parasol(), Vector2(380.0, TOP), 1)
	_bubbles = _draw_layer(2, _draw_bubbles)
	for i in 3:
		var cx: float = CLIENT_X[i]
		_name_labels.append(_bubble_label(Vector2(cx - 190, BUBBLE_TOP + 6), Vector2(380, 30), 22, INK))
		_line_labels.append(_bubble_label(Vector2(cx - 190, BUBBLE_TOP + 86), Vector2(380, 54), 22, Color(0.42, 0.26, 0.14)))
		_ask_labels.append(_bubble_label(Vector2(cx - 190, BUBBLE_TOP + 34), Vector2(380, 52), 44, Color(0.85, 0.55, 0.08)))
		_ask_labels[i].text = "?"
	_layer(_paint_counter(), Vector2(CART_L, 0.0), 3)
	var pot_img: Image = _paint_pot()
	var pot_tex: ImageTexture = ImageTexture.create_from_image(pot_img)
	var split: int = int((WATER_Y - POT_TOP) / D)
	var back: Sprite2D = _layer_tex(pot_tex, Vector2(POT_L, POT_TOP), 4)
	back.region_enabled = true
	back.region_rect = Rect2(0, 0, pot_img.get_width(), split)
	var front: Sprite2D = _layer_tex(pot_tex, Vector2(POT_L, POT_TOP + split * D), 6)
	front.region_enabled = true
	front.region_rect = Rect2(0, split, pot_img.get_width(), pot_img.get_height() - split)
	for i in 3:
		var cob: Sprite2D = Sprite2D.new()
		cob.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cob.centered = false
		cob.scale = Vector2(COB_SCALE, COB_SCALE)
		cob.z_index = 5
		cob.visible = false
		add_child(cob)
		_cob_sprites.append(cob)
	_layer(_paint_ground_props(), Vector2(LEFT, 300.0), -11)
	_layer(_paint_cart(), Vector2(CART_L - 240.0, TRAY_Y), 7)
	_cart_sign(Vector2(-636, 64), "MILHO\nDO ZÉ", CART_YELLOW)
	_cart_sign(Vector2(444, 58), "FIADO SÓ\nAMANHÃ", PAPER)
	_fx = _draw_layer(8, _draw_fx)
	_napkin = Sprite2D.new()
	_napkin.texture = _napkin_texture()
	_napkin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_napkin.scale = Vector2(5, 5)
	_napkin.position = HAND_POS + Vector2(84, 0)
	_napkin.z_index = 9
	add_child(_napkin)
	_hand_sprite = Sprite2D.new()
	_hand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand_sprite.scale = Vector2(5, 5)
	_hand_sprite.position = HAND_POS
	_hand_sprite.z_index = 8
	add_child(_hand_sprite)
	for i in 3:
		var l: Label = Label.new()
		l.theme_type_variation = &"Pastille"
		l.position = Vector2(POT_X[i] - 112, 128)
		l.size = Vector2(224, 48)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.z_index = 9
		add_child(l)
		_pot_labels.append(l)

func _layer(img: Image, origin: Vector2, z: int) -> Sprite2D:
	return _layer_tex(ImageTexture.create_from_image(img), origin, z)

func _layer_tex(tex: Texture2D, origin: Vector2, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(D, D)
	s.position = origin
	s.z_index = z
	add_child(s)
	return s

func _dome(tex: Texture2D, base_center: Vector2, z: int) -> void:
	var s: Sprite2D = _layer_tex(tex, Vector2.ZERO, z)
	s.position = Vector2(base_center.x - float(tex.get_width() / 2 * D), base_center.y - float(tex.get_height() * D))

func _draw_layer(z: int, cb: Callable) -> Node2D:
	var n: Node2D = Node2D.new()
	n.z_index = z
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.draw.connect(cb)
	add_child(n)
	return n

func _bubble_label(pos: Vector2, sz: Vector2, font: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	_bubbles.add_child(l)
	return l

# Planchette peinte à la main, clouée sur le comptoir.
func _cart_sign(pos: Vector2, text: String, board: Color) -> void:
	var w: int = 64
	var h: int = 24
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(board)
	_fill(img, 0, 0, w, 1, board.lightened(0.3))
	_fill(img, 0, h - 2, w, 2, board.darkened(0.25))
	for x in [3, w - 4]:
		img.set_pixel(x, 2, INK)
	_outline_box(img)
	_layer(img, pos, 7)
	var l: Label = Label.new()
	l.text = text
	l.position = pos + Vector2(0, 4)
	l.size = Vector2(w * D, h * D - 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.55, 0.10, 0.08) if board == CART_YELLOW else ZE_BLUE.darkened(0.3))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", -2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 9
	add_child(l)

# --- Peintures (une fois) ---

func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0: int = maxi(x, 0)
	var y0: int = maxi(y, 0)
	var x1: int = mini(x + w, img.get_width())
	var y1: int = mini(y + h, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)

func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _native_w() -> int:
	return int((RIGHT - LEFT) / D)

func _col(wx: float) -> int:
	return int(floor((wx - LEFT) / D))

# Ciel en bandes tramées, nuages, Ilhas Cagarras sur l'horizon.
func _paint_sky() -> Image:
	var w: int = _native_w()
	var h: int = int((HORIZON - TOP) / D) + 1
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var limits: Array[float] = [-470.0, -400.0, -340.0, -296.0]
	for r in h:
		var wy: float = TOP + float(r * D)
		var b: int = 0
		while b < limits.size() and wy >= limits[b]:
			b += 1
		_fill(img, 0, r, w, 1, SKY_BANDS[b])
		if b < limits.size():
			var left: int = int((limits[b] - wy) / D)
			if left <= 3:
				var step: int = 2 if left <= 1 else 4
				var off: int = (r % 2) * (step / 2)
				for x in range(off, w, step):
					img.set_pixel(x, r, SKY_BANDS[b + 1])
	for c: Vector3 in [Vector3(-720, -470, 30), Vector3(-160, -420, 22), Vector3(420, -490, 36),
			Vector3(980, -380, 26), Vector3(-1100, -400, 20)]:
		_cloud(img, _col(c.x), int((c.y - TOP) / D), int(c.z))
	# Cagarras : bosses bleutées posées sur l'horizon, au large.
	var isle: Color = Color(0.40, 0.52, 0.58)
	for isl: Vector3 in [Vector3(560, 26, 5), Vector3(650, 12, 3), Vector3(760, 18, 4), Vector3(1080, 10, 2)]:
		var cx: int = _col(isl.x)
		var half: int = int(isl.y)
		for dx in range(-half, half + 1):
			var k: float = 1.0 - pow(float(dx) / float(half), 2.0)
			var hh: int = int(round(isl.z * sqrt(maxf(k, 0.0))))
			if hh > 0:
				_fill(img, cx + dx, h - 1 - hh, 1, hh + 1, isle)
				_dot(img, cx + dx, h - 1 - hh, isle.lightened(0.15))
	return img

func _cloud(img: Image, cx: int, cy: int, wn: int) -> void:
	var white: Color = Color(1, 1, 1)
	var under: Color = Color(0.84, 0.90, 0.97)
	_fill(img, cx - wn / 2, cy, wn, 2, white)
	_fill(img, cx - wn / 2 + 2, cy + 2, wn - 4, 1, under)
	_fill(img, cx - wn / 3, cy - 2, wn / 3, 2, white)
	_fill(img, cx - wn / 10, cy - 4, wn / 3, 4, white)
	_fill(img, cx + wn / 4, cy - 2, wn / 5, 2, white)

func _build_sea() -> void:
	var sea: Sprite2D = Sprite2D.new()
	sea.texture = GroundPainter.sea(SEA_COLOR, 11)
	sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sea.region_enabled = true
	sea.region_rect = Rect2(0, 0, _native_w(), int((SHORE - HORIZON) / D) + 2)
	sea.centered = false
	sea.scale = Vector2(D, D)
	sea.position = Vector2(LEFT, HORIZON)
	sea.z_index = -19
	add_child(sea)

func _build_sand() -> void:
	var sand: Sprite2D = Sprite2D.new()
	sand.texture = GroundPainter.sand(SAND_COLOR, 4)
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sand.region_enabled = true
	sand.region_rect = Rect2(0, 0, _native_w(), int((CURB - SHORE) / D) + 2)
	sand.centered = false
	sand.scale = Vector2(D, D)
	sand.position = Vector2(LEFT, SHORE)
	sand.z_index = -16
	add_child(sand)

# Parasols et baigneurs au loin, sur le sable.
func _build_bathers() -> void:
	var umbs: Array = [[-760.0, 0], [-420.0, 1], [-120.0, 2], [200.0, 0], [470.0, 1], [760.0, 2], [1040.0, 0], [-1040.0, 1]]
	for u in umbs:
		var v: Dictionary = PropSprites.UMBRELLA_VARIANTS[int(u[1])]
		var s: Sprite2D = PropSprites.spawn(self, v.region, Vector2(float(u[0]), SHORE + 52.0), float(v.h) * 0.9)
		s.z_index = -14
	for b: Vector3 in [Vector3(-600, 40, 11), Vector3(-260, 54, 12), Vector3(80, 46, 13), Vector3(640, 50, 14), Vector3(920, 40, 15)]:
		var p: Sprite2D = Sprite2D.new()
		p.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(int(b.z) * 977))
		p.region_enabled = true
		p.region_rect = Rect2(0, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H if int(b.z) % 2 == 0 else 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
		p.scale = Vector2(0.67, 0.67)
		p.position = Vector2(b.x, SHORE + b.y)
		p.z_index = -14
		add_child(p)

# Calçadão de Copa : la vague de Burle Marx parallèle à la plage, les bandes
# s'élargissant vers nous (fausse perspective), bordure de granit côté sable.
func _paint_calcadao() -> Image:
	var w: int = _native_w()
	var h: int = int((BOTTOM - CURB) / D) + 1
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var curb_l: Color = Color(0.86, 0.84, 0.80)
	var curb_s: Color = Color(0.62, 0.60, 0.58)
	for y in h:
		if y < 3:
			_fill(img, 0, y, w, 1, curb_l if y == 0 else curb_s)
			continue
		var depth: float = float(y - 3)
		var u: float = sqrt(depth * 26.0 + 90.0)
		var amp: float = 0.6
		var period: float = 40.0 + depth * 0.3
		for x in w:
			var v: float = u + amp * sin(float(x) * TAU / period)
			var col: Color = PAVE_B if posmod(int(floor(v)), 2) == 0 else PAVE_W
			if (x * 7 + y * 13) % 23 == 0:
				col = col.darkened(0.1) if col == PAVE_W else col.lightened(0.14)
			img.set_pixel(x, y, col)
	# Joints de bordure.
	for x in range(0, w, 12):
		_fill(img, x, 1, 1, 2, curb_s.darkened(0.2))
	return img

# Le guarda-sol bleu et jaune de la carrocinha (celle du monde), vu de dessous.
func _paint_parasol() -> Image:
	var w: int = int((RIGHT - 380.0) / D)
	var h: int = 40
	var img: Image = Image.create(w, h + 220, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pole_x: int = int((CART_R - 6.0 - 380.0) / D)
	_fill(img, pole_x, 10, 2, h + 220, Color(0.84, 0.84, 0.86))
	_fill(img, pole_x + 2, 10, 1, h + 220, Color(0.55, 0.55, 0.6))
	for x in w:
		var seg: int = x / 24
		var col: Color = ZE_BLUE if seg % 2 == 0 else CART_YELLOW
		var local: float = float(x % 24) / 24.0
		var scallop: int = int(round(3.0 * sin(local * PI)))
		var bottom: int = 22 + scallop
		_fill(img, x, 0, 1, bottom, col)
		_fill(img, x, bottom - 3, 1, 2, col.darkened(0.2))
		_dot(img, x, bottom, INK)
		if x % 24 == 0:
			_fill(img, x, 0, 1, bottom, col.darkened(0.3))
	return img

# Le comptoir d'inox où repose la panela (vu de haut et de derrière).
func _paint_counter() -> Image:
	var w: int = int((CART_R - CART_L) / D)
	var h: int = int(TRAY_Y / D) + 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(STEEL)
	_fill(img, 0, 0, w, 3, CART_RED)
	_fill(img, 0, 3, w, 1, CART_RED.darkened(0.35))
	_fill(img, 0, 4, w, 1, STEEL.lightened(0.3))
	for y in range(8, h, 9):
		_fill(img, 0, y, w, 1, STEEL.darkened(0.08))
	for i in 40:
		_fill(img, _rng.randi_range(0, w - 8), _rng.randi_range(6, h - 2), _rng.randi_range(3, 8), 1, STEEL.lightened(0.18))
	_fill(img, 0, 0, 2, h, INK)
	_fill(img, w - 2, 0, 2, h, INK)
	return img

# Panela d'alu : bord ovale, eau qui frémit, corps cerclé de rivets, anses.
func _paint_pot() -> Image:
	var w: int = int((POT_R - POT_L) / D)
	var h: int = int((TRAY_Y + 12.0 - POT_TOP) / D)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var alu: Color = Color(0.80, 0.82, 0.85)
	var alu_hi: Color = Color(0.94, 0.95, 0.97)
	var alu_lo: Color = Color(0.55, 0.57, 0.62)
	var water: Color = Color(0.80, 0.70, 0.36)
	var water_hi: Color = Color(0.95, 0.88, 0.60)
	var cx: float = float(w) * 0.5
	var rx: float = cx - 8.0
	var ry: float = 9.0
	var cy: float = ry + 1.0
	# Corps.
	for x in range(8, w - 8):
		var nxv: float = (float(x) + 0.5 - cx) / rx
		var bottom_curve: int = int(round(ry * sqrt(maxf(0.0, 1.0 - nxv * nxv))))
		var col: Color = alu
		if nxv < -0.75:
			col = alu_lo
		elif nxv > 0.7:
			col = alu_lo.lightened(0.1)
		elif absf(nxv + 0.45) < 0.08:
			col = alu_hi
		_fill(img, x, int(cy), 1, h - int(cy), col)
		_dot(img, x, int(cy) + bottom_curve + 4, alu_lo)
	_fill(img, 8, int(cy), 1, h, INK)
	_fill(img, w - 9, int(cy), 1, h, INK)
	for x in range(14, w - 14, 10):
		var nxv2: float = (float(x) + 0.5 - cx) / rx
		var yy: int = int(cy) + int(round(ry * sqrt(maxf(0.0, 1.0 - nxv2 * nxv2)))) + 8
		_dot(img, x, yy, alu_lo.darkened(0.2))
		_dot(img, x, yy - 1, alu_hi)
	# Anses.
	for side in [-1, 1]:
		var ax: int = 0 if side < 0 else w - 8
		_fill(img, ax, int(cy) + 6, 8, 3, Color(0.2, 0.18, 0.18))
		_fill(img, ax, int(cy) + 6, 8, 1, Color(0.4, 0.38, 0.38))
	# Bord ovale + eau.
	for y in range(0, int(cy) + int(ry) + 2):
		for x in range(8, w - 8):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			var d: float = dx * dx + dy * dy
			if d > 1.0:
				continue
			var inner: float = (float(x) + 0.5 - cx) / (rx - 3.0)
			var inner_y: float = (float(y) + 0.5 - cy) / (ry - 1.5)
			var di: float = inner * inner + inner_y * inner_y
			var col: Color
			if di <= 1.0:
				col = water
				if (x + y * 3) % 17 == 0 or (y % 4 == 2 and (x + y) % 9 < 3):
					col = water_hi
				if dy < -0.55:
					col = water.darkened(0.12)
			else:
				col = alu_hi if dy < 0.0 else alu
				if d > 0.93:
					col = INK
			img.set_pixel(x, y, col)
	return img

# Plateau de bois (côté vendeur), caisse rouge et jaune, roues, botijão de gaz
# à gauche, isopor de mate à droite.
func _paint_cart() -> Image:
	var off: float = CART_L - 240.0
	var w: int = int((CART_R - CART_L + 480.0) / D)
	var h: int = int((BOTTOM - TRAY_Y) / D) + 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x0: int = int((CART_L - off) / D)
	var cw: int = int((CART_R - CART_L) / D)
	var tray_h: int = int(206.0 / D)
	# Botijão (P13) : derrière la roue gauche.
	var bx: int = x0 - 62
	var by: int = tray_h - 10
	var gas: Color = Color(0.86, 0.42, 0.14)
	_fill(img, bx, by + 6, 40, h - by - 6, gas)
	_fill(img, bx + 4, by, 32, 8, gas.darkened(0.15))
	_fill(img, bx + 12, by - 6, 16, 6, Color(0.5, 0.5, 0.55))
	_fill(img, bx + 6, by + 6, 6, h - by - 6, gas.lightened(0.2))
	_fill(img, bx, by + 22, 40, 2, gas.darkened(0.3))
	_fill(img, bx + 18, by - 12, 4, 6, Color(0.2, 0.2, 0.2))
	_fill(img, bx + 22, by - 10, 22, 2, Color(0.12, 0.12, 0.14))
	_outline_alpha(img)
	# Isopor à droite.
	var ix: int = x0 + cw + 16
	var iy: int = tray_h + 10
	_fill(img, ix, iy, 56, h - iy, Color(0.95, 0.95, 0.92))
	_fill(img, ix - 2, iy - 6, 60, 8, ZE_BLUE)
	_fill(img, ix - 2, iy - 6, 60, 2, ZE_BLUE.lightened(0.25))
	_fill(img, ix + 6, iy + 12, 44, 10, Color(0.85, 0.85, 0.82))
	for k in 6:
		_fill(img, ix + 3 + k * 9, iy + 30, 4, 4, Color(0.88, 0.88, 0.85))
	# Plateau.
	_fill(img, x0, 0, cw, tray_h, WOOD)
	for y in range(0, tray_h, 8):
		_fill(img, x0, y, cw, 1, WOOD.darkened(0.2))
		_fill(img, x0, y + 1, cw, 1, WOOD.lightened(0.1))
	for i in 90:
		_fill(img, x0 + _rng.randi_range(0, cw - 6), _rng.randi_range(2, tray_h - 2), _rng.randi_range(2, 6), 1, WOOD.darkened(0.12))
	_fill(img, x0, 0, cw, 2, WOOD.lightened(0.3))
	# Caisse : bandeau jaune, panneaux rouges, liseré.
	var body_y: int = tray_h
	_fill(img, x0, body_y, cw, 6, CART_YELLOW)
	_fill(img, x0, body_y + 6, cw, h - body_y - 6, CART_RED)
	_fill(img, x0, body_y + 6, cw, 1, CART_RED.darkened(0.35))
	for px in range(x0 + 8, x0 + cw - 8, 74):
		_fill(img, px, body_y + 14, 66, h - body_y - 14, CART_RED.lightened(0.08))
		_fill(img, px, body_y + 14, 66, 1, CART_RED.darkened(0.25))
		_fill(img, px, body_y + 14, 1, h - body_y - 14, CART_RED.darkened(0.25))
	# Roues de vélo, de part et d'autre.
	for wx in [x0 + 26, x0 + cw - 26]:
		_wheel(img, wx, h + 4, 22)
	_fill(img, x0, 0, 2, h, INK)
	_fill(img, x0 + cw - 2, 0, 2, h, INK)
	_fill(img, x0, body_y - 1, cw, 1, INK)
	return img

# Ombre de la carrocinha sur les pedras, et la cadeira de plástico de Zé
# (pour l'habitué qui reste papoter), à gauche.
func _paint_ground_props() -> Image:
	var w: int = _native_w()
	var h: int = int((BOTTOM - 300.0) / D) + 1
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var sh: Color = Color(0.0, 0.0, 0.05, 0.28)
	_fill(img, _col(CART_L - 300.0), 50, int((CART_R - CART_L + 600.0) / D), h - 50, sh)
	_fill(img, _col(CART_L - 290.0), 46, int((CART_R - CART_L + 580.0) / D), 4, Color(0.0, 0.0, 0.05, 0.14))
	var chair: Color = Color(0.86, 0.22, 0.2)
	var cx: int = _col(-1080.0)
	var cy: int = 6
	_fill(img, cx, cy, 34, 30, chair)
	_fill(img, cx + 2, cy + 2, 30, 4, chair.lightened(0.2))
	for k in 4:
		_fill(img, cx + 4 + k * 7, cy + 8, 4, 12, chair.darkened(0.2))
	_fill(img, cx - 2, cy + 30, 38, 6, chair.lightened(0.1))
	_fill(img, cx - 2, cy + 36, 4, 30, chair.darkened(0.15))
	_fill(img, cx + 32, cy + 36, 4, 30, chair.darkened(0.15))
	_fill(img, cx + 4, cy + 36, 3, 24, chair.darkened(0.3))
	_fill(img, cx + 27, cy + 36, 3, 24, chair.darkened(0.3))
	var src: Image = img.duplicate()
	for y in range(maxi(cy - 1, 0), cy + 68):
		for x in range(cx - 4, cx + 40):
			if src.get_pixel(x, y).a > 0.5 and src.get_pixel(x, y) != sh:
				continue
			for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Color = src.get_pixel(clampi(x + v.x, 0, w - 1), clampi(y + v.y, 0, h - 1))
				if q.a > 0.5:
					img.set_pixel(x, y, INK)
					break
	return img

func _wheel(img: Image, cx: int, cy: int, r: int) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d: float = sqrt(float(x * x + y * y))
			if d > float(r) + 0.5:
				continue
			var col: Color = Color(0, 0, 0, 0)
			if d > float(r) - 3.0:
				col = Color(0.12, 0.12, 0.14)
			elif d > float(r) - 4.0:
				col = Color(0.7, 0.7, 0.74)
			elif d < 3.0:
				col = Color(0.5, 0.5, 0.55)
			elif (x == 0 or y == 0 or x == y or x == -y):
				col = Color(0.75, 0.75, 0.78)
			if col.a > 0.0:
				_dot(img, cx + x, cy + y, col)

func _outline_alpha(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, INK)
					break

func _outline_box(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	_fill(img, 0, 0, w, 1, INK)
	_fill(img, 0, h - 1, w, 1, INK)
	_fill(img, 0, 0, 1, h, INK)
	_fill(img, w - 1, 0, 1, h, INK)

# --- Épis et icônes ---

# Épi debout (12×36 natifs) : grains en quinconce, couleur selon la cuisson,
# garnitures par-dessus (manteiga qui luit, sal en grains, queijo râpé).
func cob_image(cook: int, toppings: Array) -> Image:
	var key: String = "%d_%s" % [cook, ",".join(PackedStringArray(toppings))]
	if _cob_cache.has(key):
		return _cob_cache[key]
	var w: int = 12
	var h: int = 36
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = COB_COLORS[clampi(cook, 1, 4)]
	var hi: Color = base.lightened(0.28)
	var lo: Color = base.darkened(0.22)
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 31 + cook
	for y in range(1, h - 3):
		var half: float = 5.0
		if y < 5:
			half = 2.0 + float(y) * 0.75
		elif y > h - 8:
			half = 4.0
		for x in w:
			var dx: float = float(x) + 0.5 - 6.0
			if absf(dx) > half:
				continue
			var gap: bool = (y + (x / 2) % 2) % 3 == 0
			var col: Color = lo if gap else base
			if not gap and x % 2 == 0 and dx < 0.0:
				col = hi
			if dx > half - 1.2:
				col = lo
			if cook == 4 and r.randf() < 0.22:
				col = Color(0.32, 0.26, 0.2)
			img.set_pixel(x, y, col)
	# Talon (tige coupée).
	_fill(img, 4, h - 3, 4, 3, Color(0.70, 0.78, 0.48))
	_fill(img, 4, h - 1, 4, 1, Color(0.52, 0.6, 0.34))
	if toppings.has("manteiga"):
		for y in range(4, h - 5):
			img.set_pixel(4, y, Color(1.0, 0.97, 0.72))
			if y % 5 == 0:
				img.set_pixel(5, y, Color(1.0, 0.92, 0.5))
		img.set_pixel(3, h - 6, Color(1.0, 0.9, 0.45))
		img.set_pixel(8, h - 5, Color(1.0, 0.9, 0.45))
	if toppings.has("sal"):
		for i in 16:
			img.set_pixel(r.randi_range(2, 9), r.randi_range(3, h - 6), Color(1, 1, 1))
	if toppings.has("queijo"):
		for i in 12:
			var x2: int = r.randi_range(2, 8)
			var y2: int = r.randi_range(2, 18)
			img.set_pixel(x2, y2, Color(1.0, 0.97, 0.84))
			img.set_pixel(x2 + 1, y2, Color(0.95, 0.88, 0.62))
	_outline_alpha_dark(img, lo.darkened(0.5))
	_cob_cache[key] = img
	return img

func _outline_alpha_dark(img: Image, c: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a == 0.0:
				continue
			if x == 0 or y == 0 or x == w - 1 or img.get_pixel(x - 1, y).a == 0.0 or img.get_pixel(x + 1, y).a == 0.0 or img.get_pixel(x, y - 1).a == 0.0:
				img.set_pixel(x, y, c)

func _napkin_texture() -> ImageTexture:
	var img: Image = Image.create(12, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 14:
		var inset: int = absi(7 - y) / 3
		_fill(img, inset, y, 12 - inset * 2, 1, PAPER if y % 3 != 0 else Color(0.88, 0.86, 0.8))
	_outline_alpha_dark(img, Color(0.6, 0.58, 0.52))
	return ImageTexture.create_from_image(img)

# Icônes 16×16 natifs des garnitures (et de la lixeira).
func icon(id: String) -> ImageTexture:
	if _icons.has(id):
		return _icons[id]
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"manteiga":
			_fill(img, 1, 11, 14, 3, Color(0.92, 0.93, 0.96))
			_fill(img, 2, 13, 12, 1, Color(0.7, 0.72, 0.78))
			_fill(img, 3, 5, 10, 7, Color(1.0, 0.88, 0.40))
			_fill(img, 3, 5, 10, 2, Color(1.0, 0.96, 0.66))
			_fill(img, 11, 7, 2, 5, Color(0.92, 0.72, 0.26))
			_fill(img, 9, 2, 1, 6, Color(0.75, 0.75, 0.8))
			_fill(img, 10, 1, 1, 3, Color(0.55, 0.42, 0.28))
		"sal":
			_fill(img, 5, 5, 6, 10, Color(0.97, 0.97, 0.98))
			_fill(img, 9, 5, 2, 10, Color(0.8, 0.82, 0.86))
			_fill(img, 5, 9, 6, 3, ZE_BLUE)
			_fill(img, 5, 2, 6, 3, Color(0.7, 0.72, 0.76))
			_fill(img, 6, 1, 4, 1, Color(0.85, 0.86, 0.9))
			img.set_pixel(6, 3, INK)
			img.set_pixel(8, 3, INK)
			img.set_pixel(7, 2, INK)
		"queijo":
			for y in range(4, 14):
				var x_end: int = 2 + int(float(y - 3) * 1.25)
				_fill(img, 1, y, x_end, 1, Color(1.0, 0.82, 0.32))
			_fill(img, 1, 12, 14, 2, Color(0.92, 0.66, 0.2))
			for p: Vector2i in [Vector2i(3, 8), Vector2i(6, 11), Vector2i(9, 10), Vector2i(2, 11)]:
				img.set_pixel(p.x, p.y, Color(0.86, 0.62, 0.2))
			_fill(img, 1, 4, 1, 8, Color(1.0, 0.92, 0.6))
		"lixo":
			_fill(img, 3, 5, 10, 10, Color(0.36, 0.56, 0.38))
			_fill(img, 2, 3, 12, 2, Color(0.44, 0.66, 0.46))
			_fill(img, 6, 1, 4, 2, Color(0.30, 0.48, 0.32))
			for x in [5, 8, 11]:
				_fill(img, x, 7, 1, 7, Color(0.26, 0.42, 0.28))
	_outline_alpha(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex

# Icône agrandie pour un bouton (pixels nets dans le thème).
func button_icon(id: String, size_px: int = 64) -> ImageTexture:
	var img: Image = icon(id).get_image()
	img.resize(size_px, size_px, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# --- État (venu de MilhoGame) ---

func sync(pot: Array, queue: Array, hand: Dictionary, pot_state: Callable) -> void:
	_pot = pot
	_queue = queue
	_hand = hand
	for i in mini(3, pot.size()):
		var cob: Sprite2D = _cob_sprites[i]
		var lbl: Label = _pot_labels[i]
		if pot[i].is_empty():
			cob.visible = false
			lbl.text = "+ épi"
			lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82))
			continue
		var t: float = float(pot[i].t)
		var st: int = int(pot_state.call(t))
		cob.visible = true
		cob.texture = ImageTexture.create_from_image(cob_image(st, [])) if cob.get_meta("st", -1) != st else cob.texture
		cob.set_meta("st", st)
		match st:
			1:
				lbl.text = "cru · %ds" % int(ceil(5.0 - t))
				lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.8))
			2:
				lbl.text = "NO PONTO!"
				lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25))
			3:
				lbl.text = "passado"
				lbl.add_theme_color_override("font_color", Color(0.96, 0.6, 0.3))
			_:
				lbl.text = "desmanchou"
				lbl.add_theme_color_override("font_color", Color(0.7, 0.62, 0.56))
	for i in mini(3, queue.size()):
		var c: Dictionary = queue[i]
		if not c.is_empty() and not _occupied[i]:
			_arrive(i, c)
		elif c.is_empty() and _occupied[i]:
			_depart(i)
		_fill_bubble(i, c)
	if hand.is_empty():
		_hand_sprite.visible = false
		_napkin.visible = false
	else:
		var img: Image = cob_image(int(hand.cook), hand.toppings).duplicate()
		img.rotate_90(COUNTERCLOCKWISE)
		_hand_sprite.texture = ImageTexture.create_from_image(img)
		_hand_sprite.visible = true
		_napkin.visible = true

func _fill_bubble(i: int, c: Dictionary) -> void:
	var on: bool = not c.is_empty()
	_name_labels[i].visible = on
	_line_labels[i].visible = on and (c.get("regular", false) or not c.get("shows_order", true))
	_ask_labels[i].visible = on and not c.get("shows_order", true)
	if not on:
		return
	_name_labels[i].text = String(c.name)
	if not c.get("shows_order", true):
		_line_labels[i].text = "« O de sempre, moço. »"
	elif c.get("regular", false):
		_line_labels[i].text = String(c.line)

func splash(i: int) -> void:
	_splash_t[i] = 0.0

# Note du service : le client repart content, déçu ou fâché.
func serve(i: int, grade: int, known: bool) -> void:
	if grade == 2:
		_pending_mood[i] = "known" if known else "happy"
	elif grade == 1:
		_pending_mood[i] = "ok"
	else:
		_pending_mood[i] = "refused"
	if not _hand.is_empty():
		_toss(i, cob_image(int(_hand.cook), _hand.toppings))

func _sheet_for(c: Dictionary) -> Dictionary:
	if c.get("regular", false):
		return CharacterSpriteFactory.config_for_npc(String(c.id))
	return CharacterSpriteFactory.random_config(int(c.get("seed", 1)))

func _arrive(i: int, c: Dictionary) -> void:
	_occupied[i] = true
	_pending_mood[i] = ""
	var s: Sprite2D = client_sprites[i]
	s.texture = CharacterSpriteFactory.build_sheet(_sheet_for(c))
	var k: float = CLIENT_SCALE * (0.8 if c.get("kind", "") == "gamin" else 1.0)
	s.scale = Vector2(k, k)
	s.visible = true
	s.modulate = Color(1, 1, 1, 1)
	_arrive_from[i] = -1.0 if i == 0 else (1.0 if i == 2 else (1.0 if _rng.randf() < 0.5 else -1.0))
	_arrive_t[i] = 0.0

func _depart(i: int) -> void:
	_occupied[i] = false
	var s: Sprite2D = client_sprites[i]
	s.visible = false
	var mood: String = _pending_mood[i] if _pending_mood[i] != "" else "angry"
	_pending_mood[i] = ""
	if s.texture == null or not is_inside_tree():
		return
	var ghost: Sprite2D = s.duplicate() as Sprite2D
	ghost.visible = true
	add_child(ghost)
	var dir: float = -1.0 if i == 0 else 1.0
	if i == 1:
		dir = -1.0 if _rng.randf() < 0.5 else 1.0
	ghost.flip_h = dir < 0.0
	ghost.set_meta("walk", true)
	var say: Dictionary = {
		"known": ["Tu me conheces!", Color(1.0, 0.85, 0.3)],
		"happy": ["Que delícia!", Color(1.0, 0.85, 0.3)],
		"ok": ["Tá bom…", Color(0.92, 0.9, 0.82)],
		"refused": ["Isso não!", Color(1.0, 0.45, 0.4)],
		"angry": ["Demorou!", Color(1.0, 0.45, 0.4)],
	}
	var emote: Label = Label.new()
	emote.theme_type_variation = &"Pastille"
	emote.text = say[mood][0]
	emote.add_theme_color_override("font_color", say[mood][1])
	emote.add_theme_font_size_override("font_size", 22)
	emote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emote.size = Vector2(240, 44)
	emote.position = Vector2(-120 / ghost.scale.x, -330 / ghost.scale.y)
	emote.scale = Vector2(1.0 / ghost.scale.x, 1.0 / ghost.scale.y)
	emote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(emote)
	if mood == "known" or mood == "happy" or mood == "ok":
		var held: Sprite2D = Sprite2D.new()
		held.texture = ImageTexture.create_from_image(cob_image(2 if mood != "ok" else 3, []))
		held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		held.scale = Vector2(D / ghost.scale.x * 0.7, D / ghost.scale.y * 0.7)
		held.position = Vector2(14, -40)
		ghost.add_child(held)
	var tw: Tween = create_tween()
	var wait: float = 0.35 if mood != "angry" else 0.15
	tw.tween_interval(wait)
	tw.tween_property(ghost, "position:x", ghost.position.x + dir * 520.0, 1.6)
	tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.tween_callback(ghost.queue_free)

# L'épi part de la main vers le client, en cloche.
func _toss(i: int, img: Image) -> void:
	if not is_inside_tree():
		return
	var s: Sprite2D = Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(D, D)
	s.z_index = 9
	s.position = HAND_POS
	add_child(s)
	var a: Vector2 = HAND_POS
	var b: Vector2 = Vector2(CLIENT_X[i] + 20.0, FEET_Y - 100.0)
	var tw: Tween = create_tween()
	tw.tween_method(func(u: float) -> void:
		s.position = a.lerp(b, u) + Vector2(0, -sin(u * PI) * 180.0), 0.0, 1.0, 0.32)
	tw.tween_callback(s.queue_free)

# --- Animation ---

func _process(delta: float) -> void:
	_t += delta
	for i in 3:
		_splash_t[i] += delta
		var s: Sprite2D = client_sprites[i]
		if not s.visible:
			continue
		var cy: int = CharacterSpriteFactory.DIR_DOWN
		var col: int = 0
		var x: float = CLIENT_X[i]
		if _arrive_t[i] < 0.6:
			_arrive_t[i] += delta
			var u: float = clampf(_arrive_t[i] / 0.6, 0.0, 1.0)
			x += _arrive_from[i] * 300.0 * (1.0 - u)
			cy = CharacterSpriteFactory.DIR_RIGHT
			s.flip_h = _arrive_from[i] > 0.0
			col = [1, 0, 2, 0][int(_t * 9.0) % 4]
		else:
			s.flip_h = false
			var c: Dictionary = _queue[i] if i < _queue.size() else {}
			var p: float = float(c.get("patience", PATIENCE_MAX)) / PATIENCE_MAX
			# Impatient : il piétine.
			if p < 0.3:
				col = [1, 0, 2, 0][int(_t * 6.0) % 4]
		s.position = Vector2(snappedf(x, D), FEET_Y)
		s.region_rect = Rect2(col * CharacterSpriteFactory.CELL_W, cy * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	for n in get_children():
		if n is Sprite2D and n.has_meta("walk"):
			var g: Sprite2D = n
			g.region_rect = Rect2([1, 0, 2, 0][int(_t * 9.0) % 4] * CharacterSpriteFactory.CELL_W,
				CharacterSpriteFactory.DIR_RIGHT * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	for i in mini(3, _pot.size()):
		var cob: Sprite2D = _cob_sprites[i]
		if not cob.visible:
			continue
		var st: int = int(cob.get_meta("st", 1))
		var bob: float = 0.0 if int(_t * 3.0 + i) % 2 == 0 else D
		var sink: float = 18.0 if st == 4 else 0.0
		var dip: float = 0.0
		if _splash_t[i] < 0.3:
			dip = (1.0 - _splash_t[i] / 0.3) * -60.0
		cob.position = Vector2(POT_X[i] - 24.0, WATER_Y - 126.0 + bob + sink + dip).snapped(Vector2(D, D))
	if _hand_sprite.visible:
		_hand_sprite.position = HAND_POS + Vector2(0, D if int(_t * 2.0) % 2 == 0 else 0.0)
	_far.queue_redraw()
	_bubbles.queue_redraw()
	_fx.queue_redraw()

func _cell(ci: CanvasItem, p: Vector2, col: Color, n: float = 1.0) -> void:
	ci.draw_rect(Rect2((p / D).floor() * D, Vector2(D, D) * n), col)

# Écume qui va et vient sur le sable, éclats sur la mer.
func _draw_far() -> void:
	var span: float = RIGHT - LEFT
	var adv: float = (sin(_t * 1.3) * 0.5 + 0.5) * 9.0
	var x: float = LEFT
	while x < RIGHT:
		var wob: float = sin(x * 0.02 + _t * 0.8) * 4.0
		var y: float = SHORE - 3.0 + adv + wob
		_far.draw_rect(Rect2(Vector2(x, y).snapped(Vector2(D, D)), Vector2(D * 2, D)), GroundPainter.FOAM_WHITE)
		if int(x / 6.0) % 3 == 0:
			_far.draw_rect(Rect2(Vector2(x, y - D).snapped(Vector2(D, D)), Vector2(D, D)), GroundPainter.FOAM_WHITE)
		_far.draw_rect(Rect2(Vector2(x, y + D).snapped(Vector2(D, D)), Vector2(D * 2, D)), SAND_COLOR.darkened(0.12))
		x += D * 2
	for k in 14:
		var px: float = LEFT + fposmod(float(k) * 197.0 + _t * 12.0 * (1.0 + float(k % 3)), span)
		var py: float = HORIZON + 12.0 + float((k * 37) % 60)
		if int(_t * 2.0 + k) % 3 != 0:
			_far.draw_rect(Rect2(Vector2(px, py).snapped(Vector2(D, D)), Vector2(D * 2, D)), SEA_COLOR.lightened(0.45))
	# Un veleiro au large.
	var bx: float = snappedf(LEFT + fposmod(300.0 + _t * 6.0, span), D)
	_far.draw_rect(Rect2(bx - 6, HORIZON + 15, 18, D), Color(0.22, 0.18, 0.2))
	for i in 5:
		_far.draw_rect(Rect2(bx + 3 - float(i / 2 * D), HORIZON + 15 - D * (5 - i), float((i / 2 + 1) * D), D), Color(0.98, 0.97, 0.94))

# Bulles de commande et jauges de patience.
func _draw_bubbles() -> void:
	for i in mini(3, _queue.size()):
		var c: Dictionary = _queue[i]
		if c.is_empty() or _arrive_t[i] < 0.6:
			_set_bubble_labels(i, false)
			continue
		_set_bubble_labels(i, true)
		var cx: float = CLIENT_X[i]
		var p: float = clampf(float(c.get("patience", PATIENCE_MAX)) / PATIENCE_MAX, 0.0, 1.0)
		var shake: float = 0.0
		if p < 0.3:
			shake = D if int(_t * 14.0) % 2 == 0 else 0.0
		var r: Rect2 = Rect2(cx - BUBBLE_HALF_W + shake, BUBBLE_TOP, BUBBLE_HALF_W * 2.0, BUBBLE_BOTTOM - BUBBLE_TOP)
		var known: bool = c.get("regular", false) and not c.get("shows_order", true)
		var edge: Color = Color(0.85, 0.55, 0.08) if known else INK
		if p < 0.3:
			edge = Color(0.8, 0.18, 0.14)
		# Ombre, cadre aux coins coupés, queue vers la tête.
		_bubbles.draw_rect(Rect2(r.position + Vector2(D * 2, D * 2), r.size), Color(0, 0, 0, 0.25))
		_bubbles.draw_rect(r.grow_individual(-D, 0, -D, 0), edge)
		_bubbles.draw_rect(r.grow_individual(0, -D, 0, -D), edge)
		_bubbles.draw_rect(r.grow(-D), PAPER)
		_bubbles.draw_rect(Rect2(r.position.x + D, r.end.y - D * 2, r.size.x - D * 2, D), PAPER.darkened(0.08))
		for k in 5:
			var wv: float = float(5 - k) * D * 2.0
			_bubbles.draw_rect(Rect2(cx + shake - wv * 0.5 - D, r.end.y - D + k * D, wv + D * 2, D), edge)
			_bubbles.draw_rect(Rect2(cx + shake - wv * 0.5, r.end.y - D + k * D, wv, D), PAPER)
		_name_labels[i].position.x = cx - 190 + shake
		# Commande en icônes (si le client la dit).
		if c.get("shows_order", true):
			var order: Array = c.get("order", [])
			var n: int = order.size()
			var sz: float = 48.0
			var gap: float = 30.0
			var total: float = n * sz + (n - 1) * gap
			var y: float = BUBBLE_TOP + (36.0 if c.get("regular", false) else 60.0)
			var x0: float = cx + shake - total * 0.5
			var k2: int = 0
			for t in ["manteiga", "sal", "queijo"]:
				if not order.has(t):
					continue
				var ix: float = x0 + k2 * (sz + gap)
				_bubbles.draw_texture_rect(icon(t), Rect2(ix, y, sz, sz), false)
				if k2 < n - 1:
					var px: float = ix + sz + gap * 0.5
					_bubbles.draw_rect(Rect2(px - 9, y + 21, 18, 6), Color(0.45, 0.3, 0.2))
					_bubbles.draw_rect(Rect2(px - 3, y + 15, 6, 18), Color(0.45, 0.3, 0.2))
				k2 += 1
		# Jauge de patience : des grains de milho qui se vident.
		var gy: float = BUBBLE_BOTTOM - 24.0
		var gx: float = cx + shake - 162.0
		var cells: int = 18
		var full: int = int(ceil(p * cells))
		var gcol: Color = Color(0.35, 0.72, 0.3) if p > 0.55 else (Color(0.98, 0.72, 0.2) if p > 0.3 else Color(0.88, 0.25, 0.18))
		_bubbles.draw_rect(Rect2(gx - D, gy - D, cells * 18.0 + D, 18.0), Color(0.42, 0.32, 0.22))
		for k3 in cells:
			var on: bool = k3 < full
			_bubbles.draw_rect(Rect2(gx + k3 * 18.0, gy, 15.0, 12.0), gcol if on else Color(0.62, 0.55, 0.45))
			if on:
				_bubbles.draw_rect(Rect2(gx + k3 * 18.0, gy, 6.0, D), gcol.lightened(0.35))

func _set_bubble_labels(i: int, on: bool) -> void:
	if not on:
		_name_labels[i].modulate.a = 0.0
		_line_labels[i].modulate.a = 0.0
		_ask_labels[i].modulate.a = 0.0
	else:
		_name_labels[i].modulate.a = 1.0
		_line_labels[i].modulate.a = 1.0
		_ask_labels[i].modulate.a = 1.0

# Vapeur et bouillons de la panela.
func _draw_fx() -> void:
	# Frémissement de toute la surface.
	for k in 18:
		var ph: float = fposmod(_t * 1.7 + float(k) * 0.37, 1.0)
		var bx: float = POT_L + 40.0 + fposmod(float(k) * 131.0, POT_R - POT_L - 80.0)
		var by: float = POT_TOP + 12.0 + float((k * 17) % 24)
		if ph < 0.6:
			_cell(_fx, Vector2(bx, by), Color(1, 0.98, 0.85, 0.85))
		elif ph < 0.75:
			_cell(_fx, Vector2(bx - D, by), Color(1, 0.98, 0.85, 0.6))
			_cell(_fx, Vector2(bx + D, by), Color(1, 0.98, 0.85, 0.6))
	for i in mini(3, _pot.size()):
		if _pot[i].is_empty():
			continue
		var st: int = int(_cob_sprites[i].get_meta("st", 1))
		var inten: float = 0.55 if st == 1 else (0.75 if st == 4 else 1.0)
		for k in 7:
			var ph2: float = fposmod(_t * 0.5 + float(k) / 7.0 + float(i) * 0.13, 1.0)
			var y: float = WATER_Y - 20.0 - ph2 * 240.0
			var x: float = POT_X[i] + sin(ph2 * 4.0 + float(k) * 1.7) * 30.0
			var a: float = (1.0 - ph2) * 0.75 * inten
			var n: float = 3.0 + floor(ph2 * 5.0)
			var col: Color = Color(1, 1, 1, a)
			_cell(_fx, Vector2(x, y), col, n)
			_cell(_fx, Vector2(x - D * n * 0.5, y + D * n * 0.4), col, maxf(1.0, n - 1.0))
			_cell(_fx, Vector2(x + D * n * 0.6, y + D * n * 0.3), col, maxf(1.0, n - 1.0))
		# Éclat « no ponto ».
		if st == 2 and int(_t * 4.0 + i) % 4 != 0:
			var sp: Vector2 = Vector2(POT_X[i] + 27.0, WATER_Y - 126.0)
			var g: Color = Color(1, 1, 0.8)
			_cell(_fx, sp, g)
			_cell(_fx, sp + Vector2(D, 0), g)
			_cell(_fx, sp - Vector2(D, 0), g)
			_cell(_fx, sp + Vector2(0, D), g)
			_cell(_fx, sp - Vector2(0, D), g)
		if _splash_t[i] < 0.35:
			var u: float = _splash_t[i] / 0.35
			for k4 in 6:
				var ang: float = PI + float(k4) / 5.0 * PI
				var p: Vector2 = Vector2(POT_X[i], WATER_Y - 6.0) + Vector2(cos(ang) * 50.0, sin(ang) * 44.0) * u + Vector2(0, u * u * 40.0)
				_cell(_fx, p, Color(0.9, 0.95, 1.0, 1.0 - u), 2.0)
