class_name FacadePainter
extends RefCounted

# Peintre procédural de façades en pixel-art, même principe que
# CharacterSpriteFactory : on dessine à la densité GBA du jeu (1 pixel natif =
# 3 px monde), puis le Sprite2D affiche ×3 en NEAREST. Une façade = un mur
# (enduit de Copa ou brique du morro) + une grille de fenêtres par étage +
# balcons + rez-de-chaussée (porte, vitrine à auvent) + arêtes, fondation et
# contour sombre. Déterministe par `seed`, mise en cache par (taille, couleur,
# options). Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste A), règles :
# docs/STYLE_VISUEL.md.

const DENSITY: int = 3
const WINDOW_GLASS: Color = Color(0.25, 0.35, 0.55, 1)
const DOOR_BASE: Color = Color(0.35, 0.25, 0.18, 1)
const CONCRETE: Color = Color(0.72, 0.70, 0.66, 1)
const AWNINGS: Array = [
	[Color(0.85, 0.28, 0.28, 1), Color(0.96, 0.94, 0.88, 1)],
	[Color(0.20, 0.45, 0.75, 1), Color(0.96, 0.94, 0.88, 1)],
	[Color(0.22, 0.55, 0.38, 1), Color(0.96, 0.90, 0.62, 1)],
	[Color(0.95, 0.72, 0.25, 1), Color(0.45, 0.32, 0.22, 1)],
]
const SHUTTERS: Array = [
	Color(0.20, 0.50, 0.45, 1), Color(0.75, 0.30, 0.28, 1), Color(0.25, 0.40, 0.70, 1),
	Color(0.90, 0.80, 0.40, 1), Color(0.95, 0.93, 0.88, 1),
]

static var _cache: Dictionary = {}


# Rampe de 5 tons à partir de la couleur de base (lumière du haut-gauche).
static func ramp(c: Color) -> Dictionary:
	return {
		"dark": c.darkened(0.58),
		"shade": c.darkened(0.26),
		"base": c,
		"light": c.lightened(0.16),
		"lighter": c.lightened(0.34),
	}


# Taille native (pixels) d'une façade de `size` px monde.
static func native_size(size: Vector2) -> Vector2i:
	return Vector2i(int(floor(size.x / DENSITY)), int(floor(size.y / DENSITY)))


# Options : style ("copa" | "favela"), seed, door (true), door_left, shop,
# windows (true), balconies (copa : true).
static func build(size: Vector2, color: Color, opts: Dictionary = {}) -> ImageTexture:
	var n: Vector2i = native_size(size)
	var key: String = "%d_%d_%s_%s" % [n.x, n.y, color.to_html(false), JSON.stringify(opts)]
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = ImageTexture.create_from_image(build_image(size, color, opts))
	_cache[key] = tex
	return tex


