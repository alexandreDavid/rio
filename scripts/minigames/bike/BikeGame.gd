class_name BikeGame
extends Node2D

# Mini-jeu de livraison à vélo. Défilement vertical, le joueur contrôle un vélo
# qui doit éviter voitures, piétons et étals de rue pendant 30 secondes. Chaque
# collision abîme le colis (3 points d'intégrité). Si au moins 1 point survit à
# la fin du timer → livraison réussie : R$ 50 + CIVIC +1 (plafonné à 5 via "bike_deliveries").

signal match_ended(qualifies: bool, integrity: int)

const DURATION: float = 30.0
const INTEGRITY_START: int = 3

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

# Vélo : zone jouable restreinte à la "rue" (couloir central) pour forcer à
# slalomer entre les obstacles plutôt que juste se coller à un bord.
const BIKE_W: float = 54.0
const BIKE_H: float = 90.0
const BIKE_SPEED: float = 600.0
const LANE_LEFT: float = 240.0
const LANE_RIGHT: float = ARENA_W - 240.0
const LANE_TOP: float = 360.0
const LANE_BOTTOM: float = ARENA_H - 160.0

const OBSTACLE_SPEED: float = 400.0
const OBSTACLE_ACCEL: float = 12.0
const SPAWN_INTERVAL_START: float = 0.9
const SPAWN_INTERVAL_MIN: float = 0.38
const I_FRAMES: float = 0.6

# Types d'obstacles (taille + couleur)
const OBSTACLE_TYPES: Array = [
	{"w": 90.0, "h": 60.0, "color": Color(0.85, 0.2, 0.2, 1)},    # voiture rouge
	{"w": 90.0, "h": 60.0, "color": Color(0.25, 0.45, 0.85, 1)},  # voiture bleue
	{"w": 36.0, "h": 52.0, "color": Color(0.95, 0.82, 0.3, 1)},   # piéton (silhouette jaune)
	{"w": 80.0, "h": 40.0, "color": Color(0.9, 0.55, 0.2, 1)},    # étal orange
]

@onready var bike: ColorRect = $Bike
@onready var obstacle_layer: Node2D = $ObstacleLayer
@onready var integrity_label: Label = $UI/IntegrityLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status

var _time_left: float = DURATION
var _integrity: int = INTEGRITY_START
var _ended: bool = false
var _obstacle_speed: float = OBSTACLE_SPEED
var _spawn_timer: float = 0.8
var _spawn_interval: float = SPAWN_INTERVAL_START
var _iframes_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	EventBus.minigame_started.emit("bike")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	if status_label:
		status_label.text = "Livraison en cours — évite la circulation !"
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
	_obstacle_speed += OBSTACLE_ACCEL * delta
	_spawn_interval = max(SPAWN_INTERVAL_MIN, _spawn_interval - 0.02 * delta)
	_move_bike(delta)
	_spawn_and_move_obstacles(delta)
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
	if bike:
		bike.modulate.a = 0.45 if _iframes_left > 0.0 else 1.0

func _spawn_and_move_obstacles(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_obstacle()
		_spawn_timer = _spawn_interval
	for child in obstacle_layer.get_children():
		var o: ColorRect = child as ColorRect
		if o == null:
			continue
		o.position.y += _obstacle_speed * delta
		if o.position.y > ARENA_H + 20.0:
			o.queue_free()

func _spawn_obstacle() -> void:
	var t: Dictionary = OBSTACLE_TYPES[_rng.randi() % OBSTACLE_TYPES.size()]
	var x: float = _rng.randf_range(LANE_LEFT, LANE_RIGHT - t.w)
	var o: ColorRect = ColorRect.new()
	o.position = Vector2(x, -t.h)
	o.size = Vector2(t.w, t.h)
	o.color = t.color
	obstacle_layer.add_child(o)

func _check_collisions() -> void:
	if _iframes_left > 0.0 or bike == null:
		return
	var brect: Rect2 = Rect2(bike.position, Vector2(BIKE_W, BIKE_H))
	for child in obstacle_layer.get_children():
		var o: ColorRect = child as ColorRect
		if o == null:
			continue
		if brect.intersects(Rect2(o.position, o.size)):
			_take_hit()
			return

func _take_hit() -> void:
	_integrity -= 1
	_iframes_left = I_FRAMES
	if status_label:
		if _integrity > 0:
			status_label.text = "Colis secoué ! Intégrité %d/3" % _integrity
		else:
			status_label.text = "Colis détruit…"

func _update_labels() -> void:
	if integrity_label:
		integrity_label.text = "📦 %d/3" % _integrity
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _integrity > 0
	if status_label:
		if qualifies:
			status_label.text = "Livraison réussie ! (+R$ 50, +1 Respect)"
		else:
			status_label.text = "Livraison ratée (colis détruit)"
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("bike", {"integrity": _integrity, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, _integrity)
