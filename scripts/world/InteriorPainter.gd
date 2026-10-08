class_name InteriorPainter
extends RefCounted

# Peintre procédural des intérieurs en pixel-art (densité GBA) : sols
# (planches, carrelage, marbre, moquette), bande de mur du fond avec plinthe,
# fenêtre. Chaque texture est générée dans la couleur du rect qu'elle habille
# (la scène garde sa palette) et répétée par le shader de tuiles.
# Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste H).

const DENSITY: int = 3
const TILE: int = 16
const WALL_H: int = 10      # natifs → 30 px monde
const WINDOW_W: int = 12
const WINDOW_H: int = 8

static var _cache: Dictionary = {}


static func ramp(c: Color) -> Dictionary:
	return {"dark": c.darkened(0.45), "shade": c.darkened(0.18), "base": c, "light": c.lightened(0.14), "lighter": c.lightened(0.28)}


# Texture de sol selon le genre : planks | tiles | marble | carpet | stone.
static func floor_texture(kind: String, color: Color, seed: int = 1) -> ImageTexture:
	match kind:
		"planks":
			return planks(color, seed)
		"tiles":
			return tiles(color, seed)
		"marble":
			return marble(color, seed)
		"carpet":
			return carpet(color, seed)
		"stone":
			return GroundPainter.cobble(color, seed)
	return planks(color, seed)


# Planches horizontales de 4 px (3 + joint), joints verticaux décalés, grain.
static func planks(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "planks_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	img.fill(r.base)
	# Contrastes doux : un plancher se lit par ses joints, pas par ses tons.
	var joint: Color = color.darkened(0.3)
	for row in 4:
		var y: int = row * 4
		var tone: Color = [r.base, color.darkened(0.05), r.base, color.lightened(0.05)][(row + seed) % 4]
		for x in TILE:
			img.set_pixel(x, y, tone.lightened(0.05))
			img.set_pixel(x, y + 1, tone)
			img.set_pixel(x, y + 2, tone)
			img.set_pixel(x, y + 3, joint)
		# Grain : quelques pixels à peine plus sombres en ligne.
		var gx: int = rng.randi_range(0, TILE - 1)
		var gl: int = rng.randi_range(2, 5)
		for i in gl:
			img.set_pixel(posmod(gx + i, TILE), y + 1 + (i % 2), tone.darkened(0.08))
		# Joint vertical décalé une rangée sur deux.
		var jx: int = (4 if row % 2 == 0 else 12) + rng.randi_range(-1, 1)
		for i in 3:
			img.set_pixel(posmod(jx, TILE), y + i, joint)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Carreaux 8×8 à joints clairs, en damier léger, éclat en haut-gauche.
static func tiles(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "tiles_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	for ty in 2:
		for tx in 2:
			var tone: Color = r.base if (tx + ty) % 2 == 0 else r.shade.lightened(0.06)
			for y in 8:
				for x in 8:
					var c: Color = tone
					if x == 7 or y == 7:
						c = r.dark.lightened(0.1)   # joint
					elif x == 0 and y < 7 or y == 0 and x < 7:
						c = tone.lightened(0.1)     # éclat
					img.set_pixel(tx * 8 + x, ty * 8 + y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Dalles de marbre 16×16 claires, veines diagonales plus claires, joint fin.
static func marble(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "marble_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	img.fill(r.light)
	for i in 3:
		var x: int = rng.randi_range(0, TILE - 1)
		var y: int = rng.randi_range(0, TILE - 1)
		var len: int = rng.randi_range(4, 9)
		for k in len:
			img.set_pixel(posmod(x + k, TILE), posmod(y + (k / 2), TILE), r.lighter if k % 3 != 0 else r.base)
	for x in TILE:
		img.set_pixel(x, TILE - 1, r.shade)
	for y in TILE:
		img.set_pixel(TILE - 1, y, r.shade)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Moquette : fond uni piqueté.
static func carpet(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "carpet_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	img.fill(r.base)
	for i in 28:
		img.set_pixel(rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), r.shade if i % 2 == 0 else r.light)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Bande de mur du fond (16×10 natifs, répétée en largeur) : cimaise claire,
# papier peint à rayures discrètes, plinthe sombre.
static func wall(color: Color) -> ImageTexture:
	var key: String = "wall_%s" % color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, WALL_H, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	for y in WALL_H:
		for x in TILE:
			var c: Color = r.base
			if y == 0:
				c = r.lighter
			elif y == 1:
				c = r.light
			elif y >= WALL_H - 2:
				c = r.dark if y == WALL_H - 1 else r.shade
			elif x % 8 == 0:
				c = color.darkened(0.06)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Fenêtre 12×8 natifs : cadre sombre, vitre ciel en deux tons, croisillon.
static func window(night: bool = false) -> ImageTexture:
	var key: String = "window_%s" % ("n" if night else "d")
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(WINDOW_W, WINDOW_H, false, Image.FORMAT_RGBA8)
	var frame: Color = Color(0.3, 0.22, 0.16, 1)
	var glass_a: Color = Color(0.15, 0.2, 0.35, 1) if night else Color(0.55, 0.8, 0.98, 1)
	var glass_b: Color = Color(0.1, 0.13, 0.25, 1) if night else Color(0.72, 0.9, 1.0, 1)
	for y in WINDOW_H:
		for x in WINDOW_W:
			var c: Color = glass_a if (x + y) % 5 < 3 else glass_b
			if x == 0 or y == 0 or x == WINDOW_W - 1 or y == WINDOW_H - 1 or x == WINDOW_W / 2 or y == WINDOW_H / 2:
				c = frame
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
