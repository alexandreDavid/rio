extends Node2D

# Génère procéduralement les bâtiments, postes et marqueurs de zone.
# Géographie réelle : LEME à l'est (droite, x haut), FORTE à l'ouest (gauche, x bas).
# 5 postes : Posto 1 (près de Leme) à Posto 5 (près du fort).

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

@export var map_start_x: float = 160.0
@export var map_end_x: float = 2200.0
@export var building_count: int = 14

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

var _shop_spawn: Vector2
var _bar_spawn: Vector2
var _police_spawn: Vector2
var _church_spawn: Vector2
var _restaurant_spawn: Vector2
var _mercadinho_spawn: Vector2
var _pharmacy_spawn: Vector2
var _padaria_spawn: Vector2
var _palace_spawn: Vector2

func _ready() -> void:
	_spawn_interiors()
	_spawn_sand()
	_spawn_sea()
	_spawn_sea_foam()
	_spawn_roads()
	_spawn_building_row_ground()
	_spawn_buildings()
	_spawn_palace()
	_spawn_commerces()
	_spawn_church()
	_spawn_pharmacy()
	_spawn_padaria()
	_spawn_second_row()
	_spawn_police_station()
	_spawn_cop_bar()
	_spawn_academia()
	_spawn_favelas()
	_spawn_botafogo_tunnels()
	_spawn_calcadao()
	_spawn_beach_props()
	_spawn_postos()
	_spawn_forte()
	_spawn_leme_rocks()
	_spawn_zone_markers()
	_spawn_ambient_wanderers()

func _spawn_tile_strip(container_name: String, y_top: float, y_bot: float, tile_region: Rect2, z_idx: int = -5) -> void:
	var container: Node2D = Node2D.new()
	container.name = container_name
	container.z_index = z_idx
	add_child(container)
	var tex: Texture2D = load(TILESET_TEXTURE)
	var scale: Vector2 = Vector2(GROUND_TILE_SIZE / tile_region.size.x, GROUND_TILE_SIZE / tile_region.size.y)
	var cols: int = int(ceil(MAP_TOTAL_W / GROUND_TILE_SIZE))
	var rows: int = int(ceil((y_bot - y_top) / GROUND_TILE_SIZE))
	for row in rows:
		for col in cols:
			var s: Sprite2D = Sprite2D.new()
			s.texture = tex
			s.region_enabled = true
			s.region_rect = tile_region
			s.scale = scale
			s.position = Vector2(MAP_LEFT + col * GROUND_TILE_SIZE + GROUND_TILE_SIZE * 0.5, y_top + row * GROUND_TILE_SIZE + GROUND_TILE_SIZE * 0.5)
			container.add_child(s)

func _spawn_sand() -> void:
	_spawn_tile_strip("SandTiles", 128.0, 400.0, SAND_TILE_REGION)

func _spawn_sea() -> void:
	_spawn_tile_strip("SeaTiles", 400.0, 600.0, WATER_TILE_REGION)

func _spawn_roads() -> void:
	# Av. Atlântica (proche calçadão)
	_spawn_tile_strip("AvAtlanticaTiles", 0.0, 64.0, ROAD_TILE_REGION)
	# Nossa Senhora de Copacabana (côté intérieur)
	_spawn_tile_strip("NossaSenhoraTiles", -128.0, -64.0, ROAD_TILE_REGION)

func _spawn_building_row_ground() -> void:
	# Dalles trottoir sur les rangées où se posent les bâtiments pour éviter
	# que le fond bleu ciel apparaisse dans les interstices entre immeubles.
	_spawn_tile_strip("FirstRowGround", -64.0, 0.0, SIDEWALK_TILE_REGION, -6)
	_spawn_tile_strip("SecondRowGround", -192.0, -128.0, SIDEWALK_TILE_REGION, -6)

func _spawn_sea_foam() -> void:
	# Bande d'écume sable/mer à la frontière plage/océan (y=400).
	var container: Node2D = Node2D.new()
	container.name = "SeaFoam"
	container.z_index = -4
	add_child(container)
	var tex: Texture2D = load(TILESET_TEXTURE)
	var strip_h: float = 32.0
	var tile_w: float = 96.0
	var tile_count: int = int(ceil(MAP_TOTAL_W / tile_w))
	var scale_x: float = tile_w / FOAM_TILE_REGION.size.x
	var scale_y: float = strip_h / FOAM_TILE_REGION.size.y
	for i in tile_count:
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = FOAM_TILE_REGION
		s.scale = Vector2(scale_x, scale_y)
		s.position = Vector2(MAP_LEFT + i * tile_w + tile_w * 0.5, 400.0 + strip_h * 0.5)
		container.add_child(s)

func _spawn_beach_props() -> void:
	var container: Node2D = Node2D.new()
	container.name = "BeachProps"
	container.z_index = 0
	add_child(container)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20251024
	# Parasols alternés le long de la plage (y entre 200 et 360, en évitant les postes à y=168).
	var umbrella_variants: Array = [
		{"region": UMBRELLA_YELLOW_REGION, "h": 70.0},
		{"region": UMBRELLA_RED_REGION, "h": 70.0},
		{"region": UMBRELLA_BLUE_REGION, "h": 80.0},
	]
	var x: float = 260.0
	var idx: int = 0
	while x < 2200.0:
		var variant: Dictionary = umbrella_variants[idx % umbrella_variants.size()]
		var region: Rect2 = variant.region
		var target_h: float = variant.h
		var y: float = 220.0 + rng.randf_range(0.0, 120.0)
		_spawn_prop_sprite(container, region, Vector2(x, y), target_h)
		x += rng.randf_range(140.0, 220.0)
		idx += 1
	# Deux palmiers aux extrémités du calçadão
	_spawn_prop_sprite(container, PALM_TREE_REGION, Vector2(240.0, 180.0), 110.0)
	_spawn_prop_sprite(container, PALM_TREE_REGION, Vector2(2160.0, 180.0), 110.0)

