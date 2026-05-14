extends Node2D

# Niterói : anime les éléments décoratifs de la baie pour donner vie à la scène
# sans coût CPU notable. Drift horizontal lent pour les nuages, le bateau et
# les mouettes ; léger bob vertical sur le bateau.

@onready var _clouds: Array[ColorRect] = [
	get_node_or_null("CloudA") as ColorRect,
	get_node_or_null("CloudB") as ColorRect,
	get_node_or_null("CloudC") as ColorRect,
]
@onready var _gulls: Array[ColorRect] = [
	get_node_or_null("GullA") as ColorRect,
	get_node_or_null("GullB") as ColorRect,
	get_node_or_null("GullC") as ColorRect,
]
@onready var _boat: ColorRect = $FishingBoat
@onready var _boat_mast: ColorRect = $FishingBoatMast
@onready var _boat_sail: ColorRect = $FishingBoatSail

const CLOUD_SPEED: float = 6.0  # px/s vers l'ouest
const GULL_SPEED: float = 14.0  # px/s
const BOAT_SPEED: float = 3.5   # px/s (lent, marée)
const BOAT_BOB_AMP: float = 1.5
const BOAT_BOB_PERIOD: float = 2.6

var _t: float = 0.0
# Positions de départ pour ramener à l'origine quand on dépasse le bord.
var _cloud_origins: Array[float] = []
var _gull_origins: Array[float] = []
var _boat_origin_y: float = 0.0

func _ready() -> void:
	for c in _clouds:
		if c:
			_cloud_origins.append(c.offset_left)
	for g in _gulls:
		if g:
			_gull_origins.append(g.offset_left)
	if _boat:
		_boat_origin_y = _boat.offset_top

func _process(delta: float) -> void:
	_t += delta
	_drift(_clouds, _cloud_origins, CLOUD_SPEED, delta, -800.0, 800.0)
	_drift(_gulls, _gull_origins, GULL_SPEED, delta, -800.0, 800.0)
	_drift_boat(delta)

# Drift horizontal vers l'ouest ; wrap-around quand on dépasse le bord gauche.
func _drift(items: Array, origins: Array, speed: float, delta: float, left: float, right: float) -> void:
	for i in items.size():
		var node: ColorRect = items[i]
		if node == null:
			continue
		var width: float = node.offset_right - node.offset_left
		node.offset_left -= speed * delta
		node.offset_right -= speed * delta
		if node.offset_right < left:
			node.offset_left = right
			node.offset_right = right + width

func _drift_boat(delta: float) -> void:
	if _boat == null:
		return
	var w: float = _boat.offset_right - _boat.offset_left
	_boat.offset_left += BOAT_SPEED * delta
	_boat.offset_right += BOAT_SPEED * delta
	if _boat_mast:
		_boat_mast.offset_left += BOAT_SPEED * delta
		_boat_mast.offset_right += BOAT_SPEED * delta
	if _boat_sail:
		_boat_sail.offset_left += BOAT_SPEED * delta
		_boat_sail.offset_right += BOAT_SPEED * delta
	if _boat.offset_left > 700.0:
		var dx: float = 700.0 - (-300.0)  # reset à -300
		_boat.offset_left -= dx
		_boat.offset_right -= dx
		if _boat_mast:
			_boat_mast.offset_left -= dx
			_boat_mast.offset_right -= dx
		if _boat_sail:
			_boat_sail.offset_left -= dx
			_boat_sail.offset_right -= dx
	# Bob vertical léger.
	var bob: float = sin(_t * TAU / BOAT_BOB_PERIOD) * BOAT_BOB_AMP
	_boat.offset_top = _boat_origin_y + bob
	_boat.offset_bottom = _boat_origin_y + 12.0 + bob
