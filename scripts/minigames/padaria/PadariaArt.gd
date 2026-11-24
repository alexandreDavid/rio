extends RefCounted

# Peintres pixel de la Padaria São Sebastião (1 px natif = 3 px monde,
# NEAREST) : salle en damier, mur de faïence et lambris vert, porte sur la
# rue, tableau à la craie, four en briques, vitrine de salgados, lixo,
# objets en main, tenue du boulanger. Fonctions statiques seulement ; la
# cuisine en grille est composée par PadariaKitchenArt.

const D: int = 3
const INK: Color = Color(0.13, 0.10, 0.12)
const VIEW_L: int = -360
const VIEW_R: int = 2280
const ROOM_H: int = 1080
# Rangées natives du mur du fond : lambris vert, faïence, plinthe, puis sol.
const ROW_FAIENCE: int = 41
const ROW_PLINTH: int = 76
const ROW_FLOOR: int = 79
const DOOR_X0: int = 1734
const DOOR_X1: int = 1884

const OVEN_W: int = 96
const OVEN_H: int = 104

const FLOUR: Color = Color(0.98, 0.97, 0.93)
const STEEL: Color = Color(0.72, 0.74, 0.78)
const CHEESE: Color = Color(0.97, 0.9, 0.62)
const WATER: Color = Color(0.42, 0.68, 0.94)
const BRICK: Color = Color(0.72, 0.34, 0.22)
const RAW_BALL: Color = Color(0.96, 0.9, 0.74)

static func _img(w: int, h: int) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, blend: bool = false) -> void:
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				if blend:
					_blend(img, x, y, c)
				else:
					_dot(img, x, y, c)


