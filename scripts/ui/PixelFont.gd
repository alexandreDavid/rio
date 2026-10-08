class_name PixelFont
extends RefCounted

# Police bitmap 5×7 dessinée en code (pas de fichier de police dans le projet),
# à la densité GBA du jeu : chaque glyphe est une cellule de 11 px natifs
# (9 au-dessus de la ligne de base pour les accents + capitales, 2 en dessous
# pour les jambages). Construite UNE fois en FontFile, mise à l'échelle par
# facteurs entiers seulement (22 = ×2, 33 = ×3) : les lettres gardent le même
# grain que les personnages et les façades. Variante « contourée » : contour
# noir cuit dans le glyphe (le contour dynamique de Godot ne marche pas sur
# une police bitmap), le corps reste blanc donc teinté par font_color.
# Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste G).

const SIZE: int = 11      # hauteur de cellule = taille nominale de la police
const ASCENT: int = 9
const DESCENT: int = 2
const SPACE_ADVANCE: int = 3

# Capitales, chiffres, ponctuation : 7 rangées, ligne de base = dernière rangée.
const CAPS: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	".": ["..", "..", "..", "..", "..", "##", "##"],
	",": ["..", "..", "..", "..", "..", ".#", ".#", "#."],
	":": ["..", "..", "##", "##", "..", "##", "##"],
	";": ["..", "..", "##", "##", "..", ".#", ".#", "#."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"'": ["#", "#", ".", ".", ".", ".", "."],
	"’": ["#", "#", ".", ".", ".", ".", "."],
	"\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
	"«": [".#.#", "#.#.", ".#.#", "....", "....", "....", "...."],
	"»": ["#.#.", ".#.#", "#.#.", "....", "....", "....", "...."],
	"-": ["....", "....", "....", "####", "....", "....", "...."],
	"–": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	"—": ["......", "......", "......", "######", "......", "......", "......"],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
	"[": ["##", "#.", "#.", "#.", "#.", "#.", "##"],
	"]": ["##", ".#", ".#", ".#", ".#", ".#", "##"],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"=": ["....", "....", "####", "....", "####", "....", "...."],
	"$": ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."],
	"%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
	"&": [".##..", "#..#.", "#..#.", ".##..", "#.#.#", "#..#.", ".##.#"],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
	"<": ["...", "..#", ".#.", "#..", ".#.", "..#", "..."],
	">": ["...", "#..", ".#.", "..#", ".#.", "#..", "..."],
	"·": [".", ".", ".", "#", ".", ".", "."],
	"…": [".....", ".....", ".....", ".....", ".....", "#.#.#", "#.#.#"],
	"•": ["...", "...", ".#.", "###", ".#.", "...", "..."],
	"°": [".#.", "#.#", ".#.", "...", "...", "...", "..."],
	"º": [".#.", "#.#", ".#.", "...", "###", "...", "..."],
	"ª": [".##", "#.#", ".##", "...", "###", "...", "..."],
	"→": [".....", "..#..", "...#.", "#####", "...#.", "..#..", "....."],
	"←": [".....", "..#..", ".#...", "#####", ".#...", "..#..", "....."],
	"↓": ["..#..", "..#..", "..#..", "#.#.#", ".###.", "..#..", "....."],
	"✓": ["....#", "....#", "...#.", "#..#.", ".#.#.", "..#..", "....."],
	"✦": ["..#..", "..#..", ".###.", "#####", ".###.", "..#..", "..#.."],
	"†": ["..#..", "..#..", "#####", "..#..", "..#..", "..#..", "..#.."],
	"×": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."],
	"Æ": [".####", "#.#..", "#.#..", "####.", "#.#..", "#.#..", "#.###"],
	"Œ": [".####", "#.#..", "#.#..", "#.##.", "#.#..", "#.#..", ".####"],
}

