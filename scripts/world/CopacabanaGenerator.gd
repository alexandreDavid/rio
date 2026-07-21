extends AmbientDrifter

# Génère procéduralement les bâtiments, postes et marqueurs de zone.
# Étend AmbientDrifter pour faire dériver les mouettes et bateaux décoratifs
# placés dans Copacabana.tscn (groupes drift_west / drift_east / drift_bob).
# Géographie réelle : LEME à l'est (droite, x haut), FORTE à l'ouest (gauche, x bas).
# 6 postos comme en vrai : Posto 1 (près de Leme) à Posto 6 (collé au fort).
# Constantes de layout/tileset extraites dans CopacabanaConfig.gd (préchargé Cfg).

const Cfg = preload("res://scripts/world/CopacabanaConfig.gd")


@export var map_start_x: float = 160.0
@export var map_end_x: float = 2200.0
@export var building_count: int = 14

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
	# Drift décoratif (mouettes, bateaux, kite) hérité d'AmbientDrifter.
	super._ready()
	_spawn_interiors()
	_spawn_sand()
	_spawn_sea()
	_spawn_sea_foam()
	_spawn_shore_collision()
	_spawn_cagarras_islands()
	_spawn_roads()
	_spawn_ciclovia()
	_spawn_cross_streets()
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
	_spawn_metro_entrances()
	_spawn_favelas()
	_spawn_botafogo_tunnels()
	_spawn_calcadao()
	_spawn_quiosques()
	_spawn_beach_props()
	_spawn_sand_sculpture()
	_spawn_postos()
	_spawn_fishing_colony()
	_spawn_forte()
	_spawn_leme_rocks()
	_spawn_zone_markers()
	_spawn_streetlamps()
	_spawn_ambient_wanderers()
	_spawn_evening_life()
	_spawn_bloco_rehearsal()
	_spawn_ze_memories()
	_spawn_domingo_life()
	_spawn_human_cost()
	_spawn_reinado()

func _spawn_tile_strip(container_name: String, y_top: float, y_bot: float, tile_region: Rect2, z_idx: int = -5) -> void:
	var container: Node2D = Node2D.new()
	container.name = container_name
	container.z_index = z_idx
	add_child(container)
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	var scale: Vector2 = Vector2(Cfg.GROUND_TILE_SIZE / tile_region.size.x, Cfg.GROUND_TILE_SIZE / tile_region.size.y)
	var cols: int = int(ceil(Cfg.MAP_TOTAL_W / Cfg.GROUND_TILE_SIZE))
	var rows: int = int(ceil((y_bot - y_top) / Cfg.GROUND_TILE_SIZE))
	for row in rows:
		for col in cols:
			var s: Sprite2D = Sprite2D.new()
			s.texture = tex
			s.region_enabled = true
			s.region_rect = tile_region
			s.scale = scale
			s.position = Vector2(Cfg.MAP_LEFT + col * Cfg.GROUND_TILE_SIZE + Cfg.GROUND_TILE_SIZE * 0.5, y_top + row * Cfg.GROUND_TILE_SIZE + Cfg.GROUND_TILE_SIZE * 0.5)
			container.add_child(s)

func _spawn_sand() -> void:
	# Le sable descend jusqu'au rivage le plus profond (SHORE_EDGE_Y) ; la mer,
	# dessinée après au même z-index, recouvre l'excédent selon la courbe de baie.
	_spawn_tile_strip("SandTiles", 128.0, 448.0, Cfg.SAND_TILE_REGION)

func _spawn_sea() -> void:
	# La mer suit la courbe de la baie : chaque colonne de tuiles démarre à
	# Cfg.shore_y(x) (croissant de Copacabana, mer au plus proche au centre).
	var container: Node2D = Node2D.new()
	container.name = "SeaTiles"
	container.z_index = -5
	add_child(container)
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	var region: Rect2 = Cfg.WATER_TILE_REGION
	var scale: Vector2 = Vector2(Cfg.GROUND_TILE_SIZE / region.size.x, Cfg.GROUND_TILE_SIZE / region.size.y)
	var cols: int = int(ceil(Cfg.MAP_TOTAL_W / Cfg.GROUND_TILE_SIZE))
	for col in cols:
		var cx: float = Cfg.MAP_LEFT + col * Cfg.GROUND_TILE_SIZE + Cfg.GROUND_TILE_SIZE * 0.5
		var top: float = Cfg.shore_y(cx)
		var rows: int = int(ceil((600.0 - top) / Cfg.GROUND_TILE_SIZE))
		for row in rows:
			var s: Sprite2D = Sprite2D.new()
			s.texture = tex
			s.region_enabled = true
			s.region_rect = region
			s.scale = scale
			s.position = Vector2(cx, top + row * Cfg.GROUND_TILE_SIZE + Cfg.GROUND_TILE_SIZE * 0.5)
			container.add_child(s)

# Collision du rivage : empêche le joueur de marcher sur l'eau, en suivant la
# courbe de la baie (avec ~14 px de tolérance — on peut se mouiller les pieds).
func _spawn_shore_collision() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "ShoreCollision"
	add_child(body)
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = Cfg.MAP_LEFT
	while x <= Cfg.MAP_RIGHT:
		points.append(Vector2(x, Cfg.shore_y(x) + 14.0))
		x += 100.0
	points.append(Vector2(Cfg.MAP_RIGHT, Cfg.shore_y(Cfg.MAP_RIGHT) + 14.0))
	points.append(Vector2(Cfg.MAP_RIGHT, 640.0))
	points.append(Vector2(Cfg.MAP_LEFT, 640.0))
	poly.polygon = points
	body.add_child(poly)

func _spawn_roads() -> void:
	# Av. Atlântica (proche calçadão)
	_spawn_tile_strip("AvAtlanticaTiles", 0.0, 64.0, Cfg.ROAD_TILE_REGION)
	# Nossa Senhora de Copacabana (côté intérieur)
	_spawn_tile_strip("NossaSenhoraTiles", -128.0, -64.0, Cfg.ROAD_TILE_REGION)

# Ciclovia de l'Av. Atlântica : bande terracotta côté plage avec ligne médiane
# en pointillés blancs — la piste cyclable iconique du front de mer carioca.
func _spawn_ciclovia() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Ciclovia"
	container.z_index = -4
	add_child(container)
	var band: ColorRect = ColorRect.new()
	band.offset_left = Cfg.MAP_LEFT
	band.offset_top = Cfg.CICLOVIA_TOP
	band.offset_right = Cfg.MAP_RIGHT
	band.offset_bottom = Cfg.CICLOVIA_BOT
	band.color = Cfg.CICLOVIA_COLOR
	container.add_child(band)
	var mid_y: float = (Cfg.CICLOVIA_TOP + Cfg.CICLOVIA_BOT) * 0.5
	var x: float = Cfg.MAP_LEFT + 20.0
	while x < Cfg.MAP_RIGHT - 20.0:
		var dash: ColorRect = ColorRect.new()
		dash.offset_left = x
		dash.offset_top = mid_y - 1.0
		dash.offset_right = x + 14.0
		dash.offset_bottom = mid_y + 1.0
		dash.color = Color(0.95, 0.95, 0.92, 0.85)
		container.add_child(dash)
		x += 80.0

# Rues transversales réelles : bande de route verticale reliant l'Av. Atlântica
# à la bande favela, passage piéton sur l'Av. Atlântica et plaque de rue.
func _spawn_cross_streets() -> void:
	var container: Node2D = Node2D.new()
	container.name = "CrossStreets"
	add_child(container)
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	for st in Cfg.CROSS_STREETS:
		# Chaussée : colonne de tuiles asphalte de y=-192 (bande favela) à y=0.
		var strip: Node2D = Node2D.new()
		strip.z_index = -5
		container.add_child(strip)
		var rows: int = 3
		for row in rows:
			var s: Sprite2D = Sprite2D.new()
			s.texture = tex
			s.region_enabled = true
			s.region_rect = Cfg.ROAD_TILE_REGION
			s.scale = Vector2(st.w / Cfg.ROAD_TILE_REGION.size.x, Cfg.GROUND_TILE_SIZE / Cfg.ROAD_TILE_REGION.size.y)
			s.position = Vector2(st.x, -192.0 + row * Cfg.GROUND_TILE_SIZE + Cfg.GROUND_TILE_SIZE * 0.5)
			strip.add_child(s)
		# Faixa de pedestres : bandes blanches qui traversent l'Av. Atlântica.
		var cross: Node2D = Node2D.new()
		cross.z_index = -4
		container.add_child(cross)
		for i in 5:
			var stripe: ColorRect = ColorRect.new()
			stripe.offset_left = st.x - st.w * 0.5 + 4.0
			stripe.offset_top = 8.0 + i * 9.0
			stripe.offset_right = st.x + st.w * 0.5 - 4.0
			stripe.offset_bottom = 8.0 + i * 9.0 + 4.0
			stripe.color = Color(0.95, 0.95, 0.92, 0.8)
			cross.add_child(stripe)
		# Plaque de rue côté Av. Atlântica (les noms côté favela sont sur les tunnels).
		_spawn_sign(container, Vector2(st.x - st.w * 0.5 - 30.0, -48.0), st.name, Color(0.65, 0.82, 0.95, 1), 8)

# Ilhas Cagarras à l'horizon — l'archipel visible au large de la plage, et
# point de rendez-vous de la quête trafico_a6_cagarras ("au large du Posto 6").
func _spawn_cagarras_islands() -> void:
	var container: Node2D = Node2D.new()
	container.name = "IlhasCagarras"
	container.z_index = -4
	add_child(container)
	var islets: Array = [
		Rect2(420, 522, 40, 16),
		Rect2(472, 538, 24, 10),
		Rect2(508, 528, 30, 13),
	]
	for r in islets:
		var rock: ColorRect = ColorRect.new()
		rock.offset_left = r.position.x
		rock.offset_top = r.position.y
		rock.offset_right = r.position.x + r.size.x
		rock.offset_bottom = r.position.y + r.size.y
		rock.color = Color(0.30, 0.36, 0.40, 0.95)
		container.add_child(rock)
		var veg: ColorRect = ColorRect.new()
		veg.offset_left = r.position.x + 3.0
		veg.offset_top = r.position.y - 3.0
		veg.offset_right = r.position.x + r.size.x - 3.0
		veg.offset_bottom = r.position.y + 2.0
		veg.color = Color(0.26, 0.42, 0.32, 0.9)
		container.add_child(veg)
	_spawn_sign(container, Vector2(430, 552), "ILHAS CAGARRAS", Color(0.75, 0.85, 0.9, 0.75), 8)