static func _shadow(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_ellipse(img, cx, cy, rx, ry, Color(0.1, 0.05, 0.03, 0.3), true)


# Contour encre autour de tout ce qui est opaque (l'ombre portée s'efface
# sous le contour, comme chez les personnages).
static func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= 0.9:
				continue
			for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n: Color = img.get_pixel(nx, ny)
				if n.a >= 0.9 and n != INK:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixel(m.x, m.y, INK)


static func _text(img: Image, x: int, y: int, text: String, c: Color) -> void:
	var cx: int = x
	for ch in text:
		if ch == " ":
			cx += PixelFont.SPACE_ADVANCE
			continue
		var rows: Array = PixelFont._rows(ch)
		if rows.is_empty():
			cx += 4
			continue
		var gw: int = 0
		for r in rows.size():
			var row: String = rows[r]
			gw = maxi(gw, row.length())
			for i in row.length():
				if row[i] == "#":
					_dot(img, cx + i, y + r, c)
		cx += gw + 1


static func _hash(a: int, b: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663)
	return float(posmod(h, 1000)) / 1000.0


# Salle : lambris vert, faïence et frise d'azulejos, plinthe, damier.
static func paint_room() -> Image:
	var w: int = (VIEW_R - VIEW_L) / D
	var h: int = ROOM_H / D
	var img: Image = _img(w, h)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1565
	var green: Color = Color(0.16, 0.4, 0.31)
	_fill(img, 0, 0, w, 38, green)
	for x in range(0, w, 16):
		_fill(img, x, 2, 1, 35, green.darkened(0.18))
		_fill(img, x + 1, 2, 1, 35, green.lightened(0.08))
	_fill(img, 0, 0, w, 2, green.darkened(0.35))
	_fill(img, 0, 37, w, 1, green.darkened(0.35))
	_fill(img, 0, 38, w, 3, Color(0.93, 0.88, 0.72))
	_fill(img, 0, 40, w, 1, Color(0.7, 0.62, 0.48))
	# Faïence 6×6 : blanc cassé, joints gris-bleu, frise bleue (azulejos).
	var grout: Color = Color(0.7, 0.77, 0.8)
	var white: Color = Color(0.95, 0.96, 0.93)
	var blue: Color = Color(0.17, 0.33, 0.68)
	for y in range(ROW_FAIENCE, ROW_PLINTH):
		var ly: int = (y - ROW_FAIENCE) % 6
		var ty: int = (y - ROW_FAIENCE) / 6
		for x in w:
			var lx: int = x % 6
			var col: Color = white
			if lx == 0 or ly == 0:
				col = grout
			elif ty == 2:
				var md: int = absi(lx - 3) + absi(ly - 3)
				col = blue if md == 2 or md == 0 else Color(0.86, 0.9, 0.97)
				if (lx == 1 or lx == 5) and (ly == 1 or ly == 5):
					col = Color(0.45, 0.6, 0.85)
			elif lx == 1 and ly == 1:
				col = Color(1, 1, 1)
			img.set_pixel(x, y, col)
	_fill(img, 0, ROW_PLINTH, w, 3, Color(0.36, 0.22, 0.14))
	_fill(img, 0, ROW_PLINTH, w, 1, Color(0.5, 0.33, 0.2))
	# Damier de ladrilhos crème / rouge brique.
	var cream: Color = Color(0.89, 0.85, 0.75)
	var red: Color = Color(0.7, 0.35, 0.28)
	var tile: int = 12
	for ty in range((h - ROW_FLOOR) / tile + 1):
		for tx in range(w / tile + 1):
			var base: Color = cream if (tx + ty) % 2 == 0 else red
			var v: float = _hash(tx, ty) * 0.06 - 0.03
			base = base.lightened(v) if v > 0.0 else base.darkened(-v)
			var x0: int = tx * tile
			var y0: int = ROW_FLOOR + ty * tile
			_fill(img, x0, y0, tile, tile, base)
			_fill(img, x0, y0, tile, 1, base.darkened(0.14))
			_fill(img, x0, y0, 1, tile, base.darkened(0.14))
			_fill(img, x0 + 1, y0 + 1, tile - 2, 1, base.lightened(0.06))
	for i in w * 2:
		var x: int = rng.randi_range(0, w - 1)
		var y: int = rng.randi_range(ROW_FLOOR, h - 1)
		_blend(img, x, y, Color(0, 0, 0, 0.08))
	# Ombre de contact au pied du mur.
	for k in 4:
		for x in w:
			_blend(img, x, ROW_FLOOR + k, Color(0.08, 0.04, 0.02, 0.22 - 0.05 * float(k)))
	# Farine tombée autour du plan de travail.
	for i in 260:
		var fx: float = rng.randfn(700.0, 110.0)
		var fy: float = rng.randfn(612.0, 34.0)
		_blend(img, int((fx - VIEW_L) / D), int(fy / D), Color(1, 1, 0.97, 0.65))
	_paint_door(img)
	_paint_shelf(img, rng)
	_paint_chalkboard(img)
	return img


# Porte sur la rue : rideau de fer roulé, ciel, morro, calçadão en vagues.
static func _paint_door(img: Image) -> void:
	var x0: int = (DOOR_X0 - VIEW_L) / D
	var x1: int = (DOOR_X1 - VIEW_L) / D
	var top: int = 6
	for y in range(top, ROW_FLOOR):
		for x in range(x0, x1):
			var col: Color = Color(0.55, 0.8, 0.98).lerp(Color(0.8, 0.92, 1.0), float(y - top) / 30.0)
			var lx: int = x - x0
			var mh: float = 36.0 - 9.0 * exp(-pow((float(lx) - 30.0) / 9.0, 2.0)) - 4.0 * sin(float(lx) * 0.2)
			if float(y) > mh:
				col = Color(0.3, 0.55, 0.32)
			if y >= 44:
				col = Color(0.42, 0.42, 0.45)  # rua
			if y >= 54:
				var k: int = y - 54 + int(round(2.0 * sin(float(lx) * TAU / 16.0)))
				col = Color(0.16, 0.16, 0.18) if posmod(k, 7) < 3 else Color(0.95, 0.93, 0.86)
			img.set_pixel(x, y, col)
	# Rideau de fer roulé, montants, seuil.
	_fill(img, x0, top, x1 - x0, 6, Color(0.6, 0.62, 0.66))
	for y in range(top, top + 6, 2):
		_fill(img, x0, y, x1 - x0, 1, Color(0.44, 0.46, 0.5))
	_fill(img, x0 - 3, top - 1, 3, ROW_FLOOR - top + 1, Color(0.36, 0.22, 0.14))
	_fill(img, x1, top - 1, 3, ROW_FLOOR - top + 1, Color(0.36, 0.22, 0.14))
	_fill(img, x0 - 3, top - 2, x1 - x0 + 6, 1, INK)
	_fill(img, x0 - 3, ROW_FLOOR - 1, x1 - x0 + 6, 3, Color(0.75, 0.73, 0.68))


# Étagère de faïence : guaraná, goiabada, biscoitos de polvilho.
static func _paint_shelf(img: Image, rng: RandomNumberGenerator) -> void:
	var y: int = 70
	var x0: int = (-300 - VIEW_L) / D
	var x1: int = (1200 - VIEW_L) / D
	_fill(img, x0, y, x1 - x0, 2, Color(0.55, 0.36, 0.2))
	_fill(img, x0, y + 2, x1 - x0, 1, Color(0.3, 0.18, 0.1))
	var x: int = x0 + 3
	while x < x1 - 8:
		var kind: int = rng.randi() % 4
		match kind:
			0:  # latas de guaraná
				for k in 3:
					_fill(img, x + k * 3, y - 5, 2, 5, Color(0.2, 0.6, 0.25))
					_dot(img, x + k * 3, y - 5, Color(0.85, 0.85, 0.85))
				x += 10
			1:  # pote de goiabada
				_fill(img, x, y - 6, 5, 6, Color(0.75, 0.2, 0.25))
				_fill(img, x, y - 7, 5, 1, Color(0.95, 0.8, 0.3))
				x += 7
			2:  # saco de biscoito de polvilho
				_fill(img, x, y - 8, 5, 8, Color(0.97, 0.97, 0.95))
				_fill(img, x + 1, y - 5, 3, 2, Color(0.9, 0.3, 0.3))
				x += 7
			_:  # pão francês empilhado
				for k in 3:
					_ellipse(img, float(x) + 3.0 + float(k) * 4.0, float(y) - 2.0, 2.5, 1.6, Color(0.9, 0.62, 0.3))
					_dot(img, x + 3 + k * 4, y - 3, Color(0.98, 0.85, 0.55))
				x += 14
		x += rng.randi_range(2, 6)


# Tableau à la craie des prix (texte cuit en pixels natifs).
static func _paint_chalkboard(img: Image) -> void:
	var x0: int = (1236 - VIEW_L) / D
	var bw: int = 116
	var y0: int = 43
	var bh: int = 31
	_fill(img, x0 - 1, y0 - 1, bw + 2, bh + 2, INK)
	_fill(img, x0, y0, bw, bh, Color(0.55, 0.36, 0.2))
	_fill(img, x0 + 2, y0 + 2, bw - 4, bh - 4, Color(0.14, 0.21, 0.18))
	var chalk: Color = Color(0.94, 0.94, 0.88)
	var l1: String = "PÃO DE QUEIJO 1,50"
	var l2: String = "CAFEZINHO 3,00"
	_text(img, x0 + (bw - PixelFont.native_width(l1)) / 2, y0 + 2, l1, chalk)
	_text(img, x0 + (bw - PixelFont.native_width(l2)) / 2, y0 + 15, l2, Color(1, 0.88, 0.5))
	_fill(img, x0 + 6, y0 + 14, bw - 12, 1, Color(0.4, 0.46, 0.43))


# Four à pain : dôme et façade en briques, gueule voûtée, cheminée, socle.
static func paint_oven() -> Image:
	var img: Image = _img(OVEN_W, OVEN_H)
	_shadow(img, 48, 101, 47, 3)
	var mortar: Color = Color(0.56, 0.45, 0.38)
	var cx: float = 48.0
	for y in range(8, 90):
		for x in range(3, 93):
			var inside: bool = y >= 24
			if y < 24:
				var dy: float = (24.0 - float(y)) / 16.0
				inside = absf(float(x) + 0.5 - cx) <= 45.0 * sqrt(maxf(0.0, 1.0 - dy * dy))
			if not inside:
				continue
			var row: int = y / 4
			var off: int = (row % 2) * 4
			var c: Color = mortar
			if y % 4 != 3 and (x + off) % 8 != 7:
				var hsh: float = _hash((x + off) / 8, row)
				c = BRICK if hsh < 0.5 else (BRICK.darkened(0.12) if hsh < 0.8 else BRICK.lightened(0.1))
				# Lumière en haut à gauche sur le dôme.
				if y < 24 and float(x) < cx:
					c = c.lightened(0.12)
				if x > 84:
					c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	# Gueule : voûte en claveaux clairs, intérieur sombre, sole.
	for y in range(42, 76):
		for x in range(18, 78):
			var dx: float = float(x) + 0.5 - cx
			var r_in: float = 25.0
			var mouth: bool = false
			var ring: bool = false
			if y >= 58:
				mouth = absf(dx) <= r_in and y < 74
				ring = not mouth and absf(dx) <= r_in + 3.0 and y < 74
			else:
				var e: float = pow(dx / r_in, 2.0) + pow((58.0 - float(y)) / 12.0, 2.0)
				var e2: float = pow(dx / (r_in + 3.0), 2.0) + pow((58.0 - float(y)) / 15.0, 2.0)
				mouth = e <= 1.0
				ring = not mouth and e2 <= 1.0
			if mouth:
				var k: float = clampf(float(y - 46) / 28.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.12, 0.06, 0.05).lerp(Color(0.3, 0.13, 0.07), k))
			elif ring:
				var joint: bool = int(absf(dx) + float(y)) % 5 == 0
				img.set_pixel(x, y, Color(0.6, 0.45, 0.36) if joint else Color(0.86, 0.55, 0.38))
	_fill(img, 20, 74, 56, 3, Color(0.72, 0.7, 0.66))
	_fill(img, 20, 74, 56, 1, Color(0.85, 0.83, 0.78))
	# Socle en pierre.
	var stone: Color = Color(0.62, 0.6, 0.56)
	for y in range(89, 100):
		for x in range(1, 95):
			var c: Color = stone
			if y == 89:
				c = stone.lightened(0.2)
			elif (y - 90) % 5 == 4 or (x + ((y - 90) / 5) * 7) % 14 == 0:
				c = stone.darkened(0.2)
			img.set_pixel(x, y, c)
	# Cheminée en tôle.
	_fill(img, 66, 2, 9, 14, Color(0.32, 0.32, 0.35))
	_fill(img, 66, 2, 2, 14, Color(0.48, 0.48, 0.52))
	_fill(img, 65, 0, 11, 3, Color(0.25, 0.25, 0.28))
	_fill(img, 66, 8, 9, 1, Color(0.22, 0.22, 0.25))
	_outline(img)
	return img


