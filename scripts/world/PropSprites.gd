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


# Sprite ancré par la base : pos.y = le pied du prop (Sprite2D est centré par défaut).
static func spawn(parent: Node, region: Rect2, pos: Vector2, target_height: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = load(Cfg.TILESET_TEXTURE)
	s.region_enabled = true
	s.region_rect = region
	var scale_factor: float = target_height / region.size.y
	s.scale = Vector2(scale_factor, scale_factor)
	s.position = Vector2(pos.x, pos.y - (region.size.y * scale_factor) * 0.5)
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
	s.texture = load(Cfg.TILESET_TEXTURE)
	s.region_enabled = true
	s.region_rect = region
	var f: float = target_width / region.size.x
	s.scale = Vector2(f, f)
	s.position = center
	parent.add_child(s)
	return s