# Minuscules : 9 rangées (0-1 = hampes et accents, 2-6 = œil, 7-8 = jambages).
const LOWER: Dictionary = {
	"a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####", ".....", "....."],
	"b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####.", ".....", "....."],
	"c": [".....", ".....", ".###.", "#....", "#....", "#...#", ".###.", ".....", "....."],
	"d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####", ".....", "....."],
	"e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".###.", ".....", "....."],
	"f": ["..##.", ".#..#", ".#...", "###..", ".#...", ".#...", ".#...", ".....", "....."],
	"g": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
	"i": [".#.", "...", "##.", ".#.", ".#.", ".#.", "###", "...", "..."],
	"ı": ["...", "...", "##.", ".#.", ".#.", ".#.", "###", "...", "..."],
	"j": ["...#", "....", "..##", "...#", "...#", "...#", "...#", "#..#", ".##."],
	"k": ["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#.", ".....", "....."],
	"l": ["##.", ".#.", ".#.", ".#.", ".#.", ".#.", "###", "...", "..."],
	"m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#...#", ".....", "....."],
	"n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
	"o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
	"p": [".....", ".....", "####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"q": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#", "....#", "....#"],
	"r": [".....", ".....", "#.##.", "##..#", "#....", "#....", "#....", ".....", "....."],
	"s": [".....", ".....", ".####", "#....", ".###.", "....#", "####.", ".....", "....."],
	"t": [".#...", ".#...", "###..", ".#...", ".#...", ".#..#", "..##.", ".....", "....."],
	"u": [".....", ".....", "#...#", "#...#", "#...#", "#..##", ".##.#", ".....", "....."],
	"v": [".....", ".....", "#...#", "#...#", "#...#", ".#.#.", "..#..", ".....", "....."],
	"w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#.", ".....", "....."],
	"x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", ".....", "....."],
	"y": [".....", ".....", "#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####", ".....", "....."],
	"ß": [".##..", "#..#.", "#.#..", "#..#.", "#...#", "#...#", "#.##.", ".....", "....."],
	"æ": [".....", ".....", ".####", "..#.#", ".####", "#.#..", ".####", ".....", "....."],
	"œ": [".....", ".....", ".#.#.", "#.#.#", "#.###", "#.#..", ".#.##", ".....", "....."],
}

# Accents : 2 rangées de 5, posées au-dessus de la lettre.
const ACCENTS: Dictionary = {
	"acute": ["...#.", "..#.."],
	"grave": [".#...", "..#.."],
	"circ": ["..#..", ".#.#."],
	"tilde": [".##.#", "#.##."],
	"diaer": [".....", ".#.#."],
	"ring": ["..#..", ".#.#."],
}
const CEDILLA: Array = ["..#..", ".##.."]

# Lettre accentuée → (base, accent). Le i/j accentués perdent leur point.
const COMPOSED: Dictionary = {
	"á": ["a", "acute"], "à": ["a", "grave"], "â": ["a", "circ"], "ã": ["a", "tilde"], "ä": ["a", "diaer"], "å": ["a", "ring"],
	"é": ["e", "acute"], "è": ["e", "grave"], "ê": ["e", "circ"], "ë": ["e", "diaer"],
	"í": ["ı", "acute"], "ì": ["ı", "grave"], "î": ["ı", "circ"], "ï": ["ı", "diaer"],
	"ó": ["o", "acute"], "ò": ["o", "grave"], "ô": ["o", "circ"], "õ": ["o", "tilde"], "ö": ["o", "diaer"],
	"ú": ["u", "acute"], "ù": ["u", "grave"], "û": ["u", "circ"], "ü": ["u", "diaer"],
	"ñ": ["n", "tilde"], "ÿ": ["y", "diaer"], "ý": ["y", "acute"],
	"Á": ["A", "acute"], "À": ["A", "grave"], "Â": ["A", "circ"], "Ã": ["A", "tilde"], "Ä": ["A", "diaer"], "Å": ["A", "ring"],
	"É": ["E", "acute"], "È": ["E", "grave"], "Ê": ["E", "circ"], "Ë": ["E", "diaer"],
	"Í": ["I", "acute"], "Ì": ["I", "grave"], "Î": ["I", "circ"], "Ï": ["I", "diaer"],
	"Ó": ["O", "acute"], "Ò": ["O", "grave"], "Ô": ["O", "circ"], "Õ": ["O", "tilde"], "Ö": ["O", "diaer"],
	"Ú": ["U", "acute"], "Ù": ["U", "grave"], "Û": ["U", "circ"], "Ü": ["U", "diaer"],
	"Ñ": ["N", "tilde"], "Ý": ["Y", "acute"],
	"ç": ["c", "cedilla"], "Ç": ["C", "cedilla"],
}

