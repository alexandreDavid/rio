class_name PokemonSpriteFactory

# Génère des sprites pixel-art procéduraux pour les personnages décoratifs.
# Chaque sprite est une feuille 3 directions × 3 frames (16×24 px / cellule),
# composée à partir d'un Dictionary de config :
#
#   {
#     "skin": Color,          # teint de peau (3 options dans la palette)
#     "hair_color": Color,    # couleur des cheveux
#     "hair_style": String,   # "short", "medium", "long", "bun", "spiky", "bald"
#     "shirt_color": Color,
#     "shirt_pattern": String,# "solid", "stripe_h", "pocket"
#     "pants_color": Color,
#     "hat_style": String,    # "none", "cap", "fedora", "beret", "scarf"
#     "hat_color": Color,
#   }
#
# Une factory statique pour que tous les wanderers partagent un cache global
# de textures (clé = hash du config) — typiquement les 109 wanderers du jeu
# génèrent 30-50 textures uniques tout au plus.

# --- Palettes ---

const PALETTE_SKIN: Array[Color] = [
	Color(0.95, 0.82, 0.68, 1.0),   # clair (européen)
	Color(0.86, 0.70, 0.55, 1.0),   # médium-clair (latino)
	Color(0.65, 0.48, 0.32, 1.0),   # médium (mulato)
	Color(0.42, 0.28, 0.18, 1.0),   # foncé (afro-brésilien)
]

const PALETTE_HAIR_COLOR: Array[Color] = [
	Color(0.10, 0.08, 0.06, 1.0),   # noir
	Color(0.32, 0.20, 0.12, 1.0),   # brun foncé
	Color(0.55, 0.38, 0.22, 1.0),   # brun
	Color(0.85, 0.70, 0.42, 1.0),   # blond
	Color(0.78, 0.32, 0.12, 1.0),   # roux
	Color(0.65, 0.62, 0.58, 1.0),   # gris (âge)
]

const PALETTE_HAIR_STYLE: Array[String] = [
	"short", "medium", "long", "bun", "spiky", "bald",
]

const PALETTE_SHIRT_COLOR: Array[Color] = [
	Color(0.85, 0.55, 0.40, 1.0),   # rouge brique
	Color(0.40, 0.65, 0.95, 1.0),   # bleu ciel
	Color(0.55, 0.78, 0.55, 1.0),   # vert
	Color(0.95, 0.85, 0.40, 1.0),   # jaune
	Color(0.85, 0.78, 0.62, 1.0),   # beige
	Color(0.62, 0.42, 0.32, 1.0),   # marron
	Color(0.78, 0.42, 0.55, 1.0),   # rose
	Color(0.95, 0.95, 0.92, 1.0),   # blanc
	Color(0.22, 0.22, 0.28, 1.0),   # noir/sombre
]

const PALETTE_SHIRT_PATTERN: Array[String] = [
	"solid", "solid", "solid",   # solid plus probable (pondération naturelle)
	"stripe_h", "pocket",
]

const PALETTE_HAT_STYLE: Array[String] = [
	"none", "none", "none", "none",   # pas de chapeau dans la majorité
	"cap", "fedora", "beret", "scarf",
]

const PALETTE_HAT_COLOR: Array[Color] = [
	Color(0.18, 0.18, 0.22, 1.0),   # noir
	Color(0.42, 0.32, 0.22, 1.0),   # marron
	Color(0.92, 0.85, 0.55, 1.0),   # paille
	Color(0.85, 0.32, 0.32, 1.0),   # rouge
	Color(0.95, 0.95, 0.92, 1.0),   # blanc
]

const PALETTE_PANTS_COLOR: Array[Color] = [
	Color(0.30, 0.25, 0.20, 1.0),   # marron foncé
	Color(0.22, 0.30, 0.45, 1.0),   # bleu jean
	Color(0.18, 0.18, 0.22, 1.0),   # noir
	Color(0.50, 0.45, 0.40, 1.0),   # gris
	Color(0.85, 0.78, 0.62, 1.0),   # beige (short clair)
]

# --- Format sheet ---

const CELL_W: int = 16
const CELL_H: int = 24
const DIR_DOWN: int = 0
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const ROWS: int = 3
const COLS: int = 3   # idle, stepL, stepR

# Cache global ImageTexture par config-hash.
static var _cache: Dictionary = {}

