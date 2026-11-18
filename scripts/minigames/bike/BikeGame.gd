class_name BikeGame
extends MinigameBase

# Mini-jeu de livraison à vélo. La rue défile (4 voies) : les voitures
# arrivent par rangées qui bloquent 1 à 3 voies (jamais les 4), les piétons
# traversent en biais, et des colis à livrer jalonnent la route. Chaque choc
# abîme la commande (3 points). Qualifié = commande intacte (≥ 1 point) ET au
# moins 5 adresses servies. Paiement fixe au launcher ; réputation via
# ActivityRewards (signature "bike").

signal match_ended(qualifies: bool, integrity: int)

const DURATION: float = 40.0
const INTEGRITY_START: int = 3
const DELIVERIES_TO_QUALIFY: int = 5

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const BIKE_W: float = 54.0
const BIKE_H: float = 90.0
const BIKE_SPEED: float = 640.0
const LANE_LEFT: float = 240.0
const LANE_RIGHT: float = ARENA_W - 240.0
const LANES: int = 4
const LANE_W: float = (LANE_RIGHT - LANE_LEFT) / LANES
const LANE_TOP: float = 360.0
const LANE_BOTTOM: float = ARENA_H - 160.0

const SCROLL_START: float = 420.0
const SCROLL_ACCEL: float = 11.0
const ROW_INTERVAL_START: float = 1.25
const ROW_INTERVAL_MIN: float = 0.6
const I_FRAMES: float = 0.8
const PEDESTRIAN_CHANCE: float = 0.3
const PARCEL_CHANCE: float = 0.55

const CAR_COLORS: Array = [
	Color(0.85, 0.2, 0.2, 1), Color(0.25, 0.45, 0.85, 1), Color(0.95, 0.95, 0.92, 1),
	Color(0.95, 0.82, 0.25, 1), Color(0.3, 0.3, 0.32, 1),
]

@onready var bike: ColorRect = $Bike
@onready var obstacle_layer: Node2D = $ObstacleLayer
@onready var integrity_label: Label = $UI/IntegrityLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status

var _time_left: float = DURATION
var _integrity: int = INTEGRITY_START
var _deliveries: int = 0
var _ended: bool = false
var _scroll: float = SCROLL_START
var _row_timer: float = 1.0
var _row_interval: float = ROW_INTERVAL_START
var _iframes_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _dashes: Array[ColorRect] = []

func _ready() -> void:
	EventBus.minigame_started.emit("bike")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	for n in get_children():
		if n is ColorRect and String(n.name).begins_with("LaneDash"):
			_dashes.append(n)
	if status_label:
		status_label.text = "Ramasse les colis 📦, évite la circulation !"
	_update_labels()
	if bike:
		bike.position = Vector2((LANE_LEFT + LANE_RIGHT) * 0.5 - BIKE_W * 0.5, LANE_BOTTOM - BIKE_H)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	_iframes_left = max(0.0, _iframes_left - delta)
	if _time_left <= 0.0:
		_end_game()
		return
	_scroll += SCROLL_ACCEL * delta
	_row_interval = maxf(ROW_INTERVAL_MIN, _row_interval - 0.018 * delta)
	_move_bike(delta)
	_scroll_road(delta)
	_spawn_and_move(delta)
	_check_collisions()
	_update_labels()

func _move_bike(delta: float) -> void:
	if bike == null:
		return
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	bike.position += dir * BIKE_SPEED * delta
	bike.position.x = clamp(bike.position.x, LANE_LEFT, LANE_RIGHT - BIKE_W)
	bike.position.y = clamp(bike.position.y, LANE_TOP, LANE_BOTTOM - BIKE_H)
	bike.modulate.a = 0.45 if _iframes_left > 0.0 and int(_iframes_left * 12.0) % 2 == 0 else 1.0

# Les tirets de voie défilent : la vitesse se lit enfin.
func _scroll_road(delta: float) -> void:
	for d in _dashes:
		d.position.y += _scroll * delta
		if d.position.y > ARENA_H:
			d.position.y -= ARENA_H + 160.0

func _spawn_and_move(delta: float) -> void:
	_row_timer -= delta
	if _row_timer <= 0.0:
		_spawn_row()
		_row_timer = _row_interval
	for child in obstacle_layer.get_children():
		var o: ColorRect = child as ColorRect
		if o == null:
			continue
		var drift: float = float(o.get_meta("drift", 0.0))
		o.position.y += (_scroll + float(o.get_meta("extra", 0.0))) * delta
		o.position.x += drift * delta
		if o.position.y > ARENA_H + 40.0 or o.position.x < -200.0 or o.position.x > ARENA_W + 200.0:
			o.queue_free()