static var _fonts: Dictionary = {}


# La police à une échelle entière (1-3), contourée ou non, construite à la
# première demande. Les glyphes sont agrandis dans l'atlas (NEAREST) et la
# taille fixe suit : la police de secours (emojis) est alors servie à la
# même taille que les lettres.
static func font(scale: int = 1, outlined: bool = false) -> FontFile:
	scale = clampi(scale, 1, 3)
	var key: String = "%d_%s" % [scale, "o" if outlined else "p"]
	if not _fonts.has(key):
		_fonts[key] = _build(scale, outlined)
	return _fonts[key]


# Largeur native d'un texte (sans contour) : pour choisir une échelle entière
# qui tient dans une enseigne.
static func native_width(text: String) -> int:
	var w: int = 0
	for ch in text:
		w += _advance(ch, false)
	return w


# Applique la police à une Label du monde : échelle entière choisie d'après la
# taille demandée (7-8 px → ×1, 9-13 → ×2, 14+ → ×3) puis bornée par la largeur
# de l'étiquette quand elle en a une. Contour cuit, filtrage NEAREST, et la
# police système reste en secours pour les emojis et symboles inconnus.
static func style_world_label(label: Label, outlined: bool = true) -> void:
	var requested: int = label.get_theme_font_size("font_size")
	var scale: int = clampi(int(roundf(float(requested - 1) / 5.0)), 1, 3)
	var text_w: int = native_width(label.text)
	if label.size.x > 0.0 and text_w > 0:
		while scale > 2 and float(text_w * scale) > label.size.x + 2.0:
			scale -= 1
		# En dessous de ×2 on ne lit plus rien : l'étiquette s'élargit plutôt,
		# symétriquement, pour garder son centre (enseignes centrées).
		var need: float = float(text_w * scale) + 4.0
		if scale >= 2 and need > label.size.x and label.anchor_left == label.anchor_right:
			var grow: float = need - label.size.x
			label.position.x -= grow * 0.5
			label.size.x = need
	# Le contour est noir (cuit) : une étiquette sombre deviendrait un pâté,
	# elle reste nue (elle est posée sur une enseigne claire).
	var c: Color = label.get_theme_color("font_color")
	if c.get_luminance() < 0.35:
		outlined = false
	apply(label, scale, outlined)


# Applique la police à n'importe quelle Label, à une échelle entière donnée.
static func apply(label: Label, scale: int = 2, outlined: bool = false) -> void:
	scale = clampi(scale, 1, 3)
	label.add_theme_font_override("font", font(scale, outlined))
	label.add_theme_font_size_override("font_size", SIZE * scale)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if outlined:
		# Le contour est dans le glyphe : celui de Godot ne ferait rien.
		label.add_theme_constant_override("outline_size", 0)


# --- construction --------------------------------------------------------

static func _rows(ch: String) -> Array:
	# Rangées de la cellule complète (11), ou vide si la lettre est inconnue.
	var cell: Array = []
	for i in SIZE:
		cell.append("")
	var w: int = 0
	if CAPS.has(ch):
		var g: Array = CAPS[ch]
		w = (g[0] as String).length()
		for r in g.size():
			cell[2 + r] = g[r]
	elif LOWER.has(ch):
		var g: Array = LOWER[ch]
		w = (g[0] as String).length()
		for r in g.size():
			cell[2 + r] = g[r]
	elif COMPOSED.has(ch):
		var base: String = COMPOSED[ch][0]
		var acc: String = COMPOSED[ch][1]
		cell = _rows(base)
		w = _width_of(cell)
		if acc == "cedilla":
			cell[9] = _center(CEDILLA[0], w)
			cell[10] = _center(CEDILLA[1], w)
		else:
			var top: int = 0 if CAPS.has(base) else 2
			cell[top] = _center(ACCENTS[acc][0], w)
			cell[top + 1] = _center(ACCENTS[acc][1], w)
	else:
		return []
	for i in SIZE:
		var row: String = cell[i]
		while row.length() < w:
			row += "."
		cell[i] = row
	return cell


static func _center(pattern: String, w: int) -> String:
	if pattern.length() >= w:
		return pattern.substr(0, w)
	var pad: int = (w - pattern.length()) / 2
	var s: String = ""
	for i in pad:
		s += "."
	s += pattern
	while s.length() < w:
		s += "."
	return s


