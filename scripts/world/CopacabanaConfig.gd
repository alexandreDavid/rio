extends RefCounted

# Constantes de configuration de Copacabana : layout, couleurs, régions de
# tileset, tailles, positions d'intérieurs. Extrait de CopacabanaGenerator
# (cf. « Constantes clés » / « Régions utilisées » dans CLAUDE.md).
# Préchargé comme `Cfg` dans le générateur ; accès via Cfg.NOM.

const BUILDING_SIZE: Vector2 = Vector2(100, 64)
# Layout de haut en bas (y croissant = sud) :
# favelas (y<-200) | 2ème rangée (y=-192/-128) | Nossa Senhora road (y=-128/-64) |
# 1ère rangée (y=-64/0) | Av. Atlântica (y=0/64) | calçadão (y=64/128) | sable (y=128/400) | mer (y=400+)
const BUILDING_Y: float = -32.0
const BUILDING_COLORS: Array = [
	Color(0.88, 0.78, 0.64, 1),
	Color(0.78, 0.68, 0.55, 1),
	Color(0.72, 0.60, 0.40, 1),
	Color(0.68, 0.55, 0.45, 1),
	Color(0.82, 0.72, 0.58, 1),
]
const WINDOW_COLOR: Color = Color(0.25, 0.35, 0.55, 1)
const DOOR_COLOR: Color = Color(0.35, 0.25, 0.18, 1)

# 6 postos comme dans la réalité : Posto 6 collé au Forte (ouest), Posto 1 au Leme (est).
const POSTO_COUNT: int = 6
const POSTO_START_X: float = 300.0
const POSTO_END_X: float = 2100.0
const POSTO_Y: float = 168.0

const PALACE_X: float = 1700.0
const PALACE_Y: float = -40.0
const PALACE_SIZE: Vector2 = Vector2(230, 100)
const PALACE_REGION: Rect2 = Rect2(150, 0, 1250, 550)
const BUILDINGS_SCALE: float = 0.18
const BUILDINGS_TEXTURE: String = "res://assets/sprites/buildings_ai_clean.png"

# Bornes globales de la map (tuiles, sable, calçadão, etc.).
# Inclut Forte de Copacabana à l'ouest (-300..0) et Leme étendu à l'est (2200..3200).
# Les bâtiments NPC restent dans map_start_x..map_end_x — Forte et Leme sont décorés à part.
const MAP_LEFT: float = -300.0
const MAP_RIGHT: float = 3200.0
const MAP_TOTAL_W: float = 3500.0  # MAP_RIGHT - MAP_LEFT

# Courbe de la baie : le rivage suit un arc parabolique (croissant de Copacabana).
# La mer mord au plus profond au centre de la map décorée, et recule vers les
# deux pointes rocheuses (Forte à l'ouest, Pedra do Leme à l'est).
const SHORE_CENTER_X: float = 1450.0   # (MAP_LEFT + MAP_RIGHT) / 2
const SHORE_MIN_Y: float = 372.0       # rivage au centre de la baie
const SHORE_EDGE_Y: float = 435.0      # rivage aux extrémités décorées
const SHORE_HALF_SPAN: float = 1750.0  # MAP_TOTAL_W / 2

static func shore_y(x: float) -> float:
	var t: float = clampf((x - SHORE_CENTER_X) / SHORE_HALF_SPAN, -1.0, 1.0)
	return SHORE_MIN_Y + (SHORE_EDGE_Y - SHORE_MIN_Y) * t * t

const COMMERCES: Array = [
	{"x": 500.0, "label": "", "region": Rect2(70, 540, 440, 450)},
	{"x": 1050.0, "label": "", "region": Rect2(540, 540, 480, 450)},
	{"x": 1900.0, "label": "", "region": Rect2(1050, 540, 470, 450)},
]
const COMMERCE_SIZE: Vector2 = Vector2(85, 85)