# Une rangée bloque 1 à 3 voies sur 4 : il reste toujours un passage.
func _spawn_row() -> void:
	var lanes: Array = range(LANES)
	lanes.shuffle()
	var progress: float = clampf(1.0 - _time_left / DURATION, 0.0, 1.0)
	var blocked: int = 1 + int(_rng.randf() < 0.35 + 0.5 * progress) + int(_rng.randf() < progress * 0.6)
	blocked = mini(blocked, LANES - 1)
	for i in blocked:
		_spawn_car(int(lanes[i]))
	var free_lane: int = int(lanes[LANES - 1])
	if _rng.randf() < PARCEL_CHANCE:
		_spawn_parcel(free_lane)
	if _rng.randf() < PEDESTRIAN_CHANCE * (0.5 + progress):
		_spawn_pedestrian()

func _lane_x(lane: int) -> float:
	return LANE_LEFT + LANE_W * (float(lane) + 0.5)

func _spawn_car(lane: int) -> void:
	var w: float = LANE_W * 0.62
	var h: float = 150.0
	var car: ColorRect = ColorRect.new()
	car.size = Vector2(w, h)
	car.position = Vector2(_lane_x(lane) - w * 0.5, -h)
	car.color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
	car.set_meta("kind", "car")
	# Les voitures roulent dans le même sens, un peu plus lentement que la rue.
	car.set_meta("extra", -_rng.randf_range(40.0, 120.0))
	# Pare-brise + feux : lisible en un coup d'œil.
	_add_detail(car, Rect2(w * 0.14, h * 0.62, w * 0.72, h * 0.18), Color(0.55, 0.75, 0.9, 1))
	_add_detail(car, Rect2(w * 0.08, h * 0.92, w * 0.18, h * 0.06), Color(0.95, 0.3, 0.25, 1))
	_add_detail(car, Rect2(w * 0.74, h * 0.92, w * 0.18, h * 0.06), Color(0.95, 0.3, 0.25, 1))
	obstacle_layer.add_child(car)

func _spawn_pedestrian() -> void:
	var p: ColorRect = ColorRect.new()
	p.size = Vector2(36, 52)
	var from_left: bool = _rng.randf() < 0.5
	p.position = Vector2(LANE_LEFT - 60.0 if from_left else LANE_RIGHT + 24.0, -60.0)
	p.color = Color(0.95, 0.75, 0.55, 1)
	_add_detail(p, Rect2(0, 22, 36, 30), [Color(0.2, 0.6, 0.35, 1), Color(0.9, 0.3, 0.5, 1), Color(0.95, 0.85, 0.2, 1)][_rng.randi() % 3])
	p.set_meta("kind", "ped")
	p.set_meta("drift", 260.0 if from_left else -260.0)
	obstacle_layer.add_child(p)

func _spawn_parcel(lane: int) -> void:
	var c: ColorRect = ColorRect.new()
	c.size = Vector2(56, 56)
	c.position = Vector2(_lane_x(lane) - 28.0, -260.0)
	c.color = Color(0.85, 0.62, 0.32, 1)
	_add_detail(c, Rect2(24, 0, 8, 56), Color(0.98, 0.9, 0.55, 1))
	c.set_meta("kind", "parcel")
	obstacle_layer.add_child(c)

func _add_detail(parent: ColorRect, r: Rect2, color: Color) -> void:
	var d: ColorRect = ColorRect.new()
	d.position = r.position
	d.size = r.size
	d.color = color
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)

func _check_collisions() -> void:
	if bike == null:
		return
	var brect: Rect2 = Rect2(bike.position, Vector2(BIKE_W, BIKE_H)).grow(-6.0)
	for child in obstacle_layer.get_children():
		var o: ColorRect = child as ColorRect
		if o == null or o.is_queued_for_deletion():
			continue
		if not brect.intersects(Rect2(o.position, o.size)):
			continue
		if String(o.get_meta("kind", "")) == "parcel":
			_deliveries += 1
			o.queue_free()
			sfx("coin")
			pulse(0.2, 0.04)
			if status_label:
				status_label.text = "Entrega %d ✓" % _deliveries
			continue
		if _iframes_left <= 0.0:
			_take_hit()
			return

func _take_hit() -> void:
	_integrity -= 1
	_iframes_left = I_FRAMES
	sfx("mg_miss")
	sfx("mg_drop")
	pulse(0.7, 0.18)
	if status_label:
		if _integrity > 0:
			status_label.text = "Batida ! Commande secouée — %d/3" % _integrity
		else:
			status_label.text = "Commande détruite…"
	if _integrity <= 0:
		_end_game()

func _update_labels() -> void:
	if integrity_label:
		integrity_label.text = "📦 %d · ♥ %d/3" % [_deliveries, _integrity]
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = final_qualifies(_integrity > 0 and _deliveries >= DELIVERIES_TO_QUALIFY)
	if status_label:
		if qualifies:
			status_label.text = "Tournée réussie ! %d entregas · +R$ 50" % _deliveries
		elif _integrity <= 0:
			status_label.text = "Tournée ratée — commande détruite"
		else:
			status_label.text = "Seulement %d entregas (il en faut %d)" % [_deliveries, DELIVERIES_TO_QUALIFY]
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("bike", {"integrity": _integrity, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, _integrity)