func _spawn_building_row_ground() -> void:
	# Dalles trottoir sur les rangées où se posent les bâtiments pour éviter
	# que le fond bleu ciel apparaisse dans les interstices entre immeubles.
	_spawn_tile_strip("FirstRowGround", -64.0, 0.0, Cfg.SIDEWALK_TILE_REGION, -6)
	_spawn_tile_strip("SecondRowGround", -192.0, -128.0, Cfg.SIDEWALK_TILE_REGION, -6)

func _spawn_sea_foam() -> void:
	# Bande d'écume sable/mer qui épouse la courbe de la baie (Cfg.shore_y).
	var container: Node2D = Node2D.new()
	container.name = "SeaFoam"
	container.z_index = -4
	add_child(container)
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	var strip_h: float = 32.0
	var tile_w: float = 96.0
	var tile_count: int = int(ceil(Cfg.MAP_TOTAL_W / tile_w))
	var scale_x: float = tile_w / Cfg.FOAM_TILE_REGION.size.x
	var scale_y: float = strip_h / Cfg.FOAM_TILE_REGION.size.y
	for i in tile_count:
		var cx: float = Cfg.MAP_LEFT + i * tile_w + tile_w * 0.5
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = Cfg.FOAM_TILE_REGION
		s.scale = Vector2(scale_x, scale_y)
		s.position = Vector2(cx, Cfg.shore_y(cx) + strip_h * 0.5 - 8.0)
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
		{"region": Cfg.UMBRELLA_YELLOW_REGION, "h": 70.0},
		{"region": Cfg.UMBRELLA_RED_REGION, "h": 70.0},
		{"region": Cfg.UMBRELLA_BLUE_REGION, "h": 80.0},
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
	# Rangée de palmiers tout le long du front de mer (comme sur la vraie
	# Av. Atlântica), en évitant les postos et la sculpture de sable.
	var palm_x: float = 240.0
	while palm_x <= 2160.0:
		var near_posto: bool = false
		var posto_step: float = (Cfg.POSTO_END_X - Cfg.POSTO_START_X) / float(Cfg.POSTO_COUNT - 1)
		for p in Cfg.POSTO_COUNT:
			if abs(palm_x - (Cfg.POSTO_START_X + p * posto_step)) < 55.0:
				near_posto = true
				break
		if not near_posto and abs(palm_x - 1560.0) > 55.0:
			_spawn_prop_sprite(container, Cfg.PALM_TREE_REGION, Vector2(palm_x, 180.0), rng.randf_range(95.0, 120.0))
		palm_x += rng.randf_range(200.0, 260.0)

