extends Control

# Boussole directionnelle. Pointe en permanence vers l'objectif courant fourni
# par NavigationDirector. Trois cas :
#   - POINT, cible visible à l'écran   → anneau pulsant sur le lieu + libellé
#   - POINT, cible hors-écran          → flèche au bord + libellé + distance
#   - TRAVEL (autre district)          → flèche vers le TaxiStand (si à Copa),
#                                         sinon bandeau central « 🚕 → district »
#
# Rendu 100 % code (draw_*), aucune dépendance art. Conçu mobile : grosse flèche,
# police 16, n'intercepte aucun toucher. Apparition/disparition en fondu ; la
# couleur reflète la voie scellée (cf. NavigationDirector.voie_color).

const FRAME_MARGIN: float = 84.0
const ARROW_SIZE: float = 26.0
const RING_RADIUS: float = 26.0
const LABEL_FONT_SIZE: int = 16
const ARRIVED_DIST: float = 70.0
# Vitesse du fondu (≈ 0.17 s pour apparaître/disparaître).
const FADE_SPEED: float = 6.0
# Échelle d'affichage de la distance (px monde → mètres « ressentis »).
const PX_PER_M: float = 14.0

var _t: float = 0.0
var _alpha: float = 0.0
var _font: Font = null
# Dernière cible dessinable mémorisée (permet de fondre en sortie après que
# NavigationDirector soit repassé à NONE).
var _live: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_t += delta
	var nav: Dictionary = NavigationDirector.get_live()
	var active: bool = GameManager.player != null \
			and not DialogueBridge.is_active() \
			and int(nav.get("kind", NavigationDirector.Kind.NONE)) != NavigationDirector.Kind.NONE
	if active:
		_live = nav
	_alpha = move_toward(_alpha, 1.0 if active else 0.0, delta * FADE_SPEED)
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.01 or _live.is_empty() or GameManager.player == null:
		return
	var kind: int = int(_live.get("kind", NavigationDirector.Kind.NONE))
	var color: Color = _live.get("color", Color(0.96, 0.82, 0.36, 1.0))
	var label: String = _live.get("label", "")

	# Résolution de la position monde à pointer.
	var target_world: Vector2
	if kind == NavigationDirector.Kind.POINT:
		target_world = _live.get("world_pos", Vector2.ZERO)
	else:  # TRAVEL → pointer le taxi (uniquement résoluble à Copa)
		var taxi: Vector2 = _taxi_world()
		if taxi == NavigationDirector.NO_POS:
			_draw_travel_banner("🚕 → %s" % label, color)
			return
		target_world = taxi
		if label != "":
			label = "🚕 " + label

	var xform: Transform2D = get_viewport().get_canvas_transform()
	var t_screen: Vector2 = xform * target_world
	var p_screen: Vector2 = xform * GameManager.player.global_position
	var view: Rect2 = get_viewport_rect()
	var inner: Rect2 = Rect2(
		view.position + Vector2(FRAME_MARGIN, FRAME_MARGIN),
		view.size - Vector2(FRAME_MARGIN * 2.0, FRAME_MARGIN * 2.0))

	var world_dist: float = GameManager.player.global_position.distance_to(target_world)

	if inner.has_point(t_screen):
		# Cible visible : anneau pulsant dessus.
		if world_dist > ARRIVED_DIST:
			_draw_ring(t_screen, color)
		else:
			_draw_ring(t_screen, color.lerp(Color(1, 1, 1, 1), 0.3))
		if label != "":
			_draw_label(t_screen + Vector2(0, -RING_RADIUS - 14.0), label, color)
		return

	# Cible hors-écran : flèche au bord + libellé + distance.
	var origin: Vector2 = p_screen if inner.has_point(p_screen) else view.get_center()
	var dir: Vector2 = (t_screen - origin)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var tip: Vector2 = _edge_point(origin, dir, inner)
	_draw_arrow(tip, dir, color)
	var full_label: String = label
	var meters: int = int(round(world_dist / PX_PER_M))
	if meters > 0:
		full_label = "%s  ·  %dm" % [label, meters] if label != "" else "%dm" % meters
	if full_label != "":
		_draw_label(tip - dir * (ARROW_SIZE + 18.0), full_label, color)