# Vitrine de salgados : pão de queijo, coxinhas, pão francês sous verre.
static func paint_vitrine() -> Image:
	var img: Image = _img(110, 62)
	_shadow(img, 55, 59, 54, 2)
	var frame: Color = Color(0.78, 0.8, 0.84)
	_fill(img, 1, 1, 108, 36, frame)
	_fill(img, 3, 3, 104, 31, Color(0.95, 0.93, 0.86))
	for dx: int in [37, 72]:
		_fill(img, dx, 3, 2, 31, frame.darkened(0.15))
	# Pão de queijo.
	for j in 4:
		for i in 5:
			var cx: int = 6 + i * 6 + (j % 2) * 2
			var cy: int = 7 + j * 6
			_ellipse(img, cx + 0.5, cy + 0.5, 2.6, 2.4, Color(0.93, 0.7, 0.33))
			_dot(img, cx - 1, cy - 1, Color(1, 0.9, 0.6))
	# Coxinhas (gouttes dorées).
	for j in 3:
		for i in 4:
			var x0: int = 42 + i * 7 + (j % 2) * 3
			var y0: int = 6 + j * 9
			var rows: Array[int] = [0, 1, 1, 2, 2, 2]
			for r in rows.size():
				_fill(img, x0 + 2 - rows[r], y0 + r, rows[r] * 2 + 1, 1, Color(0.82, 0.48, 0.2))
			_dot(img, x0 + 2, y0, Color(0.95, 0.7, 0.35))
			_dot(img, x0 + 1, y0 + 3, Color(0.95, 0.68, 0.36))
	# Pães franceses.
	for j in 4:
		for i in 3:
			var cx2: int = 80 + i * 9 + (j % 2) * 2
			var cy2: int = 7 + j * 7
			_ellipse(img, cx2 + 0.5, cy2 + 0.5, 4.2, 2.4, Color(0.88, 0.6, 0.28))
			_fill(img, cx2 - 2, cy2, 4, 1, Color(0.98, 0.86, 0.6))
	# Étiquettes de prix.
	for tx: int in [16, 52, 88]:
		_fill(img, tx, 30, 7, 3, Color(1, 1, 1))
		_fill(img, tx + 1, 31, 5, 1, Color(0.8, 0.2, 0.18))
	# Verre : teinte froide et reflets en diagonale.
	for y in range(3, 34):
		for x in range(3, 107):
			_blend(img, x, y, Color(0.7, 0.88, 1.0, 0.16))
			var dg: int = posmod(x - y * 2, 46)
			if dg < 2 or dg == 5:
				_blend(img, x, y, Color(1, 1, 1, 0.45))
	_fill(img, 1, 34, 108, 3, frame.darkened(0.1))
	_fill(img, 1, 34, 108, 1, Color(1, 1, 1))
	# Façade émaillée, bande rouge, enseigne.
	var enamel: Color = Color(0.95, 0.94, 0.89)
	_fill(img, 1, 37, 108, 21, enamel)
	_fill(img, 1, 52, 108, 3, Color(0.8, 0.15, 0.15))
	_fill(img, 106, 37, 3, 21, enamel.darkened(0.14))
	var label: String = "SALGADOS"
	_text(img, (110 - PixelFont.native_width(label)) / 2, 38, label, Color(0.75, 0.13, 0.13))
	_fill(img, 1, 58, 108, 2, Color(0.25, 0.25, 0.28))
	_outline(img)
	return img


