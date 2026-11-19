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
# Vitres posées par le dernier build_image (pour le calque de nuit).
static var _glass_rects: Array[Rect2i] = []


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
	var m: Vector2i = margins(size, opts)
	var img: Image = Image.create(maxi(n.x + m.x * 2, 1), maxi(n.y + m.y, 1), false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	_glass_rects.clear()
	if n.x < 6 or n.y < 8:
		img.fill(r.base)
		_outline(img, r.dark)
	elif String(opts.get("style", "copa")) == "favela":
		_paint_favela(img, r, rng, opts, m)
	elif String(opts.get("style", "copa")) == "igreja":
		_paint_igreja(img, r, rng)
	else:
		_paint_copa(img, r, rng, opts)
	return img


# Débord de l'image autour de la façade (natifs) : x = de chaque côté, y = au-
# dessus. Les maisons du morro portent un toit vu du dessus qui dépasse le mur
# (avant-toit d'un pixel, dalle qui remonte au-dessus de l'empreinte).
static func margins(size: Vector2, opts: Dictionary = {}) -> Vector2i:
	if String(opts.get("style", "copa")) != "favela":
		return Vector2i.ZERO
	var n: Vector2i = native_size(size)
	if n.x < 6 or n.y < 8:
		return Vector2i.ZERO
	return Vector2i(1, 4 if n.y >= 20 else 2)


# Calque de nuit : les vitres deviennent lumineuses (une fenêtre sur ~3 reste
# éteinte, déterministe), avec un halo d'un pixel ; le reste est transparent.
# Affiché en « émissif » (hors CanvasModulate) par DayLighting (rendu D).
const NIGHT_GLASS: Color = Color(1.0, 0.86, 0.48, 1.0)
const NIGHT_HALO: Color = Color(1.0, 0.80, 0.40, 0.35)

static var _night_cache: Dictionary = {}

static func build_night(size: Vector2, color: Color, opts: Dictionary = {}) -> ImageTexture:
	var n: Vector2i = native_size(size)
	var key: String = "%d_%d_%s_%s" % [n.x, n.y, color.to_html(false), JSON.stringify(opts)]
	if _night_cache.has(key):
		return _night_cache[key]
	var tex: ImageTexture = ImageTexture.create_from_image(build_night_image(size, color, opts))
	_night_cache[key] = tex
	return tex


static func build_night_image(size: Vector2, color: Color, opts: Dictionary = {}) -> Image:
	var day: Image = build_image(size, color, opts)
	var night: Image = Image.create(day.get_width(), day.get_height(), false, Image.FORMAT_RGBA8)
	night.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1)) * 31 + 7
	# Les vitres sont celles que le peintre vient de poser (plus de détection par
	# couleur : un mur bleu ou une caixa d'água s'allumaient avec les fenêtres).
	var lit: Array[Rect2i] = []
	for pane in _glass_rects:
		if rng.randf() >= 0.35:
			lit.append(pane)
	for pane in lit:
		_fill(night, pane.position.x - 1, pane.position.y - 1, pane.size.x + 2, pane.size.y + 2, NIGHT_HALO)
	for pane in lit:
		_fill(night, pane.position.x, pane.position.y, pane.size.x, pane.size.y, NIGHT_GLASS)
	return night


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

const BRICK: Color = Color(0.74, 0.41, 0.27, 1)        # tijolo aparente
const MORTAR: Color = Color(0.60, 0.55, 0.49, 1)
const SLAB: Color = Color(0.67, 0.65, 0.61, 1)         # laje / piliers béton
const TIN: Color = Color(0.58, 0.62, 0.66, 1)          # telha de fibrocimento
const ROOF_TILE: Color = Color(0.78, 0.42, 0.27, 1)    # telha cerâmica
const TANK: Color = Color(0.20, 0.52, 0.92, 1)         # caixa d'água
const PIPE: Color = Color(0.84, 0.86, 0.88, 1)
const GATES: Array = [
	Color(0.24, 0.42, 0.62, 1), Color(0.22, 0.48, 0.36, 1), Color(0.50, 0.30, 0.20, 1),
	Color(0.60, 0.61, 0.63, 1), Color(0.68, 0.24, 0.22, 1),
]
const CLOTHES: Array = [
	Color(0.96, 0.94, 0.90, 1), Color(0.90, 0.32, 0.36, 1), Color(0.98, 0.80, 0.30, 1),
	Color(0.36, 0.62, 0.88, 1), Color(0.40, 0.72, 0.46, 1),
]