func _spawn_prop_sprite(parent: Node, region: Rect2, pos: Vector2, target_height: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = load(Cfg.TILESET_TEXTURE)
	s.region_enabled = true
	s.region_rect = region
	var scale_factor: float = target_height / region.size.y
	s.scale = Vector2(scale_factor, scale_factor)
	# Ancrage par la base (sprite 2D par défaut centré ; on décale pour que le pied touche pos.y)
	s.position = Vector2(pos.x, pos.y - (region.size.y * scale_factor) * 0.5)
	parent.add_child(s)

func _spawn_interiors() -> void:
	_shop_spawn = _instantiate_interior(Cfg.SHOP_INT_SCENE, Cfg.INT_SHOP_POS)
	_bar_spawn = _instantiate_interior(Cfg.BAR_INT_SCENE, Cfg.INT_BAR_POS)
	_police_spawn = _instantiate_interior(Cfg.POLICE_INT_SCENE, Cfg.INT_POLICE_POS)
	_palace_spawn = _instantiate_interior(Cfg.PALACE_INT_SCENE, Cfg.INT_PALACE_POS)
	_church_spawn = _instantiate_interior(Cfg.CHURCH_INT_SCENE, Cfg.INT_CHURCH_POS)
	_restaurant_spawn = _instantiate_interior(Cfg.RESTAURANT_INT_SCENE, Cfg.INT_RESTAURANT_POS)
	_mercadinho_spawn = _instantiate_interior(Cfg.MERCADINHO_INT_SCENE, Cfg.INT_MERCADINHO_POS)
	_pharmacy_spawn = _instantiate_interior(Cfg.PHARMACY_INT_SCENE, Cfg.INT_PHARMACY_POS)
	_padaria_spawn = _instantiate_interior(Cfg.PADARIA_INT_SCENE, Cfg.INT_PADARIA_POS)

func _instantiate_interior(scene: PackedScene, pos: Vector2) -> Vector2:
	var interior: Node2D = scene.instantiate()
	interior.position = pos
	add_child(interior)
	var marker: Node = interior.get_node_or_null("SpawnPoint")
	if marker and marker is Node2D:
		return (marker as Node2D).global_position
	return pos

func _add_door(parent: Node, building_pos: Vector2, half_height: float, destination: Vector2, prompt: String = "Entrer") -> void:
	var door: Node2D = Cfg.BUILDING_DOOR_SCENE.instantiate()
	door.position = building_pos + Vector2(0, half_height + Cfg.DOOR_OFFSET_Y)
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
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	var scale_factor: float = Cfg.CALCADAO_TILE_SIZE / Cfg.CALCADAO_TILE_REGION.size.x
	var tile_count: int = int(ceil(Cfg.MAP_TOTAL_W / Cfg.CALCADAO_TILE_SIZE))
	for i in tile_count:
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = Cfg.CALCADAO_TILE_REGION
		s.scale = Vector2(scale_factor, scale_factor)
		s.position = Vector2(Cfg.MAP_LEFT + i * Cfg.CALCADAO_TILE_SIZE + Cfg.CALCADAO_TILE_SIZE * 0.5, Cfg.CALCADAO_Y + Cfg.CALCADAO_HEIGHT * 0.5)
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
		if abs(x - Cfg.PALACE_X) < Cfg.PALACE_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		# Skip commerces
		var skip: bool = false
		for c in Cfg.COMMERCES:
			if abs(x - c.x) < Cfg.COMMERCE_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
				skip = true
				break
		if skip:
			continue
		# Skip les rues transversales (Santa Clara, Siqueira Campos, Princesa Isabel)
		if _near_cross_street(x):
			continue
		var color: Color = Cfg.BUILDING_COLORS[i % Cfg.BUILDING_COLORS.size()]
		_spawn_building(container, Vector2(x, Cfg.BUILDING_Y), color)

func _near_cross_street(x: float) -> bool:
	for st in Cfg.CROSS_STREETS:
		if abs(x - st.x) < st.w * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			return true
	return false

func _spawn_building(parent: Node, pos: Vector2, color: Color) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	parent.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.BUILDING_SIZE
	shape.shape = rect
	body.add_child(shape)

	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.BUILDING_SIZE.x * 0.5
	facade.offset_top = -Cfg.BUILDING_SIZE.y * 0.5
	facade.offset_right = Cfg.BUILDING_SIZE.x * 0.5
	facade.offset_bottom = Cfg.BUILDING_SIZE.y * 0.5
	facade.color = color
	body.add_child(facade)

	for j in 3:
		var win: ColorRect = ColorRect.new()
		var wx: float = -30.0 + j * 22.0
		win.offset_left = wx
		win.offset_top = -20.0
		win.offset_right = wx + 12.0
		win.offset_bottom = -8.0
		win.color = Cfg.WINDOW_COLOR
		body.add_child(win)

	var door: ColorRect = ColorRect.new()
	door.offset_left = -6.0
	door.offset_top = 12.0
	door.offset_right = 6.0
	door.offset_bottom = 32.0
	door.color = Cfg.DOOR_COLOR
	body.add_child(door)

func _spawn_palace() -> void:
	var container: Node2D = Node2D.new()
	container.name = "CopacabanaPalace"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.PALACE_X, Cfg.PALACE_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.PALACE_SIZE
	shape.shape = rect
	body.add_child(shape)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(Cfg.BUILDINGS_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = Cfg.PALACE_REGION
	sprite.scale = Vector2(Cfg.BUILDINGS_SCALE, Cfg.BUILDINGS_SCALE)
	body.add_child(sprite)

	_add_door(container, Vector2(Cfg.PALACE_X, Cfg.PALACE_Y), Cfg.PALACE_SIZE.y * 0.5, _palace_spawn, "Entrer au palace")

func _spawn_second_row() -> void:
	var container: Node2D = Node2D.new()
	container.name = "SecondRowBuildings"
	add_child(container)
	var count: int = 10
	var step: float = (map_end_x - map_start_x) / float(count - 1)
	for i in count:
		var x: float = map_start_x + i * step
		# Skip la zone du poste de police
		if abs(x - Cfg.POLICE_X) < Cfg.POLICE_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone du bar du policier
		if abs(x - Cfg.COP_BAR_X) < Cfg.COP_BAR_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone de l'Academia
		if abs(x - Cfg.ACADEMIA_X) < Cfg.ACADEMIA_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		# Skip la zone de la Favela do Morro (x=60-260)
		if x >= 60.0 and x <= 260.0:
			continue
		# Skip église, pharmacie et padaria — ils sont sur Nossa Senhora désormais.
		if abs(x - Cfg.CHURCH_X) < Cfg.CHURCH_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		if abs(x - Cfg.PHARMACY_X) < Cfg.PHARMACY_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		if abs(x - Cfg.PADARIA_X) < Cfg.PADARIA_SIZE.x * 0.5 + Cfg.BUILDING_SIZE.x * 0.5:
			continue
		# Skip les rues transversales (elles traversent les deux rangées)
		if _near_cross_street(x):
			continue
		var color: Color = Cfg.BUILDING_COLORS[(i + 2) % Cfg.BUILDING_COLORS.size()]
		_spawn_building(container, Vector2(x, Cfg.SECOND_ROW_Y), color)

func _spawn_police_station() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PoliceStation"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.POLICE_X, Cfg.SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.POLICE_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Bande supérieure bleu police
	var top_band: ColorRect = ColorRect.new()
	top_band.offset_left = -Cfg.POLICE_SIZE.x * 0.5 - 4
	top_band.offset_top = -Cfg.POLICE_SIZE.y * 0.5 - 6
	top_band.offset_right = Cfg.POLICE_SIZE.x * 0.5 + 4
	top_band.offset_bottom = -Cfg.POLICE_SIZE.y * 0.5 + 8
	top_band.color = Color(0.18, 0.3, 0.6, 1)
	body.add_child(top_band)

	# Façade blanc cassé
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.POLICE_SIZE.x * 0.5
	facade.offset_top = -Cfg.POLICE_SIZE.y * 0.5
	facade.offset_right = Cfg.POLICE_SIZE.x * 0.5
	facade.offset_bottom = Cfg.POLICE_SIZE.y * 0.5
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
	gyro.offset_top = -Cfg.POLICE_SIZE.y * 0.5 - 14
	gyro.offset_right = 6.0
	gyro.offset_bottom = -Cfg.POLICE_SIZE.y * 0.5 - 4
	gyro.color = Color(0.85, 0.2, 0.2, 1)
	body.add_child(gyro)

	# Enseigne POLÍCIA
	var label: Label = Label.new()
	label.text = "POLÍCIA"
	label.position = Vector2(Cfg.POLICE_X - 28, Cfg.SECOND_ROW_Y - Cfg.POLICE_SIZE.y * 0.5 + 2)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	label.add_theme_font_size_override("font_size", 10)
	container.add_child(label)

	_add_door(container, Vector2(Cfg.POLICE_X, Cfg.SECOND_ROW_Y), Cfg.POLICE_SIZE.y * 0.5, _police_spawn, "Entrer au poste")

func _spawn_academia() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Academia"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.ACADEMIA_X, Cfg.SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.ACADEMIA_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Auvent orange sport
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -Cfg.ACADEMIA_SIZE.x * 0.5 - 4
	awning.offset_top = -Cfg.ACADEMIA_SIZE.y * 0.5 - 8
	awning.offset_right = Cfg.ACADEMIA_SIZE.x * 0.5 + 4
	awning.offset_bottom = -Cfg.ACADEMIA_SIZE.y * 0.5 + 10
	awning.color = Color(0.9, 0.45, 0.18, 1)
	body.add_child(awning)

	# Façade blanche
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.ACADEMIA_SIZE.x * 0.5
	facade.offset_top = -Cfg.ACADEMIA_SIZE.y * 0.5
	facade.offset_right = Cfg.ACADEMIA_SIZE.x * 0.5
	facade.offset_bottom = Cfg.ACADEMIA_SIZE.y * 0.5
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
	label.position = Vector2(Cfg.ACADEMIA_X - 32, Cfg.SECOND_ROW_Y - Cfg.ACADEMIA_SIZE.y * 0.5 - 4)
	label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.22, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive : Academia possède un intérieur dédié au gym
	var academia_spawn: Vector2 = Vector2(700, -1920)
	_add_door(container, Vector2(Cfg.ACADEMIA_X, Cfg.SECOND_ROW_Y), Cfg.ACADEMIA_SIZE.y * 0.5, academia_spawn, "Entrer à l'Academia")

func _spawn_commerces() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Commerces"
	add_child(container)
	# Chaque commerce route vers son propre intérieur — pas de partage.
	# Cfg.COMMERCES[0] = x=500 → Mercadinho ; [1] = x=1050 → Cantinho Carioca ; [2] = x=1900 → Rio Style.
	var routing: Array = [
		{"spawn": _mercadinho_spawn, "prompt": "Entrer au Mercadinho"},
		{"spawn": _restaurant_spawn, "prompt": "Entrer au Cantinho Carioca"},
		{"spawn": _shop_spawn,       "prompt": "Entrer chez Rio Style"},
	]
	for i in Cfg.COMMERCES.size():
		var c: Dictionary = Cfg.COMMERCES[i]
		var r: Dictionary = routing[i]
		_spawn_commerce(container, c.x, c.region, r.spawn, r.prompt)

func _spawn_commerce(parent: Node, x: float, region: Rect2, spawn: Vector2, prompt: String) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(x, Cfg.BUILDING_Y)
	parent.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.COMMERCE_SIZE
	shape.shape = rect
	body.add_child(shape)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(Cfg.BUILDINGS_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = Vector2(Cfg.BUILDINGS_SCALE, Cfg.BUILDINGS_SCALE)
	body.add_child(sprite)

	_add_door(parent, Vector2(x, Cfg.BUILDING_Y), Cfg.COMMERCE_SIZE.y * 0.5, spawn, prompt)

func _spawn_cop_bar() -> void:
	var container: Node2D = Node2D.new()
	container.name = "CopBar"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.COP_BAR_X, Cfg.SECOND_ROW_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.COP_BAR_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Auvent bleu-marine
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -Cfg.COP_BAR_SIZE.x * 0.5 - 4
	awning.offset_top = -Cfg.COP_BAR_SIZE.y * 0.5 - 4
	awning.offset_right = Cfg.COP_BAR_SIZE.x * 0.5 + 4
	awning.offset_bottom = -Cfg.COP_BAR_SIZE.y * 0.5 + 12
	awning.color = Color(0.18, 0.28, 0.5, 1)
	body.add_child(awning)

	# Façade brique
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.COP_BAR_SIZE.x * 0.5
	facade.offset_top = -Cfg.COP_BAR_SIZE.y * 0.5
	facade.offset_right = Cfg.COP_BAR_SIZE.x * 0.5
	facade.offset_bottom = Cfg.COP_BAR_SIZE.y * 0.5
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
	label.position = Vector2(Cfg.COP_BAR_X - 46, Cfg.SECOND_ROW_Y - 50)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1))
	label.add_theme_font_size_override("font_size", 9)
	container.add_child(label)

	_add_door(container, Vector2(Cfg.COP_BAR_X, Cfg.SECOND_ROW_Y), Cfg.COP_BAR_SIZE.y * 0.5, _bar_spawn, "Entrer au bar")

func _spawn_church() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Igreja"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.CHURCH_X, Cfg.CHURCH_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.CHURCH_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade pierre claire
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.CHURCH_SIZE.x * 0.5
	facade.offset_top = -Cfg.CHURCH_SIZE.y * 0.5
	facade.offset_right = Cfg.CHURCH_SIZE.x * 0.5
	facade.offset_bottom = Cfg.CHURCH_SIZE.y * 0.5
	facade.color = Color(0.92, 0.88, 0.78, 1)
	body.add_child(facade)

	# Toit triangulaire (effet via rectangle sombre au-dessus)
	var roof: ColorRect = ColorRect.new()
	roof.offset_left = -Cfg.CHURCH_SIZE.x * 0.5 - 6
	roof.offset_top = -Cfg.CHURCH_SIZE.y * 0.5 - 12
	roof.offset_right = Cfg.CHURCH_SIZE.x * 0.5 + 6
	roof.offset_bottom = -Cfg.CHURCH_SIZE.y * 0.5 + 4
	roof.color = Color(0.45, 0.32, 0.22, 1)
	body.add_child(roof)

	# Clocher central
	var bell_tower: ColorRect = ColorRect.new()
	bell_tower.offset_left = -10.0
	bell_tower.offset_top = -Cfg.CHURCH_SIZE.y * 0.5 - 32.0
	bell_tower.offset_right = 10.0
	bell_tower.offset_bottom = -Cfg.CHURCH_SIZE.y * 0.5 - 4.0
	bell_tower.color = Color(0.92, 0.88, 0.78, 1)
	body.add_child(bell_tower)

	# Croix sur le clocher (vertical + horizontal)
	var cross_v: ColorRect = ColorRect.new()
	cross_v.offset_left = -2.0
	cross_v.offset_top = -Cfg.CHURCH_SIZE.y * 0.5 - 48.0
	cross_v.offset_right = 2.0
	cross_v.offset_bottom = -Cfg.CHURCH_SIZE.y * 0.5 - 30.0
	cross_v.color = Color(0.25, 0.18, 0.12, 1)
	body.add_child(cross_v)
	var cross_h: ColorRect = ColorRect.new()
	cross_h.offset_left = -7.0
	cross_h.offset_top = -Cfg.CHURCH_SIZE.y * 0.5 - 42.0
	cross_h.offset_right = 7.0
	cross_h.offset_bottom = -Cfg.CHURCH_SIZE.y * 0.5 - 38.0
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
	door.offset_bottom = Cfg.CHURCH_SIZE.y * 0.5
	door.color = Color(0.45, 0.30, 0.20, 1)
	body.add_child(door)

	# Enseigne IGREJA
	var label: Label = Label.new()
	label.text = "✝ IGREJA NOSSA SENHORA"
	label.position = Vector2(Cfg.CHURCH_X - 80, Cfg.CHURCH_Y - Cfg.CHURCH_SIZE.y * 0.5 - 60.0)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive vers l'intérieur de l'église.
	_add_door(container, Vector2(Cfg.CHURCH_X, Cfg.CHURCH_Y), Cfg.CHURCH_SIZE.y * 0.5, _church_spawn, "Entrer dans l'église")

func _spawn_pharmacy() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Farmacia"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.PHARMACY_X, Cfg.PHARMACY_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.PHARMACY_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade blanche
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.PHARMACY_SIZE.x * 0.5
	facade.offset_top = -Cfg.PHARMACY_SIZE.y * 0.5
	facade.offset_right = Cfg.PHARMACY_SIZE.x * 0.5
	facade.offset_bottom = Cfg.PHARMACY_SIZE.y * 0.5
	facade.color = Color(0.97, 0.97, 0.95, 1)
	body.add_child(facade)

	# Bandeau vert sur le toit (couleur pharmacie)
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -Cfg.PHARMACY_SIZE.x * 0.5 - 4
	awning.offset_top = -Cfg.PHARMACY_SIZE.y * 0.5 - 6
	awning.offset_right = Cfg.PHARMACY_SIZE.x * 0.5 + 4
	awning.offset_bottom = -Cfg.PHARMACY_SIZE.y * 0.5 + 8
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
	door.offset_bottom = Cfg.PHARMACY_SIZE.y * 0.5
	door.color = Color(0.35, 0.55, 0.45, 1)
	body.add_child(door)

	# Enseigne FARMACIA
	var label: Label = Label.new()
	label.text = "+ FARMÁCIA"
	label.position = Vector2(Cfg.PHARMACY_X - 36, Cfg.PHARMACY_Y - Cfg.PHARMACY_SIZE.y * 0.5 - 32.0)
	label.add_theme_color_override("font_color", Color(0.18, 0.55, 0.35, 1))
	label.add_theme_font_size_override("font_size", 12)
	container.add_child(label)

	# Porte interactive vers l'intérieur de la pharmacie.
	_add_door(container, Vector2(Cfg.PHARMACY_X, Cfg.PHARMACY_Y), Cfg.PHARMACY_SIZE.y * 0.5, _pharmacy_spawn, "Entrer dans la pharmacie")

func _spawn_padaria() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Padaria"
	add_child(container)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(Cfg.PADARIA_X, Cfg.PADARIA_Y)
	container.add_child(body)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Cfg.PADARIA_SIZE
	shape.shape = rect
	body.add_child(shape)

	# Façade beige clair (style boulangerie populaire).
	var facade: ColorRect = ColorRect.new()
	facade.offset_left = -Cfg.PADARIA_SIZE.x * 0.5
	facade.offset_top = -Cfg.PADARIA_SIZE.y * 0.5
	facade.offset_right = Cfg.PADARIA_SIZE.x * 0.5
	facade.offset_bottom = Cfg.PADARIA_SIZE.y * 0.5
	facade.color = Color(0.95, 0.85, 0.65, 1)
	body.add_child(facade)

	# Auvent à rayures rouge-blanc (typique des padarias brésiliennes).
	var awning: ColorRect = ColorRect.new()
	awning.offset_left = -Cfg.PADARIA_SIZE.x * 0.5 - 4
	awning.offset_top = -Cfg.PADARIA_SIZE.y * 0.5 - 6
	awning.offset_right = Cfg.PADARIA_SIZE.x * 0.5 + 4
	awning.offset_bottom = -Cfg.PADARIA_SIZE.y * 0.5 + 8
	awning.color = Color(0.85, 0.25, 0.25, 1)
	body.add_child(awning)
	# 3 bandes blanches verticales sur l'auvent.
	for i in 3:
		var stripe: ColorRect = ColorRect.new()
		var sx: float = -30.0 + i * 30.0
		stripe.offset_left = sx
		stripe.offset_top = -Cfg.PADARIA_SIZE.y * 0.5 - 6
		stripe.offset_right = sx + 8
		stripe.offset_bottom = -Cfg.PADARIA_SIZE.y * 0.5 + 8
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
	door.offset_bottom = Cfg.PADARIA_SIZE.y * 0.5
	door.color = Color(0.45, 0.30, 0.20, 1)
	body.add_child(door)

	# Enseigne PADARIA SAO SEBASTIAO.
	var label: Label = Label.new()
	label.text = "🥖 PADARIA SÃO SEBASTIÃO"
	label.position = Vector2(Cfg.PADARIA_X - 70, Cfg.PADARIA_Y - Cfg.PADARIA_SIZE.y * 0.5 - 30.0)
	label.add_theme_color_override("font_color", Color(0.65, 0.4, 0.25, 1))
	label.add_theme_font_size_override("font_size", 11)
	container.add_child(label)

	# Porte interactive vers l'intérieur de la padaria.
	_add_door(container, Vector2(Cfg.PADARIA_X, Cfg.PADARIA_Y), Cfg.PADARIA_SIZE.y * 0.5, _padaria_spawn, "Entrer dans la padaria")

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
	var entries: Array = []
	for i in house_count:
		var w: float = rng.randf_range(20, 30)
		var h: float = rng.randf_range(20, 28)
		entries.append({
			"pos": Vector2(
				rng.randf_range(zone.position.x, zone.position.x + zone.size.x - w),
				rng.randf_range(zone.position.y, zone.position.y + zone.size.y - h)
			),
			"size": Vector2(w, h),
			"color": Cfg.FAVELA_COLORS[rng.randi() % Cfg.FAVELA_COLORS.size()],
			"roof_kind": rng.randi() % 4,  # 0 antenne, 1 château d'eau, 2 panneau solaire, 3 rien
			"door_side": rng.randf() < 0.5,
		})
	entries.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for e in entries:
		_spawn_favela_house(parent, e.pos, e.size, e.color, e.roof_kind, e.door_side)
	# Petite étiquette en haut
	var label: Label = Label.new()
	label.text = label_text
	label.position = Vector2(zone.position.x - 10, zone.position.y - 18)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_font_size_override("font_size", 10)
	parent.add_child(label)

# Maison de favela : décor pur. Aucun StaticBody2D — les favelas dans Copa
# servent uniquement de style et de repère pour l'entrée vers le district
# FavelaDoMorro. Le joueur doit pouvoir traverser la zone librement.
func _spawn_favela_house(parent: Node, pos: Vector2, size: Vector2, color: Color, roof_kind: int = 3, door_left: bool = false) -> void:
	var node: Node2D = Node2D.new()
	node.position = pos + size * 0.5
	parent.add_child(node)

	# Ombre portée (effet de relief sur la colline)
	var shadow: ColorRect = ColorRect.new()
	shadow.offset_left = -size.x * 0.5 + 2
	shadow.offset_top = -size.y * 0.5 + 2
	shadow.offset_right = size.x * 0.5 + 3
	shadow.offset_bottom = size.y * 0.5 + 3
	shadow.color = Color(0, 0, 0, 0.30)
	node.add_child(shadow)

	# Mur principal (brique peinte)
	var wall: ColorRect = ColorRect.new()
	wall.offset_left = -size.x * 0.5
	wall.offset_top = -size.y * 0.5
	wall.offset_right = size.x * 0.5
	wall.offset_bottom = size.y * 0.5
	wall.color = color
	node.add_child(wall)

	# Bande verticale plus claire à gauche (lumière du matin venant de l'est)
	var highlight: ColorRect = ColorRect.new()
	highlight.offset_left = -size.x * 0.5
	highlight.offset_top = -size.y * 0.5 + 3
	highlight.offset_right = -size.x * 0.5 + 2
	highlight.offset_bottom = size.y * 0.5 - 4
	highlight.color = Color(min(color.r + 0.12, 1.0), min(color.g + 0.12, 1.0), min(color.b + 0.12, 1.0), 0.9)
	node.add_child(highlight)

	# Fondation béton (bande basse plus sombre)
	var foundation: ColorRect = ColorRect.new()
	foundation.offset_left = -size.x * 0.5
	foundation.offset_top = size.y * 0.5 - 3
	foundation.offset_right = size.x * 0.5
	foundation.offset_bottom = size.y * 0.5
	foundation.color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 1)
	node.add_child(foundation)

	# Bande toit (briques apparentes plus foncées)
	var roof: ColorRect = ColorRect.new()
	roof.offset_left = -size.x * 0.5 - 1
	roof.offset_top = -size.y * 0.5 - 3
	roof.offset_right = size.x * 0.5 + 1
	roof.offset_bottom = -size.y * 0.5 + 2
	roof.color = Color(color.r * 0.40, color.g * 0.40, color.b * 0.40, 1)
	node.add_child(roof)

	# Porte (en bas, verticale, côté tirage aléatoire)
	var door: ColorRect = ColorRect.new()
	var dx: float = -size.x * 0.5 + 4 if door_left else size.x * 0.5 - 9
	door.offset_left = dx
	door.offset_top = size.y * 0.5 - 9
	door.offset_right = dx + 5
	door.offset_bottom = size.y * 0.5 - 1
	door.color = Color(0.20, 0.13, 0.08, 1)
	node.add_child(door)

	# Fenêtre (côté opposé à la porte)
	var win: ColorRect = ColorRect.new()
	var winx: float = size.x * 0.5 - 9 if door_left else -size.x * 0.5 + 4
	win.offset_left = winx
	win.offset_top = -1
	win.offset_right = winx + 5
	win.offset_bottom = 4
	win.color = Color(0.12, 0.18, 0.28, 1)
	node.add_child(win)

	# Décor de toit aléatoire — typique des favelas cariocas
	match roof_kind:
		0:
			# Antenne TV (mât + bras horizontal)
			var mast: ColorRect = ColorRect.new()
			mast.offset_left = -1
			mast.offset_top = -size.y * 0.5 - 14
			mast.offset_right = 1
			mast.offset_bottom = -size.y * 0.5 - 3
			mast.color = Color(0.22, 0.20, 0.18, 1)
			node.add_child(mast)
			var arm: ColorRect = ColorRect.new()
			arm.offset_left = -5
			arm.offset_top = -size.y * 0.5 - 12
			arm.offset_right = 5
			arm.offset_bottom = -size.y * 0.5 - 11
			arm.color = Color(0.22, 0.20, 0.18, 1)
			node.add_child(arm)
		1:
			# Caixa d'água (cylindre bleu sur le toit, omniprésent à Rio)
			var tank: ColorRect = ColorRect.new()
			tank.offset_left = size.x * 0.5 - 8
			tank.offset_top = -size.y * 0.5 - 8
			tank.offset_right = size.x * 0.5 - 1
			tank.offset_bottom = -size.y * 0.5 - 2
			tank.color = Color(0.25, 0.45, 0.70, 1)
			node.add_child(tank)
			var lid: ColorRect = ColorRect.new()
			lid.offset_left = size.x * 0.5 - 8
			lid.offset_top = -size.y * 0.5 - 9
			lid.offset_right = size.x * 0.5 - 1
			lid.offset_bottom = -size.y * 0.5 - 7
			lid.color = Color(0.18, 0.32, 0.50, 1)
			node.add_child(lid)
		2:
			# Linge à sécher : fil + 3 vêtements
			var line: ColorRect = ColorRect.new()
			line.offset_left = -size.x * 0.5 + 2
			line.offset_top = -size.y * 0.5 - 5
			line.offset_right = size.x * 0.5 - 2
			line.offset_bottom = -size.y * 0.5 - 4
			line.color = Color(0.30, 0.28, 0.25, 1)
			node.add_child(line)
			var laundry_colors: Array = [Color(0.95, 0.85, 0.45, 1), Color(0.85, 0.35, 0.42, 1), Color(0.40, 0.65, 0.85, 1)]
			for k in 3:
				var cloth: ColorRect = ColorRect.new()
				var cx: float = -size.x * 0.5 + 4 + k * (size.x - 12) / 2.0
				cloth.offset_left = cx
				cloth.offset_top = -size.y * 0.5 - 4
				cloth.offset_right = cx + 3
				cloth.offset_bottom = -size.y * 0.5
				cloth.color = laundry_colors[k]
				node.add_child(cloth)
		_:
			pass

