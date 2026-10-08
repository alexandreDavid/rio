extends RefCounted

# Navigation du bot-joueur : grille 8 px (même sonde que l'audit d'accessibilité,
# boîte joueur 14×20 contre les StaticBody2D) + AStarGrid2D. Une instance par
# région (district, intérieur, Copa) — construite à la demande.

const STEP: float = 8.0
const COLLISION_MASK: int = 1 | 4

var bounds: Rect2
var _grid: AStarGrid2D
var _space: PhysicsDirectSpaceState2D
var _probe: RectangleShape2D
var _region: Rect2i
var solid_count: int = 0
var cell_count: int = 0


func build(space: PhysicsDirectSpaceState2D, b: Rect2) -> void:
	_space = space
	bounds = b
	_probe = RectangleShape2D.new()
	_probe.size = Vector2(14, 20)
	var top_left: Vector2i = Vector2i(int(floor(b.position.x / STEP)), int(floor(b.position.y / STEP)))
	var size: Vector2i = Vector2i(int(ceil(b.size.x / STEP)) + 1, int(ceil(b.size.y / STEP)) + 1)
	_region = Rect2i(top_left, size)
	_grid = AStarGrid2D.new()
	_grid.region = _region
	_grid.cell_size = Vector2(STEP, STEP)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = _probe
	params.collision_mask = COLLISION_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	cell_count = size.x * size.y
	for cy in range(top_left.y, top_left.y + size.y):
		for cx in range(top_left.x, top_left.x + size.x):
			params.transform = Transform2D(0.0, center_of(Vector2i(cx, cy)))
			var solid: bool = false
			for h in _space.intersect_shape(params, 4):
				if h.collider is StaticBody2D:
					solid = true
					break
			if solid:
				_grid.set_point_solid(Vector2i(cx, cy), true)
				solid_count += 1


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / STEP)), int(floor(p.y / STEP)))


static func center_of(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * STEP, (c.y + 0.5) * STEP)


func in_region(c: Vector2i) -> bool:
	return _region.has_point(c)


func is_free(c: Vector2i) -> bool:
	return in_region(c) and not _grid.is_point_solid(c)


# Cellule libre la plus proche (spirale bornée). Vector2i(INT_MAX) si aucune.
func nearest_free(p: Vector2, max_radius: int = 12) -> Vector2i:
	var c: Vector2i = cell_of(p)
	if is_free(c):
		return c
	for r in range(1, max_radius + 1):
		var best: Vector2i = Vector2i(2147483647, 2147483647)
		var best_d: float = INF
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var cc: Vector2i = c + Vector2i(dx, dy)
				if is_free(cc):
					var d: float = center_of(cc).distance_to(p)
					if d < best_d:
						best_d = d
						best = cc
		for dy in range(-r + 1, r):
			for dx in [-r, r]:
				var cc: Vector2i = c + Vector2i(dx, dy)
				if is_free(cc):
					var d: float = center_of(cc).distance_to(p)
					if d < best_d:
						best_d = d
						best = cc
		if best_d < INF:
			return best
	return Vector2i(2147483647, 2147483647)


# Chemin en positions monde (centres de cellules), vide si introuvable.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector2i = nearest_free(from)
	var b: Vector2i = nearest_free(to)
	var out: PackedVector2Array = PackedVector2Array()
	if a.x == 2147483647 or b.x == 2147483647:
		return out
	var ids: Array[Vector2i] = _grid.get_id_path(a, b)
	for id in ids:
		out.append(center_of(id))
	return out


# Marque une cellule comme bloquée (le bot s'y est coincé : PNJ, prop sans
# StaticBody détecté…) pour replanifier autour.
func block_cell(p: Vector2) -> void:
	var c: Vector2i = cell_of(p)
	if in_region(c):
		_grid.set_point_solid(c, true)


func unblock_cell(c: Vector2i) -> void:
	if in_region(c):
		_grid.set_point_solid(c, false)
