extends RefCounted

# Peintures pixel de la Regata da Glória (1 px natif = 3 px monde, comme
# GroundPainter et les personnages) : coques vues de dessus, côte de l'Aterro
# (quai, calçadão, gazon), pontons, et petits outils de dessin « à la cellule »
# pour ce qui bouge (voiles, bouées, risées, girouette).

const D: float = 3.0
const OUTLINE: Color = Color(0.07, 0.11, 0.17, 1)
const WOOD: Color = Color(0.82, 0.66, 0.42, 1)
const GRASS: Color = Color(0.34, 0.6, 0.28, 1)
const STONE: Color = Color(0.66, 0.63, 0.58, 1)
# Côte : le quai de l'Aterro borde le sud (y ≥ SHORE_Y) et l'ouest (x ≤ WEST_X).
const SHORE_Y: float = 441.0
const WEST_X: float = -930.0

# --- Cellules ---

static func cell(ci: CanvasItem, p: Vector2, col: Color, n: float = 1.0) -> void:
	ci.draw_rect(Rect2((p / D).floor() * D, Vector2(D, D) * n), col)

# Disque de cellules calé sur la grille : base, reflet haut-gauche, ombre
# bas-droite, contour sombre.
static func disc(ci: CanvasItem, c: Vector2, r: int, base: Color, alpha: float = 1.0) -> void:
	var o: Vector2 = (c / D).floor() * D
	var light: Color = base.lightened(0.3)
	var shade: Color = base.darkened(0.25)
	var line: Color = OUTLINE
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var d2: int = i * i + j * j
			if d2 > r * r:
				continue
			var col: Color = base
			if d2 > (r - 1) * (r - 1):
				col = line
			elif i + j < -r / 2 and d2 < (r - 1) * (r - 1) - 1:
				col = light
			elif i + j > r / 2:
				col = shade
			col.a *= alpha
			ci.draw_rect(Rect2(o + Vector2(i, j) * D, Vector2(D, D)), col)

# --- Coques ---

