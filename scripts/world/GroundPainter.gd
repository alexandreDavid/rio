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


# ---------------------------------------------------------------------------
# Sable, mer et écume (chantier « mer et sable peints », 2026-10-10) : les
# tuiles de l'atlas IA (sable 103×96, eau 130×50 étirée) trahissaient leur
# origine — grille de 64 px visible, grain plus fin que le reste du jeu. Ici
# tout est peint à la densité du jeu : tuile 64×64 natifs (192 px monde) pour
# le sable et la mer, bande d'écume 32×12 natifs. La mer bouge par défilement
# entier (le shader décale la tuile d'un pixel natif à la fois, elle boucle) et
# par 2 frames de reflets ; l'écume avance sur le sable en 4 frames ping-pong.
# ---------------------------------------------------------------------------

const BIG: int = 64           # sable / mer : tuile native 64×64 → 192 px monde
const SEA_FRAMES: int = 2
const FOAM_W: int = 32
const FOAM_H: int = 12        # 6 rangées côté sable, 6 côté mer (couture au milieu)
const FOAM_FRAMES: int = 4
const FOAM_ADVANCE: Array = [0, 1, 2, 1]  # avancée du front, frame par frame
const FOAM_WHITE: Color = Color(0.96, 0.97, 0.95, 1.0)


static func sand_ramp(c: Color) -> Dictionary:
	# Le sable est la matière la plus douce du jeu : rampe serrée.
	return {"dark": c.darkened(0.16), "shade": c.darkened(0.07), "base": c, "light": c.lightened(0.09), "lighter": c.lightened(0.2)}


static func sea_ramp(c: Color) -> Dictionary:
	return {"deep": c.darkened(0.22), "shade": c.darkened(0.1), "base": c, "light": c.lightened(0.17), "lighter": c.lightened(0.34)}