static func _width_of(cell: Array) -> int:
	var w: int = 0
	for row in cell:
		w = maxi(w, (row as String).length())
	return w


static func _advance(ch: String, outlined: bool) -> int:
	if ch == " ":
		return SPACE_ADVANCE
	var cell: Array = _rows(ch)
	if cell.is_empty():
		return 6
	return _width_of(cell) + (2 if outlined else 1)


static func _all_chars() -> Array:
	var chars: Array = []
	for k in CAPS.keys():
		chars.append(k)
	for k in LOWER.keys():
		chars.append(k)
	for k in COMPOSED.keys():
		chars.append(k)
	return chars


static func _build(scale: int, outlined: bool) -> FontFile:
	var chars: Array = _all_chars()
	var pad: int = 1 if outlined else 0
	var cell_h: int = SIZE + 2 * pad
	# Atlas : glyphes en ligne, retour à la ligne à 256 px.
	var atlas_w: int = 256
	var x: int = 0
	var y: int = 0
	var placements: Dictionary = {}
	for ch in chars:
		var cell: Array = _rows(ch)
		var w: int = _width_of(cell) + 2 * pad
		if x + w + 1 > atlas_w:
			x = 0
			y += cell_h + 1
		placements[ch] = Rect2i(x, y, w, cell_h)
		x += w + 1
	var atlas_h: int = y + cell_h + 1
	var img: Image = Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ch in chars:
		var cell: Array = _rows(ch)
		var r: Rect2i = placements[ch]
		if outlined:
			# Contour noir : 8 voisins de chaque pixel du corps.
			for ry in cell.size():
				var row: String = cell[ry]
				for rx in row.length():
					if row[rx] != "#":
						continue
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							img.set_pixel(r.position.x + pad + rx + dx, r.position.y + pad + ry + dy, Color(0, 0, 0, 1))
		for ry in cell.size():
			var row: String = cell[ry]
			for rx in row.length():
				if row[rx] == "#":
					img.set_pixel(r.position.x + pad + rx, r.position.y + pad + ry, Color(1, 1, 1, 1))

	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var px: int = SIZE * scale
	var f: FontFile = FontFile.new()
	f.fixed_size = px
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.generate_mipmaps = false
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.allow_system_fallback = true
	var size_key: Vector2i = Vector2i(px, 0)
	var k: float = float(scale)
	f.set_texture_image(0, size_key, 0, img)
	f.set_cache_ascent(0, px, float(ASCENT + pad) * k)
	f.set_cache_descent(0, px, float(DESCENT + pad) * k)
	f.set_cache_scale(0, px, 1.0)
	f.set_cache_underline_position(0, px, float(DESCENT) * k)
	f.set_cache_underline_thickness(0, px, k)
	for ch in chars:
		var code: int = ch.unicode_at(0)
		var r: Rect2i = placements[ch]
		f.set_glyph_texture_idx(0, size_key, code, 0)
		f.set_glyph_uv_rect(0, size_key, code, Rect2(Vector2(r.position) * k, Vector2(r.size) * k))
		f.set_glyph_size(0, size_key, code, Vector2(r.size) * k)
		# Décalage par rapport à la ligne de base : le haut de la cellule.
		f.set_glyph_offset(0, size_key, code, Vector2(-pad, -float(ASCENT + pad)) * k)
		f.set_glyph_advance(0, px, code, Vector2(float(_advance(ch, outlined)) * k, 0))
	# Espace : rien à dessiner, juste une avance.
	var sp: int = " ".unicode_at(0)
	f.set_glyph_texture_idx(0, size_key, sp, 0)
	f.set_glyph_uv_rect(0, size_key, sp, Rect2(0, 0, 0, 0))
	f.set_glyph_size(0, size_key, sp, Vector2.ZERO)
	f.set_glyph_offset(0, size_key, sp, Vector2.ZERO)
	f.set_glyph_advance(0, px, sp, Vector2(float(SPACE_ADVANCE) * k, 0))
	# Secours pour les emojis et les symboles non dessinés.
	var fallback: Font = ThemeDB.fallback_font
	if fallback != null:
		var arr: Array[Font] = [fallback]
		f.fallbacks = arr
	return f
