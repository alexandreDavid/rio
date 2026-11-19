class_name FurniturePainter
extends RefCounted

# Meubles d'intérieur en pixel-art, même principe que FacadePainter : dessinés
# à la densité du jeu (1 natif = 3 px monde) dans la boîte du ColorRect qu'ils
# remplacent, vus en faux 3/4 (le dessus du meuble + sa face avant). Le genre
# vient du nom du nœud (KINDS) ; la couleur du rect teinte ce qui a du sens
# (couverture du lit, tapis, toile cirée). Lumière du haut-gauche.

const DENSITY: int = 3
const WOOD: Color = Color(0.50, 0.33, 0.20, 1)
const STEEL: Color = Color(0.74, 0.76, 0.80, 1)
const WHITE: Color = Color(0.94, 0.93, 0.89, 1)
const INK: Color = Color(0.16, 0.13, 0.12, 1)

# Nom du nœud (ou de son parent) → genre. L'ordre compte : premier trouvé.
const KINDS: Array = [
	["KitchenCounter", "kitchen"], ["Fridge", "fridge"], ["TVRack", "tv"], ["Altar", "altar"],
	["Bed", "bed"], ["Table", "table"], ["Rug", "rug"],
]

static var _cache: Dictionary = {}


static func kind_for(node_name: String) -> String:
	for pair in KINDS:
		if node_name == String(pair[0]):
			return String(pair[1])
	return ""


static func build(kind: String, size: Vector2, color: Color, seed: int = 1) -> ImageTexture:
	var key: String = "%s_%d_%d_%s_%d" % [kind, int(size.x), int(size.y), color.to_html(false), seed]
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = ImageTexture.create_from_image(build_image(kind, size, color, seed))
	_cache[key] = tex
	return tex


static func build_image(kind: String, size: Vector2, color: Color, seed: int = 1) -> Image:
	var w: int = maxi(4, int(size.x / DENSITY))
	var h: int = maxi(4, int(size.y / DENSITY))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	match kind:
		"bed":
			_bed(img, w, h, color)
		"kitchen":
			_kitchen(img, w, h)
		"fridge":
			_fridge(img, w, h)
		"tv":
			_tv(img, w, h)
		"altar":
			_altar(img, w, h)
		"table":
			_table(img, w, h, color)
		"rug":
			_rug(img, w, h, color)
		_:
			img.fill(color)
	return img


# Lit en long, tête à gauche : cadre de bois, oreiller, couverture rayée.
static func _bed(img: Image, w: int, h: int, color: Color) -> void:
	var blanket: Color = color if color.s > 0.2 and color.b > color.r else Color(0.36, 0.52, 0.72, 1)
	_box(img, 0, 0, w, h, WOOD)
	_fill(img, 0, h - 2, w, 2, WOOD.darkened(0.30))
	# Tête de lit, plus haute et plus claire.
	_fill(img, 0, 0, 2, h - 1, WOOD.lightened(0.14))
	_vline(img, 0, 0, h, INK)
	# Matelas.
	_fill(img, 2, 1, w - 3, h - 4, WHITE)
	# Oreiller.
	_fill(img, 3, 2, 4, h - 6, WHITE.lightened(0.5))
	_vline(img, 6, 2, h - 6, WHITE.darkened(0.14))
	_hline(img, 3, h - 5, 4, WHITE.darkened(0.14))
	# Couverture : revers clair puis rayures.
	var bx: int = 8
	_fill(img, bx, 1, w - bx - 1, h - 4, blanket)
	_vline(img, bx, 1, h - 4, blanket.lightened(0.35))
	for x in range(bx + 3, w - 2, 3):
		_vline(img, x, 1, h - 4, blanket.darkened(0.16))
	_hline(img, bx + 1, 1, w - bx - 2, blanket.lightened(0.14))
	_hline(img, bx, h - 4, w - bx - 1, blanket.darkened(0.30))
	_outline(img, w, h)


# Bloc cuisine : plan de travail, cuisinière à quatre feux (une panela
# dessus), évier, et la face avant des placards.
static func _kitchen(img: Image, w: int, h: int) -> void:
	var top_h: int = h - 4
	_fill(img, 0, 0, w, top_h, STEEL)
	_hline(img, 0, 0, w, STEEL.lightened(0.3))
	# Façade des placards.
	_fill(img, 0, top_h, w, 4, Color(0.80, 0.74, 0.60, 1))
	_hline(img, 0, top_h, w, STEEL.darkened(0.40))
	for x in range(0, w, 5):
		_vline(img, x, top_h + 1, 3, Color(0.58, 0.52, 0.40, 1))
		if x + 3 < w:
			img.set_pixel(x + 3, top_h + 2, INK)
	# Cuisinière (à droite) : plaque sombre, feux, bouton.
	var sw: int = mini(9, w - 8)
	var sx: int = w - sw - 1
	_fill(img, sx, 1, sw, top_h - 1, Color(0.20, 0.20, 0.22, 1))
	for by in [2, top_h - 3]:
		for bx in [sx + 1, sx + sw - 3]:
			_fill(img, bx, by, 2, 2, Color(0.42, 0.42, 0.46, 1))
	# Panela vermelha sur le feu arrière.
	_fill(img, sx + 1, 1, 3, 3, Color(0.78, 0.22, 0.20, 1))
	_hline(img, sx + 1, 1, 3, Color(0.92, 0.42, 0.36, 1))
	img.set_pixel(sx + 4, 2, INK)
	# Évier (à gauche) : cuve et robinet.
	_fill(img, 2, 2, 5, top_h - 3, STEEL.darkened(0.30))
	_fill(img, 3, 3, 3, top_h - 5, STEEL.darkened(0.12))
	img.set_pixel(4, 1, STEEL.darkened(0.5))
	img.set_pixel(4, 2, STEEL.lightened(0.4))
	_outline(img, w, h)