# Coque vue de dessus, étrave vers +x : liston sombre, bordé coloré, filet,
# pont en lattes, cockpit, emplanture du mât. `furled` = voile ferlée sur la
# bôme (bateau au mouillage).
static func hull_texture(length: int, beam: int, hull: Color, stripe: Color, furled: bool = false) -> ImageTexture:
	var img: Image = Image.create(length, beam, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half: float = float(beam) * 0.5
	var bow_start: int = int(float(length) * 0.52)
	for x in length:
		var hw: float = half
		if x >= bow_start:
			var t: float = (float(x) + 0.5 - float(bow_start)) / float(length - bow_start)
			hw = half * sqrt(maxf(0.0, 1.0 - t * t))
		elif x == 0:
			hw = half - 1.0
		for y in beam:
			if absf(float(y) + 0.5 - half) <= hw:
				img.set_pixel(x, y, WOOD)
	# Anneaux depuis le bord : 0 = liston, 1 = bordé, 2 = filet.
	var ring: Array = []
	for x in length:
		var col: Array = []
		for y in beam:
			col.append(-1 if img.get_pixel(x, y).a == 0.0 else 99)
		ring.append(col)
	for pass_i in 3:
		for x in length:
			for y in beam:
				if ring[x][y] != 99:
					continue
				var edge: bool = false
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + v.x
					var ny: int = y + v.y
					if nx < 0 or ny < 0 or nx >= length or ny >= beam:
						edge = true
					elif ring[nx][ny] == -1 or (ring[nx][ny] < pass_i and ring[nx][ny] != 99):
						edge = true
				if edge:
					ring[x][y] = pass_i
	var cock_end: int = int(float(length) * 0.46)
	var mast_x: int = int(float(length) * 0.64)
	for x in length:
		for y in beam:
			var r: int = ring[x][y]
			if r == -1:
				continue
			var col: Color = WOOD
			var upper: bool = float(y) + 0.5 < half
			if r == 0:
				col = OUTLINE
			elif r == 1:
				col = hull.lightened(0.18) if upper else hull.darkened(0.12)
			elif r == 2:
				col = stripe
			elif x >= 2 and x <= cock_end:
				# Cockpit : plancher plus sombre, banc clair le long des bords.
				col = WOOD.darkened(0.32)
				if ring[x][y - 1] == 2 or ring[x][y + 1] == 2:
					col = WOOD.lightened(0.08)
			elif y % 2 == 0:
				col = WOOD.darkened(0.1)
			img.set_pixel(x, y, col)
	if furled:
		var cy: int = int(half)
		for x in range(3, mast_x + 1):
			img.set_pixel(x, cy, Color(0.95, 0.94, 0.88))
			img.set_pixel(x, cy - 1, Color(0.82, 0.8, 0.74))
	img.set_pixel(mast_x, int(half), OUTLINE)
	img.set_pixel(mast_x, int(half) - 1, Color(0.85, 0.85, 0.82))
	return ImageTexture.create_from_image(img)

# Sprite NEAREST ×3 (pixels natifs nets) centré.
static func sprite(tex: Texture2D) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(D, D)
	return s

# --- Côte de l'Aterro ---

# Profondeur (en px natifs) depuis la mer, quai sud et quai ouest confondus ;
# négatif = eau. (La terre est l'union des deux bandes : max.)
static func _depth(wx: float, wy: float) -> int:
	return int(floor(maxf(wy - SHORE_Y, WEST_X - wx) / D))

# Peint la terre ferme sur `rect` (monde) : liseré clair du quai, blocs de
# granit, calçadão en vagues noir/blanc, bordure, gazon de l'Aterro.
static func shore_texture(rect: Rect2, seed: int = 7) -> ImageTexture:
	var w: int = int(rect.size.x / D)
	var h: int = int(rect.size.y / D)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var stone_l: Color = STONE.lightened(0.25)
	var stone_s: Color = STONE.darkened(0.18)
	var stone_d: Color = STONE.darkened(0.45)
	var pave_w: Color = Color(0.95, 0.93, 0.86)
	var pave_b: Color = Color(0.16, 0.16, 0.18)
	var g_dark: Color = GRASS.darkened(0.22)
	var g_light: Color = GRASS.lightened(0.14)
	for py in h:
		for px in w:
			var wx: float = rect.position.x + (float(px) + 0.5) * D
			var wy: float = rect.position.y + (float(py) + 0.5) * D
			var d: int = _depth(wx, wy)
			if d < 0:
				continue
			# Coordonnée le long de la côte : x au sud, y à l'ouest.
			var south: bool = (wy - SHORE_Y) >= (WEST_X - wx)
			var a: int = px if south else py
			var col: Color
			if d == 0:
				col = stone_l
			elif d <= 4:
				var joint: bool = (a + (5 if (d - 1) / 2 % 2 == 1 else 0)) % 10 == 0 or d == 3
				col = stone_s if joint else STONE
				if d == 4:
					col = stone_d
			elif d <= 13:
				var k: int = d - 6 + int(round(2.0 * sin(float(a) * TAU / 18.0)))
				col = pave_b if posmod(k, 8) < 3 else pave_w
			elif d == 14:
				col = stone_l
			else:
				col = GRASS
				var roll: float = rng.randf()
				if roll < 0.08:
					col = g_dark
				elif roll < 0.13:
					col = g_light
			img.set_pixel(px, py, col)
	# Touffes : petit V clair sur le gazon.
	for i in w * h / 60:
		var x: int = rng.randi_range(1, w - 2)
		var y: int = rng.randi_range(1, h - 1)
		var wx2: float = rect.position.x + (float(x) + 0.5) * D
		var wy2: float = rect.position.y + (float(y) + 0.5) * D
		if _depth(wx2, wy2) > 16:
			img.set_pixel(x, y, g_dark)
			img.set_pixel(x - 1, y - 1, g_light)
			img.set_pixel(x + 1, y - 1, g_light)
	return ImageTexture.create_from_image(img)

# Ponton en lattes, `cells` natifs de long vers la mer (−y depuis le quai).
static func pontoon_texture(width: int, length: int) -> ImageTexture:
	var img: Image = Image.create(width, length, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var plank: Color = Color(0.66, 0.48, 0.3)
	for y in length:
		for x in width:
			var col: Color = plank
			if x == 0 or x == width - 1:
				col = plank.darkened(0.35)
			elif y % 3 == 2:
				col = plank.darkened(0.2)
			elif x == 1:
				col = plank.lightened(0.15)
			if (y == 0 or y == length / 2) and (x == 0 or x == width - 1):
				col = OUTLINE  # pieux
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