# L'image native, sans passer par le serveur de rendu (tests headless :
# ImageTexture.get_image() y attend un renderer qui ne répond jamais).
static func build_image(size: Vector2, color: Color, opts: Dictionary = {}) -> Image:
	var n: Vector2i = native_size(size)
	var img: Image = Image.create(maxi(n.x, 1), maxi(n.y, 1), false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	if n.x < 6 or n.y < 8:
		img.fill(r.base)
		_outline(img, r.dark)
	elif String(opts.get("style", "copa")) == "favela":
		_paint_favela(img, r, rng, opts)
	elif String(opts.get("style", "copa")) == "igreja":
		_paint_igreja(img, r, rng)
	else:
		_paint_copa(img, r, rng, opts)
	return img


# ----------------------------------------------------------------- Copa

static func _paint_copa(img: Image, r: Dictionary, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill(r.base)
	# Enduit : bandes horizontales légères + grain discret.
	for y in range(3, h - 2):
		if y % 4 == 3:
			_hline(img, 1, y, w - 2, r.base.darkened(0.05))
	for i in int(w * h / 14):
		var x: int = rng.randi_range(1, w - 2)
		var y: int = rng.randi_range(3, h - 3)
		img.set_pixel(x, y, r.base.darkened(0.07) if rng.randf() < 0.6 else r.base.lightened(0.05))
	# Corniche (y 0-2), fondation (2 dernières lignes), arêtes.
	_hline(img, 0, 0, w, r.dark)
	_hline(img, 0, 1, w, r.lighter)
	_hline(img, 0, 2, w, r.shade)
	_fill(img, 0, h - 2, w, 2, CONCRETE.darkened(0.25))
	_vline(img, 0, 3, h - 5, r.lighter)
	_vline(img, w - 1, 3, h - 5, r.shade)

	# Étages compacts (GBA) : un immeuble de Copa (21 px natifs) = rez-de-chaussée + 1 étage.
	var floor_h: int = 8
	var ground_h: int = 10
	var upper: int = maxi(0, int((h - 3 - ground_h) / floor_h))
	var win_w: int = 5
	var win_h: int = 5
	var gap: int = 3
	var cols: int = maxi(1, int((w - 4) / (win_w + gap)))
	var total: int = cols * (win_w + gap) - gap
	var x0: int = int((w - total) / 2)
	var balconies: bool = bool(opts.get("balconies", true))
	var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	var with_shutters: bool = rng.randf() < 0.45
	if bool(opts.get("windows", true)):
		for f in upper:
			var wy: int = 4 + f * floor_h
			for c in cols:
				var wx: int = x0 + c * (win_w + gap)
				_window(img, wx, wy, win_w, win_h, r, shutter if with_shutters else Color(0, 0, 0, 0))
				if rng.randf() < 0.18:
					_ac_unit(img, wx + win_w - 2, wy + win_h + 1)
			if balconies and (f > 0 or upper == 1):
				_balcony(img, x0 - 1, wy + win_h + 1, total + 2, r)
	# Rez-de-chaussée.
	var gy: int = 3 + upper * floor_h
	var door: bool = bool(opts.get("door", true))
	var door_w: int = 7
	var door_h: int = mini(9, h - 2 - gy - 1)
	var dx: int = int((w - door_w) / 2)
	if bool(opts.get("door_left", false)):
		dx = 2
	if bool(opts.get("shop", false)):
		var pal: Array = AWNINGS[rng.randi() % AWNINGS.size()]
		_awning(img, 1, gy + 1, w - 2, pal)
		# Vitrine de part et d'autre de la porte.
		var vy: int = gy + 5
		var vh: int = h - 2 - vy - 1
		if vh >= 3:
			_glass(img, 2, vy, maxi(1, dx - 3), vh, r)
			_glass(img, dx + door_w + 1, vy, maxi(1, w - (dx + door_w + 1) - 2), vh, r)
	elif bool(opts.get("windows", true)):
		# Fenêtres du rez-de-chaussée, en évitant la porte.
		for c in cols:
			var wx: int = x0 + c * (win_w + gap)
			if door and wx + win_w >= dx - 1 and wx <= dx + door_w + 1:
				continue
			_window(img, wx, gy + 2, win_w, win_h, r, shutter if with_shutters else Color(0, 0, 0, 0))
	if door and door_h >= 6:
		_door(img, dx, h - 2 - door_h, door_w, door_h, r)
	_outline(img, r.dark)


# ----------------------------------------------------------------- Favela

static func _paint_favela(img: Image, r: Dictionary, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill(r.base)
	# Brique sous l'enduit : joints horizontaux tous les 3 px, verticaux décalés.
	var mortar: Color = r.base.darkened(0.14)
	for y in range(2, h - 1, 3):
		_hline(img, 1, y, w - 2, mortar)
		var off: int = 0 if (int(y / 3) % 2 == 0) else 2
		for x in range(1 + off, w - 1, 4):
			img.set_pixel(x, y - 1 if y > 2 else y, mortar)
			if y + 1 < h - 1:
				img.set_pixel(x, y + 1, mortar)
	# Enduit partiel : le haut est parfois resté brut (béton).
	if rng.randf() < 0.4:
		var raw_h: int = rng.randi_range(2, maxi(2, int(h / 3)))
		_fill(img, 1, 1, w - 2, raw_h, CONCRETE)
		for i in int(w * raw_h / 6):
			img.set_pixel(rng.randi_range(1, w - 2), rng.randi_range(1, raw_h), CONCRETE.darkened(0.12))
	_hline(img, 0, 0, w, r.dark)
	_hline(img, 0, h - 1, w, CONCRETE.darkened(0.35))
	_vline(img, 0, 1, h - 2, r.lighter)
	_vline(img, w - 1, 1, h - 2, r.shade)
	# Une ou deux fenêtres à volets, hautes.
	var win_w: int = 4
	var win_h: int = 4
	var door_left: bool = bool(opts.get("door_left", false))
	var door_w: int = 5
	var door_h: int = mini(8, h - 3)
	var dx: int = 2 if door_left else w - 2 - door_w
	var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	# Fenêtres : une tous les ~9 px de large, deux rangées si la maison est haute
	# (lajes empilées), en évitant la porte.
	var n_win: int = maxi(1, int((w - 4) / 9))
	var rows: int = 2 if h >= 24 else 1
	var row_step: int = maxi(8, int((h - 3 - door_h) / rows)) if rows == 2 else 0
	for row in rows:
		var wy: int = 3 + row * row_step if rows == 2 else maxi(2, int(h * 0.3) - 2)
		for i in n_win:
			var wx: int
			if n_win == 1:
				wx = int((w - win_w) / 2) if h > door_h + win_h + 4 else (w - 3 - win_w if door_left else 3)
			else:
				wx = 3 + int(float(i) * float(w - 6 - win_w) / float(n_win - 1))
			if wx + win_w > dx - 1 and wx < dx + door_w + 1 and wy + win_h >= h - 1 - door_h:
				continue
			_window(img, wx, wy, win_w, win_h, r, shutter if rng.randf() < 0.7 else Color(0, 0, 0, 0))
	if bool(opts.get("door", true)) and door_h >= 6:
		_door(img, dx, h - 1 - door_h, door_w, door_h, r)
	_outline(img, r.dark)


# ----------------------------------------------------------------- Igreja

# Église de quartier : enduit clair, grand portail cintré, deux fenêtres hautes,
# rosace au-dessus de la porte.
static func _paint_igreja(img: Image, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill(r.base)
	for i in int(w * h / 16):
		img.set_pixel(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2), r.base.darkened(0.05))
	_hline(img, 0, 0, w, r.dark)
	_hline(img, 0, 1, w, r.lighter)
	_fill(img, 0, h - 2, w, 2, CONCRETE.darkened(0.25))
	_vline(img, 0, 2, h - 4, r.lighter)
	_vline(img, w - 1, 2, h - 4, r.shade)
	var door_w: int = 9 if w >= 24 else 7
	var door_h: int = mini(12, h - 6)
	var dx: int = int((w - door_w) / 2)
	var dy: int = h - 2 - door_h
	# Portail cintré : cadre sombre, arc de 2 px au-dessus.
	_fill(img, dx - 1, dy - 2, door_w + 2, door_h + 2, r.dark)
	_hline(img, dx, dy - 3, door_w, r.dark)
	_fill(img, dx, dy - 1, door_w, door_h + 1, DOOR_BASE)
	_vline(img, dx + int(door_w / 2), dy - 1, door_h + 1, DOOR_BASE.darkened(0.35))
	_vline(img, dx + 1, dy, door_h - 1, DOOR_BASE.lightened(0.25))
	# Rosace.
	var ry: int = maxi(3, dy - 8)
	_fill(img, dx + int(door_w / 2) - 1, ry, 3, 3, r.dark)
	_fill(img, dx + int(door_w / 2), ry + 1, 1, 1, WINDOW_GLASS.lightened(0.4))
	img.set_pixel(clampi(dx + int(door_w / 2) - 1, 0, w - 1), ry + 1, WINDOW_GLASS)
	img.set_pixel(clampi(dx + int(door_w / 2) + 1, 0, w - 1), ry + 1, WINDOW_GLASS)
	img.set_pixel(clampi(dx + int(door_w / 2), 0, w - 1), ry, WINDOW_GLASS)
	img.set_pixel(clampi(dx + int(door_w / 2), 0, w - 1), ry + 2, WINDOW_GLASS)
	# Fenêtres hautes de part et d'autre.
	var fw: int = 3
	var fh: int = mini(8, h - 8)
	var fy: int = maxi(3, dy - 1 - fh + 4)
	for fx in [dx - 3 - fw, dx + door_w + 3]:
		if fx - 1 < 1 or fx + fw + 1 > w - 1:
			continue
		_fill(img, fx - 1, fy - 2, fw + 2, fh + 2, r.dark)
		_hline(img, fx, fy - 3, fw, r.dark)
		_fill(img, fx, fy - 1, fw, fh, WINDOW_GLASS)
		_vline(img, fx, fy - 1, fh, WINDOW_GLASS.lightened(0.3))
	_outline(img, r.dark)


# ----------------------------------------------------------------- éléments

static func _window(img: Image, x: int, y: int, w: int, h: int, r: Dictionary, shutter: Color) -> void:
	_fill(img, x - 1, y - 1, w + 2, h + 2, r.dark)
	_glass(img, x, y, w, h, r)
	_hline(img, x - 1, y + h, w + 2, r.lighter)  # appui
	if shutter.a > 0.0:
		_vline(img, x - 2, y, h, shutter)
		_vline(img, x + w + 1, y, h, shutter)
		_vline(img, x - 2, y, 1, shutter.darkened(0.3))
		_vline(img, x + w + 1, y, 1, shutter.darkened(0.3))


static func _glass(img: Image, x: int, y: int, w: int, h: int, r: Dictionary) -> void:
	if w <= 0 or h <= 0:
		return
	_fill(img, x, y, w, h, WINDOW_GLASS)
	_fill(img, x, y, mini(2, w), mini(2, h), WINDOW_GLASS.lightened(0.35))
	if w >= 4:
		_vline(img, x + int(w / 2), y, h, WINDOW_GLASS.darkened(0.35))
	if h >= 5:
		_hline(img, x, y + int(h / 2), w, WINDOW_GLASS.darkened(0.3))


static func _balcony(img: Image, x: int, y: int, w: int, r: Dictionary) -> void:
	_hline(img, x, y, w, r.dark)
	for bx in range(x, x + w, 2):
		img.set_pixel(clampi(bx, 0, img.get_width() - 1), clampi(y - 1, 0, img.get_height() - 1), r.dark)
	_hline(img, x, y + 1, w, r.shade)


static func _ac_unit(img: Image, x: int, y: int) -> void:
	_fill(img, x, y, 3, 2, CONCRETE.lightened(0.15))
	img.set_pixel(clampi(x + 1, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1), CONCRETE.darkened(0.3))


static func _awning(img: Image, x: int, y: int, w: int, pal: Array) -> void:
	for ax in range(x, x + w):
		var c: Color = pal[0] if int((ax - x) / 2) % 2 == 0 else pal[1]
		_vline(img, ax, y, 3, c)
	_hline(img, x, y + 3, w, Color(0, 0, 0, 0.35).blend(pal[0]).darkened(0.5))


static func _door(img: Image, x: int, y: int, w: int, h: int, r: Dictionary) -> void:
	_fill(img, x - 1, y - 1, w + 2, h + 1, r.dark)
	_fill(img, x, y, w, h, DOOR_BASE)
	_vline(img, x + 1, y + 1, h - 2, DOOR_BASE.lightened(0.25))
	_hline(img, x + 1, y + 1, w - 2, DOOR_BASE.lightened(0.25))
	img.set_pixel(clampi(x + w - 2, 0, img.get_width() - 1), clampi(y + int(h / 2), 0, img.get_height() - 1), Color(0.95, 0.85, 0.5, 1))


static func _outline(img: Image, c: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	_hline(img, 0, 0, w, c)
	_hline(img, 0, h - 1, w, c)
	_vline(img, 0, 0, h, c)
	_vline(img, w - 1, 0, h, c)


# ----------------------------------------------------------------- primitives

static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0: int = clampi(x, 0, img.get_width())
	var y0: int = clampi(y, 0, img.get_height())
	var x1: int = clampi(x + w, 0, img.get_width())
	var y1: int = clampi(y + h, 0, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	_fill(img, x, y, w, 1, c)


static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	_fill(img, x, y, 1, h, c)