# Quiosques du calçadão — les petits kiosques à água de coco omniprésents sur
# le front de mer. Décor pur, posés sur le bord sud du calçadão.
func _spawn_quiosques() -> void:
	var container: Node2D = Node2D.new()
	container.name = "Quiosques"
	add_child(container)
	var menus: Array = ["ÁGUA DE COCO", "BISCOITO GLOBO", "CALDO DE CANA", "MATE GELADO", "ÁGUA DE COCO"]
	for i in Cfg.QUIOSQUE_XS.size():
		var x: float = Cfg.QUIOSQUE_XS[i]
		var kiosk: Node2D = Node2D.new()
		kiosk.position = Vector2(x, 124.0)
		container.add_child(kiosk)
		# Toit de paille débordant
		var roof: ColorRect = ColorRect.new()
		roof.offset_left = -24.0
		roof.offset_top = -28.0
		roof.offset_right = 24.0
		roof.offset_bottom = -19.0
		roof.color = Color(0.85, 0.74, 0.48, 1)
		kiosk.add_child(roof)
		var roof_edge: ColorRect = ColorRect.new()
		roof_edge.offset_left = -24.0
		roof_edge.offset_top = -20.0
		roof_edge.offset_right = 24.0
		roof_edge.offset_bottom = -18.0
		roof_edge.color = Color(0.66, 0.55, 0.32, 1)
		kiosk.add_child(roof_edge)
		# Corps blanc + comptoir
		var bodyk: ColorRect = ColorRect.new()
		bodyk.offset_left = -17.0
		bodyk.offset_top = -18.0
		bodyk.offset_right = 17.0
		bodyk.offset_bottom = 0.0
		bodyk.color = Color(0.94, 0.93, 0.88, 1)
		kiosk.add_child(bodyk)
		var counter: ColorRect = ColorRect.new()
		counter.offset_left = -17.0
		counter.offset_top = -6.0
		counter.offset_right = 17.0
		counter.offset_bottom = 0.0
		counter.color = Color(0.42, 0.32, 0.24, 1)
		kiosk.add_child(counter)
		# Pile de noix de coco vertes à côté du comptoir
		for offset in [Vector2(20, -5), Vector2(25, -5), Vector2(22.5, -10)]:
			var coco: ColorRect = ColorRect.new()
			coco.offset_left = offset.x
			coco.offset_top = offset.y
			coco.offset_right = offset.x + 5.0
			coco.offset_bottom = offset.y + 5.0
			coco.color = Color(0.45, 0.62, 0.30, 1)
			kiosk.add_child(coco)
		_spawn_sign(kiosk, Vector2(-22.0, -40.0), menus[i % menus.size()], Color(0.25, 0.2, 0.15, 1), 7)

