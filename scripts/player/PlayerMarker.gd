class_name PlayerMarker
extends Node2D

# « Tu es ici » : un chevron doré qui rebondit au-dessus du joueur pendant
# quelques secondes au démarrage et après chaque saut de position (porte,
# taxi, couture, cinématique) — là où l'on perd son personnage parmi les PNJ.

const SHOW_SEC: float = 4.0
const TELEPORT_PX: float = 160.0
const HEAD_Y: float = -34.0
const GOLD: Color = Color(1.0, 0.84, 0.3, 1)
const INK: Color = Color(0.12, 0.08, 0.04, 1)

var _left: float = SHOW_SEC
var _t: float = 0.0
var _last_pos: Vector2 = Vector2.INF

func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	var p: Node2D = get_parent() as Node2D
	if p != null:
		var gp: Vector2 = p.global_position
		if _last_pos != Vector2.INF and gp.distance_to(_last_pos) > TELEPORT_PX:
			_left = SHOW_SEC
		_last_pos = gp
	# Le compte à rebours attend que le joueur ait la main (pas pendant un
	# dialogue ou une cinématique, où il ne cherche pas son personnage).
	if not DialogueBridge.is_active():
		_left = maxf(0.0, _left - delta)
	_t += delta
	visible = _left > 0.0
	if visible:
		# Fondu sur la dernière seconde.
		modulate.a = clampf(_left, 0.0, 1.0)
		queue_redraw()

func is_showing() -> bool:
	return _left > 0.0

func _draw() -> void:
	var y: float = HEAD_Y - 4.0 - absf(sin(_t * 5.0)) * 5.0
	var outer: PackedVector2Array = [Vector2(-8, y - 8), Vector2(8, y - 8), Vector2(0, y + 2)]
	var inner: PackedVector2Array = [Vector2(-5, y - 6.5), Vector2(5, y - 6.5), Vector2(0, y - 0.5)]
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(inner, GOLD)