# Lixeira à pédale en inox.
static func paint_trash() -> Image:
	var img: Image = _img(28, 38)
	_shadow(img, 14, 35, 13, 2)
	for y in range(8, 33):
		for x in range(3, 25):
			var c: Color = STEEL
			if x % 4 == 0:
				c = STEEL.darkened(0.12)
			if x <= 4:
				c = STEEL.darkened(0.22)
			elif x >= 22:
				c = STEEL.lightened(0.18)
			_dot(img, x, y, c)
	_fill(img, 3, 8, 22, 1, STEEL.darkened(0.3))
	_ellipse(img, 14, 6.5, 12, 4, STEEL.lightened(0.12))
	_ellipse(img, 13, 5.5, 7, 2, STEEL.lightened(0.3))
	_fill(img, 12, 2, 4, 2, Color(0.35, 0.35, 0.4))
	_fill(img, 9, 33, 10, 2, Color(0.3, 0.3, 0.34))
	_fill(img, 10, 18, 8, 6, Color(0.3, 0.65, 0.35))
	_fill(img, 12, 20, 4, 2, Color(0.95, 0.95, 0.9))
	_outline(img)
	return img


static func ball_color(step: int) -> Color:
	match step:
		1:
			return Color(0.97, 0.8, 0.46)
		2:
			return Color(0.93, 0.68, 0.32)
		3:
			return Color(0.86, 0.57, 0.24)
		4:
			return Color(0.66, 0.4, 0.2)
		5:
			return Color(0.48, 0.28, 0.15)
		6:
			return Color(0.2, 0.15, 0.13)
	return RAW_BALL


