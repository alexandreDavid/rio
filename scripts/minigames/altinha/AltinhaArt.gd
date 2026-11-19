extends Node2D

# Rendu de l'altinha (aucune règle ici) : la roda vue de 3/4 sur le sable
# d'Ipanema, mer peinte et écume derrière, Dois Irmãos et les Cagarras à
# l'horizon, barracas, cangas, cadeiras, vendeurs de mate et de biscoito
# Globo qui passent, baigneurs. Variante « laje » : toit du morro, maisons en
# face, caixa d'água, varal et pipas. Tout est peint en pixels natifs
# (1 px = 3 px monde) et affiché en NEAREST ; les personnages sont ceux de
# CharacterSpriteFactory, avec des poses de touche (genou, tête, pied)
# repeintes à partir de leur planche.

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const PX: int = 3
const INK: Color = Color(0.13, 0.10, 0.12)
const VIEW_L: float = -960.0
const VIEW_R: float = 960.0
const SKY_TOP: float = -480.0
const HORIZON_Y: float = -186.0
const SHORE_Y: float = -126.0
const GROUND_BOTTOM: float = 480.0

# Toile des poses : la cellule native 21×32 décalée de (3, 3) pour laisser
# dépasser bras écartés, jambe tendue et saut.
const POSE_W: int = 27
const POSE_H: int = 36
const POSE_OX: int = 3
const POSE_OY: int = 3
const POSE_OFFSET: Vector2 = Vector2(-13.5, -34.0)

const SEA_COLOR: Color = Color(0.20, 0.62, 0.78)
const FOAM_FPS: float = 5.0
const SEA_PERIOD: float = 0.6
const KICK_TIME: float = 0.26

static var _pose_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

var _t: float = 0.0
var _setting: String = "praia"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sea: Sprite2D = null
var _foam: Sprite2D = null
var _foam_frames: Array[Texture2D] = []
var _bathers: Array[Sprite2D] = []
var _bather_base: Array[Vector2] = []
var _walkers: Array[Dictionary] = []
var _kites: Array[Dictionary] = []
var _kite_layer: Node2D = null

# Joueur (vu de dos, face à la roda).
var _player_node: Node2D = null
var _player_spr: Sprite2D = null
var _player_poses: Dictionary = {}
var _player_kick: float = 0.0
var _player_kick_key: String = ""
var _player_kick_flip: bool = false
var _walk_t: float = 0.0


func build(setting: String) -> void:
	_setting = setting
	_rng.seed = 1977
	if setting == "laje":
		_build_laje()
	else:
		_build_praia()


func tick(delta: float) -> void:
	_t += delta
	if _sea:
		var r: Rect2 = _sea.region_rect
		r.position.x = float(GroundPainter.BIG * (int(_t / SEA_PERIOD) % GroundPainter.SEA_FRAMES))
		_sea.region_rect = r
	if _foam and not _foam_frames.is_empty():
		_foam.texture = _foam_frames[int(_t * FOAM_FPS) % _foam_frames.size()]
	for i in _bathers.size():
		var b: Sprite2D = _bathers[i]
		b.position.y = _bather_base[i].y + snappedf(sin(_t * 1.7 + float(i) * 1.9) * 2.0, PX)
	_tick_walkers(delta)
	if _kite_layer:
		_kite_layer.queue_redraw()


# --- Joueur ---

func make_player(node: Node2D) -> void:
	_player_node = node
	_player_poses = poses(CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices()))
	var sh: Sprite2D = shadow_sprite(9)
	node.add_child(sh)
	_player_spr = body_sprite(_player_poses, "up_0")
	node.add_child(_player_spr)


# axis = déplacement tenu ; ball_x = abscisse de la balle (sol) ; incoming =
# la balle vient vers le joueur.
func update_player(delta: float, axis: float, _ball_x: float) -> void:
	if _player_spr == null:
		return
	if _player_kick > 0.0:
		_player_kick -= delta
		_player_spr.texture = _player_poses[_player_kick_key]
		_player_spr.flip_h = _player_kick_flip
		return
	if absf(axis) > 0.05:
		_walk_t += delta * (6.0 + 4.0 * absf(axis))
		var seq: Array[int] = [1, 0, 2, 0]
		_player_spr.texture = _player_poses["right_%d" % seq[int(_walk_t) % 4]]
		_player_spr.flip_h = axis < 0.0
	else:
		# Ginga sur place : on ne reste jamais planté dans une roda.
		var seq2: Array[int] = [0, 1, 0, 2]
		_player_spr.texture = _player_poses["up_%d" % seq2[int(_t * 3.0) % 4]]
		_player_spr.flip_h = false


# Pose de touche : Perfeito = coup de pied orienté vers le parceiro visé,
# Boa = genou, Mole = tête (la balle mal négociée).
func player_kick(quality: int, aim_right: bool) -> void:
	match quality:
		2:
			_player_kick_key = "right_kick"
			_player_kick_flip = not aim_right
		1:
			_player_kick_key = "up_knee"
			_player_kick_flip = not aim_right
		_:
			_player_kick_key = "up_head"
			_player_kick_flip = false
	_player_kick = KICK_TIME


# --- Poses (statiques, partagées avec AltinhaPartner) ---

# Dictionnaire de textures natives : "<dir>_<frame>" (down/up/right × 0..2)
# + "down_knee", "down_head", "up_knee", "up_head", "right_kick".
static func poses(cfg: Dictionary) -> Dictionary:
	var sheet_tex: ImageTexture = CharacterSpriteFactory.build_sheet(cfg)
	var key: int = sheet_tex.get_instance_id()
	if _pose_cache.has(key):
		return _pose_cache[key]
	var sheet: Image = sheet_tex.get_image()
	var out: Dictionary = {}
	var names: Array[String] = ["down", "up", "right"]
	var bases: Dictionary = {}
	for d in 3:
		for f in 3:
			var img: Image = _native_cell(sheet, d, f)
			if f == 0:
				bases[names[d]] = img
			out["%s_%d" % [names[d], f]] = ImageTexture.create_from_image(img)
	var skin: Color = cfg.get("skin", Color(0.92, 0.78, 0.62))
	var shirt: Color = cfg.get("shirt_color", Color(0.85, 0.55, 0.4))
	var pants: Color = cfg.get("pants_color", Color(0.3, 0.25, 0.2))
	for dn: String in ["down", "up"]:
		out[dn + "_knee"] = ImageTexture.create_from_image(_front_knee(bases[dn], skin, shirt, pants))
		out[dn + "_head"] = ImageTexture.create_from_image(_front_head(bases[dn], skin, shirt))
	out["right_kick"] = ImageTexture.create_from_image(_side_kick(bases["right"], skin, shirt, pants))
	_pose_cache[key] = out
	return out


