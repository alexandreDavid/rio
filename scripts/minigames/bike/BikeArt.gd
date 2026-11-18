extends RefCounted

# Peintre pixel-art du mini-jeu vélo (Av. Atlântica vue de haut) : véhicules
# vus de trois quarts arrière, colis, parasols, cimes de palmiers et
# d'amendoeiras, pavé du calçadão, asphalte, ciclovia. Tout est peint en
# résolution native puis affiché ×3 (NEAREST) — 1 px natif = 3 px monde, la
# densité des personnages de CharacterSpriteFactory à 96 px de haut.

const P: int = 3

const OUTLINE: Color = Color(0.13, 0.10, 0.12, 1.0)
const GLASS: Color = Color(0.20, 0.27, 0.38, 1.0)
const GLASS_HI: Color = Color(0.58, 0.74, 0.88, 1.0)
const TYRE: Color = Color(0.10, 0.10, 0.12, 1.0)
const TAIL: Color = Color(0.92, 0.18, 0.16, 1.0)
const TAIL_HI: Color = Color(1.0, 0.62, 0.50, 1.0)
const PLATE: Color = Color(0.93, 0.93, 0.89, 1.0)
const PLATE_BLUE: Color = Color(0.15, 0.32, 0.70, 1.0)
const BUMPER: Color = Color(0.20, 0.20, 0.23, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.05, 0.30)
const TAXI_YELLOW: Color = Color(0.98, 0.80, 0.14, 1.0)
const TAXI_BLUE: Color = Color(0.16, 0.34, 0.78, 1.0)

static var _cache: Dictionary = {}


static func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