# Ce que le boulanger tient en main : bol de farine, pichet d'eau, part de queijo.
static func paint_hand_item(kind: String) -> Image:
	var img: Image = _img(16, 14)
	match kind:
		"flour":
			_ellipse(img, 8, 9, 6.5, 4, Color(0.75, 0.55, 0.32))
			_fill(img, 2, 7, 13, 2, Color(0.75, 0.55, 0.32))
			_ellipse(img, 8, 6.5, 5.5, 2.6, FLOUR)
			_ellipse(img, 7, 5.5, 2.5, 1.3, Color(1, 1, 1))
		"water":
			_fill(img, 4, 3, 8, 9, WATER)
			_fill(img, 4, 3, 8, 2, WATER.lightened(0.35))
			_fill(img, 5, 5, 1, 6, Color(0.85, 0.94, 1))
			_fill(img, 12, 5, 2, 4, Color(0.3, 0.5, 0.8))
			_fill(img, 3, 2, 3, 1, WATER.darkened(0.2))
		"queijo":
			for j in 7:
				_fill(img, 3, 4 + j, 3 + j + (j / 2), 1, CHEESE if j < 5 else CHEESE.darkened(0.15))
			_fill(img, 3, 10, 11, 1, Color(0.85, 0.7, 0.35))
			_dot(img, 5, 6, Color(1, 0.97, 0.8))
	_outline(img)
	return img