# Geladeira blanche : dessus, deux portes, poignées, un aimant.
static func _fridge(img: Image, w: int, h: int) -> void:
	_fill(img, 0, 0, w, h, WHITE)
	_fill(img, 0, 0, w, 3, WHITE.lightened(0.5))
	_hline(img, 0, 3, w, WHITE.darkened(0.30))
	var split: int = 3 + int((h - 3) / 3)
	_hline(img, 1, split, w - 2, WHITE.darkened(0.30))
	_vline(img, w - 2, 4, h - 5, WHITE.darkened(0.14))
	_vline(img, 1, 5, split - 6, STEEL.darkened(0.35))
	_vline(img, 1, split + 2, 3, STEEL.darkened(0.35))
	img.set_pixel(mini(w - 3, 4), split + 3, Color(0.85, 0.30, 0.28, 1))
	img.set_pixel(mini(w - 3, 3), split + 5, Color(0.95, 0.78, 0.30, 1))
	_hline(img, 0, h - 1, w, WHITE.darkened(0.45))
	_outline(img, w, h)


# Vieille télé à tube sur son meuble bas, antenne en V.
static func _tv(img: Image, w: int, h: int) -> void:
	var rack_y: int = h - 4
	# Meuble.
	_fill(img, 0, rack_y, w, 4, WOOD)
	_hline(img, 0, rack_y, w, WOOD.lightened(0.22))
	_hline(img, 0, h - 1, w, WOOD.darkened(0.40))
	_vline(img, int(w / 2), rack_y + 1, 3, WOOD.darkened(0.30))
	_hline(img, 0, rack_y - 1, w, INK)
	_vline(img, 0, rack_y, 4, INK)
	_vline(img, w - 1, rack_y, 4, INK)
	# Poste.
	var tw: int = mini(w - 4, 10)
	var tx: int = int((w - tw) / 2)
	var ty: int = 2
	var th: int = rack_y - 1 - ty
	_fill(img, tx, ty, tw, th, Color(0.28, 0.24, 0.22, 1))
	_fill(img, tx + 1, ty + 1, tw - 4, th - 2, Color(0.36, 0.62, 0.74, 1))
	_fill(img, tx + 1, ty + 1, 2, 1, Color(0.80, 0.94, 0.98, 1))
	_fill(img, tx + 2, ty + th - 3, tw - 6, 1, Color(0.26, 0.48, 0.34, 1))
	img.set_pixel(tx + tw - 2, ty + 1, Color(0.85, 0.30, 0.28, 1))
	img.set_pixel(tx + tw - 2, ty + 3, STEEL)
	_hline(img, tx, ty, tw, INK)
	_vline(img, tx, ty, th, INK)
	_vline(img, tx + tw - 1, ty, th, INK)
	# Antenne.
	img.set_pixel(tx + int(tw / 2) - 1, ty - 1, INK)
	img.set_pixel(tx + int(tw / 2) - 2, ty - 2, INK)
	img.set_pixel(tx + int(tw / 2), ty - 1, INK)
	img.set_pixel(tx + int(tw / 2) + 1, ty - 2, INK)


# Petit autel : console, napperon, portrait encadré, bougie allumée, fleurs.
static func _altar(img: Image, w: int, h: int) -> void:
	var top_y: int = h - 5
	_fill(img, 0, top_y, w, 5, WOOD)
	_fill(img, 0, top_y, w, 2, WHITE)
	_hline(img, 0, top_y + 2, w, WHITE.darkened(0.25))
	_hline(img, 0, h - 1, w, WOOD.darkened(0.40))
	_hline(img, 0, top_y - 1, w, INK)
	_vline(img, 0, top_y, 5, INK)
	_vline(img, w - 1, top_y, 5, INK)
	# Portrait.
	var px: int = 1
	_fill(img, px, 0, 5, top_y, Color(0.72, 0.56, 0.24, 1))
	_fill(img, px + 1, 1, 3, top_y - 2, Color(0.88, 0.80, 0.64, 1))
	_fill(img, px + 2, 2, 1, 2, Color(0.55, 0.40, 0.30, 1))
	_hline(img, px + 1, top_y - 2, 3, Color(0.30, 0.36, 0.52, 1))
	_hline(img, px, 0, 5, INK)
	_vline(img, px, 0, top_y, INK)
	_vline(img, px + 4, 0, top_y, INK)
	# Bougie.
	if w >= 9:
		var cx: int = w - 3
		_vline(img, cx, top_y - 3, 3, WHITE.lightened(0.6))
		img.set_pixel(cx, top_y - 4, Color(1.0, 0.72, 0.24, 1))
		img.set_pixel(cx, top_y - 5, Color(1.0, 0.92, 0.60, 1))
	# Fleurs.
	if w >= 10:
		img.set_pixel(w - 5, top_y - 1, Color(0.30, 0.56, 0.34, 1))
		img.set_pixel(w - 5, top_y - 2, Color(0.92, 0.36, 0.42, 1))