static func body_sprite(pose_set: Dictionary, key: String) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = "CharSprite"
	s.texture = pose_set[key]
	s.centered = false
	s.offset = POSE_OFFSET
	s.scale = Vector2(PX, PX)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


static func shadow_sprite(w: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = "Shadow"
	s.texture = ellipse_tex(w, maxi(2, w / 3), Color(0.30, 0.20, 0.08, 0.35))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PX, PX)
	s.z_index = -1
	return s


static func ellipse_tex(w: int, h: int, c: Color) -> Texture2D:
	var key: String = "ell_%d_%d_%s" % [w, h, c.to_html()]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img: Image = Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


# Flamme pixel du parceiro « quente » : 3 frames 7×10.
static func flame_frames() -> Array[Texture2D]:
	if _tex_cache.has("flame"):
		return _tex_cache["flame"]
	var frames: Array[Texture2D] = []
	var rows: Array = [
		["...o...", "...o...", "..o...."],
		["..oo...", "...oo..", "..oo..."],
		["..oyo..", "..oyo..", ".oyo..."],
		[".oyyo..", ".oyyo..", ".oyyo.."],
		[".oywyo.", "oyywyo.", ".oywyo."],
		["oyywyo.", "oywwyo.", "oyywwo."],
		["oywwyoo", "oywwyyo", "oywwyo."],
		["royyyor", "royyyor", "royyyor"],
		[".rooor.", ".roooor", "rroooo."],
		["..rrr..", "..rrr..", "..rrr.."],
	]
	var pal: Dictionary = {"o": Color(1.0, 0.55, 0.12), "y": Color(1.0, 0.85, 0.25), "w": Color(1.0, 0.98, 0.82), "r": Color(0.86, 0.22, 0.12)}
	for f in 3:
		var img: Image = Image.create(7, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in 10:
			var line: String = rows[y][f]
			for x in 7:
				var ch: String = line[x]
				if pal.has(ch):
					img.set_pixel(x, y, pal[ch])
		_outline(img)
		frames.append(ImageTexture.create_from_image(img))
	_tex_cache["flame"] = frames
	return frames


static func _native_cell(sheet: Image, dir: int, frame: int) -> Image:
	var img: Image = Image.create(POSE_W, POSE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in CharacterSpriteFactory.NAT_H:
		for x in CharacterSpriteFactory.NAT_W:
			var c: Color = sheet.get_pixel(frame * CharacterSpriteFactory.CELL_W + x * 3 + 1,
				dir * CharacterSpriteFactory.CELL_H + y * 3 + 1)
			if c.a > 0.01:
				img.set_pixel(x + POSE_OX, y + POSE_OY, c)
	return img


static func _p(img: Image, x: int, y: int, c: Color) -> void:
	var px: int = x + POSE_OX
	var py: int = y + POSE_OY
	if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
		img.set_pixel(px, py, c)


static func _erase(img: Image, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_p(img, x, y, Color(0, 0, 0, 0))


static func _box(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_p(img, x, y, c)


# Bras écartés vers le haut (équilibre de la roda), repère natif du perso.
static func _arms_out(img: Image, skin: Color, shirt: Color) -> void:
	_erase(img, 2, 15, 5, 23)
	_erase(img, 15, 15, 18, 23)
	_box(img, 6, 15, 6, 22, shirt.darkened(0.24))
	_box(img, 14, 15, 14, 22, shirt)
	for side in 2:
		var m: Callable = func(x: int) -> int: return x if side == 0 else 20 - x
		var sk: Color = skin if side == 0 else skin.darkened(0.22)
		_p(img, m.call(5), 15, shirt)
		_p(img, m.call(4), 15, shirt.darkened(0.24))
		_p(img, m.call(5), 16, shirt.darkened(0.24))
		_p(img, m.call(3), 14, sk)
		_p(img, m.call(4), 14, sk)
		_p(img, m.call(2), 13, sk)
		_p(img, m.call(3), 13, sk)
		_p(img, m.call(1), 12, skin.darkened(0.22))
		_p(img, m.call(2), 12, sk)


# Genou levé (vue de face ou de dos) : la jambe droite de l'image remonte,
# cuisse à l'horizontale, tibia replié.
static func _front_knee(base: Image, skin: Color, shirt: Color, pants: Color) -> Image:
	var img: Image = base.duplicate()
	_erase(img, 11, 23, 16, 32)
	_box(img, 11, 22, 15, 24, pants)
	_box(img, 11, 22, 11, 24, pants.darkened(0.26))
	_box(img, 12, 25, 15, 26, skin)
	_box(img, 12, 26, 15, 26, skin.darkened(0.22))
	_box(img, 12, 27, 16, 27, Color(0.28, 0.20, 0.14))
	_arms_out(img, skin, shirt)
	_clean_outline(img)
	return img


# Tête : saut de 3 pixels, bras ouverts, jambes un peu repliées.
static func _front_head(base: Image, skin: Color, shirt: Color) -> Image:
	var src: Image = base.duplicate()
	_strip_outline(src)
	var img: Image = Image.create(POSE_W, POSE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(3, POSE_H):
		for x in POSE_W:
			var c: Color = src.get_pixel(x, y)
			if c.a > 0.01:
				img.set_pixel(x, y - 3, c)
	_arms_out(img, skin, shirt)
	_clean_outline(img)
	return img


# Coup de pied de profil : jambe avant tendue à hauteur de genou, bras arrière
# levé pour l'équilibre.
static func _side_kick(base: Image, skin: Color, shirt: Color, pants: Color) -> Image:
	var img: Image = base.duplicate()
	_erase(img, 5, 23, 20, 32)
	var sandal: Color = Color(0.28, 0.20, 0.14)
	# Jambe d'appui.
	_box(img, 8, 23, 10, 26, pants.darkened(0.26))
	_box(img, 9, 27, 10, 28, skin.darkened(0.22))
	_box(img, 7, 29, 11, 30, sandal)
	# Jambe de frappe.
	_box(img, 11, 22, 14, 24, pants)
	_box(img, 15, 22, 17, 23, skin)
	_box(img, 18, 21, 19, 23, sandal)
	# Bras : l'avant recouvert de chemise, un bras levé vers l'arrière.
	_box(img, 13, 18, 13, 21, shirt)
	_erase(img, 2, 15, 6, 22)
	_box(img, 7, 15, 7, 22, shirt.darkened(0.24))
	_p(img, 6, 15, shirt.darkened(0.24))
	_p(img, 5, 14, skin)
	_p(img, 4, 13, skin)
	_p(img, 3, 12, skin.darkened(0.22))
	_p(img, 14, 16, skin)
	_p(img, 15, 15, skin)
	_p(img, 16, 14, skin.darkened(0.22))
	_clean_outline(img)
	return img


static func _strip_outline(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(CharacterSpriteFactory.LINE_COLOR):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


# Retire le contour d'origine (orphelin là où on a repeint) et le régénère.
static func _clean_outline(img: Image) -> void:
	_strip_outline(img)
	_outline(img)


static func _outline(img: Image) -> void:
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


# --- Construction commune ---

func _layer(img: Image, origin: Vector2, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PX, PX)
	s.position = origin
	s.z_index = z
	add_child(s)
	return s


func _tex_sprite(tex: Texture2D, feet: Vector2, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PX, PX)
	s.position = feet
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


func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _native_w() -> int:
	return int((VIEW_R - VIEW_L) / float(PX))


func _col(wx: float) -> int:
	return int(floor((wx - VIEW_L) / float(PX)))


# Ciel en bandes tramées (du zénith à `bottom`), nuages pixel.
func _paint_sky(bottom: float) -> Image:
	var w: int = _native_w()
	var h: int = int((bottom - SKY_TOP) / float(PX)) + 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bands: Array[Color] = [Color(0.31, 0.56, 0.88), Color(0.38, 0.64, 0.92), Color(0.47, 0.72, 0.95),
		Color(0.59, 0.80, 0.97), Color(0.74, 0.88, 0.98)]
	var limits: Array[float] = [-390.0, -320.0, -262.0, -215.0]
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
	for c: Vector3 in [Vector3(-700, -330, 30), Vector3(-260, -290, 22), Vector3(90, -350, 36),
			Vector3(520, -300, 26), Vector3(820, -360, 20), Vector3(-90, -235, 14)]:
		_cloud(img, _col(c.x), int((c.y - SKY_TOP) / float(PX)), int(c.z))
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


# --- Ipanema ---

func _build_praia() -> void:
	var sky: Image = _paint_sky(HORIZON_Y)
	_paint_dois_irmaos(sky)
	_paint_islands(sky)
	_layer(sky, Vector2(VIEW_L, SKY_TOP), -14)
	_build_sea()
	_build_sand()
	_build_foam()
	_build_bathers()
	_build_beach_props()
	_build_walkers()


# Dois Irmãos à droite (ouest), Vidigal au pied, Pedra da Gávea derrière ;
# la mata est voilée par la distance.
func _paint_dois_irmaos(img: Image) -> void:
	var hz: int = img.get_height() - 2
	var haze: Color = Color(0.74, 0.88, 0.98)
	var gavea: Color = Color(0.50, 0.62, 0.74)
	var veg: Color = Color(0.27, 0.50, 0.38).lerp(haze, 0.22)
	var veg_hi: Color = veg.lightened(0.12)
	var veg_sh: Color = veg.darkened(0.18)
	var rock: Color = Color(0.56, 0.56, 0.60).lerp(haze, 0.2)
	var rock_sh: Color = rock.darkened(0.2)
	var w: int = img.get_width()
	var prof: PackedFloat32Array = PackedFloat32Array()
	prof.resize(w)
	for x in w:
		var wx: float = VIEW_L + float(x * PX)
		# Gávea : table de granit au loin.
		var g: float = 0.0
		if wx > 380.0:
			g = 26.0 * clampf((wx - 380.0) / 90.0, 0.0, 1.0) + 3.0 * sin(wx * 0.04)
			_fill(img, x, hz - int(g), 1, int(g) + 2, gavea)
			_dot(img, x, hz - int(g), gavea.lightened(0.15))
		var p1: float = _peak(wx, 255.0, 66.0, 30.0)
		var p2: float = _peak(wx, 345.0, 58.0, 24.0)
		var ridge: float = 8.0 * clampf((wx - 150.0) / 60.0, 0.0, 1.0) + 2.0 * sin(wx * 0.05)
		prof[x] = maxf(maxf(p1, p2), ridge if wx > 150.0 else 0.0)
	for x in w:
		var hh: float = prof[x]
		if hh < 1.0:
			continue
		var top: int = hz - int(hh)
		var slope: float = prof[mini(x + 1, w - 1)] - prof[maxi(x - 1, 0)]
		for y in range(top, hz + 2):
			var depth: int = y - top
			var c: Color = veg
			# Face rocheuse : pentes raides du côté de la mer (à gauche).
			if slope > 1.5 and depth < int(hh * 0.7):
				c = rock if (x + y) % 5 != 0 else rock_sh
			elif depth == 0:
				c = veg_hi
			elif (x * 7 + y * 3) % 11 == 0:
				c = veg_sh
			_dot(img, x, y, c)
	# Vidigal : petites façades claires au pied du premier morro.
	var house_cols: Array[Color] = [Color(0.95, 0.88, 0.74), Color(0.92, 0.72, 0.56), Color(0.85, 0.85, 0.82), Color(0.96, 0.80, 0.50)]
	for i in 26:
		var hx: int = _col(_rng.randf_range(175.0, 285.0))
		var hy: int = hz - _rng.randi_range(1, 7)
		if prof[hx] < float(hz - hy) + 2.0:
			continue
		_fill(img, hx, hy, 2, 2, house_cols[i % house_cols.size()])
		_dot(img, hx, hy + 1, Color(0.35, 0.3, 0.3))


func _peak(wx: float, cx: float, hw: float, hh: float) -> float:
	var u: float = (wx - cx) / hw
	if absf(u) >= 1.0:
		return 0.0
	# Flanc gauche plus raide (la face qui tombe dans la mer).
	var k: float = 1.0 - pow(absf(u), 1.5 if u < 0.0 else 1.1)
	return hh * pow(k, 0.85)


# Cagarras et Arpoador.
func _paint_islands(img: Image) -> void:
	var hz: int = img.get_height() - 2
	var isl: Color = Color(0.40, 0.55, 0.60)
	var isl_hi: Color = isl.lightened(0.18)
	for spec: Vector3 in [Vector3(-210, 40, 7), Vector3(-120, 14, 4), Vector3(-75, 9, 3), Vector3(40, 12, 3)]:
		var cx: int = _col(spec.x)
		var hw: int = int(spec.y) / 2
		for dx in range(-hw, hw + 1):
			var u: float = float(dx) / float(maxi(hw, 1))
			var hgt: int = int(spec.z * pow(1.0 - u * u, 0.6))
			if hgt < 1:
				continue
			_fill(img, cx + dx, hz - hgt, 1, hgt + 2, isl)
			_dot(img, cx + dx, hz - hgt, isl_hi)
	# Pedra do Arpoador (à gauche, est) qui ferme la baie.
	var arp: Color = Color(0.46, 0.44, 0.42)
	for x in range(0, _col(-500.0)):
		var wx: float = VIEW_L + float(x * PX)
		var hgt2: int = int(10.0 * clampf((-500.0 - wx) / 120.0, 0.0, 1.0) + 2.0 * sin(wx * 0.09))
		if hgt2 > 0:
			_fill(img, x, hz - hgt2, 1, hgt2 + 2, arp if x % 4 else arp.darkened(0.15))
			_dot(img, x, hz - hgt2, Color(0.30, 0.48, 0.32))


func _build_sea() -> void:
	_sea = Sprite2D.new()
	_sea.texture = GroundPainter.sea(SEA_COLOR, 9)
	_sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sea.region_enabled = true
	_sea.region_rect = Rect2(0, 0, _native_w(), int((SHORE_Y - HORIZON_Y) / float(PX)) + 2)
	_sea.centered = false
	_sea.scale = Vector2(PX, PX)
	_sea.position = Vector2(VIEW_L, HORIZON_Y)
	_sea.z_index = -13
	add_child(_sea)
	# Ligne d'horizon claire + houle plus foncée au large.
	var img: Image = Image.create(_native_w(), 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, 0, 0, img.get_width(), 1, SEA_COLOR.lightened(0.35))
	_fill(img, 0, 1, img.get_width(), 2, Color(SEA_COLOR.darkened(0.25), 0.55))
	_layer(img, Vector2(VIEW_L, HORIZON_Y), -12)


func _build_sand() -> void:
	var rows: int = int((GROUND_BOTTOM - SHORE_Y) / float(PX))
	var sand: Sprite2D = Sprite2D.new()
	sand.texture = GroundPainter.sand(Cfg.SAND_COLOR, 41)
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sand.region_enabled = true
	sand.region_rect = Rect2(0, 0, _native_w(), rows)
	sand.centered = false
	sand.scale = Vector2(PX, PX)
	sand.position = Vector2(VIEW_L, SHORE_Y)
	sand.z_index = -12
	add_child(sand)
	# Voile : sable mouillé près du bord, sable battu de la roda, empreintes.
	var img: Image = Image.create(_native_w(), rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in 9:
		var a: float = 0.16 * (1.0 - float(r) / 9.0)
		for x in img.get_width():
			if r < 4 or (x + r) % 3 != 0:
				img.set_pixel(x, r, Color(0.35, 0.25, 0.1, a))
	var trod: Color = Color(0.55, 0.40, 0.18, 0.10)
	for y in img.get_height():
		var wy: float = SHORE_Y + float(y * PX)
		for x in img.get_width():
			var wx: float = VIEW_L + float(x * PX)
			# Ellipse de la roda (joueur + parceiros), là où le sable est remué.
			var dx: float = wx / 250.0
			var dy: float = (wy - 40.0) / 150.0
			var d: float = dx * dx + dy * dy
			if d < 1.0 and (x * 13 + y * 7) % 4 == 0:
				img.set_pixel(x, y, trod)
	for i in 160:
		var fx: int = _rng.randi_range(0, img.get_width() - 3)
		var fy: int = _rng.randi_range(10, img.get_height() - 2)
		var c: Color = Color(0.45, 0.32, 0.12, 0.22)
		_dot(img, fx, fy, c)
		_dot(img, fx + 1, fy, c)
		_dot(img, fx + 1, fy + 1, Color(1, 1, 1, 0.18))
	var ov: Sprite2D = _layer(img, Vector2(VIEW_L, SHORE_Y), -12)
	ov.name = "SandMarks"


func _build_foam() -> void:
	var tex: ImageTexture = GroundPainter.foam(SEA_COLOR, 5)
	var src: Image = tex.get_image()
	var w: int = _native_w()
	for f in GroundPainter.FOAM_FRAMES:
		var img: Image = Image.create(w, GroundPainter.FOAM_H, false, Image.FORMAT_RGBA8)
		for x in range(0, w, GroundPainter.FOAM_W):
			img.blit_rect(src, Rect2i(f * GroundPainter.FOAM_W, 0, GroundPainter.FOAM_W, GroundPainter.FOAM_H), Vector2i(x, 0))
		# Orientation : sable en haut dans la tuile ; ici la mer est au-dessus.
		img.flip_y()
		_foam_frames.append(ImageTexture.create_from_image(img))
	_foam = Sprite2D.new()
	_foam.texture = _foam_frames[0]
	_foam.centered = false
	_foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foam.scale = Vector2(PX, PX)
	_foam.position = Vector2(VIEW_L, SHORE_Y - float(GroundPainter.FOAM_H / 2 * PX))
	_foam.z_index = -11
	add_child(_foam)


# Baigneurs dans l'eau jusqu'à la taille (moitié haute de la planche).
func _build_bathers() -> void:
	var spots: Array[Vector3] = [Vector3(-420, -150, 1), Vector3(-330, -160, 0), Vector3(-30, -168, 1),
		Vector3(205, -146, 0), Vector3(440, -158, 1), Vector3(560, -165, 0)]
	for i in spots.size():
		var sp: Vector3 = spots[i]
		var s: Sprite2D = Sprite2D.new()
		s.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(500 + i * 37))
		s.region_enabled = true
		var dir: int = CharacterSpriteFactory.DIR_UP if sp.z > 0.5 else CharacterSpriteFactory.DIR_DOWN
		s.region_rect = Rect2(0, dir * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, 60)
		s.centered = false
		s.offset = Vector2(-32, -60)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
		s.position = Vector2(sp.x, sp.y)
		s.z_index = -12
		add_child(s)
		var ring: Sprite2D = Sprite2D.new()
		ring.texture = ellipse_tex(9, 2, Color(0.96, 0.97, 0.95, 0.75))
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.scale = Vector2(PX * 2.0 / 3.0, PX * 2.0 / 3.0)
		ring.position = Vector2(0, -1)
		s.add_child(ring)
		_bathers.append(s)
		_bather_base.append(s.position)


func _build_beach_props() -> void:
	# Barracas du fond : parasols de l'atlas, en ligne derrière la roda.
	for p: Array in [[Cfg.UMBRELLA_RED_REGION, Vector2(-520, -96), 70.0], [Cfg.UMBRELLA_YELLOW_REGION, Vector2(-300, -104), 66.0],
			[Cfg.UMBRELLA_RED_REGION, Vector2(330, -100), 70.0], [Cfg.UMBRELLA_YELLOW_REGION, Vector2(560, -92), 70.0],
			[Cfg.UMBRELLA_RED_REGION, Vector2(-760, -100), 70.0], [Cfg.UMBRELLA_YELLOW_REGION, Vector2(800, -96), 70.0]]:
		var spr: Sprite2D = PropSprites.spawn(self, p[0], p[1], p[2])
		spr.z_index = -8
	# Cadeiras, cangas, isopor et coco autour (hors de la roda).
	_tex_sprite(_chair_tex(Color(0.20, 0.45, 0.80)), Vector2(-470, -78), -7)
	_tex_sprite(_chair_tex(Color(0.92, 0.35, 0.30)), Vector2(-410, -82), -7)
	_seated(Vector2(-470, -82), 812)
	_tex_sprite(_chair_tex(Color(0.98, 0.78, 0.20)), Vector2(380, -78), -7)
	_seated(Vector2(380, -82), 433)
	_tex_sprite(_cooler_tex(), Vector2(440, -72), -7)
	_tex_sprite(_coco_tex(), Vector2(-436, -70), -7)
	var canga: Sprite2D = PropSprites.spawn_flat(self, Cfg.TOWEL_STRIPED_REGION, Vector2(-420, 66), 110.0)
	canga.z_index = -10
	_lying(Vector2(-420, 66), 977)
	var canga2: Sprite2D = PropSprites.spawn_flat(self, Cfg.TOWEL_LOUNGER_REGION, Vector2(400, 66), 105.0)
	canga2.z_index = -10
	_tex_sprite(_cooler_tex(), Vector2(318, 214), -2)
	_tex_sprite(_chair_tex(Color(0.25, 0.70, 0.45)), Vector2(-500, 150), -2)
	_tex_sprite(_coco_tex(), Vector2(-462, 156), -2)
	var parasol: Sprite2D = PropSprites.spawn(self, Cfg.UMBRELLA_RED_REGION, Vector2(-545, 160), 96.0)
	parasol.z_index = -1
	# Les chinelos de la roda : on joue pieds nus, les sandales attendent.
	for c: Vector2 in [Vector2(-60, 208), Vector2(-246, -40), Vector2(252, -30), Vector2(90, 222)]:
		_tex_sprite(_chinelos_tex(int(absf(c.x)) % 3), c, -10)


func _seated(pos: Vector2, seed_value: int) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(seed_value))
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, 69)
	s.centered = false
	s.offset = Vector2(-32, -69)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos + Vector2(0, -6)
	s.z_index = -8
	add_child(s)


func _lying(center: Vector2, seed_value: int) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(seed_value))
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.rotation = -PI * 0.5
	s.scale = Vector2(0.8, 0.8)
	s.position = center
	s.z_index = -9
	add_child(s)


# Cadeira de praia en alu, toile rayée (vue de 3/4), 12×12 natifs.
func _chair_tex(stripe: Color) -> Texture2D:
	var key: String = "chair_" + stripe.to_html(false)
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img: Image = Image.create(12, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var alu: Color = Color(0.82, 0.84, 0.86)
	var alu_sh: Color = Color(0.55, 0.57, 0.62)
	# Dossier incliné.
	for y in 7:
		var x0: int = 3 + y / 3
		for x in range(x0, x0 + 7):
			img.set_pixel(x, y + 1, stripe if (x - x0) % 2 == 0 else Color(0.97, 0.96, 0.92))
	# Assise.
	for x in range(2, 11):
		img.set_pixel(x, 8, stripe.darkened(0.15))
		img.set_pixel(x, 9, stripe.darkened(0.3))
	# Pieds.
	for y in range(9, 13):
		img.set_pixel(2, y, alu)
		img.set_pixel(10, y, alu_sh)
	for y in range(1, 9):
		img.set_pixel(3 + (y - 1) / 3, y, alu)
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _cooler_tex() -> Texture2D:
	if _tex_cache.has("cooler"):
		return _tex_cache["cooler"]
	var img: Image = Image.create(11, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, 1, 3, 9, 5, Color(0.96, 0.96, 0.94))
	_fill(img, 1, 6, 9, 2, Color(0.82, 0.84, 0.86))
	_fill(img, 0, 1, 11, 2, Color(0.18, 0.42, 0.78))
	_fill(img, 4, 0, 3, 1, Color(0.18, 0.42, 0.78))
	_fill(img, 3, 4, 5, 1, Color(0.85, 0.2, 0.18))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["cooler"] = tex
	return tex


func _coco_tex() -> Texture2D:
	if _tex_cache.has("coco"):
		return _tex_cache["coco"]
	var img: Image = Image.create(6, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, 1, 3, 4, 4, Color(0.36, 0.66, 0.24))
	_fill(img, 1, 3, 2, 2, Color(0.50, 0.78, 0.32))
	_fill(img, 4, 0, 1, 4, Color(0.95, 0.35, 0.55))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["coco"] = tex
	return tex


func _chinelos_tex(variant: int) -> Texture2D:
	var key: String = "chinelo_%d" % variant
	if _tex_cache.has(key):
		return _tex_cache[key]
	var cols: Array[Color] = [Color(0.15, 0.55, 0.30), Color(0.95, 0.80, 0.15), Color(0.20, 0.40, 0.85)]
	var img: Image = Image.create(9, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for o: int in [0, 5]:
		_fill(img, o, 1, 3, 4, cols[variant])
		_dot(img, o + 1, 1, Color(0.97, 0.97, 0.95))
		_dot(img, o + 1, 2, Color(0.97, 0.97, 0.95))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


# --- Vendeurs ambulants ---

func _build_walkers() -> void:
	_add_walker(Vector2(-420, -88), 24.0, 11, "mate", "Ó o mate! Mate gelado!")
	_add_walker(Vector2(300, -96), -19.0, 23, "globo", "Biscoito Globo!")


func _add_walker(start: Vector2, speed: float, seed_value: int, kind: String, cry: String) -> void:
	var cfg: Dictionary = CharacterSpriteFactory.random_config(seed_value * 101)
	if kind == "mate":
		cfg["shirt_color"] = Color(0.95, 0.55, 0.12)
		cfg["hat_style"] = "cap"
		cfg["hat_color"] = Color(0.95, 0.55, 0.12)
	else:
		cfg["shirt_color"] = Color(0.97, 0.97, 0.94)
		cfg["hat_style"] = "cap"
		cfg["hat_color"] = Color(0.85, 0.15, 0.12)
	var root: Node2D = Node2D.new()
	root.position = start
	root.z_index = -6
	add_child(root)
	root.add_child(shadow_sprite(8))
	var body: Sprite2D = body_sprite(poses(cfg), "right_0")
	root.add_child(body)
	var gear: Sprite2D = Sprite2D.new()
	gear.texture = _mate_tex() if kind == "mate" else _globo_tex()
	gear.centered = false
	gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear.scale = Vector2(PX, PX)
	root.add_child(gear)
	var label: Label = Label.new()
	label.text = cry
	label.visible = false
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-60, -132)
	root.add_child(label)
	_walkers.append({"root": root, "body": body, "gear": gear, "kind": kind, "speed": speed,
		"poses": poses(cfg), "label": label, "cry_t": _rng.randf_range(1.5, 4.0)})


func _tick_walkers(delta: float) -> void:
	for w: Dictionary in _walkers:
		var root: Node2D = w["root"]
		var speed: float = w["speed"]
		root.position.x += speed * delta
		if root.position.x > 700.0:
			root.position.x = -700.0
		elif root.position.x < -700.0:
			root.position.x = 700.0
		var body: Sprite2D = w["body"]
		var seq: Array[int] = [1, 0, 2, 0]
		var pz: Dictionary = w["poses"]
		body.texture = pz["right_%d" % seq[int(_t * 5.0) % 4]]
		var left: bool = speed < 0.0
		body.flip_h = left
		var gear: Sprite2D = w["gear"]
		gear.flip_h = left
		var gw: float = float(gear.texture.get_width() * PX)
		var bob: float = PX if int(_t * 5.0) % 2 == 0 else 0.0
		if w["kind"] == "mate":
			# Les deux bidons à l'épaule, côté dos.
			gear.position = Vector2(-9.0 if left else 9.0 - gw, -63.0 + bob)
		else:
			# La perche de sachets portée sur l'épaule.
			gear.position = Vector2(-gw * 0.5, -86.0 + bob)
		gear.z_index = 1 if w["kind"] == "globo" else 0
		var cry: float = w["cry_t"] - delta
		var label: Label = w["label"]
		if cry <= 0.0:
			label.visible = not label.visible
			cry = 2.4 if label.visible else _rng.randf_range(5.0, 9.0)
		w["cry_t"] = cry


# Bidons de mate : deux cylindres alu à bande orange, 10×14 natifs.
func _mate_tex() -> Texture2D:
	if _tex_cache.has("mate"):
		return _tex_cache["mate"]
	var img: Image = Image.create(11, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var alu: Color = Color(0.82, 0.84, 0.88)
	for o: int in [0, 6]:
		_fill(img, o, 2, 5, 12, alu)
		_fill(img, o, 2, 1, 12, alu.lightened(0.25))
		_fill(img, o + 4, 2, 1, 12, alu.darkened(0.3))
		_fill(img, o, 6, 5, 3, Color(0.95, 0.55, 0.12))
		_fill(img, o + 1, 1, 3, 1, alu.darkened(0.2))
		_dot(img, o + 2, 0, Color(0.2, 0.2, 0.22))
	_fill(img, 4, 0, 3, 1, Color(0.35, 0.25, 0.15))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["mate"] = tex
	return tex


# Perche à biscoito Globo : sachets verts et jaunes au bout d'un bâton.
func _globo_tex() -> Texture2D:
	if _tex_cache.has("globo"):
		return _tex_cache["globo"]
	var img: Image = Image.create(24, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, 0, 2, 24, 1, Color(0.55, 0.40, 0.25))
	var cols: Array[Color] = [Color(0.25, 0.65, 0.30), Color(0.98, 0.82, 0.20)]
	for i in 6:
		var x: int = 1 + i * 4 if i < 3 else 13 + (i - 3) * 4
		var c: Color = cols[i % 2]
		_fill(img, x, 3, 3, 6, c)
		_fill(img, x, 3, 3, 1, c.darkened(0.25))
		_dot(img, x + 1, 5, Color(0.85, 0.15, 0.12))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["globo"] = tex
	return tex


# --- Laje (toit du morro, défi de Juca) ---

func _build_laje() -> void:
	var wall_y: float = -150.0
	var sky: Image = _paint_sky(wall_y)
	_paint_morro_facing(sky)
	_layer(sky, Vector2(VIEW_L, SKY_TOP), -14)
	_kite_layer = Node2D.new()
	_kite_layer.z_index = -13
	_kite_layer.draw.connect(_draw_kites)
	add_child(_kite_layer)
	for k: Vector4 in [Vector4(-380, -262, 0.9, 0), Vector4(-170, -282, 1.3, 1), Vector4(200, -270, 0.7, 2)]:
		_kites.append({"pos": Vector2(k.x, k.y), "phase": k.z, "col": int(k.w)})
	# Dalle de béton (matière de la dalle, grain de terre recoloré).
	var rows: int = int((GROUND_BOTTOM - wall_y) / float(PX))
	var slab: Sprite2D = Sprite2D.new()
	slab.texture = GroundPainter.dirt(Color(0.70, 0.67, 0.62), 13)
	slab.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slab.region_enabled = true
	slab.region_rect = Rect2(0, 0, _native_w(), rows)
	slab.centered = false
	slab.scale = Vector2(PX, PX)
	slab.position = Vector2(VIEW_L, wall_y)
	slab.z_index = -12
	add_child(slab)
	_layer(_paint_slab_marks(rows), Vector2(VIEW_L, wall_y), -11)
	_layer(_paint_parapet(), Vector2(VIEW_L, wall_y - 42.0), -10)
	# Caixa d'água, varal, cadeiras de plástico, isopor.
	_tex_sprite(_caixa_tex(), Vector2(-430, -96), -8)
	_tex_sprite(_plastic_chair_tex(), Vector2(390, -86), -8)
	_tex_sprite(_plastic_chair_tex(), Vector2(440, -80), -8)
	_seated(Vector2(390, -90), 615)
	_tex_sprite(_cooler_tex(), Vector2(-340, -78), -8)
	_layer(_paint_varal(), Vector2(150.0, -240.0), -9)
	for c: Vector2 in [Vector2(-60, 208), Vector2(-246, -40), Vector2(252, -30)]:
		_tex_sprite(_chinelos_tex(int(absf(c.x)) % 3), c, -10)


# Le morro d'en face : maisons de brique et d'enduit coloré en gradins, un
# peu de mata, le Cristo sur le Corcovado au loin.
func _paint_morro_facing(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var base_row: int = h - 2
	var far: Color = Color(0.42, 0.58, 0.48).lerp(Color(0.74, 0.88, 0.98), 0.35)
	# Corcovado au loin, Cristo au sommet.
	var cc: int = _col(330.0)
	for x in w:
		var u: float = float(x - cc) / 60.0
		var hgt: int = int(30.0 * pow(maxf(0.0, 1.0 - absf(u)), 1.4))
		if hgt > 0:
			_fill(img, x, base_row - 10 - hgt, 1, hgt + 10, far)
	var cross: Color = Color(0.95, 0.95, 0.92)
	var top: int = base_row - 10 - 30
	_fill(img, cc, top - 6, 1, 6, cross)
	_fill(img, cc - 2, top - 5, 5, 1, cross)
	# Profil du morro habité.
	var hill: PackedInt32Array = PackedInt32Array()
	hill.resize(w)
	for x in w:
		var wx: float = VIEW_L + float(x * PX)
		hill[x] = int(29.0 + 6.0 * sin(wx * 0.004 + 0.6) + 3.0 * sin(wx * 0.013))
	var mata: Color = Color(0.30, 0.52, 0.32)
	for x in w:
		_fill(img, x, base_row - hill[x], 1, hill[x] + 2, mata if (x * 5) % 7 else mata.darkened(0.12))
	var cols: Array[Color] = [Color(0.80, 0.42, 0.30), Color(0.93, 0.80, 0.45), Color(0.55, 0.72, 0.62),
		Color(0.85, 0.48, 0.48), Color(0.66, 0.66, 0.80), Color(0.93, 0.92, 0.84), Color(0.72, 0.40, 0.28)]
	var x2: int = 0
	var i: int = 0
	while x2 < w:
		var hw: int = 5 + (i * 7) % 6
		var col_top: int = base_row - hill[mini(x2, w - 1)] + 2
		var y2: int = col_top
		var j: int = 0
		while y2 < base_row:
			var hh: int = 4 + (i * 3 + j * 5) % 3
			if (i + j) % 6 != 5:
				var c: Color = cols[(i * 3 + j * 2) % cols.size()]
				_fill(img, x2, y2, hw - 1, hh, c)
				_fill(img, x2, y2, hw - 1, 1, c.lightened(0.15))
				_fill(img, x2 + hw - 2, y2, 1, hh, c.darkened(0.2))
				if hw > 5:
					_dot(img, x2 + 2, y2 + 2, Color(0.2, 0.22, 0.28))
					_dot(img, x2 + hw - 4, y2 + 2, Color(0.2, 0.22, 0.28))
				if (i + j) % 4 == 0:
					_dot(img, x2 + 1, y2 - 1, Color(0.25, 0.45, 0.75))
			y2 += hh
			j += 1
		x2 += hw
		i += 1


func _paint_slab_marks(rows: int) -> Image:
	var img: Image = Image.create(_native_w(), rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var crack: Color = Color(0.35, 0.32, 0.30, 0.55)
	for k in 9:
		var x: int = _rng.randi_range(0, img.get_width() - 1)
		var y: int = _rng.randi_range(4, rows - 4)
		for s in _rng.randi_range(8, 18):
			_dot(img, x, y, crack)
			x += 1
			y += _rng.randi_range(-1, 1)
	for k in 6:
		var cx: int = _rng.randi_range(0, img.get_width() - 1)
		var cy: int = _rng.randi_range(4, rows - 4)
		for yy in range(-2, 3):
			for xx in range(-5, 6):
				if (xx * xx) / 25.0 + (yy * yy) / 4.0 <= 1.0:
					_blend(img, cx + xx, cy + yy, Color(0.3, 0.27, 0.22, 0.12))
	# Ombre portée du parapet.
	_fill(img, 0, 0, img.get_width(), 2, Color(0, 0, 0, 0.18))
	return img


# Parapet de brique crue, enduit à moitié, vergalhões qui dépassent.
func _paint_parapet() -> Image:
	var w: int = _native_w()
	var img: Image = Image.create(w, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var brick: Color = Color(0.74, 0.40, 0.28)
	var mortar: Color = Color(0.62, 0.55, 0.48)
	for y in range(3, 15):
		for x in w:
			var row: int = (y - 3) / 3
			var c: Color = brick if (y - 3) % 3 != 2 and (x + (row % 2) * 4) % 8 != 0 else mortar
			if (x * 3 + y * 7) % 23 == 0:
				c = brick.darkened(0.15)
			img.set_pixel(x, y, c)
	_fill(img, 0, 3, w, 1, brick.lightened(0.2))
	for x in range(0, w, 1):
		# Enduit à moitié posé : plaques tramées, jamais un aplat.
		if sin(float(x) * 0.05) > 0.55:
			for y in range(5, 13):
				if (x + y) % 2 == 0 or (x * 7 + y) % 5 == 0:
					img.set_pixel(x, y, Color(0.80, 0.78, 0.72))
	for x in range(6, w, 70):
		_fill(img, x, 0, 1, 3, Color(0.40, 0.25, 0.20))
	return img


func _caixa_tex() -> Texture2D:
	if _tex_cache.has("caixa"):
		return _tex_cache["caixa"]
	var img: Image = Image.create(20, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blue: Color = Color(0.20, 0.42, 0.78)
	_fill(img, 1, 4, 18, 14, blue)
	_fill(img, 1, 4, 3, 14, blue.lightened(0.2))
	_fill(img, 15, 4, 4, 14, blue.darkened(0.25))
	_fill(img, 0, 2, 20, 3, blue.lightened(0.1))
	_fill(img, 6, 0, 8, 2, blue.darkened(0.1))
	_fill(img, 3, 18, 2, 4, Color(0.55, 0.52, 0.5))
	_fill(img, 15, 18, 2, 4, Color(0.55, 0.52, 0.5))
	_fill(img, 2, 18, 16, 1, Color(0.55, 0.52, 0.5))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["caixa"] = tex
	return tex


func _plastic_chair_tex() -> Texture2D:
	if _tex_cache.has("pchair"):
		return _tex_cache["pchair"]
	var img: Image = Image.create(10, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white: Color = Color(0.95, 0.95, 0.93)
	_fill(img, 1, 0, 8, 6, white)
	_fill(img, 2, 1, 6, 1, Color(0.8, 0.8, 0.8))
	_fill(img, 0, 6, 10, 2, white)
	_fill(img, 0, 8, 1, 6, Color(0.82, 0.82, 0.8))
	_fill(img, 9, 8, 1, 6, Color(0.82, 0.82, 0.8))
	_fill(img, 2, 8, 1, 5, Color(0.88, 0.88, 0.86))
	_fill(img, 7, 8, 1, 5, Color(0.88, 0.88, 0.86))
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["pchair"] = tex
	return tex


# Varal tendu entre deux poteaux, linge de toutes les couleurs.
func _paint_varal() -> Image:
	var img: Image = Image.create(90, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post: Color = Color(0.45, 0.35, 0.28)
	_fill(img, 0, 4, 1, 30, post)
	_fill(img, 89, 4, 1, 30, post)
	for x in 90:
		var sag: int = int(3.0 * sin(PI * float(x) / 89.0))
		_dot(img, x, 5 + sag, Color(0.25, 0.25, 0.28))
	var cloths: Array[Color] = [Color(0.85, 0.2, 0.2), Color(0.98, 0.85, 0.2), Color(0.2, 0.55, 0.85),
		Color(0.97, 0.97, 0.95), Color(0.25, 0.65, 0.35), Color(0.9, 0.5, 0.7)]
	var x0: int = 5
	var i: int = 0
	while x0 < 82:
		var cw: int = 5 + (i * 3) % 4
		var ch: int = 7 + (i * 5) % 6
		var sag2: int = int(3.0 * sin(PI * float(x0 + cw / 2) / 89.0))
		var c: Color = cloths[i % cloths.size()]
		_fill(img, x0, 6 + sag2, cw, ch, c)
		_fill(img, x0, 6 + sag2, cw, 1, c.darkened(0.2))
		x0 += cw + 2
		i += 1
	return img


func _draw_kites() -> void:
	var cols: Array[Color] = [Color(0.95, 0.25, 0.25), Color(0.98, 0.85, 0.2), Color(0.3, 0.5, 0.95)]
	for k: Dictionary in _kites:
		var base: Vector2 = k["pos"]
		var ph: float = k["phase"]
		var p: Vector2 = base + Vector2(sin(_t * 0.7 + ph) * 18.0, cos(_t * 1.1 + ph) * 9.0)
		p = p.snapped(Vector2(PX, PX))
		var c: Color = cols[int(k["col"]) % cols.size()]
		for r in 5:
			var hw: int = r if r < 3 else 4 - r
			_kite_layer.draw_rect(Rect2(p.x - float(hw * PX), p.y + float(r * PX), float((hw * 2 + 1) * PX), PX), c if r < 3 else c.darkened(0.2))
		for t in 6:
			var tp: Vector2 = p + Vector2(sin(_t * 3.0 + float(t) * 0.8 + ph) * 4.0, float(15 + t * 5)).snapped(Vector2(PX, PX))
			_kite_layer.draw_rect(Rect2(tp, Vector2(PX, PX)), Color(0.15, 0.15, 0.18) if t % 2 == 0 else c)