# Maison du morro en faux 3/4 : un toit vu du dessus (laje de béton avec sa
# caixa d'água et son linge, fibrocimento lesté de briques, ou tuile), puis le
# mur — enduit peint dans la couleur de la maison, ou brique apparente entre
# piliers de béton, souvent un étage de chaque. Un étage ≈ 16 natifs, à
# l'échelle des personnages : une maison, pas un immeuble.
static func _paint_favela(img: Image, r: Dictionary, rng: RandomNumberGenerator, opts: Dictionary, m: Vector2i) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	img.fill(Color(0, 0, 0, 0))
	var x0: int = m.x
	var w: int = iw - m.x * 2
	var n_h: int = ih - m.y
	var rh: int = clampi(int(round(n_h * 0.26)) + m.y, m.y + 3, 12)
	var wall_h: int = ih - rh
	var floors: int = 2 if wall_h >= 26 else 1
	var upper_h: int = int(wall_h / 2) if floors == 2 else 0
	var ground_y: int = rh + upper_h
	var ground_h: int = wall_h - upper_h

	# Finition par étage : 0 = enduit peint, 1 = brique apparente.
	var roll: float = rng.randf()
	var finish_ground: int = 0
	var finish_upper: int = 0
	if roll > 0.75:
		finish_ground = 1
		finish_upper = 1
	elif roll > 0.42:
		finish_upper = 1
		if floors == 1:
			finish_ground = 0
	if floors == 2:
		_wall(img, x0, rh, w, upper_h, r, finish_upper, rng)
	_wall(img, x0, ground_y, w, ground_h, r, finish_ground, rng)
	# Tout en brique : la couleur de la maison reste sur un soubassement peint.
	if finish_ground == 1 and (floors == 1 or finish_upper == 1):
		_fill(img, x0, ih - 5, w, 4, r.base)
		_hline(img, x0, ih - 5, w, r.light)
	if floors == 2:
		# Dalle entre les étages, en légère saillie.
		_hline(img, x0, ground_y - 1, w, SLAB.lightened(0.12))
		_hline(img, x0, ground_y, w, SLAB.darkened(0.30))

	# Ouvertures.
	var door: bool = bool(opts.get("door", true))
	var door_left: bool = bool(opts.get("door_left", false))
	var door_w: int = 6 if w >= 18 else 5
	var door_h: int = clampi(ground_h - 4, 6, 11)
	var dx: int = x0 + (3 if door_left else w - 3 - door_w)
	# `door_x` : centre imposé (natifs depuis le bord gauche du mur) quand une
	# vraie porte (BuildingDoor) attend le joueur à cet endroit.
	if opts.has("door_x"):
		dx = x0 + clampi(int(opts["door_x"]) - int(door_w / 2), 2, w - 2 - door_w)
		door_left = dx - x0 < int(w / 2)
	var dy: int = ih - 1 - door_h
	if bool(opts.get("windows", true)):
		if floors == 2:
			_favela_windows(img, x0, rh, w, upper_h, r if finish_upper == 0 else ramp(BRICK), rng, -1, 0)
		_favela_windows(img, x0, ground_y, w, ground_h, r if finish_ground == 0 else ramp(BRICK), rng,
			dx if door else -1, door_w)
	if door and door_h >= 6:
		_gate(img, dx, dy, door_w, door_h, GATES[rng.randi() % GATES.size()], rng)
		# Relógio de luz à côté de la porte.
		if rng.randf() < 0.6 and w >= 20:
			var bx: int = dx + door_w + 2 if door_left else dx - 4
			_fill(img, bx, dy + 1, 2, 3, SLAB.lightened(0.1))
			img.set_pixel(clampi(bx, 0, iw - 1), clampi(dy + 2, 0, ih - 1), SLAB.darkened(0.45))
	# Descente d'eau en PVC, du toit au sol, côté opposé à la porte.
	if rng.randf() < 0.55 and w >= 16:
		var px: int = x0 + (w - 3 if door_left else 2)
		for y in range(rh + 1, ih - 1):
			img.set_pixel(px, y, PIPE if y % 5 != 0 else PIPE.darkened(0.3))

	# Arêtes : lumière à gauche, ombre à droite, ombre du toit, fondation.
	for y in range(rh, ih - 1):
		img.set_pixel(x0, y, img.get_pixel(x0, y).darkened(0.55))
		img.set_pixel(x0 + 1, y, img.get_pixel(x0 + 1, y).lightened(0.14))
		img.set_pixel(x0 + w - 2, y, img.get_pixel(x0 + w - 2, y).darkened(0.16))
		img.set_pixel(x0 + w - 1, y, img.get_pixel(x0 + w - 1, y).darkened(0.55))
	for x in range(x0 + 1, x0 + w - 1):
		img.set_pixel(x, rh, img.get_pixel(x, rh).darkened(0.30))
		if wall_h > 12:
			img.set_pixel(x, rh + 1, img.get_pixel(x, rh + 1).darkened(0.12))
	_hline(img, x0, ih - 1, w, SLAB.darkened(0.55))
	if door and door_h >= 6:
		# Marche de béton devant la porte.
		_hline(img, dx - 1, ih - 1, door_w + 2, SLAB.lightened(0.05))

	_favela_roof(img, iw, rh, r, rng)