func _spawn_prop_sprite(parent: Node, region: Rect2, pos: Vector2, target_height: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = load(TILESET_TEXTURE)
	s.region_enabled = true
	s.region_rect = region
	var scale_factor: float = target_height / region.size.y
	s.scale = Vector2(scale_factor, scale_factor)
	# Ancrage par la base (sprite 2D par défaut centré ; on décale pour que le pied touche pos.y)
	s.position = Vector2(pos.x, pos.y - (region.size.y * scale_factor) * 0.5)
	parent.add_child(s)

func _spawn_interiors() -> void:
	_shop_spawn = _instantiate_interior(SHOP_INT_SCENE, INT_SHOP_POS)
	_bar_spawn = _instantiate_interior(BAR_INT_SCENE, INT_BAR_POS)
	_police_spawn = _instantiate_interior(POLICE_INT_SCENE, INT_POLICE_POS)
	_palace_spawn = _instantiate_interior(PALACE_INT_SCENE, INT_PALACE_POS)
	_church_spawn = _instantiate_interior(CHURCH_INT_SCENE, INT_CHURCH_POS)
	_restaurant_spawn = _instantiate_interior(RESTAURANT_INT_SCENE, INT_RESTAURANT_POS)
	_mercadinho_spawn = _instantiate_interior(MERCADINHO_INT_SCENE, INT_MERCADINHO_POS)
	_pharmacy_spawn = _instantiate_interior(PHARMACY_INT_SCENE, INT_PHARMACY_POS)
	_padaria_spawn = _instantiate_interior(PADARIA_INT_SCENE, INT_PADARIA_POS)

func _instantiate_interior(scene: PackedScene, pos: Vector2) -> Vector2:
	var interior: Node2D = scene.instantiate()
	interior.position = pos
	add_child(interior)
	var marker: Node = interior.get_node_or_null("SpawnPoint")
	if marker and marker is Node2D:
		return (marker as Node2D).global_position
	return pos

func _add_door(parent: Node, building_pos: Vector2, half_height: float, destination: Vector2, prompt: String = "Entrer") -> void:
	var door: Node2D = BUILDING_DOOR_SCENE.instantiate()
	door.position = building_pos + Vector2(0, half_height + DOOR_OFFSET_Y)
	if "destination" in door:
		door.destination = destination
	if "prompt_text" in door:
		door.prompt_text = prompt
	parent.add_child(door)

func _spawn_calcadao() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Calcadao"
	container.z_index = -5
	add_child(container)
	var tex: Texture2D = load(TILESET_TEXTURE)
	var scale_factor: float = CALCADAO_TILE_SIZE / CALCADAO_TILE_REGION.size.x
	var tile_count: int = int(ceil(MAP_TOTAL_W / CALCADAO_TILE_SIZE))
	for i in tile_count:
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = CALCADAO_TILE_REGION
		s.scale = Vector2(scale_factor, scale_factor)
		s.position = Vector2(MAP_LEFT + i * CALCADAO_TILE_SIZE + CALCADAO_TILE_SIZE * 0.5, CALCADAO_Y + CALCADAO_HEIGHT * 0.5)
		container.add_child(s)

func _spawn_buildings() -> void:
	var container: Node2D = Node2D.new()
	container.name = "GeneratedBuildings"
	add_child(container)
	var total_span: float = map_end_x - map_start_x
	var spacing: float = total_span / float(building_count - 1)
	for i in building_count:
		var x: float = map_start_x + i * spacing
		# Skip palace
		if abs(x - PALACE_X) < PALACE_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		# Skip commerces
		var skip: bool = false
		for c in COMMERCES:
			if abs(x - c.x) < COMMERCE_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
				skip = true
				break
		if skip:
			continue
		var color: Color = BUILDING_COLORS[i % BUILDING_COLORS.size()]
		_spawn_building(container, Vector2(x, BUILDING_Y), color)

func _spawn_building(parent: Node, pos: Vector2, color: Color) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	parent.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = BUILDING_SIZE
	shape.shape = rect
	body.add_child(shape)

	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -BUILDING_SIZE.x * 0.5
	facade.offset_top = -BUILDING_SIZE.y * 0.5
	facade.offset_right = BUILDING_SIZE.x * 0.5
	facade.offset_bottom = BUILDING_SIZE.y * 0.5
	facade.color = color
	body.add_child(facade)

	for j in 3:
		var win: ColorRect = ColorRect.new()
		var wx: float = -30.0 + j * 22.0
		win.offset_left = wx
		win.offset_top = -20.0
		win.offset_right = wx + 12.0
		win.offset_bottom = -8.0
		win.color = WINDOW_COLOR
		body.add_child(win)

	var door: ColorRect = ColorRect.new()
	door.offset_left = -6.0
	door.offset_top = 12.0
	door.offset_right = 6.0
	door.offset_bottom = 32.0
	door.color = DOOR_COLOR
	body.add_child(door)

func _spawn_palace() -> void:
	var container: Node2D = Node2D.new()
	container.name = "CopacabanaPalace"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(PALACE_X, PALACE_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = PALACE_SIZE
	shape.shape = rect
	body.add_child(shape)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(BUILDINGS_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = PALACE_REGION
	sprite.scale = Vector2(BUILDINGS_SCALE, BUILDINGS_SCALE)
	body.add_child(sprite)

	_add_door(container, Vector2(PALACE_X, PALACE_Y), PALACE_SIZE.y * 0.5, _palace_spawn, "Entrer au palace")

func _spawn_second_row() -> void:
	var container: Node2D = Node2D.new()
	container.name = "SecondRowBuildings"
	add_child(container)
	var count: int = 10
	var step: float = (map_end_x - map_start_x) / float(count - 1)
	for i in count:
		var x: float = map_start_x + i * step
		# Skip la zone du poste de police
		if abs(x - POLICE_X) < POLICE_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone du bar du policier
		if abs(x - COP_BAR_X) < COP_BAR_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone de l'Academia
		if abs(x - ACADEMIA_X) < ACADEMIA_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone de la Favela do Morro (x=60-260)
		if x >= 60.0 and x <= 260.0:
			continue
		# Skip église, pharmacie et padaria — ils sont sur Nossa Senhora désormais.
		if abs(x - CHURCH_X) < CHURCH_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		if abs(x - PHARMACY_X) < PHARMACY_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		if abs(x - PADARIA_X) < PADARIA_SIZE.x * 0.5 + BUILDING_SIZE.x * 0.5:
			continue
		var color: Color = BUILDING_COLORS[(i + 2) % BUILDING_COLORS.size()]
		_spawn_building(container, Vector2(x, SECOND_ROW_Y), color)

func _spawn_police_station() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PoliceStation"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(POLICE_X, SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = POLICE_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Bande supérieure bleu police
	var top_band: ColorRect = ColorRect.new()
	top_band.offset_left = -POLICE_SIZE.x * 0.5 - 4
	top_band.offset_top = -POLICE_SIZE.y * 0.5 - 6
	top_band.offset_right = POLICE_SIZE.x * 0.5 + 4
	top_band.offset_bottom = -POLICE_SIZE.y * 0.5 + 8
	top_band.color = Color(0.18, 0.3, 0.6, 1)
	body.add_child(top_band)

	# Façade blanc cassé
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -POLICE_SIZE.x * 0.5
	facade.offset_top = -POLICE_SIZE.y * 0.5
	facade.offset_right = POLICE_SIZE.x * 0.5
	facade.offset_bottom = POLICE_SIZE.y * 0.5
	facade.color = Color(0.92, 0.92, 0.9, 1)
	body.add_child(facade)

	# Fenêtres
	for col in 4:
		var win: ColorRect = ColorRect.new()
		var wx: float = -54.0 + col * 28.0
		win.offset_left = wx
		win.offset_top = -22.0
		win.offset_right = wx + 16.0
		win.offset_bottom = -8.0
		win.color = Color(0.3, 0.45, 0.7, 1)
		body.add_child(win)

	# Porte centrale
	var door: ColorRect = ColorRect.new()
	door.offset_left = -10.0
	door.offset_top = 12.0
	door.offset_right = 10.0
	door.offset_bottom = 38.0
	door.color = Color(0.15, 0.2, 0.3, 1)
	body.add_child(door)

	# Gyrophare
	var gyro: ColorRect = ColorRect.new()
	gyro.offset_left = -6.0
	gyro.offset_top = -POLICE_SIZE.y * 0.5 - 14
	gyro.offset_right = 6.0
	gyro.offset_bottom = -POLICE_SIZE.y * 0.5 - 4
	gyro.color = Color(0.85, 0.2, 0.2, 1)
	body.add_child(gyro)

	# Enseigne POLÍCIA
	var label: Label = Label.new()
	label.text = "POLÍCIA"
	label.position = Vector2(POLICE_X - 28, SECOND_ROW_Y - POLICE_SIZE.y * 0.5 + 2)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	label.add_theme_font_size_override("font_size", 10)
	container.add_child(label)

	_add_door(container, Vector2(POLICE_X, SECOND_ROW_Y), POLICE_SIZE.y * 0.5, _police_spawn, "Entrer au poste")

func _spawn_academia() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Academia"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(ACADEMIA_X, SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = ACADEMIA_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Auvent orange sport
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -ACADEMIA_SIZE.x * 0.5 - 4
	awning.offset_top = -ACADEMIA_SIZE.y * 0.5 - 8
	awning.offset_right = ACADEMIA_SIZE.x * 0.5 + 4
	awning.offset_bottom = -ACADEMIA_SIZE.y * 0.5 + 10
	awning.color = Color(0.9, 0.45, 0.18, 1)
	body.add_child(awning)

	# Façade blanche
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -ACADEMIA_SIZE.x * 0.5
	facade.offset_top = -ACADEMIA_SIZE.y * 0.5
	facade.offset_right = ACADEMIA_SIZE.x * 0.5
	facade.offset_bottom = ACADEMIA_SIZE.y * 0.5
	facade.color = Color(0.94, 0.94, 0.92, 1)
	body.add_child(facade)

	# Grandes vitres
	for i in 3:
		var win: ColorRect = ColorRect.new()
		var wx: float = -44.0 + i * 30.0
		win.offset_left = wx
		win.offset_top = -18.0
		win.offset_right = wx + 22.0
		win.offset_bottom = 8.0
		win.color = Color(0.45, 0.65, 0.8, 1)
		body.add_child(win)

	# Porte en verre
	var door: ColorRect = ColorRect.new()
	door.offset_left = -12.0
	door.offset_top = 14.0
	door.offset_right = 12.0
	door.offset_bottom = 38.0
	door.color = Color(0.35, 0.5, 0.6, 1)
	body.add_child(door)

	# Enseigne ACADEMIA
	var label: Label = Label.new()
	label.text = "ACADEMIA"
	label.position = Vector2(ACADEMIA_X - 32, SECOND_ROW_Y - ACADEMIA_SIZE.y * 0.5 - 4)
	label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.22, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive : Academia possède un intérieur dédié au gym
	var academia_spawn: Vector2 = Vector2(700, -1920)
	_add_door(container, Vector2(ACADEMIA_X, SECOND_ROW_Y), ACADEMIA_SIZE.y * 0.5, academia_spawn, "Entrer à l'Academia")

func _spawn_commerces() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Commerces"
	add_child(container)
	# Chaque commerce route vers son propre intérieur — pas de partage.
	# COMMERCES[0] = x=500 → Mercadinho ; [1] = x=1050 → Cantinho Carioca ; [2] = x=1900 → Rio Style.
	var routing: Array = [
		{"spawn": _mercadinho_spawn, "prompt": "Entrer au Mercadinho"},
		{"spawn": _restaurant_spawn, "prompt": "Entrer au Cantinho Carioca"},
		{"spawn": _shop_spawn,       "prompt": "Entrer chez Rio Style"},
	]
	for i in COMMERCES.size():
		var c: Dictionary = COMMERCES[i]
		var r: Dictionary = routing[i]
		_spawn_commerce(container, c.x, c.region, r.spawn, r.prompt)

func _spawn_commerce(parent: Node, x: float, region: Rect2, spawn: Vector2, prompt: String) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(x, BUILDING_Y)
	parent.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = COMMERCE_SIZE
	shape.shape = rect
	body.add_child(shape)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(BUILDINGS_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = Vector2(BUILDINGS_SCALE, BUILDINGS_SCALE)
	body.add_child(sprite)

	_add_door(parent, Vector2(x, BUILDING_Y), COMMERCE_SIZE.y * 0.5, spawn, prompt)

func _spawn_cop_bar() -> void:
	var container: Node2D = Node2D.new()
	container.name = "CopBar"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(COP_BAR_X, SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = COP_BAR_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Auvent bleu-marine
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -COP_BAR_SIZE.x * 0.5 - 4
	awning.offset_top = -COP_BAR_SIZE.y * 0.5 - 4
	awning.offset_right = COP_BAR_SIZE.x * 0.5 + 4
	awning.offset_bottom = -COP_BAR_SIZE.y * 0.5 + 12
	awning.color = Color(0.18, 0.28, 0.5, 1)
	body.add_child(awning)

	# Façade brique
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -COP_BAR_SIZE.x * 0.5
	facade.offset_top = -COP_BAR_SIZE.y * 0.5
	facade.offset_right = COP_BAR_SIZE.x * 0.5
	facade.offset_bottom = COP_BAR_SIZE.y * 0.5
	facade.color = Color(0.72, 0.45, 0.35, 1)
	body.add_child(facade)

	# Vitrine
	var window: ColorRect = ColorRect.new()
	window.offset_left = -38.0
	window.offset_top = -12.0
	window.offset_right = 38.0
	window.offset_bottom = 10.0
	window.color = Color(0.55, 0.7, 0.85, 1)
	body.add_child(window)

	# Porte
	var door: ColorRect = ColorRect.new()
	door.offset_left = -8.0
	door.offset_top = 14.0
	door.offset_right = 8.0
	door.offset_bottom = 34.0
	door.color = Color(0.25, 0.18, 0.12, 1)
	body.add_child(door)

	# Enseigne
	var label: Label = Label.new()
	label.text = "BAR DO POLICIAL"
	label.position = Vector2(COP_BAR_X - 46, SECOND_ROW_Y - 50)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1))
	label.add_theme_font_size_override("font_size", 9)
	container.add_child(label)

	_add_door(container, Vector2(COP_BAR_X, SECOND_ROW_Y), COP_BAR_SIZE.y * 0.5, _bar_spawn, "Entrer au bar")

func _spawn_church() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Igreja"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(CHURCH_X, CHURCH_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = CHURCH_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade pierre claire
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -CHURCH_SIZE.x * 0.5
	facade.offset_top = -CHURCH_SIZE.y * 0.5
	facade.offset_right = CHURCH_SIZE.x * 0.5
	facade.offset_bottom = CHURCH_SIZE.y * 0.5
	facade.color = Color(0.92, 0.88, 0.78, 1)
	body.add_child(facade)

	# Toit triangulaire (effet via rectangle sombre au-dessus)
	var roof: ColorRect = ColorRect.new()
	roof.offset_left = -CHURCH_SIZE.x * 0.5 - 6
	roof.offset_top = -CHURCH_SIZE.y * 0.5 - 12
	roof.offset_right = CHURCH_SIZE.x * 0.5 + 6
	roof.offset_bottom = -CHURCH_SIZE.y * 0.5 + 4
	roof.color = Color(0.45, 0.32, 0.22, 1)
	body.add_child(roof)

	# Clocher central
	var bell_tower: ColorRect = ColorRect.new()
	bell_tower.offset_left = -10.0
	bell_tower.offset_top = -CHURCH_SIZE.y * 0.5 - 32.0
	bell_tower.offset_right = 10.0
	bell_tower.offset_bottom = -CHURCH_SIZE.y * 0.5 - 4.0
	bell_tower.color = Color(0.92, 0.88, 0.78, 1)
	body.add_child(bell_tower)

	# Croix sur le clocher (vertical + horizontal)
	var cross_v: ColorRect = ColorRect.new()
	cross_v.offset_left = -2.0
	cross_v.offset_top = -CHURCH_SIZE.y * 0.5 - 48.0
	cross_v.offset_right = 2.0
	cross_v.offset_bottom = -CHURCH_SIZE.y * 0.5 - 30.0
	cross_v.color = Color(0.25, 0.18, 0.12, 1)
	body.add_child(cross_v)
	var cross_h: ColorRect = ColorRect.new()
	cross_h.offset_left = -7.0
	cross_h.offset_top = -CHURCH_SIZE.y * 0.5 - 42.0
	cross_h.offset_right = 7.0
	cross_h.offset_bottom = -CHURCH_SIZE.y * 0.5 - 38.0
	cross_h.color = Color(0.25, 0.18, 0.12, 1)
	body.add_child(cross_h)

	# Vitrail rond au-dessus de la porte
	var rosace: ColorRect = ColorRect.new()
	rosace.offset_left = -10.0
	rosace.offset_top = -22.0
	rosace.offset_right = 10.0
	rosace.offset_bottom = -2.0
	rosace.color = Color(0.45, 0.55, 0.85, 1)
	body.add_child(rosace)

	# Vitraux latéraux
	for j in 4:
		var win: ColorRect = ColorRect.new()
		var wx: float = -52.0 + j * 28.0
		if j >= 2:
			wx += 24.0  # saute la porte centrale
		win.offset_left = wx
		win.offset_top = 0.0
		win.offset_right = wx + 14.0
		win.offset_bottom = 22.0
		win.color = Color(0.75, 0.4, 0.55, 1)
		body.add_child(win)

	# Grande porte en bois
	var door: ColorRect = ColorRect.new()
	door.offset_left = -12.0
	door.offset_top = 6.0
	door.offset_right = 12.0
	door.offset_bottom = CHURCH_SIZE.y * 0.5
	door.color = Color(0.45, 0.30, 0.20, 1)
	body.add_child(door)

	# Enseigne IGREJA
	var label: Label = Label.new()
	label.text = "✝ IGREJA NOSSA SENHORA"
	label.position = Vector2(CHURCH_X - 80, CHURCH_Y - CHURCH_SIZE.y * 0.5 - 60.0)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive vers l'intérieur de l'église.
	_add_door(container, Vector2(CHURCH_X, CHURCH_Y), CHURCH_SIZE.y * 0.5, _church_spawn, "Entrer dans l'église")

func _spawn_pharmacy() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Farmacia"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(PHARMACY_X, PHARMACY_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = PHARMACY_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade blanche
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -PHARMACY_SIZE.x * 0.5
	facade.offset_top = -PHARMACY_SIZE.y * 0.5
	facade.offset_right = PHARMACY_SIZE.x * 0.5
	facade.offset_bottom = PHARMACY_SIZE.y * 0.5
	facade.color = Color(0.97, 0.97, 0.95, 1)
	body.add_child(facade)

	# Bandeau vert sur le toit (couleur pharmacie)
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -PHARMACY_SIZE.x * 0.5 - 4
	awning.offset_top = -PHARMACY_SIZE.y * 0.5 - 6
	awning.offset_right = PHARMACY_SIZE.x * 0.5 + 4
	awning.offset_bottom = -PHARMACY_SIZE.y * 0.5 + 8
	awning.color = Color(0.25, 0.65, 0.4, 1)
	body.add_child(awning)

	# Croix verte (vertical + horizontal) sur la façade — symbole pharmacie
	var cross_v: ColorRect = ColorRect.new()
	cross_v.offset_left = -4.0
	cross_v.offset_top = -22.0
	cross_v.offset_right = 4.0
	cross_v.offset_bottom = 6.0
	cross_v.color = Color(0.25, 0.65, 0.4, 1)
	body.add_child(cross_v)
	var cross_h: ColorRect = ColorRect.new()
	cross_h.offset_left = -14.0
	cross_h.offset_top = -12.0
	cross_h.offset_right = 14.0
	cross_h.offset_bottom = -4.0
	cross_h.color = Color(0.25, 0.65, 0.4, 1)
	body.add_child(cross_h)

	# Vitrines (gauche/droite de la croix)
	var win_l: ColorRect = ColorRect.new()
	win_l.offset_left = -50.0
	win_l.offset_top = -14.0
	win_l.offset_right = -22.0
	win_l.offset_bottom = 6.0
	win_l.color = Color(0.55, 0.75, 0.9, 1)
	body.add_child(win_l)
	var win_r: ColorRect = ColorRect.new()
	win_r.offset_left = 22.0
	win_r.offset_top = -14.0
	win_r.offset_right = 50.0
	win_r.offset_bottom = 6.0
	win_r.color = Color(0.55, 0.75, 0.9, 1)
	body.add_child(win_r)

	# Porte centrale
	var door: ColorRect = ColorRect.new()
	door.offset_left = -10.0
	door.offset_top = 14.0
	door.offset_right = 10.0
	door.offset_bottom = PHARMACY_SIZE.y * 0.5
	door.color = Color(0.35, 0.55, 0.45, 1)
	body.add_child(door)

	# Enseigne FARMACIA
	var label: Label = Label.new()
	label.text = "+ FARMÁCIA"
	label.position = Vector2(PHARMACY_X - 36, PHARMACY_Y - PHARMACY_SIZE.y * 0.5 - 32.0)
	label.add_theme_color_override("font_color", Color(0.18, 0.55, 0.35, 1))
	label.add_theme_font_size_override("font_size", 12)
	container.add_child(label)

	# Porte interactive vers l'intérieur de la pharmacie.
	_add_door(container, Vector2(PHARMACY_X, PHARMACY_Y), PHARMACY_SIZE.y * 0.5, _pharmacy_spawn, "Entrer dans la pharmacie")

func _spawn_padaria() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Padaria"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(PADARIA_X, PADARIA_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = PADARIA_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade beige clair (style boulangerie populaire).
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -PADARIA_SIZE.x * 0.5
	facade.offset_top = -PADARIA_SIZE.y * 0.5
	facade.offset_right = PADARIA_SIZE.x * 0.5
	facade.offset_bottom = PADARIA_SIZE.y * 0.5
	facade.color = Color(0.95, 0.85, 0.65, 1)
	body.add_child(facade)

	# Auvent à rayures rouge-blanc (typique des padarias brésiliennes).
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -PADARIA_SIZE.x * 0.5 - 4
	awning.offset_top = -PADARIA_SIZE.y * 0.5 - 6
	awning.offset_right = PADARIA_SIZE.x * 0.5 + 4
	awning.offset_bottom = -PADARIA_SIZE.y * 0.5 + 8
	awning.color = Color(0.85, 0.25, 0.25, 1)
	body.add_child(awning)
	# 3 bandes blanches verticales sur l'auvent.
	for i in 3:
		var stripe: ColorRect = ColorRect.new()
		var sx: float = -30.0 + i * 30.0
		stripe.offset_left = sx
		stripe.offset_top = -PADARIA_SIZE.y * 0.5 - 6
		stripe.offset_right = sx + 8
		stripe.offset_bottom = -PADARIA_SIZE.y * 0.5 + 8
		stripe.color = Color(0.97, 0.97, 0.95, 1)
		body.add_child(stripe)

	# Vitrine large (deux pains/biscoitos visibles).
	var window: ColorRect = ColorRect.new()
	window.offset_left = -38.0
	window.offset_top = -16.0
	window.offset_right = 38.0
	window.offset_bottom = 6.0
	window.color = Color(0.85, 0.95, 0.9, 1)
	body.add_child(window)
	# Petites miches dans la vitrine.
	for i in 3:
		var loaf: ColorRect = ColorRect.new()
		var lx: float = -28.0 + i * 22.0
		loaf.offset_left = lx
		loaf.offset_top = -10.0
		loaf.offset_right = lx + 14.0
		loaf.offset_bottom = 2.0
		loaf.color = Color(0.78, 0.55, 0.32, 1)
		body.add_child(loaf)

	# Porte centrale (bois).
	var door: ColorRect = ColorRect.new()
	door.offset_left = -8.0
	door.offset_top = 12.0
	door.offset_right = 8.0
	door.offset_bottom = PADARIA_SIZE.y * 0.5
	door.color = Color(0.45, 0.30, 0.20, 1)
	body.add_child(door)

	# Enseigne PADARIA SAO SEBASTIAO.
	var label: Label = Label.new()
	label.text = "🥖 PADARIA SÃO SEBASTIÃO"
	label.position = Vector2(PADARIA_X - 70, PADARIA_Y - PADARIA_SIZE.y * 0.5 - 30.0)
	label.add_theme_color_override("font_color", Color(0.65, 0.4, 0.25, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive vers l'intérieur de la padaria.
	_add_door(container, Vector2(PADARIA_X, PADARIA_Y), PADARIA_SIZE.y * 0.5, _padaria_spawn, "Entrer dans la padaria")

func _spawn_favelas() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Favelas"
	add_child(container)
	# Favela do Morro (au nord du Posto 5, côté ouest mais recentrée)
	_spawn_favela_cluster(container, Rect2(60, -340, 200, 150), 28, 12345, "FAVELA DO MORRO", Color(0.95, 0.5, 0.3, 1))
	# Favela do Leme (est, sur la colline)
	_spawn_favela_cluster(container, Rect2(2240, -340, 156, 150), 25, 54321, "FAVELA DO LEME", Color(0.95, 0.85, 0.35, 1))

# Bouches de tunnel Copa→Botafogo, alignées avec les ExitToBotafogo* dans
# Copacabana.tscn. Arch sombre + nom de rue, dans la bande favela (y < -200).
# Túnel Velho (mid-Copa, R. Figueiredo Magalhães / Siqueira Campos) à x=1100,
# Túnel Novo (Leme, Av. Princesa Isabel) à x=2150.
func _spawn_botafogo_tunnels() -> void:
	var container: Node2D = Node2D.new()
	container.name = "BotafogoTunnels"
	add_child(container)
	_spawn_tunnel_arch(container, Vector2(1100, -210), "TÚNEL VELHO", "R. SIQUEIRA CAMPOS")
	_spawn_tunnel_arch(container, Vector2(2150, -210), "TÚNEL NOVO", "AV. PRINCESA ISABEL")

func _spawn_tunnel_arch(parent: Node, top_center: Vector2, name_text: String, street_text: String) -> void:
	# Bouche du tunnel : rectangle sombre pour le passage, voussure plus claire au-dessus.
	var mouth: ColorRect = ColorRect.new()
	mouth.offset_left = top_center.x - 50
	mouth.offset_top = top_center.y - 60
	mouth.offset_right = top_center.x + 50
	mouth.offset_bottom = top_center.y
	mouth.color = Color(0.14, 0.13, 0.16, 1)
	parent.add_child(mouth)
	var arch: ColorRect = ColorRect.new()
	arch.offset_left = top_center.x - 60
	arch.offset_top = top_center.y - 70
	arch.offset_right = top_center.x + 60
	arch.offset_bottom = top_center.y - 60
	arch.color = Color(0.55, 0.5, 0.5, 1)
	parent.add_child(arch)
	_spawn_sign(parent, Vector2(top_center.x - 30, top_center.y - 84), name_text, Color(0.92, 0.88, 0.78, 1), 9)
	_spawn_sign(parent, Vector2(top_center.x - 50, top_center.y + 4), street_text, Color(0.85, 0.82, 0.7, 0.9), 7)

func _spawn_favela_cluster(parent: Node, zone: Rect2, house_count: int, seed_val: int, label_text: String, label_color: Color) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	# Trie par y pour que les plus hauts sur la colline dessinent en premier (derrière)
	var positions: Array = []
	for i in house_count:
		positions.append(Vector2(
			rng.randf_range(zone.position.x, zone.position.x + zone.size.x - 26),
			rng.randf_range(zone.position.y, zone.position.y + zone.size.y - 30)
		))
	positions.sort_custom(func(a, b): return a.y < b.y)
	for pos in positions:
		var w: float = rng.randf_range(18, 28)
		var h: float = rng.randf_range(18, 26)
		var color: Color = FAVELA_COLORS[rng.randi() % FAVELA_COLORS.size()]
		_spawn_favela_house(parent, pos, Vector2(w, h), color)
	# Petite étiquette en haut
	var label: Label = Label.new()
	label.text = label_text
	label.position = Vector2(zone.position.x - 10, zone.position.y - 18)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_font_size_override("font_size", 10)
	parent.add_child(label)

func _spawn_favela_house(parent: Node, pos: Vector2, size: Vector2, color: Color) -> void:
	# Mur principal
	var wall: ColorRect = ColorRect.new()
	wall.offset_left = pos.x
	wall.offset_top = pos.y
	wall.offset_right = pos.x + size.x
	wall.offset_bottom = pos.y + size.y
	wall.color = color
	parent.add_child(wall)
	# Bande toit plus foncée
	var roof: ColorRect = ColorRect.new()
	roof.offset_left = pos.x - 1
	roof.offset_top = pos.y - 3
	roof.offset_right = pos.x + size.x + 1
	roof.offset_bottom = pos.y + 2
	roof.color = Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1)
	parent.add_child(roof)
	# Fenêtre sombre
	var win: ColorRect = ColorRect.new()
	var wx: float = pos.x + size.x * 0.55
	var wy: float = pos.y + size.y * 0.35
	win.offset_left = wx
	win.offset_top = wy
	win.offset_right = wx + 4
	win.offset_bottom = wy + 5
	win.color = Color(0.15, 0.2, 0.28, 1)
	parent.add_child(win)

func _spawn_postos() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PostoStations"
	add_child(container)
	# 5 postes régulièrement espacés. Numérotation décroissante de gauche à droite :
	# Posto 5 à l'ouest (côté fort), Posto 1 à l'est (côté Leme).
	var step: float = (POSTO_END_X - POSTO_START_X) / float(POSTO_COUNT - 1)
	for i in POSTO_COUNT:
		var x: float = POSTO_START_X + i * step
		var number: int = POSTO_COUNT - i
		_spawn_lifeguard_hut(container, Vector2(x, POSTO_Y))
		_spawn_sign(container, Vector2(x - 14, POSTO_Y + 24), "P%d" % number, Color(0.15, 0.15, 0.2, 1), 11)

func _spawn_lifeguard_hut(parent: Node, pos: Vector2) -> void:
	var hut: Node2D = Node2D.new()
	hut.position = pos
	parent.add_child(hut)
	# Toit rouge
	var roof: ColorRect = ColorRect.new()
	roof.offset_left = -18.0
	roof.offset_top = -26.0
	roof.offset_right = 18.0
	roof.offset_bottom = -16.0
	roof.color = Color(0.85, 0.25, 0.25, 1)
	hut.add_child(roof)
	# Corps blanc
	var body: ColorRect = ColorRect.new()
	body.offset_left = -14.0
	body.offset_top = -16.0
	body.offset_right = 14.0
	body.offset_bottom = 4.0
	body.color = Color(0.96, 0.96, 0.93, 1)
	hut.add_child(body)
	# Fenêtre avant
	var window: ColorRect = ColorRect.new()
	window.offset_left = -6.0
	window.offset_top = -10.0
	window.offset_right = 6.0
	window.offset_bottom = -2.0
	window.color = Color(0.3, 0.5, 0.65, 1)
	hut.add_child(window)
	# Échasses
	for dx in [-11.0, 11.0]:
		var leg: ColorRect = ColorRect.new()
		leg.offset_left = dx - 1.0
		leg.offset_top = 4.0
		leg.offset_right = dx + 1.0
		leg.offset_bottom = 16.0
		leg.color = Color(0.5, 0.35, 0.2, 1)
		hut.add_child(leg)

func _spawn_zone_markers() -> void:
	var container: Node2D = Node2D.new()
	container.name = "ZoneMarkers"
	add_child(container)
	# LEME à l'est (Pedra do Leme), FORTE à l'ouest (Forte de Copacabana)
	_spawn_sign(container, Vector2(-160, -360), "FORTE", Color(0.85, 0.85, 0.9, 1), 16)
	_spawn_sign(container, Vector2(3050, -360), "LEME", Color(0.5, 0.85, 0.6, 1), 16)

# Forte de Copacabana — extrémité ouest. Petit promontoire rocheux avec une
# fortification militaire historique (mur épais blanc, deux canons, drapeau BR).
# x=-280..-50, y=128..200 (sur le sable). C'est le bord ouest de la map jouable.
func _spawn_forte() -> void:
	var container: Node2D = Node2D.new()
	container.name = "ForteDeCopacabana"
	add_child(container)
	# Promontoire rocheux qui s'avance dans la mer
	var rock: ColorRect = ColorRect.new()
	rock.offset_left = -290.0
	rock.offset_top = 140.0
	rock.offset_right = -40.0
	rock.offset_bottom = 360.0
	rock.color = Color(0.45, 0.42, 0.45, 1)
	container.add_child(rock)
	var rock_top: ColorRect = ColorRect.new()
	rock_top.offset_left = -270.0
	rock_top.offset_top = 130.0
	rock_top.offset_right = -70.0
	rock_top.offset_bottom = 145.0
	rock_top.color = Color(0.35, 0.32, 0.36, 1)
	container.add_child(rock_top)
	# Vegetation au sommet
	var veg: ColorRect = ColorRect.new()
	veg.offset_left = -250.0
	veg.offset_top = 124.0
	veg.offset_right = -90.0
	veg.offset_bottom = 132.0
	veg.color = Color(0.32, 0.55, 0.32, 0.85)
	container.add_child(veg)
	# Mur du fort (blanc, ouvert vers la mer)
	var fort_wall: ColorRect = ColorRect.new()
	fort_wall.offset_left = -240.0
	fort_wall.offset_top = 152.0
	fort_wall.offset_right = -100.0
	fort_wall.offset_bottom = 200.0
	fort_wall.color = Color(0.92, 0.88, 0.78, 1)
	container.add_child(fort_wall)
	# Créneaux du fort
	for cx in [-230.0, -210.0, -190.0, -170.0, -150.0, -130.0, -110.0]:
		var crenel: ColorRect = ColorRect.new()
		crenel.offset_left = cx - 4.0
		crenel.offset_top = 145.0
		crenel.offset_right = cx + 4.0
		crenel.offset_bottom = 152.0
		crenel.color = Color(0.92, 0.88, 0.78, 1)
		container.add_child(crenel)
	# Deux canons
	for cx in [-200.0, -140.0]:
		var cannon: ColorRect = ColorRect.new()
		cannon.offset_left = cx - 8.0
		cannon.offset_top = 156.0
		cannon.offset_right = cx + 8.0
		cannon.offset_bottom = 162.0
		cannon.color = Color(0.18, 0.18, 0.22, 1)
		container.add_child(cannon)
	# Drapeau brésilien
	var pole: ColorRect = ColorRect.new()
	pole.offset_left = -170.0
	pole.offset_top = 130.0
	pole.offset_right = -167.0
	pole.offset_bottom = 152.0
	pole.color = Color(0.32, 0.28, 0.22, 1)
	container.add_child(pole)
	var flag_g: ColorRect = ColorRect.new()
	flag_g.offset_left = -167.0
	flag_g.offset_top = 130.0
	flag_g.offset_right = -148.0
	flag_g.offset_bottom = 142.0
	flag_g.color = Color(0.18, 0.55, 0.32, 1)
	container.add_child(flag_g)
	var flag_y: ColorRect = ColorRect.new()
	flag_y.offset_left = -161.0
	flag_y.offset_top = 132.0
	flag_y.offset_right = -154.0
	flag_y.offset_bottom = 140.0
	flag_y.color = Color(0.95, 0.85, 0.18, 1)
	container.add_child(flag_y)
	_spawn_sign(container, Vector2(-200, 174), "FORTE DE COPACABANA", Color(0.55, 0.4, 0.32, 1), 8)

# Leme — extrémité est. Petit prolongement de la plage avec un rocher
# (Pedra do Leme) et une végétation montagneuse en arrière-plan, marquant la
# transition vers le tunnel pour Botafogo.
func _spawn_leme_rocks() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PedraDoLeme"
	add_child(container)
	# Rocher principal au bord de l'eau
	var rock: ColorRect = ColorRect.new()
	rock.offset_left = 2980.0
	rock.offset_top = 140.0
	rock.offset_right = 3180.0
	rock.offset_bottom = 380.0
	rock.color = Color(0.48, 0.45, 0.48, 1)
	container.add_child(rock)
	var rock_top: ColorRect = ColorRect.new()
	rock_top.offset_left = 3000.0
	rock_top.offset_top = 130.0
	rock_top.offset_right = 3160.0
	rock_top.offset_bottom = 145.0
	rock_top.color = Color(0.38, 0.35, 0.38, 1)
	container.add_child(rock_top)
	# Vegetation au sommet
	var veg: ColorRect = ColorRect.new()
	veg.offset_left = 3010.0
	veg.offset_top = 122.0
	veg.offset_right = 3150.0
	veg.offset_bottom = 132.0
	veg.color = Color(0.28, 0.5, 0.32, 0.9)
	container.add_child(veg)
	# Morro qui se prolonge au nord-est (vue sur les hills derrière le tunnel)
	var morro_back: ColorRect = ColorRect.new()
	morro_back.offset_left = 2900.0
	morro_back.offset_top = -350.0
	morro_back.offset_right = 3200.0
	morro_back.offset_bottom = -100.0
	morro_back.color = Color(0.32, 0.42, 0.35, 0.92)
	container.add_child(morro_back)
	# Tunnel arch (entrée vers Botafogo) — au nord-est de la map
	var tunnel: ColorRect = ColorRect.new()
	tunnel.offset_left = 3060.0
	tunnel.offset_top = -100.0
	tunnel.offset_right = 3160.0
	tunnel.offset_bottom = -40.0
	tunnel.color = Color(0.18, 0.16, 0.18, 1)
	container.add_child(tunnel)
	var tunnel_arch: ColorRect = ColorRect.new()
	tunnel_arch.offset_left = 3050.0
	tunnel_arch.offset_top = -110.0
	tunnel_arch.offset_right = 3170.0
	tunnel_arch.offset_bottom = -100.0
	tunnel_arch.color = Color(0.55, 0.5, 0.5, 1)
	container.add_child(tunnel_arch)
	# Le panneau "TÚNEL NOVO" a migré sur l'ExitToBotafogoNovo en x=2150 (Av.
	# Princesa Isabel). Ici on garde juste la silhouette du morro derrière la
	# Pedra do Leme — décor lointain, hors zone jouable.
	_spawn_sign(container, Vector2(3080, 174), "PEDRA DO LEME", Color(0.55, 0.4, 0.32, 1), 8)

func _spawn_sign(parent: Node, pos: Vector2, text: String, color: Color, size: int = 11) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

# Ajoute une vingtaine de passants ambiants sur Copacabana — joggers sur le
# calçadão, touristes sur l'av. Atlântica, baigneurs sur le sable, locaux dans
# la 2e rangée. Aucune interaction, aucun dialogue, juste de la vie.
func _spawn_ambient_wanderers() -> void:
	var container: Node2D = Node2D.new()
	container.name = "AmbientWanderers"
	add_child(container)
	var scene: PackedScene = load("res://scenes/props/AmbientWanderer.tscn")
	if scene == null:
		return
	# Joggers sur le calçadão (y=88..120 environ — pleine bande noir/blanc).
	_add_wanderer(container, scene, Vector2(400, 96), Color(0.4, 0.85, 0.55, 1), Vector2(9, 16),
		[Vector2(400, 96), Vector2(2100, 96)], 70.0, 0.2)
	_add_wanderer(container, scene, Vector2(1900, 110), Color(0.95, 0.55, 0.4, 1), Vector2(9, 16),
		[Vector2(1900, 110), Vector2(300, 110)], 60.0, 0.2)
	_add_wanderer(container, scene, Vector2(1100, 100), Color(0.4, 0.65, 0.95, 1), Vector2(9, 16),
		[Vector2(1100, 100), Vector2(2000, 100), Vector2(400, 100)], 55.0, 0.3)
	# Touristes sur l'Av. Atlântica (y=20..40).
	_add_wanderer(container, scene, Vector2(700, 30), Color(0.95, 0.85, 0.4, 1), Vector2(10, 18),
		[Vector2(700, 30), Vector2(1000, 30), Vector2(800, 50)], 24.0, 1.4)
	_add_wanderer(container, scene, Vector2(1500, 40), Color(0.4, 0.85, 0.55, 1), Vector2(10, 18),
		[Vector2(1500, 40), Vector2(1850, 50), Vector2(1700, 30)], 22.0, 1.6)
	_add_wanderer(container, scene, Vector2(1900, 30), Color(0.85, 0.4, 0.55, 1), Vector2(10, 18),
		[Vector2(1900, 30), Vector2(2150, 30), Vector2(1900, 50)], 18.0, 2.0)
	# Locaux 2e rangée (Nossa Senhora, y=-100..-60).
	_add_wanderer(container, scene, Vector2(500, -90), Color(0.55, 0.42, 0.32, 1), Vector2(10, 18),
		[Vector2(500, -90), Vector2(900, -90), Vector2(700, -70)], 28.0, 1.0)
	_add_wanderer(container, scene, Vector2(1300, -85), Color(0.42, 0.45, 0.5, 1), Vector2(10, 18),
		[Vector2(1300, -85), Vector2(1600, -85), Vector2(1450, -65)], 26.0, 1.2)
	# Baigneurs sur le sable (y=160..280) — petits, lents, longues pauses.
	_add_wanderer(container, scene, Vector2(450, 200), Color(0.95, 0.65, 0.55, 1), Vector2(11, 14),
		[Vector2(450, 200), Vector2(500, 230), Vector2(420, 220)], 10.0, 5.0)
	_add_wanderer(container, scene, Vector2(900, 240), Color(0.4, 0.65, 0.95, 1), Vector2(11, 14),
		[Vector2(900, 240), Vector2(950, 220), Vector2(880, 250)], 10.0, 5.0)
	_add_wanderer(container, scene, Vector2(1450, 200), Color(0.95, 0.85, 0.4, 1), Vector2(11, 14),
		[Vector2(1450, 200), Vector2(1500, 240), Vector2(1420, 220)], 10.0, 5.0)
	_add_wanderer(container, scene, Vector2(1850, 250), Color(0.85, 0.4, 0.55, 1), Vector2(11, 14),
		[Vector2(1850, 250), Vector2(1900, 220), Vector2(1820, 240)], 10.0, 5.0)
	# Enfants qui jouent près des postes (y=190..210).
	_add_wanderer(container, scene, Vector2(700, 200), Color(0.4, 0.85, 0.55, 1), Vector2(7, 12),
		[Vector2(700, 200), Vector2(750, 180), Vector2(680, 220), Vector2(720, 200)], 38.0, 0.4)
	_add_wanderer(container, scene, Vector2(1200, 195), Color(0.95, 0.85, 0.2, 1), Vector2(7, 12),
		[Vector2(1200, 195), Vector2(1240, 215), Vector2(1170, 200)], 36.0, 0.4)
	# Skaters près du palace côté est (y=120..130 sur calçadão).
	_add_wanderer(container, scene, Vector2(2050, 130), Color(0.85, 0.3, 0.5, 1), Vector2(10, 16),
		[Vector2(2050, 130), Vector2(2150, 110), Vector2(1980, 150), Vector2(2080, 130)], 50.0, 0.3)
	# Vendeur ambulant qui longe la plage (y=180).
	_add_wanderer(container, scene, Vector2(300, 180), Color(0.85, 0.55, 0.4, 1), Vector2(10, 17),
		[Vector2(300, 180), Vector2(2150, 180)], 22.0, 3.0)
	# Couple sur l'Av. Atlântica.
	_add_wanderer(container, scene, Vector2(1100, 50), Color(0.85, 0.42, 0.55, 1), Vector2(10, 18),
		[Vector2(1100, 50), Vector2(1300, 50), Vector2(1100, 30)], 16.0, 2.4)
	_add_wanderer(container, scene, Vector2(1108, 50), Color(0.4, 0.55, 0.95, 1), Vector2(10, 18),
		[Vector2(1108, 50), Vector2(1308, 50), Vector2(1108, 30)], 16.0, 2.4)
	# Surveillance discrète : un PM qui patrouille (y=-80, le long de Nossa Senhora).
	_add_wanderer(container, scene, Vector2(1180, -80), Color(0.18, 0.32, 0.62, 1), Vector2(10, 18),
		[Vector2(1180, -80), Vector2(1500, -80), Vector2(1000, -80)], 30.0, 1.5,
		Color(0.18, 0.18, 0.22, 1), Color(0.18, 0.32, 0.62, 1), true)
	# Touriste avec chapeau de paille sur l'Av. Atlântica.
	_add_wanderer(container, scene, Vector2(800, 30), Color(0.95, 0.55, 0.4, 1), Vector2(10, 18),
		[Vector2(800, 30), Vector2(600, 50), Vector2(900, 30)], 18.0, 2.5,
		Color(0.18, 0.12, 0.08, 1), Color(0.92, 0.85, 0.55, 1), true)
	# Vendeur de glaces avec casquette blanche.
	_add_wanderer(container, scene, Vector2(1600, 200), Color(0.95, 0.95, 0.95, 1), Vector2(10, 17),
		[Vector2(1600, 200), Vector2(1200, 200), Vector2(2000, 200)], 16.0, 2.8,
		Color(0.18, 0.12, 0.08, 1), Color(0.95, 0.95, 0.92, 1), true)

func _add_wanderer(container: Node, scene: PackedScene, pos: Vector2, color: Color, size: Vector2,
		path: Array, speed: float, pause: float,
		hair: Color = Color(0.18, 0.12, 0.08, 1),
		hat_color: Color = Color(0.85, 0.85, 0.4, 1),
		hat: bool = false) -> void:
	var w: Node2D = scene.instantiate() as Node2D
	if w == null:
		return
	w.position = pos
	# Cast typé : path en Array[Vector2] requis par AmbientWanderer.
	var typed_path: Array[Vector2] = []
	for p in path:
		typed_path.append(p)
	w.set("color", color)
	w.set("size", size)
	w.set("path", typed_path)
	w.set("speed", speed)
	w.set("pause_at_waypoints", pause)
	w.set("hair_color", hair)
	w.set("hat_color", hat_color)
	w.set("hat", hat)
	container.add_child(w)