const SECOND_ROW_Y: float = -160.0
const POLICE_X: float = 1200.0
const POLICE_SIZE: Vector2 = Vector2(140, 80)
const COP_BAR_X: float = 1380.0
const COP_BAR_SIZE: Vector2 = Vector2(130, 72)
const ACADEMIA_X: float = 700.0
const ACADEMIA_SIZE: Vector2 = Vector2(130, 80)

# Bâtiments emblématiques en 2ème rangée (sur Nossa Senhora, y=SECOND_ROW_Y).
const CHURCH_X: float = 1500.0
const CHURCH_SIZE: Vector2 = Vector2(140, 80)
const CHURCH_Y: float = SECOND_ROW_Y
const PHARMACY_X: float = 2040.0
const PHARMACY_SIZE: Vector2 = Vector2(120, 80)
const PHARMACY_Y: float = SECOND_ROW_Y
const PADARIA_X: float = 850.0
const PADARIA_SIZE: Vector2 = Vector2(110, 76)
const PADARIA_Y: float = SECOND_ROW_Y

# Rues transversales réelles reliant l'Av. Atlântica à la bande favela.
# Largeurs serrées pour passer entre les bâtiments fixes (commerces, police…).
const CROSS_STREETS: Array = [
	{"x": 600.0, "w": 48.0, "name": "R. SANTA CLARA"},
	{"x": 1111.0, "w": 32.0, "name": "R. SIQUEIRA CAMPOS"},   # alignée Túnel Velho
	{"x": 2150.0, "w": 56.0, "name": "AV. PRINCESA ISABEL"},  # frontière réelle Copa/Leme, alignée Túnel Novo
]

# Entrées de métro réelles (décor) sur Nossa Senhora de Copacabana.
const METRO_STATIONS: Array = [
	{"x": 420.0, "name": "CANTAGALO"},
	{"x": 1075.0, "name": "SIQUEIRA CAMPOS"},  # côté ouest de la rue, dégage le poste de police
	{"x": 1900.0, "name": "CARDEAL ARCOVERDE"},
]

# Ciclovia de l'Av. Atlântica — bande terracotta côté plage, sur toute la map.
const CICLOVIA_TOP: float = 48.0
const CICLOVIA_BOT: float = 64.0
const CICLOVIA_COLOR: Color = Color(0.72, 0.34, 0.27, 1)

# Quiosques décoratifs du calçadão (xs choisis pour éviter lampadaires,
# Quiosque do Zé à x=500 et le valet du Palace à x~1820).
const QUIOSQUE_XS: Array = [350.0, 780.0, 1250.0, 1750.0, 2060.0]

const FAVELA_COLORS: Array = [
	Color(0.88, 0.35, 0.32, 1),  # rouge brique
	Color(0.95, 0.75, 0.28, 1),  # jaune soleil
	Color(0.32, 0.65, 0.85, 1),  # bleu ciel
	Color(0.85, 0.55, 0.35, 1),  # orange
	Color(0.88, 0.45, 0.62, 1),  # rose
	Color(0.55, 0.75, 0.45, 1),  # lime
	Color(0.78, 0.65, 0.45, 1),  # beige
	Color(0.55, 0.45, 0.72, 1),  # violet
	Color(0.92, 0.88, 0.72, 1),  # crème
]

