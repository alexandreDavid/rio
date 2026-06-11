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

const POSTO_COUNT: int = 5
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
