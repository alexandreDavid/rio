class_name AmbientDrifter
extends Node2D

# Anime les enfants ColorRect décoratifs d'un district en fonction de leur
# groupe Godot. Léger et zéro-allocation par frame.
#
# Groupes reconnus (attachables dans l'éditeur ou via la déclaration .tscn
# `groups=["drift_west"]`) :
#   - "drift_west"  : dérive horizontale -x (vent dominant)
#   - "drift_east"  : dérive horizontale +x (marée montante)
#   - "drift_bob"   : bob vertical sinusoïdal seul
#
# Le wrap se fait sur les bornes WRAP_LEFT / WRAP_RIGHT. Chaque district peut
# overrider via setters dans son script enfant si besoin.

@export var drift_speed: float = 8.0  # px/s
@export var drift_speed_vertical: float = 22.0  # px/s pour drift_south (confettis)
@export var bob_amp: float = 1.5
@export var bob_period: float = 2.6
@export var wrap_left: float = -800.0
@export var wrap_right: float = 800.0
@export var wrap_top: float = -300.0
@export var wrap_bottom: float = 400.0

var _t: float = 0.0
var _drift_west: Array[Node] = []
var _drift_east: Array[Node] = []
var _drift_bob: Array[Node] = []
var _drift_south: Array[Node] = []
var _bob_origins: Dictionary = {}  # node -> origin y

func _ready() -> void:
	_drift_west = get_tree().get_nodes_in_group("drift_west").filter(_is_descendant)
	_drift_east = get_tree().get_nodes_in_group("drift_east").filter(_is_descendant)
	_drift_bob = get_tree().get_nodes_in_group("drift_bob").filter(_is_descendant)
	_drift_south = get_tree().get_nodes_in_group("drift_south").filter(_is_descendant)
	for n in _drift_bob:
		if n is ColorRect:
			_bob_origins[n] = (n as ColorRect).offset_top

func _is_descendant(n: Node) -> bool:
	return n.is_inside_tree() and is_ancestor_of(n)

func _process(delta: float) -> void:
	_t += delta
	for n in _drift_west:
		_drift_horizontal(n, -drift_speed, delta)
	for n in _drift_east:
		_drift_horizontal(n, drift_speed, delta)
	for n in _drift_south:
		_drift_vertical(n, drift_speed_vertical, delta)
	var bob: float = sin(_t * TAU / bob_period) * bob_amp
	for n in _drift_bob:
		if n is ColorRect:
			var rect: ColorRect = n as ColorRect
			var origin: float = float(_bob_origins.get(rect, rect.offset_top))
			var h: float = rect.offset_bottom - rect.offset_top
			rect.offset_top = origin + bob
			rect.offset_bottom = origin + h + bob

func _drift_horizontal(n: Node, speed: float, delta: float) -> void:
	if not (n is ColorRect):
		return
	var rect: ColorRect = n as ColorRect
	var width: float = rect.offset_right - rect.offset_left
	rect.offset_left += speed * delta
	rect.offset_right += speed * delta
	if speed < 0.0 and rect.offset_right < wrap_left:
		rect.offset_left = wrap_right
		rect.offset_right = wrap_right + width
	elif speed > 0.0 and rect.offset_left > wrap_right:
		rect.offset_left = wrap_left - width
		rect.offset_right = wrap_left

# Drift vertical descendant (confettis). Wrap au-dessus quand on dépasse le bas.
func _drift_vertical(n: Node, speed: float, delta: float) -> void:
	if not (n is ColorRect):
		return
	var rect: ColorRect = n as ColorRect
	var height: float = rect.offset_bottom - rect.offset_top
	rect.offset_top += speed * delta
	rect.offset_bottom += speed * delta
	if rect.offset_top > wrap_bottom:
		rect.offset_top = wrap_top - height
		rect.offset_bottom = wrap_top