# Entrées de métro (décor) sur le bord nord de Nossa Senhora — Cantagalo,
# Siqueira Campos et Cardeal Arcoverde, les trois vraies stations de Copa.
func _spawn_metro_entrances() -> void:
	var container: Node2D = Node2D.new()
	container.name = "MetroStations"
	add_child(container)
	for stn in Cfg.METRO_STATIONS:
		var entry: Node2D = Node2D.new()
		entry.position = Vector2(stn.x, -128.0)
		container.add_child(entry)
		# Escalier qui descend (bouche sombre + marches)
		var mouth: ColorRect = ColorRect.new()
		mouth.offset_left = -14.0
		mouth.offset_top = 2.0
		mouth.offset_right = 14.0
		mouth.offset_bottom = 24.0
		mouth.color = Color(0.16, 0.15, 0.18, 1)
		entry.add_child(mouth)
		for step_i in 3:
			var step: ColorRect = ColorRect.new()
			step.offset_left = -12.0
			step.offset_top = 4.0 + step_i * 6.0
			step.offset_right = 12.0
			step.offset_bottom = 5.5 + step_i * 6.0
			step.color = Color(0.45, 0.44, 0.48, 0.8 - step_i * 0.25)
			entry.add_child(step)
		# Rambardes
		for rx in [-16.0, 14.0]:
			var rail: ColorRect = ColorRect.new()
			rail.offset_left = rx
			rail.offset_top = 0.0
			rail.offset_right = rx + 2.0
			rail.offset_bottom = 24.0
			rail.color = Color(0.62, 0.62, 0.66, 1)
			entry.add_child(rail)
		# Totem "M" orange du MetrôRio
		var totem: ColorRect = ColorRect.new()
		totem.offset_left = -22.0
		totem.offset_top = -14.0
		totem.offset_right = -10.0
		totem.offset_bottom = -2.0
		totem.color = Color(0.93, 0.45, 0.12, 1)
		entry.add_child(totem)
		_spawn_sign(entry, Vector2(-19.0, -14.0), "M", Color(1, 1, 1, 1), 9)
		_spawn_sign(entry, Vector2(-6.0, -13.0), stn.name, Color(0.9, 0.88, 0.8, 0.9), 7)

# Colônia de pescadores Z-13 — la vraie colonie de pêcheurs installée sur le
# sable du Posto 6, près du Forte : barques colorées échouées + panneau.
func _spawn_fishing_colony() -> void:
	var container: Node2D = Node2D.new()
	container.name = "ColoniaZ13"
	add_child(container)
	var boats: Array = [
		{"pos": Vector2(195, 330), "hull": Color(0.30, 0.50, 0.78, 1)},
		{"pos": Vector2(265, 362), "hull": Color(0.90, 0.88, 0.84, 1)},
		{"pos": Vector2(322, 338), "hull": Color(0.82, 0.34, 0.28, 1)},
	]
	for b in boats:
		var boat: Node2D = Node2D.new()
		boat.position = b.pos
		container.add_child(boat)
		# Ombre sous la coque
		var shadow: ColorRect = ColorRect.new()
		shadow.offset_left = -22.0
		shadow.offset_top = 4.0
		shadow.offset_right = 24.0
		shadow.offset_bottom = 8.0
		shadow.color = Color(0, 0, 0, 0.22)
		boat.add_child(shadow)
		# Coque + plat-bord plus sombre
		var hull: ColorRect = ColorRect.new()
		hull.offset_left = -22.0
		hull.offset_top = -6.0
		hull.offset_right = 22.0
		hull.offset_bottom = 6.0
		hull.color = b.hull
		boat.add_child(hull)
		var gunwale: ColorRect = ColorRect.new()
		gunwale.offset_left = -22.0
		gunwale.offset_top = -6.0
		gunwale.offset_right = 22.0
		gunwale.offset_bottom = -3.0
		gunwale.color = Color(b.hull.r * 0.55, b.hull.g * 0.55, b.hull.b * 0.55, 1)
		boat.add_child(gunwale)
		# Banc de nage
		var bench: ColorRect = ColorRect.new()
		bench.offset_left = -4.0
		bench.offset_top = -6.0
		bench.offset_right = 0.0
		bench.offset_bottom = 6.0
		bench.color = Color(0.48, 0.36, 0.24, 1)
		boat.add_child(bench)
	_spawn_sign(container, Vector2(210, 378), "COLÔNIA DE PESCADORES Z-13", Color(0.45, 0.35, 0.28, 1), 7)

# Sculpture de sable "RIO DE JANEIRO" — l'attraction permanente du calçadão.
func _spawn_sand_sculpture() -> void:
	var container: Node2D = Node2D.new()
	container.name = "SandSculpture"
	container.position = Vector2(1560, 215)
	add_child(container)
	# Socle de sable compacté
	var base: ColorRect = ColorRect.new()
	base.offset_left = -28.0
	base.offset_top = -8.0
	base.offset_right = 28.0
	base.offset_bottom = 2.0
	base.color = Color(0.78, 0.65, 0.42, 1)
	container.add_child(base)
	# Tours du château de sable (3 hauteurs)
	for t in [[-20.0, -22.0, 10.0], [-4.0, -30.0, 12.0], [12.0, -20.0, 9.0]]:
		var tower: ColorRect = ColorRect.new()
		tower.offset_left = t[0]
		tower.offset_top = t[1]
		tower.offset_right = t[0] + t[2]
		tower.offset_bottom = -6.0
		tower.color = Color(0.84, 0.72, 0.48, 1)
		container.add_child(tower)
	# Petit drapeau brésilien planté au sommet
	var pole: ColorRect = ColorRect.new()
	pole.offset_left = 1.0
	pole.offset_top = -38.0
	pole.offset_right = 2.0
	pole.offset_bottom = -30.0
	pole.color = Color(0.3, 0.26, 0.2, 1)
	container.add_child(pole)
	var flag: ColorRect = ColorRect.new()
	flag.offset_left = 2.0
	flag.offset_top = -38.0
	flag.offset_right = 9.0
	flag.offset_bottom = -33.0
	flag.color = Color(0.18, 0.55, 0.32, 1)
	container.add_child(flag)
	_spawn_sign(container, Vector2(-32.0, 4.0), "RIO DE JANEIRO", Color(0.55, 0.42, 0.28, 1), 7)

func _spawn_postos() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PostoStations"
	add_child(container)
	# 6 postos régulièrement espacés, comme en vrai. Numérotation décroissante
	# de gauche à droite : Posto 6 à l'ouest (collé au fort), Posto 1 à l'est (Leme).
	var step: float = (Cfg.POSTO_END_X - Cfg.POSTO_START_X) / float(Cfg.POSTO_COUNT - 1)
	for i in Cfg.POSTO_COUNT:
		var x: float = Cfg.POSTO_START_X + i * step
		var number: int = Cfg.POSTO_COUNT - i
		_spawn_lifeguard_hut(container, Vector2(x, Cfg.POSTO_Y))
		_spawn_sign(container, Vector2(x - 14, Cfg.POSTO_Y + 24), "P%d" % number, Color(0.15, 0.15, 0.2, 1), 11)

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
	# Promontoire rocheux qui s'avance dans la mer (au-delà du rivage de la baie)
	var rock: ColorRect = ColorRect.new()
	rock.offset_left = -290.0
	rock.offset_top = 140.0
	rock.offset_right = -40.0
	rock.offset_bottom = 470.0
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
	# Passerelle d'accès au Forte : 3 entrées clusterisées au bord ouest de la
	# zone jouable (x ≥ map_start_x=160). Café Colombo + Confeitaria 18 +
	# Le Forte est désormais un district à part (ForteDeCopacabana) — l'entrée
	# se fait via DistrictExit "ExitToForte" déclaré dans Copa.tscn à (200,175).

