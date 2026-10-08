class_name PropSprites
extends RefCounted

# Props ponctuels tirés de l'atlas (palmiers, parasols), partagés entre le
# générateur de Copacabana et l'habilleur des districts : un seul endroit pour
# les régions, les hauteurs cibles et l'ancrage par la base.

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const UMBRELLA_VARIANTS: Array = [
	{"region": Cfg.UMBRELLA_YELLOW_REGION, "h": 70.0},
	{"region": Cfg.UMBRELLA_RED_REGION, "h": 70.0},
	{"region": Cfg.UMBRELLA_BLUE_REGION, "h": 80.0},
]
const PALM_MIN_H: float = 95.0
const PALM_MAX_H: float = 120.0
const PALM_REGIONS: Array = [Cfg.PALM_TREE_REGION, Cfg.PALM_TREE_B_REGION]
const TOWEL_REGIONS: Array = [Cfg.TOWEL_STRIPED_REGION, Cfg.TOWEL_LOUNGER_REGION]


# Densité du pixel-art du jeu : 1 pixel natif = 3 px monde (les personnages
# sont dessinés en 21×32 et affichés ×3). Les props peints de l'atlas sont
# rééchantillonnés UNE fois à cette densité (réduction LANCZOS vers la taille
# native, puis affichage ×3 NEAREST) : fini les pixels irréguliers d'une
# échelle flottante, et une seule écriture avec les personnages.
const PIXEL_DENSITY: int = 3

static var _resampled_cache: Dictionary = {}

# Texture d'un prop à la taille native (hauteur cible / densité), mise en cache.
static func resampled(region: Rect2, target_height: float, density: int = PIXEL_DENSITY) -> Texture2D:
	var native_h: int = maxi(1, int(roundf(target_height / float(density))))
	var native_w: int = maxi(1, int(roundf(region.size.x * float(native_h) / region.size.y)))
	var key: String = "%d_%d_%d_%d_%d_%d" % [int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y), native_w, native_h]
	if _resampled_cache.has(key):
		return _resampled_cache[key]
	var atlas: Texture2D = load(Cfg.TILESET_TEXTURE)
	var img: Image = atlas.get_image()
	if img.is_compressed():
		img.decompress()
	var sub: Image = img.get_region(Rect2i(region))
	sub.resize(native_w, native_h, Image.INTERPOLATE_LANCZOS)
	# Les bords anti-aliasés du peint deviennent des pixels francs.
	_harden_alpha(sub)
	var tex: ImageTexture = ImageTexture.create_from_image(sub)
	_resampled_cache[key] = tex
	return tex


static func _harden_alpha(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a < 1.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


# Sprite ancré par la base : pos.y = le pied du prop (Sprite2D est centré par défaut).
static func spawn(parent: Node, region: Rect2, pos: Vector2, target_height: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = resampled(region, target_height)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PIXEL_DENSITY, PIXEL_DENSITY)
	var world_h: float = float(s.texture.get_height() * PIXEL_DENSITY)
	s.position = Vector2(pos.x, pos.y - world_h * 0.5)
	parent.add_child(s)
	return s


# Variante de parasol la plus proche d'une couleur de toile (rouge / bleu / sinon jaune).
static func umbrella_variant_for(color: Color) -> Dictionary:
	if color.b > color.r and color.b > color.g:
		return UMBRELLA_VARIANTS[2]
	if color.r > 0.75 and color.g < 0.6:
		return UMBRELLA_VARIANTS[1]
	return UMBRELLA_VARIANTS[0]


# Hauteur de palmier déterministe (même rendu à chaque chargement) dans la
# fourchette de Copa, à partir d'une position.
static func palm_height_at(pos: Vector2) -> float:
	var h: int = int(absf(pos.x * 7.0 + pos.y * 13.0))
	return PALM_MIN_H + float(h % int(PALM_MAX_H - PALM_MIN_H + 1.0))


# Variante de palmier déterministe (les deux couronnes de l'atlas alternent).
static func palm_region_at(pos: Vector2) -> Rect2:
	# hash() de Godot (murmur3) : un simple a·x + b·y garde la parité des
	# coordonnées (toutes paires dans les scènes) et ne ferait jamais alterner.
	return PALM_REGIONS[absi(hash(Vector2i(int(pos.x), int(pos.y)))) % PALM_REGIONS.size()]


# Prop à plat (serviette) : centré sur un rectangle, largeur imposée.
static func spawn_flat(parent: Node, region: Rect2, center: Vector2, target_width: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	var target_h: float = target_width * region.size.y / region.size.x
	s.texture = resampled(region, target_h)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PIXEL_DENSITY, PIXEL_DENSITY)
	s.position = center
	parent.add_child(s)
	return s
