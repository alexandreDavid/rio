class_name GroundPainter
extends RefCounted

# Peintre procédural de sols en pixel-art (densité GBA, 1 px natif = 3 px
# monde), complément de FacadePainter pour les dalles des districts : pavés
# (esplanades, ruelles), terre du morro, escaliers. Les textures sont
# répétées par le shader de DistrictDresser (cellule = taille native × 3) et
# recolorées à la source : chaque dalle garde SA couleur.
# Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste B).

const DENSITY: int = 3
const TILE: int = 16  # pavé / terre : tuile native 16×16 → 48 px monde

static var _cache: Dictionary = {}


static func ramp(c: Color) -> Dictionary:
	return {"dark": c.darkened(0.45), "shade": c.darkened(0.18), "base": c, "light": c.lightened(0.14), "lighter": c.lightened(0.28)}


# Pavés irréguliers : pierres 3-5 px, joints sombres, éclat clair en haut-gauche.
static func cobble(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "cobble_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	img.fill(r.dark)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	# Rangées de pierres de hauteur 4 (3 + joint), décalées une rangée sur deux.
	for row in 4:
		var y: int = row * 4
		var x: int = (0 if row % 2 == 0 else 2)
		var start: int = x
		while x < TILE + 2:
			var w: int = rng.randi_range(3, 5)
			var stone: Color = [r.base, r.base, r.shade, r.light][rng.randi() % 4]
			_fill_wrap(img, x, y, w - 1, 3, stone)
			img.set_pixel(posmod(x, TILE), y, stone.lightened(0.18))  # éclat
			x += w
		if start > 0:
			_fill_wrap(img, start - 2, y, 1, 3, r.shade)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Terre battue : fond uni, cailloux, touffes et traces, dans la couleur de la dalle.
static func dirt(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "dirt_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	img.fill(r.base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for i in 22:
		img.set_pixel(rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), r.shade)
	for i in 10:
		img.set_pixel(rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), r.light)
	for i in 3:  # cailloux 2×1
		var x: int = rng.randi_range(0, TILE - 1)
		var y: int = rng.randi_range(0, TILE - 1)
		img.set_pixel(x, y, r.lighter)
		img.set_pixel(posmod(x + 1, TILE), y, r.dark)
	for i in 2:  # touffe d'herbe sèche
		var x: int = rng.randi_range(0, TILE - 1)
		var y: int = rng.randi_range(0, TILE - 1)
		var g: Color = Color(0.45, 0.55, 0.28, 1).lerp(r.base, 0.4)
		img.set_pixel(x, y, g)
		img.set_pixel(posmod(x + 1, TILE), posmod(y - 1, TILE), g.lightened(0.1))
		img.set_pixel(posmod(x - 1, TILE), posmod(y - 1, TILE), g)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Escalier : marches de 3 px natifs (nez clair, giron, contremarche sombre),
# répété verticalement ; la largeur est celle de la dalle.
static func stairs(width_world: float, color: Color) -> ImageTexture:
	var w: int = maxi(2, int(floor(width_world / DENSITY)))
	var key: String = "stairs_%d_%s" % [w, color.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var step_h: int = 3
	var img: Image = Image.create(w, step_h * 2, false, Image.FORMAT_RGBA8)
	var r: Dictionary = ramp(color)
	for s in 2:
		var y: int = s * step_h
		img.fill_rect(Rect2i(0, y, w, 1), r.lighter)        # nez de marche
		img.fill_rect(Rect2i(0, y + 1, w, 1), r.base)       # giron
		img.fill_rect(Rect2i(0, y + 2, w, 1), r.dark)       # contremarche
		# usure : quelques pixels du giron plus sombres
		for x in range(1, w - 1, 5):
			img.set_pixel(x, y + 1, r.shade)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _fill_wrap(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			img.set_pixel(posmod(xx, TILE), posmod(yy, TILE), c)