# Leme — extrémité est. Petit prolongement de la plage avec un rocher
# (Pedra do Leme) et une végétation montagneuse en arrière-plan, marquant la
# transition vers le tunnel pour Botafogo.
func _spawn_leme_rocks() -> void:
	var container: Node2D = Node2D.new()
	container.name = "PedraDoLeme"
	add_child(container)
	# Rocher principal qui s'avance dans la mer (au-delà du rivage de la baie)
	var rock: ColorRect = ColorRect.new()
	rock.offset_left = 2980.0
	rock.offset_top = 140.0
	rock.offset_right = 3180.0
	rock.offset_bottom = 460.0
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
	# Cyclistes sur la ciclovia (y=56, rapides, traversent toute la map).
	_add_wanderer(container, scene, Vector2(300, 56), Color(0.95, 0.75, 0.2, 1), Vector2(8, 14),
		[Vector2(300, 56), Vector2(2150, 56)], 130.0, 0.1)
	_add_wanderer(container, scene, Vector2(2000, 58), Color(0.3, 0.8, 0.75, 1), Vector2(8, 14),
		[Vector2(2000, 58), Vector2(250, 58)], 120.0, 0.1)
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

# La vie du soir : roda de samba au quiosque do Zé (le Musicien y migre via
# NPCScheduler) et futevôlei au posto 3. Le conteneur n'est visible qu'en
# phase EVENING — le soir doit être différent du matin (cf. skill ame-carioca).
var _evening_container: Node2D = null

func _spawn_evening_life() -> void:
	_evening_container = Node2D.new()
	_evening_container.name = "EveningLife"
	add_child(_evening_container)
	var scene: PackedScene = load("res://scenes/props/AmbientWanderer.tscn")
	if scene == null:
		return
	# --- Roda de samba au quiosque do Zé (ze_bar à x=500) ---
	# Quatre figurants qui tournent lentement autour du cercle, instruments imaginaires.
	_add_wanderer(_evening_container, scene, Vector2(492, 118), Color(0.92, 0.75, 0.35, 1), Vector2(9, 15),
		[Vector2(492, 118), Vector2(500, 126), Vector2(488, 124)], 7.0, 2.5)
	_add_wanderer(_evening_container, scene, Vector2(536, 116), Color(0.45, 0.75, 0.55, 1), Vector2(9, 15),
		[Vector2(536, 116), Vector2(530, 126), Vector2(540, 122)], 7.0, 2.8)
	_add_wanderer(_evening_container, scene, Vector2(514, 130), Color(0.85, 0.45, 0.55, 1), Vector2(9, 15),
		[Vector2(514, 130), Vector2(508, 124), Vector2(520, 128)], 6.0, 3.0)
	_add_wanderer(_evening_container, scene, Vector2(505, 108), Color(0.55, 0.55, 0.85, 1), Vector2(9, 15),
		[Vector2(505, 108), Vector2(512, 104), Vector2(500, 110)], 6.0, 3.2)
	# Halo chaleureux de la roda (le quiosque éclaire le cercle)
	var glow: ColorRect = ColorRect.new()
	glow.offset_left = 478.0
	glow.offset_top = 96.0
	glow.offset_right = 552.0
	glow.offset_bottom = 138.0
	glow.color = Color(1.0, 0.82, 0.45, 0.18)
	_evening_container.add_child(glow)
	_spawn_sign(_evening_container, Vector2(486, 86), "♪ RODA DO ZÉ", Color(0.98, 0.85, 0.5, 1), 9)
	# --- Futevôlei au posto 3 (x=1380) : filet + deux joueurs qui sautent ---
	for px in [1352.0, 1408.0]:
		var pole: ColorRect = ColorRect.new()
		pole.offset_left = px - 1.5
		pole.offset_top = 232.0
		pole.offset_right = px + 1.5
		pole.offset_bottom = 264.0
		pole.color = Color(0.45, 0.38, 0.3, 1)
		_evening_container.add_child(pole)
	var net: ColorRect = ColorRect.new()
	net.offset_left = 1352.0
	net.offset_top = 234.0
	net.offset_right = 1408.0
	net.offset_bottom = 242.0
	net.color = Color(0.92, 0.92, 0.88, 0.7)
	_evening_container.add_child(net)
	_add_wanderer(_evening_container, scene, Vector2(1335, 262), Color(0.95, 0.62, 0.3, 1), Vector2(9, 16),
		[Vector2(1335, 262), Vector2(1325, 248), Vector2(1345, 258), Vector2(1330, 252)], 42.0, 0.3)
	_add_wanderer(_evening_container, scene, Vector2(1425, 258), Color(0.35, 0.7, 0.75, 1), Vector2(9, 16),
		[Vector2(1425, 258), Vector2(1437, 246), Vector2(1418, 254), Vector2(1432, 250)], 42.0, 0.3)
	_spawn_sign(_evening_container, Vector2(1352, 270), "FUTEVÔLEI", Color(0.95, 0.9, 0.7, 0.9), 8)
	# Visible uniquement le soir.
	EventBus.time_of_day_changed.connect(_on_evening_phase_changed)
	_on_evening_phase_changed(TimeOfDay.current_phase)

func _on_evening_phase_changed(phase: int) -> void:
	if _evening_container and is_instance_valid(_evening_container):
		_evening_container.visible = phase == TimeOfDay.Phase.EVENING

# Dimanche carioca : la plage déborde, la messe sort de l'église. Visible
# uniquement le Domingo (CarnavalCalendar), togglé à chaque changement de jour.
var _domingo_container: Node2D = null

func _spawn_domingo_life() -> void:
	_domingo_container = Node2D.new()
	_domingo_container.name = "DomingoLife"
	add_child(_domingo_container)
	var scene: PackedScene = load("res://scenes/props/AmbientWanderer.tscn")
	if scene == null:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7771
	# La plage déborde : huit baigneurs de plus, petits trajets nonchalants.
	for i in 8:
		var p: Vector2 = Vector2(rng.randf_range(380, 2080), rng.randf_range(190, 330))
		var col: Color = Color(rng.randf_range(0.3, 0.95), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.95), 1)
		_add_wanderer(_domingo_container, scene, p, col, Vector2(10, 14),
			[p, p + Vector2(rng.randf_range(-30, 30), rng.randf_range(-15, 15))], 9.0, 4.0)
	# Parasols supplémentaires (le sable se remplit).
	for i in 5:
		var up: Vector2 = Vector2(rng.randf_range(420, 2050), rng.randf_range(230, 340))
		_spawn_prop_sprite(_domingo_container, Cfg.UMBRELLA_RED_REGION if i % 2 == 0 else Cfg.UMBRELLA_YELLOW_REGION, up, 70.0)
	# La sortie de la messe devant l'église (2e rangée, x=CHURCH_X).
	for i in 4:
		var cp: Vector2 = Vector2(Cfg.CHURCH_X - 30 + i * 20, -112.0 + (i % 2) * 8.0)
		_add_wanderer(_domingo_container, scene, cp, Color(0.85 - i * 0.1, 0.8, 0.75, 1), Vector2(9, 16),
			[cp, cp + Vector2(6, 4), cp + Vector2(-5, 2)], 5.0, 5.0)
	_spawn_sign(_domingo_container, Vector2(Cfg.CHURCH_X - 44, -134), "MISSA DE DOMINGO · 10H", Color(0.95, 0.92, 0.8, 1), 8)
	EventBus.day_elapsed.connect(_on_domingo_day_changed)
	_on_domingo_day_changed(TimeOfDay.day_count)

func _on_domingo_day_changed(_day: int) -> void:
	if _domingo_container and is_instance_valid(_domingo_container):
		_domingo_container.visible = CarnavalCalendar.is_domingo()

# Coût humain des voies sombres — le bairro change quand on choisit le tráfico
# ou le consórcio. Reconstruit aux changements d'acte et de jour (les flags de
# voie sont posés entre-temps). Décor + spots de voisins qui réagissent.
var _human_cost_container: Node2D = null

func _spawn_human_cost() -> void:
	EventBus.act_changed.connect(func(_a: int): _rebuild_human_cost())
	EventBus.day_elapsed.connect(func(_d: int): _rebuild_human_cost())
	_rebuild_human_cost()