# Contour sombre automatique : tout pixel vide qui touche un pixel plein.
static func _outline(img: Image, c: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixelv(q).a > 0.5:
					img.set_pixel(x, y, c)
					break


static func _done(key: String, img: Image) -> ImageTexture:
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Voiture vue de trois quarts arrière (on la double) : capot, pare-brise,
# toit, lunette, coffre, face arrière avec feux et plaque Mercosul.
# Native 76×52 (corps 74×50 = la hitbox 223×150, ombre décalée de 2 px).
static func car(color: Color, taxi: bool) -> ImageTexture:
	var key: String = "car_%s_%s" % [color.to_html(false), taxi]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(76, 52, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = TAXI_YELLOW if taxi else color
	var shade: Color = base.darkened(0.22)
	var light: Color = base.lightened(0.28)
	var dark: Color = base.darkened(0.55)
	_fr(img, 4, 4, 72, 48, SHADOW)
	# Pneus qui dépassent de la caisse.
	_fr(img, 4, 4, 5, 9, TYRE)
	_fr(img, 65, 4, 5, 9, TYRE)
	_fr(img, 1, 33, 6, 14, TYRE)
	_fr(img, 67, 33, 6, 14, TYRE)
	# Caisse (capot → coffre), coins arrondis, flanc droit à l'ombre.
	_fr(img, 7, 0, 60, 40, dark)
	_fr(img, 8, 1, 58, 38, base)
	for c in [Vector2i(7, 0), Vector2i(8, 0), Vector2i(7, 1), Vector2i(65, 0), Vector2i(66, 0), Vector2i(66, 1)]:
		img.set_pixelv(c, Color(0, 0, 0, 0))
	img.set_pixel(8, 1, dark)
	img.set_pixel(65, 1, dark)
	_fr(img, 8, 2, 2, 36, light)
	_fr(img, 62, 2, 4, 36, shade)
	_fr(img, 10, 2, 50, 1, light)
	_fr(img, 36, 3, 2, 5, shade)
	_fr(img, 12, 1, 7, 2, Color(0.98, 0.96, 0.82))
	_fr(img, 55, 1, 7, 2, Color(0.98, 0.96, 0.82))
	# Habitacle plus étroit que la caisse : pare-brise, toit, lunette.
	_fr(img, 13, 9, 48, 25, dark)
	_fr(img, 14, 10, 46, 5, GLASS)
	_fr(img, 16, 11, 9, 1, GLASS_HI)
	_fr(img, 4, 11, 4, 3, dark)
	_fr(img, 5, 11, 2, 2, base)
	_fr(img, 66, 11, 4, 3, dark)
	_fr(img, 67, 11, 2, 2, base)
	_fr(img, 14, 15, 2, 12, GLASS)
	_fr(img, 58, 15, 2, 12, GLASS)
	_fr(img, 16, 15, 42, 12, base.lerp(light, 0.45))
	_fr(img, 17, 16, 28, 1, light.lightened(0.2))
	_fr(img, 16, 26, 42, 1, shade)
	_fr(img, 14, 27, 46, 6, GLASS)
	for k in 5:
		img.set_pixel(44 + k, 32 - k, GLASS_HI)
		img.set_pixel(46 + k, 32 - k, GLASS_HI)
	# Coffre.
	_fr(img, 10, 34, 52, 4, base)
	_fr(img, 8, 38, 58, 1, shade)
	if taxi:
		# Táxi carioca : jaune, bande bleue sur les flancs, lanterne sur le toit.
		_fr(img, 8, 1, 2, 38, TAXI_BLUE)
		_fr(img, 64, 1, 2, 38, TAXI_BLUE)
		_fr(img, 27, 17, 20, 7, OUTLINE)
		_fr(img, 28, 18, 18, 5, Color(0.97, 0.97, 0.94))
		for k in 4:
			_fr(img, 30 + k * 4, 19, 2, 3, TAXI_BLUE)
	# Face arrière : feux, plaque, pare-chocs.
	_fr(img, 2, 39, 70, 9, dark)
	_fr(img, 3, 40, 68, 7, shade)
	_fr(img, 4, 40, 11, 3, TAIL)
	_fr(img, 59, 40, 11, 3, TAIL)
	_fr(img, 5, 40, 3, 1, TAIL_HI)
	_fr(img, 60, 40, 3, 1, TAIL_HI)
	_fr(img, 31, 41, 12, 5, PLATE)
	_fr(img, 31, 41, 12, 1, PLATE_BLUE)
	_fr(img, 33, 43, 8, 1, OUTLINE)
	_fr(img, 2, 47, 70, 3, BUMPER)
	_fr(img, 3, 47, 68, 1, BUMPER.lightened(0.25))
	return _done(key, img)


# Ônibus vu de trois quarts arrière : toit à clim, lunette, girouette LED
# (la ligne 474 qui longe la praia), bande de la compagnie, feux.
static func bus(color: Color, accent: Color) -> ImageTexture:
	var key: String = "bus_%s_%s" % [color.to_html(false), accent.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(76, 52, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = color
	var shade: Color = base.darkened(0.2)
	var dark: Color = base.darkened(0.55)
	_fr(img, 4, 4, 72, 48, SHADOW)
	_fr(img, 1, 36, 7, 12, TYRE)
	_fr(img, 66, 36, 7, 12, TYRE)
	_fr(img, 2, 0, 70, 49, dark)
	_fr(img, 3, 1, 68, 47, base)
	# Toit : bandes de la compagnie, clim, trappes.
	_fr(img, 3, 1, 3, 27, accent)
	_fr(img, 68, 1, 3, 27, accent)
	_fr(img, 7, 2, 60, 1, base.lightened(0.25))
	var ac: Color = Color(0.80, 0.82, 0.84)
	_fr(img, 21, 5, 32, 13, ac.darkened(0.45))
	_fr(img, 22, 6, 30, 11, ac)
	for k in 5:
		_fr(img, 24 + k * 6, 8, 3, 7, ac.darkened(0.25))
	_fr(img, 10, 5, 8, 6, ac.darkened(0.3))
	_fr(img, 11, 6, 6, 4, ac)
	_fr(img, 56, 5, 8, 6, ac.darkened(0.3))
	_fr(img, 57, 6, 6, 4, ac)
	_fr(img, 3, 27, 68, 1, shade)
	# Face arrière.
	_fr(img, 3, 28, 68, 20, shade)
	_fr(img, 6, 29, 62, 8, GLASS)
	_fr(img, 8, 30, 12, 1, GLASS_HI)
	_fr(img, 24, 30, 26, 5, OUTLINE)
	var led: Color = Color(1.0, 0.62, 0.12)
	# « 474 » en LED 3×3.
	var digits: Array = [
		[1, 0, 1, 1, 1, 1, 0, 0, 1],
		[1, 1, 1, 0, 0, 1, 0, 0, 1],
		[1, 0, 1, 1, 1, 1, 0, 0, 1],
	]
	for i in digits.size():
		var g: Array = digits[i]
		for k in 9:
			if int(g[k]) == 1:
				img.set_pixel(29 + i * 6 + k % 3, 31 + k / 3, led)
	_fr(img, 3, 38, 68, 3, accent)
	_fr(img, 4, 41, 6, 4, TAIL)
	_fr(img, 64, 41, 6, 4, TAIL)
	_fr(img, 5, 41, 2, 1, TAIL_HI)
	_fr(img, 65, 41, 2, 1, TAIL_HI)
	_fr(img, 24, 41, 26, 5, dark)
	for k in 6:
		_fr(img, 26 + k * 4, 42, 2, 3, shade.darkened(0.3))
	_fr(img, 2, 46, 70, 3, BUMPER)
	return _done(key, img)


# Colis en carton (18×18 natifs + ombre) : dessus clair, scotch, étiquette.
static func parcel() -> ImageTexture:
	if _cache.has("parcel"):
		return _cache["parcel"]
	var img: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var card: Color = Color(0.80, 0.56, 0.30)
	_fr(img, 2, 2, 18, 18, SHADOW)
	_fr(img, 0, 0, 18, 18, OUTLINE)
	_fr(img, 1, 1, 16, 6, card.lightened(0.22))
	_fr(img, 1, 7, 16, 10, card)
	_fr(img, 1, 7, 16, 1, card.darkened(0.3))
	_fr(img, 1, 16, 16, 1, card.darkened(0.2))
	var tape: Color = Color(0.96, 0.86, 0.55)
	_fr(img, 8, 1, 2, 16, tape)
	_fr(img, 1, 3, 16, 1, tape.darkened(0.08))
	_fr(img, 11, 10, 5, 4, Color(0.97, 0.97, 0.94))
	_fr(img, 12, 11, 3, 1, OUTLINE)
	_fr(img, 12, 12, 2, 1, Color(0.85, 0.2, 0.2))
	_fr(img, 2, 2, 3, 1, card.lightened(0.4))
	return _done("parcel", img)


# Parasol vu de dessus : 8 pans alternés, piquet au centre.
static func umbrella(color: Color) -> ImageTexture:
	var key: String = "umb_%s" % color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var n: int = 24
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Vector2 = Vector2(11.5, 11.5)
	for y in n:
		for x in n:
			var d: Vector2 = Vector2(x, y) - c
			if d.length() > 10.6:
				continue
			var sector: int = int(floor((d.angle() + PI) / (PI / 4.0))) % 2
			var col: Color = color if sector == 0 else Color(0.97, 0.96, 0.92)
			# Lumière en haut à gauche.
			if d.x + d.y > 7.0:
				col = col.darkened(0.16)
			elif d.x + d.y < -9.0:
				col = col.lightened(0.12)
			img.set_pixel(x, y, col)
	img.set_pixel(11, 11, OUTLINE)
	img.set_pixel(12, 12, OUTLINE)
	_outline(img, color.darkened(0.6))
	return _done(key, img)


# Cime de palmier vue de dessus : palmes en étoile, cocos au centre.
static func palm_crown(seed: int) -> ImageTexture:
	var key: String = "palm_%d" % seed
	if _cache.has(key):
		return _cache[key]
	var n: int = 34
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var leaf: Color = Color(0.24, 0.58, 0.30)
	var leaf_hi: Color = Color(0.48, 0.78, 0.36)
	var leaf_lo: Color = Color(0.16, 0.40, 0.22)
	var c: Vector2 = Vector2(16.5, 16.5)
	var count: int = 8
	for i in count:
		var a: float = TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var dir: Vector2 = Vector2.from_angle(a)
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var length: float = rng.randf_range(12.0, 15.5)
		var lit: bool = dir.x + dir.y < 0.0
		var r: float = 1.5
		while r < length:
			var t: float = r / length
			var half: float = sin(t * PI) * 2.6
			# Palme qui retombe un peu : la pointe s'incurve.
			var p: Vector2 = c + dir * r + nrm * t * t * 2.0
			var s: float = -half
			while s <= half:
				var q: Vector2 = p + nrm * s
				var qi: Vector2i = Vector2i(int(q.x), int(q.y))
				if qi.x >= 0 and qi.y >= 0 and qi.x < n and qi.y < n:
					var col: Color = leaf
					if absf(s) < 0.6:
						col = leaf_hi if lit else leaf
					elif s > 0.0:
						col = leaf if lit else leaf_lo
					img.set_pixelv(qi, col)
				s += 0.5
			r += 0.5
	var coco: Color = Color(0.45, 0.32, 0.16)
	_fr(img, 15, 15, 2, 2, coco)
	_fr(img, 17, 16, 2, 2, coco.lightened(0.15))
	_fr(img, 15, 17, 2, 2, coco.darkened(0.2))
	_outline(img, Color(0.08, 0.20, 0.10))
	return _done(key, img)


# Amendoeira (le trottoir côté immeubles) : cime ronde bosselée.
static func tree_crown(seed: int) -> ImageTexture:
	var key: String = "tree_%d" % seed
	if _cache.has(key):
		return _cache[key]
	var n: int = 30
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var base: Color = Color(0.30, 0.55, 0.26)
	var blobs: Array = [Vector3(14.5, 14.5, 9.0)]
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + rng.randf_range(-0.3, 0.3)
		blobs.append(Vector3(14.5 + cos(a) * 6.5, 14.5 + sin(a) * 6.5, rng.randf_range(4.5, 6.0)))
	for y in n:
		for x in n:
			for b in blobs:
				var bv: Vector3 = b
				var d: Vector2 = Vector2(x, y) - Vector2(bv.x, bv.y)
				if d.length() <= bv.z:
					var col: Color = base
					if d.x + d.y < -bv.z * 0.6:
						col = base.lightened(0.22)
					elif d.x + d.y > bv.z * 0.7:
						col = base.darkened(0.2)
					img.set_pixel(x, y, col)
	for i in 10:
		img.set_pixel(rng.randi_range(6, 23), rng.randi_range(6, 23), base.lightened(0.35))
	_outline(img, Color(0.10, 0.22, 0.10))
	return _done(key, img)


# Pedra portuguesa du calçadão : bandes noir/blanc ondulées dans le sens de
# la promenade (la vague de Burle Marx), joints de pierre en pointillé.
static func calcadao(w: int) -> ImageTexture:
	var key: String = "calc_%d" % w
	if _cache.has(key):
		return _cache[key]
	var h: int = 24
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var black: Color = Color(0.16, 0.16, 0.18)
	var white: Color = Color(0.95, 0.94, 0.89)
	for y in h:
		var wob: float = sin(TAU * float(y) / float(h)) * 3.0
		for x in w:
			var band: int = int(floor((float(x) + wob) / 7.0))
			var col: Color = black if posmod(band, 2) == 0 else white
			if (x * 3 + y * 5) % 11 == 0:
				col = col.darkened(0.12) if col == white else col.lightened(0.12)
			img.set_pixel(x, y, col)
	return _done(key, img)


# Asphalte : grain fin sur trois tons, quelques gravillons clairs.
static func asphalt() -> ImageTexture:
	if _cache.has("asphalt"):
		return _cache["asphalt"]
	var n: int = 32
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.29, 0.29, 0.32)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 120:
		img.set_pixel(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1), base.darkened(0.12))
	for i in 60:
		img.set_pixel(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1), base.lightened(0.10))
	for i in 10:
		img.set_pixel(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1), base.lightened(0.3))
	return _done("asphalt", img)


# Ciclovia de Copa : enrobé terracotta grenu.
static func ciclovia(w: int) -> ImageTexture:
	var key: String = "ciclo_%d" % w
	if _cache.has(key):
		return _cache[key]
	var h: int = 32
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.70, 0.33, 0.24)
	img.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i in w * 2:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1), base.darkened(0.1))
	for i in w:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1), base.lightened(0.12))
	return _done(key, img)