# Planche du joueur en tenue de boulanger : toque et tablier peints en
# surcouche native sur la planche de l'usine (même grain, même contour).
static func baker_sheet(cfg: Dictionary) -> ImageTexture:
	var src: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var sheet: Image = src.duplicate() as Image
	var nw: int = CharacterSpriteFactory.NAT_W
	var nh: int = CharacterSpriteFactory.NAT_H
	var sc: int = CharacterSpriteFactory.SCALE
	for dir in CharacterSpriteFactory.ROWS:
		for frame in CharacterSpriteFactory.COLS:
			var ox: int = frame * CharacterSpriteFactory.CELL_W
			var oy: int = dir * CharacterSpriteFactory.CELL_H
			var n: Image = _img(nw, nh)
			for y in nh:
				for x in nw:
					n.set_pixel(x, y, src.get_pixel(ox + x * sc + 1, oy + y * sc + 1))
			var over: Image = _img(nw, nh)
			_baker_overlay(over, dir, frame)
			for y in nh:
				for x in nw:
					var c: Color = over.get_pixel(x, y)
					if c.a > 0.0:
						n.set_pixel(x, y, c)
			# Contour du blanc là où il dépasse de la silhouette.
			for y in nh:
				for x in nw:
					if n.get_pixel(x, y).a > 0.01:
						continue
					for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var px: int = x + v.x
						var py: int = y + v.y
						if px >= 0 and py >= 0 and px < nw and py < nh and over.get_pixel(px, py).a > 0.0:
							n.set_pixel(x, y, CharacterSpriteFactory.LINE_COLOR)
							break
			for y in nh:
				for x in nw:
					sheet.fill_rect(Rect2i(ox + x * sc, oy + y * sc, sc, sc), n.get_pixel(x, y))
	return ImageTexture.create_from_image(sheet)


static func _baker_overlay(n: Image, dir: int, frame: int) -> void:
	var cloth: Color = Color(0.98, 0.98, 0.96)
	var sh: Color = Color(0.82, 0.83, 0.86)
	# Toque : bandeau sur le front, champignon bouffant au-dessus.
	var x0: int = 5 if dir != CharacterSpriteFactory.DIR_RIGHT else 6
	var x1: int = 15 if dir != CharacterSpriteFactory.DIR_RIGHT else 14
	_fill(n, x0 + 1, 0, x1 - x0 - 1, 1, cloth)
	_fill(n, x0, 1, x1 - x0 + 1, 3, cloth)
	_fill(n, x0, 3, x1 - x0 + 1, 1, sh)
	_fill(n, x0 + 1, 4, x1 - x0 - 1, 2, cloth)
	_fill(n, x0 + 1, 5, x1 - x0 - 1, 1, sh)
	_dot(n, x0 + 2, 1, Color(1, 1, 1))
	# Tablier.
	if dir == CharacterSpriteFactory.DIR_DOWN:
		_fill(n, 8, 16, 5, 3, cloth)
		_fill(n, 7, 19, 7, 7, cloth)
		_fill(n, 7, 25, 7, 1, sh)
		_fill(n, 13, 19, 1, 7, sh)
		_fill(n, 9, 21, 3, 2, Color(0.88, 0.88, 0.9))
	elif dir == CharacterSpriteFactory.DIR_UP:
		_fill(n, 6, 20, 9, 1, cloth)
		_dot(n, 10, 21, cloth)
		_dot(n, 9, 22, cloth)
		_dot(n, 11, 22, cloth)
	else:
		var sway: int = 1 if frame == 1 else 0
		_fill(n, 12, 17, 2, 3, cloth)
		_fill(n, 12 + sway, 20, 3, 6, cloth)
		_fill(n, 12 + sway, 25, 3, 1, sh)
		_fill(n, 7, 20, 5, 1, cloth)