const TILESET_TEXTURE: String = "res://assets/sprites/tileset_ai.png"
# Régions cadrées à l'intérieur du cadre décoratif de chaque tuile pour éviter
# les coutures visibles lors du tiling. Tuiles atlas ~143x136 px, on retire ~20 px de marge.
const CALCADAO_TILE_REGION: Rect2 = Rect2(286, 246, 104, 96)  # Vague noir/blanc iconique de Copacabana
const SAND_TILE_REGION: Rect2 = Rect2(128, 92, 103, 96)       # Sable plein
const ROAD_TILE_REGION: Rect2 = Rect2(128, 401, 103, 93)      # Asphalte plain
const WATER_TILE_REGION: Rect2 = Rect2(1165, 145, 130, 50)    # Eau bleue (partie basse, sans sable)
const SIDEWALK_TILE_REGION: Rect2 = Rect2(128, 582, 103, 60)  # Trottoir béton (sans bord blanc)
const FOAM_TILE_REGION: Rect2 = Rect2(1100, 88, 180, 60)      # Écume sable/mer (bord plage)
# Props (parasols, palmiers) — extraits tels quels, sans marge
const UMBRELLA_YELLOW_REGION: Rect2 = Rect2(460, 660, 143, 181)
const UMBRELLA_RED_REGION: Rect2 = Rect2(614, 660, 142, 180)
const UMBRELLA_BLUE_REGION: Rect2 = Rect2(1031, 660, 89, 250)
const PALM_TREE_REGION: Rect2 = Rect2(296, 660, 122, 252)
# Décors de la même bande, inventoriés le 2026-10-07 (segmentation alpha) :
const PALM_TREE_B_REGION: Rect2 = Rect2(108, 680, 165, 229)    # second palmier, couronne plus large
const TOWEL_STRIPED_REGION: Rect2 = Rect2(785, 696, 211, 99)   # canga rayée (vue de dessus)
const TOWEL_LOUNGER_REGION: Rect2 = Rect2(778, 825, 217, 82)   # esteira à carreaux
const BEACH_CART_REGION: Rect2 = Rect2(1198, 660, 224, 260)    # carrocinha de plage (parasol bleu/jaune)
const CALCADAO_Y: float = 64.0          # top de la zone
const CALCADAO_HEIGHT: float = 64.0     # 64px tall (1 row de tuiles 64x64)
const CALCADAO_TILE_SIZE: float = 64.0
const GROUND_TILE_SIZE: float = 64.0

# Intérieurs uniques (instanciés une fois, loin du monde joué)
const SHOP_INT_SCENE: PackedScene = preload("res://scenes/interiors/ShopInterior.tscn")
const BAR_INT_SCENE: PackedScene = preload("res://scenes/interiors/BarInterior.tscn")
const POLICE_INT_SCENE: PackedScene = preload("res://scenes/interiors/PoliceInterior.tscn")
const PALACE_INT_SCENE: PackedScene = preload("res://scenes/interiors/PalaceLobbyInterior.tscn")
const CHURCH_INT_SCENE: PackedScene = preload("res://scenes/interiors/ChurchInterior.tscn")
const RESTAURANT_INT_SCENE: PackedScene = preload("res://scenes/interiors/RestaurantInterior.tscn")
const MERCADINHO_INT_SCENE: PackedScene = preload("res://scenes/interiors/MercadinhoInterior.tscn")
const PHARMACY_INT_SCENE: PackedScene = preload("res://scenes/interiors/PharmacyInterior.tscn")
const PADARIA_INT_SCENE: PackedScene = preload("res://scenes/interiors/PadariaInterior.tscn")
const BUILDING_DOOR_SCENE: PackedScene = preload("res://scenes/props/BuildingDoor.tscn")
# Chaque intérieur vit dans son propre carré décalé (loin du monde joué).
const INT_SHOP_POS: Vector2 = Vector2(900, -3000)
const INT_BAR_POS: Vector2 = Vector2(1600, -3000)
const INT_POLICE_POS: Vector2 = Vector2(2300, -3000)
const INT_PALACE_POS: Vector2 = Vector2(3000, -3000)
const INT_CHURCH_POS: Vector2 = Vector2(3700, -3000)
const INT_RESTAURANT_POS: Vector2 = Vector2(4400, -3000)
const INT_MERCADINHO_POS: Vector2 = Vector2(5100, -3000)
const INT_PHARMACY_POS: Vector2 = Vector2(5800, -3000)
const INT_PADARIA_POS: Vector2 = Vector2(6500, -3000)
const DOOR_OFFSET_Y: float = 0.0  # 0 = porte placée exactement sur le bord sud du bâtiment