# Un pan de mur : enduit peint (grain, éclats où la brique revient, pied sali)
# ou brique apparente entre deux piliers de béton.
static func _wall(img: Image, x: int, y: int, w: int, h: int, r: Dictionary, finish: int, rng: RandomNumberGenerator) -> void:
	if h <= 0:
		return
	if finish == 0:
		_fill(img, x, y, w, h, r.base)
		for i in int(w * h / 10):
			var gx: int = rng.randi_range(x + 1, x + w - 2)
			var gy: int = rng.randi_range(y, y + h - 1)
			img.set_pixel(gx, gy, r.base.darkened(0.07) if rng.randf() < 0.6 else r.base.lightened(0.06))
		# Éclats d'enduit.
		for i in rng.randi_range(0, 2):
			if w < 14 or h < 8:
				break
			var px: int = rng.randi_range(x + 2, x + w - 7)
			var py: int = rng.randi_range(y + 2, y + h - 5)
			var pw: int = rng.randi_range(3, 5)
			_fill(img, px, py, pw, 2, BRICK)
			_hline(img, px + 1, py + 2, pw - 2, BRICK.darkened(0.12))
			img.set_pixel(px + int(pw / 2), py, MORTAR)
		_hline(img, x, y + h - 2, w, r.base.darkened(0.10))
		_hline(img, x, y + h - 1, w, r.base.darkened(0.20))
		return
	_fill(img, x, y, w, h, BRICK)
	var row: int = 0
	for by in range(y, y + h):
		if (by - y) % 3 == 2:
			_hline(img, x, by, w, MORTAR)
			row += 1
			continue
		var off: int = 0 if row % 2 == 0 else 3
		for bx in range(x + off, x + w, 6):
			img.set_pixel(clampi(bx, x, x + w - 1), by, MORTAR)
	# Briques plus cuites, au hasard.
	for i in int(w * h / 18):
		var cx: int = rng.randi_range(x + 1, x + w - 2)
		var cy: int = rng.randi_range(y, y + h - 1)
		if img.get_pixel(cx, cy).is_equal_approx(BRICK):
			img.set_pixel(cx, cy, BRICK.darkened(0.14) if rng.randf() < 0.6 else BRICK.lightened(0.10))
	# Piliers de béton aux angles.
	_fill(img, x, y, 2, h, SLAB)
	_fill(img, x + w - 2, y, 2, h, SLAB.darkened(0.08))