# Table sous sa toile cirée à carreaux, deux tabourets, le café servi.
static func _table(img: Image, w: int, h: int, color: Color) -> void:
	var stool: int = 3 if w >= 16 else 0
	# Tabourets.
	if stool > 0:
		for sx in [0, w - stool]:
			_fill(img, sx, 3, stool, h - 6, WOOD.lightened(0.10))
			_hline(img, sx, 3, stool, WOOD.lightened(0.30))
			_hline(img, sx, h - 4, stool, WOOD.darkened(0.35))
			_hline(img, sx, 2, stool, INK)
			_hline(img, sx, h - 3, stool, INK)
			_vline(img, sx if sx == 0 else sx + stool - 1, 2, h - 4, INK)
	var tx: int = stool + 1 if stool > 0 else 0
	var tw: int = w - tx * 2
	var cloth: Color = Color(0.86, 0.26, 0.24, 1)
	_fill(img, tx, 0, tw, h - 3, WHITE)
	for y in range(1, h - 3):
		for x in range(tx + 1, tx + tw - 1):
			if (x + y) % 2 == 0 and (x % 4 < 2) == (y % 4 < 2):
				img.set_pixel(x, y, cloth)
	# Tombée de la nappe et pieds.
	_fill(img, tx, h - 3, tw, 2, WHITE.darkened(0.22))
	_fill(img, tx + 1, h - 1, 1, 1, WOOD.darkened(0.35))
	_fill(img, tx + tw - 2, h - 1, 1, 1, WOOD.darkened(0.35))
	# Garrafa de café et deux tasses.
	var mx: int = tx + int(tw / 2)
	_fill(img, mx - 1, 1, 2, 3, Color(0.22, 0.36, 0.58, 1))
	img.set_pixel(mx - 1, 1, Color(0.80, 0.82, 0.86, 1))
	img.set_pixel(mx - 4, 3, WHITE.lightened(0.6))
	img.set_pixel(mx + 3, 2, WHITE.lightened(0.6))
	_hline(img, tx, 0, tw, INK)
	_vline(img, tx, 0, h - 1, INK)
	_vline(img, tx + tw - 1, 0, h - 1, INK)
	_hline(img, tx, h - 2, tw, INK)


# Tapis tissé : bordure, liseré, losanges, franges aux deux bouts.
static func _rug(img: Image, w: int, h: int, color: Color) -> void:
	var base: Color = Color(color.r, color.g, color.b, 1)
	var dark: Color = base.darkened(0.35)
	var light: Color = Color(0.90, 0.78, 0.52, 1)
	_fill(img, 1, 0, w - 2, h, base)
	for y in range(0, h, 2):
		img.set_pixel(0, y, light)
		img.set_pixel(w - 1, y, light)
	_fill(img, 1, 0, w - 2, 1, dark)
	_fill(img, 1, h - 1, w - 2, 1, dark)
	_vline(img, 1, 0, h, dark)
	_vline(img, w - 2, 0, h, dark)
	_hline(img, 3, 2, w - 6, light)
	_hline(img, 3, h - 3, w - 6, light)
	_vline(img, 3, 2, h - 4, light)
	_vline(img, w - 4, 2, h - 4, light)
	var cy: int = int(h / 2)
	for cx in range(8, w - 7, 8):
		for d in 3:
			_hline(img, cx - (2 - d), cy - d, (2 - d) * 2 + 1, light if d == 2 else dark)
			_hline(img, cx - (2 - d), cy + d, (2 - d) * 2 + 1, light if d == 2 else dark)
	for i in int(w * h / 12):
		var gx: int = (i * 37 + 11) % (w - 4) + 2
		var gy: int = (i * 53 + 7) % (h - 2) + 1
		if img.get_pixel(gx, gy).is_equal_approx(base):
			img.set_pixel(gx, gy, base.darkened(0.08))


# ----------------------------------------------------------------- primitives

static func _box(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_fill(img, x, y, w, h, c)
	_hline(img, x, y, w, c.lightened(0.20))


static func _outline(img: Image, w: int, h: int) -> void:
	_hline(img, 0, 0, w, INK)
	_hline(img, 0, h - 1, w, INK)
	_vline(img, 0, 0, h, INK)
	_vline(img, w - 1, 0, h, INK)


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0: int = clampi(x, 0, img.get_width())
	var y0: int = clampi(y, 0, img.get_height())
	var x1: int = clampi(x + w, 0, img.get_width())
	var y1: int = clampi(y + h, 0, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	_fill(img, x, y, w, 1, c)


static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	_fill(img, x, y, 1, h, c)