func _rebuild_human_cost() -> void:
	if _human_cost_container and is_instance_valid(_human_cost_container):
		_human_cost_container.queue_free()
	_human_cost_container = Node2D.new()
	_human_cost_container.name = "HumanCost"
	add_child(_human_cost_container)
	var spot_scene: PackedScene = load("res://scenes/props/ReactiveDialogueSpot.tscn")
	# La voisine du bairro — toujours là, son discours suit la voie choisie.
	if spot_scene:
		var voisine: Node2D = spot_scene.instantiate()
		voisine.name = "VoisinaBairro"
		voisine.position = Vector2(905, -76)
		voisine.set("npc_id", "voisina_bairro")
		voisine.set("prompt", "Écouter la voisine")
		voisine.set("character_seed", 4242)
		var variants: Array[Dictionary] = [
			{"id": "trafico", "flag": "voie_trafico", "speaker": "Voisine",
				"text": "*baisse la voix, regarde par-dessus ton épaule* Le fils de Dona Marta ne descend plus jouer sur le sable depuis que les « livraisons » passent par la ruelle. *te dévisage* On sait pour qui tu portes, menino. Le morro le sait toujours.",
				"choices": ["..."]},
			{"id": "consortium", "flag": "voie_consortium", "speaker": "Voisine",
				"text": "*serre son cabas contre elle* Trois familles de mon immeuble ont reçu l'avis de despejo ce mois-ci. Quarante ans qu'on habite là. *amer* Il paraît que c'est « la maison » qui recouvre, maintenant. Tu leur diras bonjour, à la maison.",
				"choices": ["..."]},
			{"id": "default", "speaker": "Voisine",
				"text": "*étend son linge à la fenêtre* Bom dia, menino. Le bairro tient debout — tant que personne ne le vend ni ne le brûle, hein.",
				"choices": ["Bom dia"]},
		]
		voisine.set("variants", variants)
		_human_cost_container.add_child(voisine)
	# --- Voie Tráfico : le commerce ferme, un mémorial apparaît ---
	if CampaignManager.has_flag("voie_trafico"):
		var shutter: ColorRect = ColorRect.new()
		shutter.offset_left = 1012.0
		shutter.offset_top = -36.0
		shutter.offset_right = 1088.0
		shutter.offset_bottom = 8.0
		shutter.color = Color(0.45, 0.45, 0.48, 1)
		_human_cost_container.add_child(shutter)
		for ly in [-28.0, -18.0, -8.0]:
			var slat: ColorRect = ColorRect.new()
			slat.offset_left = 1012.0
			slat.offset_top = ly
			slat.offset_right = 1088.0
			slat.offset_bottom = ly + 2.0
			slat.color = Color(0.35, 0.35, 0.38, 1)
			_human_cost_container.add_child(slat)
		_spawn_sign(_human_cost_container, Vector2(1016, -20), "FECHADO ATÉ SEGUNDA ORDEM", Color(0.9, 0.85, 0.75, 1), 7)
		# Mémorial de rue : bougies, fleurs, une photo. Personne n'en parle fort.
		var memorial: Node2D = Node2D.new()
		memorial.position = Vector2(1320, -8)
		_human_cost_container.add_child(memorial)
		for k in 3:
			var candle: ColorRect = ColorRect.new()
			candle.offset_left = -8.0 + k * 6.0
			candle.offset_top = -6.0
			candle.offset_right = -5.0 + k * 6.0
			candle.offset_bottom = 0.0
			candle.color = Color(0.95, 0.93, 0.85, 1)
			memorial.add_child(candle)
			var flame: ColorRect = ColorRect.new()
			flame.offset_left = -7.5 + k * 6.0
			flame.offset_top = -8.0
			flame.offset_right = -5.5 + k * 6.0
			flame.offset_bottom = -6.0
			flame.color = Color(1.0, 0.8, 0.3, 1)
			memorial.add_child(flame)
		var photo: ColorRect = ColorRect.new()
		photo.offset_left = 6.0
		photo.offset_top = -12.0
		photo.offset_right = 14.0
		photo.offset_bottom = -2.0
		photo.color = Color(0.85, 0.82, 0.75, 1)
		memorial.add_child(photo)
		var flowers: ColorRect = ColorRect.new()
		flowers.offset_left = -14.0
		flowers.offset_top = -4.0
		flowers.offset_right = -10.0
		flowers.offset_bottom = 0.0
		flowers.color = Color(0.9, 0.4, 0.5, 1)
		memorial.add_child(flowers)
		if spot_scene:
			var mspot: Node2D = spot_scene.instantiate()
			mspot.name = "MemorialSpot"
			mspot.position = Vector2(1320, -4)
			mspot.set("npc_id", "memorial_bairro")
			mspot.set("prompt", "Se recueillir")
			var mvariants: Array[Dictionary] = [
				{"id": "default", "speaker": "Sobrinho",
					"text": "Trois bougies, des fleurs d'hier, une photo que tu ne regardes pas trop longtemps. Personne ne dit de qui c'est. Tout le monde le sait. Les affaires du morro descendent jusqu'au calçadão maintenant — et ça, c'est passé par toi.",
					"choices": ["..."]},
			]
			mspot.set("variants", mvariants)
			_human_cost_container.add_child(mspot)
	# --- Voie Consórcio : les avis d'expulsion fleurissent ---
	if CampaignManager.has_flag("voie_consortium"):
		for nx in [622.0, 792.0]:
			var notice: ColorRect = ColorRect.new()
			notice.offset_left = nx
			notice.offset_top = -50.0
			notice.offset_right = nx + 14.0
			notice.offset_bottom = -40.0
			notice.color = Color(0.95, 0.85, 0.35, 1)
			_human_cost_container.add_child(notice)
		_spawn_sign(_human_cost_container, Vector2(616, -64), "DESPEJO", Color(0.9, 0.3, 0.25, 1), 8)
		# Le tas d'une vie sur le trottoir : cartons, matelas.
		var pile: Node2D = Node2D.new()
		pile.position = Vector2(648, 4)
		_human_cost_container.add_child(pile)
		for k in 3:
			var box: ColorRect = ColorRect.new()
			box.offset_left = -12.0 + k * 9.0
			box.offset_top = -8.0 - (k % 2) * 5.0
			box.offset_right = -4.0 + k * 9.0
			box.offset_bottom = 0.0
			box.color = Color(0.62 - k * 0.05, 0.48, 0.32, 1)
			pile.add_child(box)
		var mattress: ColorRect = ColorRect.new()
		mattress.offset_left = 16.0
		mattress.offset_top = -5.0
		mattress.offset_right = 40.0
		mattress.offset_bottom = 1.0
		mattress.color = Color(0.8, 0.78, 0.7, 1)
		pile.add_child(mattress)
		if spot_scene:
			var dspot: Node2D = spot_scene.instantiate()
			dspot.name = "DespejadoSpot"
			dspot.position = Vector2(672, 8)
			dspot.set("npc_id", "despejado")
			dspot.set("prompt", "Parler à l'homme assis")
			dspot.set("character_seed", 1717)
			var dvariants: Array[Dictionary] = [
				{"id": "default", "speaker": "Despejado",
					"text": "*assis sur un carton, regarde l'immeuble* Dix-huit ans dans le 302. Ma fille est née là. *te tend l'avis jaune froissé* « Recouvrement », ils disent. Joli mot. *te regarde enfin* C'est toi qui fais signer les papiers de la maison, non ? T'as une belle écriture, paraît-il.",
					"choices": ["..."]},
			]
			dspot.set("variants", dvariants)
			_human_cost_container.add_child(dspot)

# Souvenirs muets de Zé — la saudade disséminée dans le décor. Trois spots
# contemplatifs SANS récompense (skill ame-carioca) : le banc de dominos, les
# initiales gravées au Posto 6, la canne à pêche plantée près de la Colônia.
func _spawn_ze_memories() -> void:
	var container: Node2D = Node2D.new()
	container.name = "ZeMemories"
	add_child(container)
	var spot_scene: PackedScene = load("res://scenes/props/ReactiveDialogueSpot.tscn")
	if spot_scene == null:
		return
	# 1. Le banc de dominos (calçadão, à l'ouest du quiosque do Zé)
	var bench: Node2D = Node2D.new()
	bench.position = Vector2(430, 112)
	container.add_child(bench)
	var seat: ColorRect = ColorRect.new()
	seat.offset_left = -16.0
	seat.offset_top = -6.0
	seat.offset_right = 16.0
	seat.offset_bottom = -2.0
	seat.color = Color(0.55, 0.42, 0.3, 1)
	bench.add_child(seat)
	for lx in [-13.0, 11.0]:
		var leg: ColorRect = ColorRect.new()
		leg.offset_left = lx
		leg.offset_top = -2.0
		leg.offset_right = lx + 2.0
		leg.offset_bottom = 4.0
		leg.color = Color(0.4, 0.3, 0.22, 1)
		bench.add_child(leg)
	for dx in [-6.0, -2.0, 3.0]:
		var domino: ColorRect = ColorRect.new()
		domino.offset_left = dx
		domino.offset_top = -5.5
		domino.offset_right = dx + 3.0
		domino.offset_bottom = -3.5
		domino.color = Color(0.94, 0.94, 0.9, 1)
		bench.add_child(domino)
	_add_ze_memory(container, spot_scene, Vector2(430, 116), "ze_mem_bench", "Regarder le banc",
		"Un banc raide, l'accoudoir entaillé par vingt ans de parties de dominos. Les vieux jouent ailleurs maintenant — depuis « l'histoire de la dette », dit-on sans finir la phrase. La chaise du fond, celle de Zé, personne ne l'a prise.",
		"La chaise du fond est toujours vide. Les dominos attendent.")
	# 2. Les initiales gravées dans le béton (Posto 6, côté Forte)
	var carve: ColorRect = ColorRect.new()
	carve.offset_left = 306.0
	carve.offset_top = 124.0
	carve.offset_right = 318.0
	carve.offset_bottom = 130.0
	carve.color = Color(0.45, 0.42, 0.4, 0.85)
	container.add_child(carve)
	_add_ze_memory(container, spot_scene, Vector2(312, 132), "ze_mem_carving", "Lire la gravure",
		"« Z ♥ M », gravé dans le béton du calçadão, poli par quarante ans de pieds nus. Le Z, c'est forcément lui — la même boucle que sur les notes de dette. Le M, tu ne sauras jamais. Lui non plus, peut-être, à la fin.",
		"Z ♥ M. Quelqu'un a fleuri la gravure d'un pétale de bougainvillier. Pas toi.")
	# 3. La canne à pêche plantée (près de la Colônia Z-13)
	var rod: ColorRect = ColorRect.new()
	rod.offset_left = 354.0
	rod.offset_top = 296.0
	rod.offset_right = 356.0
	rod.offset_bottom = 330.0
	rod.color = Color(0.5, 0.38, 0.25, 1)
	rod.rotation = 0.18
	container.add_child(rod)
	var line: ColorRect = ColorRect.new()
	line.offset_left = 356.0
	line.offset_top = 296.0
	line.offset_right = 410.0
	line.offset_bottom = 297.0
	line.rotation = 0.55
	line.color = Color(0.85, 0.85, 0.85, 0.5)
	container.add_child(line)
	_add_ze_memory(container, spot_scene, Vector2(355, 334), "ze_mem_rod", "La canne de Zé",
		"Une canne plantée dans le sable, la ligne encore à l'eau. Les pêcheurs de la Colônia disent que c'est celle de Zé et que personne n'ose la retirer. « Il reviendra la chercher. » La mer, elle, ne promet rien.",
		"La ligne est toujours à l'eau. Un jour il faudra bien que quelqu'un la remonte.")

func _add_ze_memory(parent: Node, spot_scene: PackedScene, pos: Vector2, flag: String,
		prompt: String, first_text: String, echo_text: String) -> void:
	var spot: Node2D = spot_scene.instantiate()
	spot.name = "ZeMemory_" + flag
	spot.position = pos
	spot.set("npc_id", flag)
	spot.set("prompt", prompt)
	var variants: Array[Dictionary] = [
		{"id": "first", "not_flag": flag, "speaker": "Sobrinho", "text": first_text,
			"choices": ["…"], "set_flag_after": flag},
		{"id": "echo", "speaker": "Sobrinho", "text": echo_text, "choices": ["…"]},
	]
	spot.set("variants", variants)
	parent.add_child(spot)

# Répétition de bloco qui grossit avec les actes — le compte à rebours du
# Carnaval rendu VISIBLE (cf. backlog ame-carioca). Rien en acte 1, trois
# percussionnistes en acte 2, fanfare + bannière en acte 3, cortège en acte 4+.
var _bloco_container: Node2D = null

func _spawn_bloco_rehearsal() -> void:
	EventBus.act_changed.connect(_rebuild_bloco)
	_rebuild_bloco(CampaignManager.current_act)