# Fenêtres d'un étage : une par tranche de ~11 natifs, jamais alignées au
# cordeau — certaines manquent, d'autres ont une grille, des volets, un rideau.
# `door_x` >= 0 : on évite la porte.
static func _favela_windows(img: Image, x: int, y: int, w: int, h: int, r: Dictionary, rng: RandomNumberGenerator, door_x: int, door_w: int) -> void:
	if h < 8:
		return
	var slots: int = maxi(1, int((w - 4) / 11))
	var slot_w: float = float(w - 4) / float(slots)
	var win_h: int = 5 if h >= 12 else 4
	for i in slots:
		var win_w: int = 5 if rng.randf() < 0.6 else 4
		var kind: float = rng.randf()
		var skip: bool = slots > 1 and rng.randf() < 0.20
		var wx: int = x + 2 + int(slot_w * float(i) + (slot_w - float(win_w)) * 0.5) + rng.randi_range(-1, 1)
		var wy: int = y + (3 if h >= 12 else 2) + rng.randi_range(0, 1)
		if skip:
			continue
		if door_x >= 0 and wx + win_w + 2 > door_x - 1 and wx - 2 < door_x + door_w + 1:
			continue
		wx = clampi(wx, x + 3, x + w - 3 - win_w)
		var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
		_window(img, wx, wy, win_w, win_h, r, shutter if kind < 0.35 else Color(0, 0, 0, 0))
		if kind >= 0.35 and kind < 0.60:
			# Grade de ferro.
			for gx in range(wx + 1, wx + win_w, 2):
				_vline(img, gx, wy, win_h, r.dark)
		elif kind >= 0.80:
			# Rideau tiré.
			var cloth: Color = CLOTHES[rng.randi() % CLOTHES.size()]
			_fill(img, wx, wy + 1, win_w, win_h - 1, cloth)
			_vline(img, wx + int(win_w / 2), wy + 1, win_h - 1, cloth.darkened(0.18))
		# Coulure sous l'appui.
		if rng.randf() < 0.4 and wy + win_h + 3 < y + h:
			var sx: int = wx + rng.randi_range(0, win_w - 1)
			for sy in range(wy + win_h + 1, wy + win_h + 3):
				img.set_pixel(sx, sy, img.get_pixel(sx, sy).darkened(0.14))
		if rng.randf() < 0.14 and wy + win_h + 4 < y + h:
			_ac_unit(img, wx + win_w - 3, wy + win_h + 2)


# Porte de tôle ou de bois, un coup sur deux à barreaux.
static func _gate(img: Image, x: int, y: int, w: int, h: int, c: Color, rng: RandomNumberGenerator) -> void:
	_fill(img, x - 1, y - 1, w + 2, h + 1, c.darkened(0.62))
	_fill(img, x, y, w, h, c)
	_vline(img, x, y, h, c.lightened(0.22))
	_hline(img, x, y, w, c.lightened(0.22))
	_vline(img, x + w - 1, y + 1, h - 1, c.darkened(0.22))
	if rng.randf() < 0.5:
		for gx in range(x + 2, x + w - 1, 2):
			_vline(img, gx, y + 1, h - 1, c.darkened(0.30))
	else:
		_hline(img, x + 1, y + int(h / 2), w - 2, c.darkened(0.30))
	img.set_pixel(clampi(x + w - 2, 0, img.get_width() - 1), clampi(y + int(h / 2) + 1, 0, img.get_height() - 1), Color(0.95, 0.85, 0.5, 1))