# --- Résolution du taxi (mode voyage) ---

func _taxi_world() -> Vector2:
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return NavigationDirector.NO_POS
	var taxi: Node2D = world.get_node_or_null("TaxiStand") as Node2D
	if taxi == null:
		return NavigationDirector.NO_POS
	if GameManager.player != null \
			and taxi.global_position.distance_to(GameManager.player.global_position) > NavigationDirector.MAX_POINT_DIST:
		return NavigationDirector.NO_POS
	return taxi.global_position

# --- Primitives de dessin (toutes teintées par _alpha) ---

# Applique le fondu courant à une couleur.
func _a(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * _alpha)

func _draw_ring(center: Vector2, color: Color) -> void:
	var pulse: float = 1.0 + sin(_t * 4.0) * 0.18
	var r: float = RING_RADIUS * pulse
	draw_arc(center, r, 0.0, TAU, 32, _a(Color(0, 0, 0, 0.45)), 6.0, true)
	draw_arc(center, r, 0.0, TAU, 32, _a(color), 3.0, true)
	draw_circle(center, 4.0, _a(color))

func _draw_arrow(tip: Vector2, dir: Vector2, color: Color) -> void:
	var pulse: float = 1.0 + sin(_t * 5.0) * 0.12
	var s: float = ARROW_SIZE * pulse
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var back: Vector2 = tip - dir * s
	var p2: Vector2 = back + perp * (s * 0.6)
	var p3: Vector2 = back - perp * (s * 0.6)
	var tri: PackedVector2Array = PackedVector2Array([tip, p2, p3])
	var halo: PackedVector2Array = PackedVector2Array([
		tip + dir * 2.0,
		back + perp * (s * 0.6) - perp * 2.0,
		back - perp * (s * 0.6) + perp * 2.0,
	])
	draw_colored_polygon(halo, _a(Color(0, 0, 0, 0.5)))
	draw_colored_polygon(tri, _a(color))

func _draw_label(center: Vector2, text: String, color: Color) -> void:
	if _font == null or text == "":
		return
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var pad: Vector2 = Vector2(8.0, 4.0)
	var box: Rect2 = Rect2(center - text_size / 2.0 - pad, text_size + pad * 2.0)
	var view: Rect2 = get_viewport_rect()
	box.position.x = clampf(box.position.x, view.position.x + 4.0, view.end.x - box.size.x - 4.0)
	box.position.y = clampf(box.position.y, view.position.y + 4.0, view.end.y - box.size.y - 4.0)
	draw_rect(box, _a(Color(0.05, 0.05, 0.08, 0.78)), true)
	draw_rect(box, _a(color), false, 1.5)
	var baseline: Vector2 = box.position + pad + Vector2(0, _font.get_ascent(LABEL_FONT_SIZE))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, _a(Color(0.97, 0.97, 0.93, 1.0)))

func _draw_travel_banner(text: String, color: Color) -> void:
	var view: Rect2 = get_viewport_rect()
	_draw_label(Vector2(view.get_center().x, view.position.y + FRAME_MARGIN * 0.6), text, color)

func _edge_point(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var best_t: float = INF
	if dir.x != 0.0:
		for ex in [rect.position.x, rect.end.x]:
			var t: float = (ex - origin.x) / dir.x
			if t > 0.0:
				var y: float = origin.y + dir.y * t
				if y >= rect.position.y - 0.5 and y <= rect.end.y + 0.5:
					best_t = minf(best_t, t)
	if dir.y != 0.0:
		for ey in [rect.position.y, rect.end.y]:
			var t2: float = (ey - origin.y) / dir.y
			if t2 > 0.0:
				var x: float = origin.x + dir.x * t2
				if x >= rect.position.x - 0.5 and x <= rect.end.x + 0.5:
					best_t = minf(best_t, t2)
	if best_t == INF:
		return origin
	return origin + dir * best_t