# Tire une config aléatoire reproductible à partir d'une seed (typiquement
# `node.name.hash()` pour stabilité entre runs). Garantit que le même NPC
# garde la même apparence si on relance le jeu, sans avoir à sérialiser.
static func random_config(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"skin": _pick(rng, PALETTE_SKIN),
		"hair_color": _pick(rng, PALETTE_HAIR_COLOR),
		"hair_style": _pick(rng, PALETTE_HAIR_STYLE),
		"shirt_color": _pick(rng, PALETTE_SHIRT_COLOR),
		"shirt_pattern": _pick(rng, PALETTE_SHIRT_PATTERN),
		"pants_color": _pick(rng, PALETTE_PANTS_COLOR),
		"hat_style": _pick(rng, PALETTE_HAT_STYLE),
		"hat_color": _pick(rng, PALETTE_HAT_COLOR),
	}

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]

# Construit (ou récupère du cache) une feuille 3×3 pour la config donnée.
static func build_sheet(config: Dictionary) -> ImageTexture:
	var key: int = _config_hash(config)
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(CELL_W * COLS, CELL_H * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for dir in ROWS:
		for frame in COLS:
			_draw_cell(img, frame * CELL_W, dir * CELL_H, dir, frame, config)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _config_hash(config: Dictionary) -> int:
	# Concat texte stable + hash. Suffisant pour ~30-50 combos uniques.
	var parts: Array = []
	for k in ["skin", "hair_color", "hair_style", "shirt_color",
			"shirt_pattern", "pants_color", "hat_style", "hat_color"]:
		parts.append(str(config.get(k, "")))
	return "|".join(parts).hash()

# Dessine une cellule 16×24 à l'offset (ox, oy) pour la direction `dir` et
# le frame de marche `frame` (0=idle, 1=stepL, 2=stepR).
static func _draw_cell(img: Image, ox: int, oy: int, dir: int, frame: int, c: Dictionary) -> void:
	var skin: Color = c.get("skin", Color(0.92, 0.78, 0.62))
	var hair_color: Color = c.get("hair_color", Color(0.18, 0.12, 0.08))
	var hair_style: String = c.get("hair_style", "short")
	var shirt_color: Color = c.get("shirt_color", Color(0.85, 0.55, 0.4))
	var shirt_pattern: String = c.get("shirt_pattern", "solid")
	var pants_color: Color = c.get("pants_color", Color(0.30, 0.25, 0.20))
	var hat_style: String = c.get("hat_style", "none")
	var hat_color: Color = c.get("hat_color", Color(0.18, 0.18, 0.22))
	var outline: Color = Color(0.06, 0.05, 0.08, 1.0)
	var face_visible: bool = (dir != DIR_UP)

	# Cheveux (au-dessus + autour de la tête selon hair_style).
	_draw_hair(img, ox, oy, dir, hair_style, hair_color)
	# Tête (rows 4-9). Vue de dos = couvert tout entier de cheveux.
	var head_main: Color = skin if face_visible else hair_color
	_fill_rect(img, ox + 2, oy + 4, 12, 6, head_main)
	# Frange / contour cheveux côté visage (DOWN ou RIGHT).
	if face_visible and hair_style != "bald":
		_fill_rect(img, ox + 2, oy + 4, 1, 2, hair_color)
		_fill_rect(img, ox + 13, oy + 4, 1, 2, hair_color)
		_fill_rect(img, ox + 2, oy + 4, 12, 1, hair_color)
	# Yeux.
	if dir == DIR_DOWN:
		img.set_pixel(ox + 5, oy + 7, outline)
		img.set_pixel(ox + 10, oy + 7, outline)
	elif dir == DIR_RIGHT:
		img.set_pixel(ox + 10, oy + 7, outline)
	# Cou.
	if face_visible:
		_fill_rect(img, ox + 6, oy + 9, 4, 1, skin)

	# Corps (rows 10-17).
	_fill_rect(img, ox + 3, oy + 10, 10, 8, shirt_color)
	# Motif du shirt.
	_draw_shirt_pattern(img, ox, oy, shirt_pattern, shirt_color)
	# Bras (côtés du corps).
	var arm_color: Color = shirt_color.darkened(0.15)
	_fill_rect(img, ox + 1, oy + 10, 2, 5, arm_color)
	_fill_rect(img, ox + 13, oy + 10, 2, 5, arm_color)
	# Mains (skin tone).
	_fill_rect(img, ox + 1, oy + 14, 2, 1, skin)
	_fill_rect(img, ox + 13, oy + 14, 2, 1, skin)

	# Jambes (rows 18-23) avec décalage de marche.
	var l_off: int = 0
	var r_off: int = 0
	if frame == 1:
		l_off = -1
	elif frame == 2:
		r_off = -1
	_fill_rect(img, ox + 4, oy + 18 + l_off, 3, 6 - l_off, pants_color)
	_fill_rect(img, ox + 9, oy + 18 + r_off, 3, 6 - r_off, pants_color)

	# Chapeau optionnel (couvre les cheveux du sommet).
	_draw_hat(img, ox, oy, dir, hat_style, hat_color)

	# Contour bas (ombre fine).
	_fill_rect(img, ox + 4, oy + 23, 8, 1, outline)

# --- Helpers de dessin ---

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
				img.set_pixel(xx, yy, c)

static func _draw_hair(img: Image, ox: int, oy: int, _dir: int, style: String, c: Color) -> void:
	match style:
		"bald":
			pass
		"short":
			# Calotte courte 4 rangs.
			_fill_rect(img, ox + 4, oy + 0, 8, 1, c)
			_fill_rect(img, ox + 3, oy + 1, 10, 1, c)
			_fill_rect(img, ox + 2, oy + 2, 12, 2, c)
		"medium":
			# Comme short + descend sur les côtés du visage (rows 4-7).
			_fill_rect(img, ox + 4, oy + 0, 8, 1, c)
			_fill_rect(img, ox + 3, oy + 1, 10, 1, c)
			_fill_rect(img, ox + 2, oy + 2, 12, 2, c)
			_fill_rect(img, ox + 2, oy + 4, 1, 4, c)
			_fill_rect(img, ox + 13, oy + 4, 1, 4, c)
		"long":
			# Calotte courte + cheveux qui descendent jusqu'au cou (rows 4-9).
			_fill_rect(img, ox + 4, oy + 0, 8, 1, c)
			_fill_rect(img, ox + 3, oy + 1, 10, 1, c)
			_fill_rect(img, ox + 2, oy + 2, 12, 2, c)
			_fill_rect(img, ox + 2, oy + 4, 2, 6, c)
			_fill_rect(img, ox + 12, oy + 4, 2, 6, c)
		"bun":
			# Calotte courte + chignon en boule au sommet.
			_fill_rect(img, ox + 4, oy + 0, 8, 1, c)
			_fill_rect(img, ox + 3, oy + 1, 10, 1, c)
			_fill_rect(img, ox + 2, oy + 2, 12, 2, c)
			# Chignon : petit dôme au-dessus.
			_fill_rect(img, ox + 6, oy - 2, 4, 2, c)
			_fill_rect(img, ox + 7, oy - 3, 2, 1, c)
		"spiky":
			# Pointes irrégulières sur le sommet.
			_fill_rect(img, ox + 3, oy + 2, 10, 2, c)
			_fill_rect(img, ox + 2, oy + 1, 1, 2, c)
			_fill_rect(img, ox + 5, oy + 0, 1, 2, c)
			_fill_rect(img, ox + 8, oy + 0, 1, 2, c)
			_fill_rect(img, ox + 11, oy + 0, 1, 2, c)
			_fill_rect(img, ox + 13, oy + 1, 1, 2, c)

static func _draw_hat(img: Image, ox: int, oy: int, _dir: int, style: String, c: Color) -> void:
	match style:
		"none":
			pass
		"cap":
			# Casquette : couronne plate + visière.
			_fill_rect(img, ox + 2, oy + 1, 12, 2, c)
			_fill_rect(img, ox + 1, oy + 3, 14, 1, c)  # visière
		"fedora":
			# Fedora : couronne plus haute + bord large.
			_fill_rect(img, ox + 3, oy + 0, 10, 1, c)
			_fill_rect(img, ox + 4, oy + 1, 8, 2, c)
			_fill_rect(img, ox + 1, oy + 3, 14, 1, c)  # large bord
		"beret":
			# Béret : disque souple incliné.
			_fill_rect(img, ox + 4, oy + 1, 8, 2, c)
			_fill_rect(img, ox + 3, oy + 2, 10, 1, c)
			_fill_rect(img, ox + 11, oy + 0, 2, 1, c)  # pic incliné
		"scarf":
			# Foulard : couvre cheveux + descend sur les oreilles.
			_fill_rect(img, ox + 2, oy + 0, 12, 4, c)
			_fill_rect(img, ox + 2, oy + 4, 1, 2, c)
			_fill_rect(img, ox + 13, oy + 4, 1, 2, c)

static func _draw_shirt_pattern(img: Image, ox: int, oy: int, pattern: String, base: Color) -> void:
	match pattern:
		"solid":
			pass
		"stripe_h":
			# Bandes horizontales alternées (un peu plus claires).
			var lighter: Color = base.lightened(0.18)
			_fill_rect(img, ox + 3, oy + 11, 10, 1, lighter)
			_fill_rect(img, ox + 3, oy + 14, 10, 1, lighter)
			_fill_rect(img, ox + 3, oy + 17, 10, 1, lighter)
		"pocket":
			# Petite poche carrée sur le côté droit du torse.
			var darker: Color = base.darkened(0.25)
			_fill_rect(img, ox + 9, oy + 12, 3, 3, darker)