func _rebuild_bloco(act: int) -> void:
	if _bloco_container and is_instance_valid(_bloco_container):
		_bloco_container.queue_free()
	_bloco_container = null
	if act < 2:
		return
	_bloco_container = Node2D.new()
	_bloco_container.name = "BlocoRehearsal"
	add_child(_bloco_container)
	var scene: PackedScene = load("res://scenes/props/AmbientWanderer.tscn")
	if scene == null:
		return
	var center: Vector2 = Vector2(2030, 105)
	var drummer_count: int = 3 if act == 2 else (6 if act == 3 else 10)
	var colors: Array = [
		Color(0.95, 0.75, 0.2, 1), Color(0.85, 0.3, 0.35, 1), Color(0.35, 0.75, 0.5, 1),
		Color(0.4, 0.55, 0.9, 1), Color(0.95, 0.5, 0.7, 1), Color(0.95, 0.95, 0.9, 1),
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 19500220 + act  # déterministe par acte
	for i in drummer_count:
		var ang: float = TAU * float(i) / float(drummer_count)
		var p: Vector2 = center + Vector2(cos(ang), sin(ang) * 0.5) * (26.0 + 8.0 * (act - 2))
		_add_wanderer(_bloco_container, scene, p, colors[i % colors.size()], Vector2(9, 16),
			[p, p + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6)), p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-8, 8))],
			10.0, 0.8)
	var title: String = "ENSAIO DO BLOCO"
	if act == 3:
		title = "BLOCO UNIDOS DA COPA — ENSAIO GERAL"
	elif act >= 4:
		title = "BLOCO UNIDOS DA COPA — O CARNAVAL VEM AÍ!"
	_spawn_sign(_bloco_container, Vector2(center.x - 70, center.y - 42), title, Color(0.98, 0.8, 0.3, 1), 9)
	if act >= 3:
		# Bannière du bloco tenue entre deux mâts
		var banner: ColorRect = ColorRect.new()
		banner.offset_left = center.x - 45
		banner.offset_top = center.y - 30
		banner.offset_right = center.x + 45
		banner.offset_bottom = center.y - 18
		banner.color = Color(0.85, 0.25, 0.4, 0.9)
		_bloco_container.add_child(banner)
		for mx in [center.x - 47, center.x + 45]:
			var mast: ColorRect = ColorRect.new()
			mast.offset_left = mx
			mast.offset_top = center.y - 32
			mast.offset_right = mx + 2
			mast.offset_bottom = center.y + 2
			mast.color = Color(0.5, 0.42, 0.32, 1)
			_bloco_container.add_child(mast)
	if act >= 4:
		# Confettis au sol — la répétition déborde déjà sur l'avenue
		for k in 26:
			var confetti: ColorRect = ColorRect.new()
			var cp: Vector2 = center + Vector2(rng.randf_range(-90, 90), rng.randf_range(-10, 35))
			confetti.offset_left = cp.x
			confetti.offset_top = cp.y
			confetti.offset_right = cp.x + 3
			confetti.offset_bottom = cp.y + 3
			confetti.color = colors[k % colors.size()]
			_bloco_container.add_child(confetti)

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

# Lampadaires le long du calçadão, à intervalles réguliers. Le poteau est
# toujours visible (visuel statique) ; le halo + l'ampoule sont tagués
# "nightlight" et s'allument uniquement le soir (cf. DayLighting.gd).
func _spawn_streetlamps() -> void:
	var container: Node2D = Node2D.new()
	container.name = "StreetLamps"
	add_child(container)
	const LAMP_Y_POLE_TOP: float = 90.0
	const LAMP_Y_POLE_BOTTOM: float = 124.0
	const LAMP_SPACING: float = 280.0
	var x: float = map_start_x + 100.0
	while x <= map_end_x:
		_spawn_one_streetlamp(container, x)
		x += LAMP_SPACING

func _spawn_one_streetlamp(parent: Node, x: float) -> void:
	# Poteau (visible jour + nuit)
	var pole: ColorRect = ColorRect.new()
	pole.name = "Pole"
	pole.offset_left = x - 2.0
	pole.offset_top = 90.0
	pole.offset_right = x + 2.0
	pole.offset_bottom = 124.0
	pole.color = Color(0.32, 0.30, 0.30, 1)
	parent.add_child(pole)
	# Halo jaune (groupe nightlight)
	var halo: ColorRect = ColorRect.new()
	halo.name = "Halo"
	halo.offset_left = x - 14.0
	halo.offset_top = 80.0
	halo.offset_right = x + 14.0
	halo.offset_bottom = 100.0
	halo.color = Color(1.0, 0.92, 0.55, 0.45)
	halo.add_to_group("nightlight")
	halo.visible = false
	parent.add_child(halo)
	# Ampoule (groupe nightlight)
	var bulb: ColorRect = ColorRect.new()
	bulb.name = "Bulb"
	bulb.offset_left = x - 3.0
	bulb.offset_top = 88.0
	bulb.offset_right = x + 3.0
	bulb.offset_bottom = 94.0
	bulb.color = Color(1.0, 0.95, 0.62, 1)
	bulb.add_to_group("nightlight")
	bulb.visible = false
	parent.add_child(bulb)

# Reinado (acte 5) — le règne se voit à Copa : une faixa au-dessus du calçadão
# et un habitant dont le salut dit ce que le bairro pense du nouveau pouvoir.
# Reconstruit à act_changed (complete_endgame pose l'acte 5 + chosen_endgame).
var _reinado_container: Node2D = null

func _spawn_reinado() -> void:
	EventBus.act_changed.connect(func(_a: int): _rebuild_reinado())
	_rebuild_reinado()

func _rebuild_reinado() -> void:
	if _reinado_container and is_instance_valid(_reinado_container):
		_reinado_container.queue_free()
		_reinado_container = null
	if CampaignManager.current_act < 5:
		return
	_reinado_container = Node2D.new()
	_reinado_container.name = "Reinado"
	add_child(_reinado_container)
	var faixa_text: String = ""
	var faixa_color: Color = Color(0.9, 0.85, 0.6, 1)
	var morador: Dictionary = {}
	match CampaignManager.chosen_endgame:
		CampaignManager.Endgame.TRAFICO:
			faixa_text = "★ O MORRO DESCEU PRA AREIA ★"
			faixa_color = Color(0.85, 0.32, 0.28, 1)
			morador = {"speaker": "Camelô", "seed": 90521,
				"text": "*il te voit arriver et rajuste son étal d'un geste nerveux — les prix sont déjà « corrigés » pour toi* Patrão. *il n'ose pas soutenir ton regard* Tout est en ordre, le pedágio est prêt. *un gamin court prévenir la barraca suivante que tu passes*"}
		CampaignManager.Endgame.POLICIA:
			faixa_text = "★ CALÇADÃO SEGURO — CAP. RAMOS AGRADECE ★"
			faixa_color = Color(0.3, 0.45, 0.75, 1)
			morador = {"speaker": "Joggeuse", "seed": 90522,
				"text": "*elle s'arrête à ta hauteur, essoufflée, et te salue de la tête* Capitão. *elle montre le calçadão d'un geste* Ma mère refait sa marche du soir — la première fois depuis des années. *elle repart, puis se retourne* Le camelô de la Rua Santa Clara, lui, il dit qu'on respire un peu trop fort, ces temps-ci. Vous lui demanderez.*"}
		CampaignManager.Endgame.CONSORTIUM:
			faixa_text = "◆ COPACABANA RISERVA — UM NOVO PADRÃO ◆"
			faixa_color = Color(0.85, 0.75, 0.45, 1)
			morador = {"speaker": "Serveur", "seed": 90523,
				"text": "*uniforme ivoire et or, badge « Riserva » au revers* Monsieur. *il incline le buste exactement comme le manuel l'exige* Tout le front de mer est aux couleurs de la maison — même les parasols saluent, maintenant. *plus bas, en regardant ailleurs* Mon ancien patron tenait ce bar depuis vingt ans. Il est caissier, désormais. Beau Carnaval, monsieur.*"}
		CampaignManager.Endgame.PREFEITO:
			faixa_text = "♥ O BAIRRO VENCEU — BLOCO UNIDO ♥"
			faixa_color = Color(0.35, 0.65, 0.4, 1)
			morador = {"speaker": "Moradora", "seed": 90524,
				"text": "*elle accroche des fanions verts et or entre deux lampadaires, juchée sur un escabeau que deux gamins tiennent* Meu filho ! *elle te lance un fanion* Accroche ça quelque part — tout le bairro s'y met, le bloco sort bientôt. *elle rit* Le Padre dit que t'as monté tout ça. Moi je dis que c'est nous TOUS. Il dit que c'est exactement ça que t'as monté.*"}
		_:
			return
	# Faixa au-dessus du calçadão.
	var faixa_bg: ColorRect = ColorRect.new()
	faixa_bg.offset_left = 560.0
	faixa_bg.offset_top = 70.0
	faixa_bg.offset_right = 1040.0
	faixa_bg.offset_bottom = 92.0
	faixa_bg.color = faixa_color
	_reinado_container.add_child(faixa_bg)
	var faixa_label: Label = Label.new()
	faixa_label.offset_left = 560.0
	faixa_label.offset_top = 72.0
	faixa_label.offset_right = 1040.0
	faixa_label.offset_bottom = 90.0
	faixa_label.text = faixa_text
	faixa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faixa_label.add_theme_font_size_override("font_size", 12)
	faixa_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	faixa_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	faixa_label.add_theme_constant_override("outline_size", 3)
	_reinado_container.add_child(faixa_label)
	# Un habitant qui incarne le règne (salut, crainte ou fierté selon la voie).
	var spot_scene: PackedScene = load("res://scenes/props/ReactiveDialogueSpot.tscn")
	if spot_scene:
		var morador_spot: Node2D = spot_scene.instantiate()
		morador_spot.name = "MoradorReinado"
		morador_spot.position = Vector2(800, 110)
		morador_spot.set("npc_id", "morador_reinado")
		morador_spot.set("prompt", "Le bairro te regarde")
		morador_spot.set("character_seed", int(morador.get("seed", 90520)))
		var variants: Array[Dictionary] = [
			{"id": "default", "speaker": String(morador.get("speaker", "Morador")),
				"text": String(morador.get("text", "…")), "choices": ["…"]},
		]
		morador_spot.set("variants", variants)
		_reinado_container.add_child(morador_spot)