# Le toit, vu du dessus, sur toute la largeur de l'image (avant-toit compris).
static func _favela_roof(img: Image, iw: int, rh: int, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var roll: float = rng.randf()
	var deep: bool = rh >= 7
	if roll < 0.56:
		# Laje : dalle de béton à parapet, l'étage qu'on montera plus tard.
		_fill(img, 0, 0, iw, rh, SLAB)
		for i in int(iw * rh / 9):
			img.set_pixel(rng.randi_range(1, iw - 2), rng.randi_range(1, rh - 2),
				SLAB.darkened(0.08) if rng.randf() < 0.65 else SLAB.lightened(0.06))
		_hline(img, 0, 1, iw, SLAB.lightened(0.20))
		_vline(img, 1, 1, rh - 2, SLAB.lightened(0.20))
		_vline(img, iw - 2, 2, rh - 3, SLAB.darkened(0.14))
		_hline(img, 1, rh - 2, iw - 2, SLAB.lightened(0.10))
		var used_from: int = 3
		if deep and iw >= 20:
			# Vergalhões : les fers en attente aux angles.
			img.set_pixel(2, 2, BRICK.darkened(0.45))
			img.set_pixel(iw - 3, 2, BRICK.darkened(0.45))
		if rng.randf() < 0.75:
			var tx: int = rng.randi_range(3, maxi(3, iw - 9))
			_tank(img, tx, maxi(1, rh - 7), deep)
			used_from = tx + 7
		if deep and iw - used_from >= 12 and rng.randf() < 0.7:
			# Varal : fil et linge qui sèche.
			var ly: int = 3
			_hline(img, used_from, ly, iw - used_from - 3, Color(0.22, 0.20, 0.18, 1))
			var cx: int = used_from + 1
			while cx < iw - 5:
				var cloth: Color = CLOTHES[rng.randi() % CLOTHES.size()]
				var cw: int = rng.randi_range(2, 3)
				_fill(img, cx, ly + 1, cw, rng.randi_range(2, 3), cloth)
				_vline(img, cx + cw - 1, ly + 1, 2, cloth.darkened(0.16))
				cx += cw + rng.randi_range(1, 2)
		elif deep and used_from > 12 and rng.randf() < 0.6:
			# Antena parabólica.
			_fill(img, 3, rh - 5, 4, 2, PIPE)
			_hline(img, 3, rh - 3, 4, PIPE.darkened(0.30))
			img.set_pixel(5, rh - 6, Color(0.22, 0.20, 0.18, 1))
	elif roll < 0.82:
		# Fibrocimento ondulé, lesté de briques et d'un pneu.
		for x in iw:
			var t: int = x % 3
			_vline(img, x, 0, rh, TIN.lightened(0.12) if t == 0 else (TIN if t == 1 else TIN.darkened(0.16)))
		_hline(img, 0, int(rh / 2), iw, TIN.darkened(0.26))
		for i in rng.randi_range(1, 3):
			var rx: int = rng.randi_range(2, maxi(2, iw - 5))
			var ry: int = rng.randi_range(1, maxi(1, rh - 4))
			_fill(img, rx, ry, rng.randi_range(2, 3), 2, Color(0.62, 0.40, 0.26, 1))
		for i in rng.randi_range(2, 3):
			var bx: int = rng.randi_range(2, maxi(2, iw - 5))
			var by: int = rng.randi_range(1, maxi(1, rh - 3))
			_fill(img, bx, by, 3, 1, BRICK)
			_hline(img, bx, by + 1, 3, BRICK.darkened(0.35))
		if deep and rng.randf() < 0.5:
			var px: int = rng.randi_range(3, maxi(3, iw - 7))
			_fill(img, px, 2, 4, 3, Color(0.16, 0.15, 0.15, 1))
			_fill(img, px + 1, 3, 2, 1, TIN.darkened(0.16))
	else:
		# Telha cerâmica : rangs décalés.
		_fill(img, 0, 0, iw, rh, ROOF_TILE)
		for y in range(1, rh - 1):
			if y % 2 == 0:
				_hline(img, 0, y, iw, ROOF_TILE.darkened(0.16))
			for x in range((int(y / 2) % 2) * 2, iw, 4):
				img.set_pixel(x, y, ROOF_TILE.darkened(0.30) if y % 2 == 0 else ROOF_TILE.lightened(0.12))
		_hline(img, 0, 1, iw, ROOF_TILE.lightened(0.18))
	# Contour et rive du toit.
	_hline(img, 0, 0, iw, r.dark)
	_vline(img, 0, 0, rh, r.dark)
	_vline(img, iw - 1, 0, rh, r.dark)
	_hline(img, 0, rh - 1, iw, Color(0.20, 0.18, 0.17, 1))


# Caixa d'água bleue sur ses deux parpaings.
static func _tank(img: Image, x: int, y: int, deep: bool) -> void:
	var tw: int = 5 if deep else 4
	var th: int = 4 if deep else 3
	_fill(img, x - 1, y - 1, tw + 2, th + 2, TANK.darkened(0.62))
	_fill(img, x, y, tw, th, TANK)
	_hline(img, x, y, tw, TANK.lightened(0.38))
	_vline(img, x, y + 1, th - 1, TANK.lightened(0.18))
	_vline(img, x + tw - 1, y + 1, th - 1, TANK.darkened(0.22))
	_hline(img, x + 1, y + th + 1, tw, Color(0, 0, 0, 0.28).blend(SLAB))


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
	_glass_rects.append(Rect2i(x, y, w, h))
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