# Sable : fond uni, grain épars sur 3 tons, quelques rides de vent (trait
# d'ombre souligné d'un trait clair). Pas de motif répétitif lisible : c'est
# ce qui faisait « papier peint » avec l'atlas.
static func sand(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "sand_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(BIG, BIG, false, Image.FORMAT_RGBA8)
	var r: Dictionary = sand_ramp(color)
	img.fill(r.base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for i in 170:
		img.set_pixel(rng.randi_range(0, BIG - 1), rng.randi_range(0, BIG - 1), r.shade)
	for i in 110:
		img.set_pixel(rng.randi_range(0, BIG - 1), rng.randi_range(0, BIG - 1), r.light)
	for i in 24:
		img.set_pixel(rng.randi_range(0, BIG - 1), rng.randi_range(0, BIG - 1), r.lighter)
	for i in 14:
		img.set_pixel(rng.randi_range(0, BIG - 1), rng.randi_range(0, BIG - 1), r.dark)
	for i in 12:  # rides de vent
		var x: int = rng.randi_range(0, BIG - 1)
		var y: int = rng.randi_range(1, BIG - 1)
		var len: int = rng.randi_range(3, 6)
		for k in len:
			img.set_pixel(posmod(x + k, BIG), y, r.shade)
			img.set_pixel(posmod(x + k, BIG), y - 1, r.light)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Mer : SEA_FRAMES tuiles côte à côte. Crêtes claires (trait + crochet),
# ombre sous la crête, taches plus profondes ; la 2e frame décale les éclats
# d'un pixel pour que l'eau scintille sans que rien ne « saute ».
static func sea(color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "sea_%s_%d" % [color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(BIG * SEA_FRAMES, BIG, false, Image.FORMAT_RGBA8)
	var r: Dictionary = sea_ramp(color)
	img.fill(r.base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	# Crêtes : au plus une par bande de 4 rangées, une bande sur deux vide,
	# abscisse libre → des traits espacés, jamais un semis ; la tuile boucle
	# (posmod) dans les deux sens.
	var crests: Array = []
	for band in BIG / 4:
		if rng.randf() < 0.45:
			continue
		crests.append({"x": rng.randi_range(0, BIG - 1), "y": band * 4 + rng.randi_range(0, 3), "len": rng.randi_range(4, 9), "hook": rng.randf() < 0.5})
	var deeps: Array = []
	for i in 7:
		deeps.append({"x": rng.randi_range(0, BIG - 1), "y": rng.randi_range(0, BIG - 1), "len": rng.randi_range(3, 5)})
	var glints: Array = []
	for i in 6:
		glints.append(Vector2i(rng.randi_range(0, BIG - 1), rng.randi_range(0, BIG - 1)))
	for f in SEA_FRAMES:
		var ox: int = f * BIG
		for d in deeps:
			for k in d.len:
				img.set_pixel(ox + posmod(d.x + k, BIG), d.y, r.shade)
		for c in crests:
			var hi: int = (c.len / 2 + f) % c.len  # l'éclat court le long de la crête
			for k in c.len:
				img.set_pixel(ox + posmod(c.x + k, BIG), c.y, r.lighter if k == hi else r.light)
			# Ombre courte sous le début de la crête : le creux, pas un soulignement.
			for k in range(1, 3):
				img.set_pixel(ox + posmod(c.x + k, BIG), posmod(c.y + 1, BIG), r.deep)
			if c.hook:
				img.set_pixel(ox + posmod(c.x + c.len, BIG), posmod(c.y + 1, BIG), r.light)
		for i in glints.size():
			if (i + f) % 2 == 0:
				var g: Vector2i = glints[i]
				img.set_pixel(ox + g.x, g.y, r.lighter)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# Écume : bande FOAM_W × FOAM_H, FOAM_FRAMES frames côte à côte, orientée
# sable en haut / mer en bas, couture au milieu (rangée 6). Rangées 0-1 :
# sable humide (voile sombre translucide) ; le front blanc avance sur le
# sable puis recule (ping-pong), laissant du sable mouillé derrière lui ; côté
# mer : eau peu profonde éclaircie, puis moutons et une ligne de ressac
# pointillée sur fond transparent (la mer peinte défile dessous).
static func foam(sea_color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "foam_%s_%d" % [sea_color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(FOAM_W * FOAM_FRAMES, FOAM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var r: Dictionary = sea_ramp(sea_color)
	var damp: Color = Color(0, 0, 0, 0.10)
	var wet: Color = Color(0, 0, 0, 0.20)
	# Relief du front : +0/+1 par paquets de 3 à 7 colonnes (boucle en x).
	var bump: PackedInt32Array = PackedInt32Array()
	bump.resize(FOAM_W)
	var x: int = 0
	var level: int = 0
	while x < FOAM_W:
		var run: int = rng.randi_range(3, 7)
		for k in run:
			if x + k < FOAM_W:
				bump[x + k] = level
		x += run
		level = 1 - level
	var dashes: Array = []
	x = rng.randi_range(0, 3)
	while x < FOAM_W:
		var len: int = rng.randi_range(3, 6)
		dashes.append({"x": x, "len": len})
		x += len + rng.randi_range(2, 5)
	var specks: Array = []
	for i in 26:
		specks.append(Vector3i(rng.randi_range(0, FOAM_W - 1), rng.randi_range(7, FOAM_H - 1), rng.randi_range(0, 3)))
	for f in FOAM_FRAMES:
		var ox: int = f * FOAM_W
		var adv: int = FOAM_ADVANCE[f]
		for cx in FOAM_W:
			var front: int = 2 + adv + bump[cx]  # rangée du front blanc (2..5)
			img.set_pixel(ox + cx, 0, damp)
			img.set_pixel(ox + cx, 1, damp)
			for y in range(2, front):
				img.set_pixel(ox + cx, y, wet)
			img.set_pixel(ox + cx, front, FOAM_WHITE)
			for y in range(front + 1, FOAM_H / 2):
				img.set_pixel(ox + cx, y, r.base)
			if front + 1 < FOAM_H:
				img.set_pixel(ox + cx, front + 1, FOAM_WHITE.lerp(r.lighter, 0.35))
			if front + 2 < FOAM_H:
				img.set_pixel(ox + cx, front + 2, Color(FOAM_WHITE, 0.35))
		# Ligne de ressac : tirets qui glissent d'un pixel par frame.
		var dash_y: int = FOAM_H / 2 + 2
		for d in dashes:
			for k in d.len:
				img.set_pixel(ox + posmod(d.x + k + adv, FOAM_W), dash_y, Color(FOAM_WHITE, 0.8))
		for s in specks:
			if (s.z + f) % 4 < 2:
				var a: float = 0.65 - 0.1 * float(s.y - 7)
				img.set_pixel(ox + s.x, s.y, Color(FOAM_WHITE, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
