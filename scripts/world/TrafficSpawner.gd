extends Node

# Spawn périodique de véhicules sur les quatre voies (2 routes × 2 sens).
# Av. Atlântica (proche calçadão) : nord (y=16) ←, sud (y=48) →
# Nossa Senhora de Copacabana (intérieur) : nord (y=-112) ←, sud (y=-80) →

const VEHICLES_TEXTURE: Texture2D = preload("res://assets/sprites/vehicles.png")

const CELL_W: float = 328.0
const CELL_H: float = 163.2
const VEHICLE_SCALE: float = 0.3

# (col, row) des cellules utilisées, organisées par catégorie
const CAR_CELLS: Array = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),  # sedans
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),  # SUV, hatchback, pickup, luxe
]
const BUS_CELLS: Array = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
]
const MOTO_CELLS: Array = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),  # cellule (3,3) vide dans l'image
]
const SPECIAL_CELLS: Array = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),  # police, ambulance, pompiers, UPS
]

const AV_ATLANTICA_N_Y: float = 16.0    # voie nord (→ gauche)
const AV_ATLANTICA_S_Y: float = 48.0    # voie sud  (→ droite)
const NOSSA_SENHORA_N_Y: float = -112.0 # voie nord (→ gauche)
const NOSSA_SENHORA_S_Y: float = -80.0  # voie sud  (→ droite)
const SPAWN_LEFT: float = -100.0
const SPAWN_RIGHT: float = 2500.0

var _timer_atl_n: float = 2.0
var _timer_atl_s: float = 1.0
var _timer_nossa_n: float = 3.0
var _timer_nossa_s: float = 1.5

func _process(delta: float) -> void:
	_timer_atl_n -= delta
	_timer_atl_s -= delta
	_timer_nossa_n -= delta
	_timer_nossa_s -= delta
	if _timer_atl_n <= 0:
		_spawn(AV_ATLANTICA_N_Y, -1)
		_timer_atl_n = randf_range(2.0, 5.5)
	if _timer_atl_s <= 0:
		_spawn(AV_ATLANTICA_S_Y, 1)
		_timer_atl_s = randf_range(2.0, 5.5)
	if _timer_nossa_n <= 0:
		_spawn(NOSSA_SENHORA_N_Y, -1)
		_timer_nossa_n = randf_range(2.5, 6.0)
	if _timer_nossa_s <= 0:
		_spawn(NOSSA_SENHORA_S_Y, 1)
		_timer_nossa_s = randf_range(2.5, 6.0)

func _spawn(y_pos: float, direction: int) -> void:
	var cell: Vector2i = _pick_random_cell()
	var vehicle: Vehicle = _create_vehicle(cell)
	var spawn_x: float = SPAWN_LEFT if direction > 0 else SPAWN_RIGHT
	vehicle.position = Vector2(spawn_x, y_pos)
	vehicle.speed_x = direction * randf_range(100.0, 180.0)
	get_parent().add_child(vehicle)

func _pick_random_cell() -> Vector2i:
	var r: float = randf()
	if r < 0.50:
		return CAR_CELLS[randi() % CAR_CELLS.size()]
	elif r < 0.72:
		return BUS_CELLS[randi() % BUS_CELLS.size()]
	elif r < 0.92:
		return MOTO_CELLS[randi() % MOTO_CELLS.size()]
	else:
		return SPECIAL_CELLS[randi() % SPECIAL_CELLS.size()]

func _create_vehicle(cell: Vector2i) -> Vehicle:
	var v: Vehicle = Vehicle.new()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = VEHICLES_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = Rect2(cell.x * CELL_W, cell.y * CELL_H, CELL_W, CELL_H)
	sprite.scale = Vector2(VEHICLE_SCALE, VEHICLE_SCALE)
	v.add_child(sprite)
	return v
