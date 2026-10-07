extends Node2D

# Outil dev : audit d'accessibilité géométrique du monde complet.
# Charge Copacabana.tscn (autoloads actifs, districts et intérieurs en place),
# puis propage depuis chaque point d'apparition (joueur, PlayerSpawn*, SpawnPoint,
# retour Copa) sur une grille de 8 px : une cellule est franchissable si la
# boîte du joueur (14×20) n'y touche aucun StaticBody2D. On vérifie ensuite que
# chaque interactif (Area2D scripté : Interactable, DistrictExit, triggers…) est
# atteignable, que chaque téléport (portes, sorties piétonnes, taxi) débouche sur
# du sol atteint, et on signale les zones mortes et les régions sans mur.
# Usage : godot --headless --path . tools/ReachabilityAudit.tscn
# Code de sortie 1 s'il reste un injoignable, une fuite, un téléport ou un seed
# dans un mur (branché dans run_tests.sh). RIO_AUDIT_OUT=<dossier> écrit en plus
# une carte PNG par région (1 px = 1 cellule ; rouge = injoignable).

const STEP: float = 8.0
const COLLISION_MASK: int = 1 | 4  # comme PlayerController : murs + eau
const MAX_CELLS_PER_SEED: int = 300000
const COPA_BOUNDS: Rect2 = Rect2(-450, -1500, 3800, 2300)  # large au nord : on veut savoir si la map est fermée
const INTERACT_GROW: Vector2 = Vector2(9, 12)  # demi-boîte joueur + marge

var _world: Node2D
var _space: PhysicsDirectSpaceState2D
var _probe: RectangleShape2D
var _walk_cache: Dictionary = {}   # Vector2i -> bool
var _visited: Dictionary = {}      # Vector2i -> owner name
var _owner_cells: Dictionary = {}  # owner name -> int
var _leaks: Array[String] = []
var _blocked_seeds: Array[String] = []
var _interactable_total: int = 0


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn")
	_world = packed.instantiate() as Node2D
	_world.name = "World"
	add_child(_world)
	for i in 8:
		await get_tree().physics_frame
	_space = get_world_2d().direct_space_state
	_probe = RectangleShape2D.new()
	_probe.size = Vector2(14, 20)

	var seeds: Array = _collect_seeds()
	print("== SEEDS : %d" % seeds.size())
	for s in seeds:
		_flood(s)
	print("== CELLULES ATTEINTES : %d" % _visited.size())
	for owner in _owner_cells:
		print("   %-28s %7d cellules" % [owner, _owner_cells[owner]])
	if not _blocked_seeds.is_empty():
		print("== SEEDS BLOQUÉS (apparition dans un mur) :")
		for b in _blocked_seeds:
			print("   " + b)
	if not _leaks.is_empty():
		print("== FUITES (propagation sans mur jusqu'à la borne) :")
		for l in _leaks:
			print("   " + l)

	var unreachable_count: int = _audit_interactables()
	var teleport_ko: int = _audit_teleports()
	if OS.get_environment("RIO_AUDIT_OUT") != "":
		_dump_images()
	var failures: int = unreachable_count + teleport_ko + _leaks.size() + _blocked_seeds.size()
	if failures == 0:
		print("== AUDIT ACCESSIBILITÉ : OK (%d interactifs, %d régions)" % [_interactable_total, _owner_cells.size()])
	else:
		print("== AUDIT ACCESSIBILITÉ : %d PROBLÈME(S) — %d injoignable(s), %d téléport(s) KO, %d fuite(s), %d seed(s) bloqué(s)" % [failures, unreachable_count, teleport_ko, _leaks.size(), _blocked_seeds.size()])
	get_tree().quit(0 if failures == 0 else 1)


# --- Seeds -----------------------------------------------------------------

func _collect_seeds() -> Array:
	var seeds: Array = []
	var player: Node2D = _world.get_node_or_null("Player") as Node2D
	if player:
		seeds.append({"pos": player.global_position, "label": "Player (départ)", "owner": _region_node_at(player.global_position)})
	seeds.append({"pos": DistrictManager.COPACABANA_RETURN_POS, "label": "COPACABANA_RETURN_POS", "owner": null})
	for n in _world.find_children("*", "Marker2D", true, false):
		if n.name.begins_with("PlayerSpawn") or n.name == "SpawnPoint":
			seeds.append({"pos": (n as Node2D).global_position, "label": str(_world.get_path_to(n)), "owner": _region_node_of(n)})
	for n in _world.find_children("SpawnPoint", "", true, false):
		if not (n is Marker2D) and n is Node2D:
			seeds.append({"pos": (n as Node2D).global_position, "label": str(_world.get_path_to(n)), "owner": _region_node_of(n)})
	# Destinations de portes : certains intérieurs (Academia…) n'ont pas de
	# SpawnPoint, la porte porte une destination en dur.
	for d in _world.find_children("*", "", true, false):
		if d is BuildingDoor and (d as BuildingDoor).destination != Vector2.ZERO:
			var dest: Vector2 = (d as BuildingDoor).destination
			seeds.append({"pos": dest, "label": "porte " + str(_world.get_path_to(d)).right(40), "owner": _region_node_at(dest)})
	return seeds


# Le « propriétaire » d'un nœud = l'enfant direct de World qui le contient
# (district, intérieur, prop) ; sert à nommer la région et à la borner.
func _owner_of(node: Node) -> Node:
	var n: Node = node
	while n != null and n.get_parent() != _world:
		n = n.get_parent()
	return n


# Région d'audit : district ou intérieur ; tout le reste (props posés à la racine,
# joueur, intérieurs générés par Copa au-dessus de la map) = « Copacabana ».
# Enfant direct de World dont le sol contient le point (districts, intérieurs).
func _owner_at(p: Vector2) -> Node:
	for child in _world.get_children():
		if not (child.name.ends_with("District") or child.name.ends_with("Interior")):
			continue
		if _ground_bbox(child).has_point(p):
			return child
	return null


func _owner_name(owner: Node) -> String:
	if owner == null:
		return "Copacabana"
	if owner.name.ends_with("District") or owner.name.ends_with("Interior"):
		return owner.name
	return "Copacabana"


# Région d'audit d'un nœud : l'intérieur embarqué qui le contient (sous-scène
# de scenes/interiors/ posée hors carte dans un district), sinon son district,
# sinon Copa. Chaque région a sa propre enceinte.
func _region_node_of(node: Node) -> Node:
	var n: Node = node
	var district: Node = null
	while n != null and n != _world:
		if n.scene_file_path.contains("/interiors/"):
			return n
		if n.get_parent() == _world and (n.name.ends_with("District") or n.name.ends_with("Interior")):
			district = n
		n = n.get_parent()
	return district


func _region_name_of(node: Node) -> String:
	var r: Node = _region_node_of(node)
	return r.name if r != null else "Copacabana"


# Région contenant un point : le plus petit intérieur dont le sol contient p,
# sinon le district, sinon Copa.
func _region_node_at(p: Vector2) -> Node:
	var best: Node = null
	var best_area: float = INF
	for n in _world.find_children("*", "Node2D", true, false):
		if not n.scene_file_path.contains("/interiors/"):
			continue
		var bb: Rect2 = _rects_bbox(n)
		if bb.size.x > 0.0 and bb.grow(40.0).has_point(p) and bb.get_area() < best_area:
			best = n
			best_area = bb.get_area()
	if best != null:
		return best
	return _owner_at(p)


func _rects_bbox(node: Node) -> Rect2:
	var bbox: Rect2 = Rect2()
	var first: bool = true
	for cr in node.find_children("*", "ColorRect", true, false):
		if cr.is_in_group("district_backdrop") or not (cr as ColorRect).visible:
			continue
		var r: Rect2 = (cr as ColorRect).get_global_rect()
		bbox = r if first else bbox.merge(r)
		first = false
	return bbox if not first else Rect2()


# Sol réel d'un district : ses ColorRect hors toile de fond étendue.
func _ground_bbox(owner: Node) -> Rect2:
	var bbox: Rect2 = Rect2()
	var first: bool = true
	# Enfants directs seulement : les intérieurs embarqués dans une scène de
	# district (Penthouse, Le Parc…) sont des sous-scènes posées hors carte.
	for cr in owner.get_children():
		if not (cr is ColorRect) or cr.is_in_group("district_backdrop") or not (cr as ColorRect).visible:
			continue
		var r: Rect2 = (cr as ColorRect).get_global_rect()
		bbox = r if first else bbox.merge(r)
		first = false
	return bbox if not first else Rect2()


func _bounds_for(owner: Node) -> Rect2:
	if owner == null or owner.name == "Player":
		return COPA_BOUNDS
	if owner.scene_file_path.contains("/interiors/"):
		var bb: Rect2 = _rects_bbox(owner)
		return bb.grow(200.0) if bb.size.x > 0.0 else COPA_BOUNDS
	if _owner_name(owner) == "Copacabana":
		return COPA_BOUNDS
	var walls: Rect2 = _walls_bbox(owner)
	if walls.size.x > 100.0:
		return walls.grow(150.0)
	var bbox: Rect2 = _ground_bbox(owner)
	if bbox.size.x < 100.0:
		return COPA_BOUNDS
	return bbox.grow(200.0)


# Enceinte voulue par l'auteur : l'étendue des murs du nœud « Walls ».
func _walls_bbox(owner: Node) -> Rect2:
	var walls: Node = owner.get_node_or_null("Walls")
	if walls == null:
		return Rect2()
	var bbox: Rect2 = Rect2()
	var first: bool = true
	for body in walls.get_children():
		for cs in body.get_children():
			if cs is CollisionShape2D and (cs as CollisionShape2D).shape is RectangleShape2D:
				var half: Vector2 = ((cs as CollisionShape2D).shape as RectangleShape2D).size * 0.5
				var r: Rect2 = _transformed_rect((cs as CollisionShape2D).global_transform, Rect2(-half, half * 2.0))
				bbox = r if first else bbox.merge(r)
				first = false
	return bbox if not first else Rect2()


# --- Propagation -------------------------------------------------------------

func _local_rect(owner: Node, g: Rect2) -> String:
	if owner is Node2D:
		var o: Vector2 = (owner as Node2D).global_position
		return "x %d..%d, y %d..%d" % [int(g.position.x - o.x), int(g.end.x - o.x), int(g.position.y - o.y), int(g.end.y - o.y)]
	return str(g)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / STEP)), int(floor(p.y / STEP)))


func _center_of(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * STEP, (c.y + 0.5) * STEP)


func _walkable(c: Vector2i) -> bool:
	if _walk_cache.has(c):
		return _walk_cache[c]
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = _probe
	params.transform = Transform2D(0.0, _center_of(c))
	params.collision_mask = COLLISION_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var ok: bool = true
	for h in _space.intersect_shape(params, 8):
		if h.collider is StaticBody2D:
			ok = false
			break
	_walk_cache[c] = ok
	return ok


# Une sortie piétonne téléporte dès qu'on la touche : la cellule est atteinte
# (on peut y aller) mais on ne continue pas à pied au-delà (sauf couture).
var _exit_cache: Dictionary = {}

func _is_exit_cell(c: Vector2i) -> bool:
	if _exit_cache.has(c):
		return _exit_cache[c]
	var ap: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	ap.shape = _probe
	ap.transform = Transform2D(0.0, _center_of(c))
	ap.collision_mask = 0x7FFFFFFF
	ap.collide_with_areas = true
	ap.collide_with_bodies = false
	var is_exit: bool = false
	for h in _space.intersect_shape(ap, 8):
		if h.collider is DistrictExit:
			is_exit = true  # couture comprise : l'autre côté appartient à l'autre région
			break
	_exit_cache[c] = is_exit
	return is_exit


func _flood(seed: Dictionary) -> void:
	var owner: Node = seed.owner
	var oname: String = _owner_name(owner)
	var bounds: Rect2 = _bounds_for(owner)
	var start: Vector2i = _cell_of(seed.pos)
	if not _walkable(start):
		# Tolérance : une cellule voisine libre suffit (le joueur est poussé hors du mur).
		var rescued: bool = false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var c: Vector2i = start + Vector2i(dx, dy)
				if _walkable(c):
					start = c
					rescued = true
					break
			if rescued:
				break
		if not rescued:
			_blocked_seeds.append("%s @ %s (%s)" % [seed.label, seed.pos, oname])
			return
	if _visited.has(start):
		return
	var queue: Array[Vector2i] = [start]
	_visited[start] = oname
	var count: int = 0
	var leaked: bool = false
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		count += 1
		if count >= MAX_CELLS_PER_SEED:
			leaked = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if _visited.has(n):
				continue
			var p: Vector2 = _center_of(n)
			if not bounds.has_point(p):
				leaked = leaked or (owner != null)  # Copa est bornée par convention, pas par mur
				continue
			if not _walkable(n):
				continue
			_visited[n] = oname
			if _is_exit_cell(n):
				continue
			queue.append(n)
	_owner_cells[oname] = _owner_cells.get(oname, 0) + count
	if owner == null and seed.label == "COPACABANA_RETURN_POS":
		var reach_c: Rect2 = Rect2()
		var fc: bool = true
		for c in _visited:
			if _visited[c] != "Copacabana":
				continue
			var pc: Vector2 = _center_of(c)
			reach_c = Rect2(pc, Vector2.ZERO) if fc else reach_c.expand(pc)
			fc = false
		print("== COPA : étendue atteinte x %d..%d, y %d..%d (map décorée x -300..3200 ; sable 128..~435)" % [int(reach_c.position.x), int(reach_c.end.x), int(reach_c.position.y), int(reach_c.end.y)])
	if leaked and owner != null:
		var ground: Rect2 = _rects_bbox(owner) if owner.scene_file_path.contains("/interiors/") else _walls_bbox(owner)
		if ground.size.x < 100.0:
			ground = _ground_bbox(owner)
		var reach: Rect2 = Rect2()
		var f: bool = true
		for c in _visited:
			if _visited[c] != oname:
				continue
			var pc: Vector2 = _center_of(c)
			reach = Rect2(pc, Vector2.ZERO) if f else reach.expand(pc)
			f = false
		var sides: Array[String] = []
		if reach.position.x < ground.position.x - 40.0: sides.append("ouest")
		if reach.end.x > ground.end.x + 40.0: sides.append("est")
		if reach.position.y < ground.position.y - 40.0: sides.append("nord")
		if reach.end.y > ground.end.y + 40.0: sides.append("sud")
		_leaks.append("%s (seed %s) — le joueur sort de l'enceinte par : %s ; enceinte locale %s ; atteint local %s" % [oname, seed.label, ", ".join(sides) if not sides.is_empty() else "plafond atteint", _local_rect(owner, ground), _local_rect(owner, reach)])


# --- Interactifs ---------------------------------------------------------------

func _area_rect(area: Area2D) -> Rect2:
	var rect: Rect2 = Rect2(area.global_position, Vector2.ZERO)
	var any: bool = false
	for child in area.get_children():
		var r: Rect2
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var cs: CollisionShape2D = child
			var sh: Shape2D = cs.shape
			var half: Vector2 = Vector2(8, 8)
			if sh is RectangleShape2D:
				half = (sh as RectangleShape2D).size * 0.5
			elif sh is CircleShape2D:
				half = Vector2.ONE * (sh as CircleShape2D).radius
			elif sh is CapsuleShape2D:
				half = Vector2((sh as CapsuleShape2D).radius, (sh as CapsuleShape2D).height * 0.5)
			r = _transformed_rect(cs.global_transform, Rect2(-half, half * 2.0))
		elif child is CollisionPolygon2D:
			var poly: CollisionPolygon2D = child
			if poly.polygon.is_empty():
				continue
			var first: bool = true
			for pt in poly.polygon:
				var g: Vector2 = poly.global_transform * pt
				r = Rect2(g, Vector2.ZERO) if first else r.expand(g)
				first = false
		else:
			continue
		rect = r if not any else rect.merge(r)
		any = true
	return rect


func _transformed_rect(xf: Transform2D, local: Rect2) -> Rect2:
	var pts: Array[Vector2] = [local.position, local.position + Vector2(local.size.x, 0), local.end, local.position + Vector2(0, local.size.y)]
	var out: Rect2 = Rect2(xf * pts[0], Vector2.ZERO)
	for i in range(1, 4):
		out = out.expand(xf * pts[i])
	return out


func _rect_reached(rect: Rect2) -> bool:
	var c0: Vector2i = _cell_of(rect.position)
	var c1: Vector2i = _cell_of(rect.end)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			if _visited.has(Vector2i(cx, cy)):
				return true
	return false


func _nearest_reached_dist(p: Vector2, oname: String) -> float:
	var best: float = INF
	for c in _visited:
		if _visited[c] != oname:
			continue
		best = minf(best, _center_of(c).distance_to(p))
	return best


func _audit_interactables() -> int:
	var areas: Array = _world.find_children("*", "Area2D", true, false)
	var total: int = 0
	var per_owner_total: Dictionary = {}
	var unreachable: Array = []
	var entries: Array = []
	for a in areas:
		var area: Area2D = a
		if area.get_script() == null:
			continue
		var owner: Node = _owner_of(area)
		if owner != null and owner.name == "Player":
			continue
		var oname: String = _region_name_of(area)
		var rect: Rect2 = _area_rect(area).grow_individual(INTERACT_GROW.x, INTERACT_GROW.y, INTERACT_GROW.x, INTERACT_GROW.y)
		var script_name: String = (area.get_script() as Script).resource_path.get_file()
		var enabled: bool = bool(area.get("enabled")) if "enabled" in area else true
		total += 1
		per_owner_total[oname] = per_owner_total.get(oname, 0) + 1
		var entry: Dictionary = {"area": area, "owner": oname, "rect": rect, "script": script_name, "enabled": enabled}
		entries.append(entry)
		if not _rect_reached(rect):
			unreachable.append(entry)
			_unreachable_marks.append([oname, area.global_position])
		else:
			_reached_marks.append([oname, area.global_position])
	print("== INTERACTIFS : %d, injoignables : %d" % [total, unreachable.size()])
	for oname in per_owner_total:
		print("   %-28s %3d interactifs" % [oname, per_owner_total[oname]])
	for oname in _owner_cells:
		if per_owner_total.get(oname, 0) == 0:
			print("   ZONE SANS INTERACTIF : %s" % oname)
	for e in unreachable:
		var area: Area2D = e.area
		var d: float = _nearest_reached_dist(area.global_position, e.owner)
		var parent_name: String = area.get_parent().name if area.get_parent() else "?"
		print("UNREACHABLE | %-24s | %-36s | %-26s | %s | %s | plus proche sol atteint : %s px" % [
			e.owner, str(_world.get_path_to(area)).right(60), e.script, parent_name,
			"%.0f,%.0f" % [area.global_position.x, area.global_position.y],
			("%.0f" % d) if d != INF else "aucun"])
	# Chevauchements : deux interactifs (hors triggers) dont les zones se recouvrent
	var overlaps: int = 0
	for i in entries.size():
		var a: Dictionary = entries[i]
		if a.script.contains("Trigger") or a.script == "DistrictExit.gd" or a.script == "StreetEvent.gd":
			continue
		for j in range(i + 1, entries.size()):
			var b: Dictionary = entries[j]
			if b.owner != a.owner or b.script.contains("Trigger") or b.script == "DistrictExit.gd" or b.script == "StreetEvent.gd":
				continue
			if (a.rect as Rect2).intersects(b.rect):
				overlaps += 1
				if OS.get_environment("RIO_AUDIT_OUT") != "":
					print("OVERLAP | %-24s | %s <-> %s" % [a.owner, (a.area as Node).get_parent().name, (b.area as Node).get_parent().name])
	print("== CHEVAUCHEMENTS D'INTERACTIFS : %d" % overlaps)
	_interactable_total = total
	return unreachable.size()


# --- Images de debug : 1 px par cellule, blanc = atteint, rouge = interactif injoignable,
# vert = interactif atteint. Écrites dans user:// (ou RIO_AUDIT_OUT si défini).
var _unreachable_marks: Array = []  # [owner, Vector2]
var _reached_marks: Array = []

func _dump_images() -> void:
	var out_dir: String = OS.get_environment("RIO_AUDIT_OUT")
	if out_dir == "":
		out_dir = OS.get_user_data_dir()
	var regions: Dictionary = {}
	for c in _visited:
		var o: String = _visited[c]
		if not regions.has(o):
			regions[o] = Rect2i(c, Vector2i.ONE)
		else:
			regions[o] = (regions[o] as Rect2i).expand(c)
	for o in regions:
		var r: Rect2i = regions[o]
		r = r.grow(6)
		if r.size.x > 4000 or r.size.y > 4000:
			continue
		var img: Image = Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.15, 0.15, 0.18, 1))
		for c in _visited:
			if _visited[c] == o:
				img.set_pixelv(c - r.position, Color(0.85, 0.85, 0.8, 1))
		for m in _reached_marks:
			if m[0] == o:
				_mark(img, _cell_of(m[1]) - r.position, Color(0.2, 0.9, 0.3, 1))
		for m in _unreachable_marks:
			if m[0] == o:
				_mark(img, _cell_of(m[1]) - r.position, Color(1.0, 0.2, 0.2, 1))
		var path: String = out_dir.path_join("audit_%s.png" % o)
		img.save_png(path)
	print("== IMAGES : %s/audit_<region>.png" % out_dir)


func _mark(img: Image, c: Vector2i, col: Color) -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var p: Vector2i = c + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixelv(p, col)


# --- Téléports -----------------------------------------------------------------

func _point_reached(p: Vector2) -> bool:
	var c: Vector2i = _cell_of(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _visited.has(c + Vector2i(dx, dy)):
				return true
	return false


func _district_id_of(owner: Node) -> String:
	if owner == null:
		return "copacabana"
	for id in DistrictManager.DISTRICTS:
		if DistrictManager.DISTRICTS[id].get("node_name", "") == owner.name:
			return id
	return "copacabana"


func _audit_teleports() -> int:
	var ko: int = 0
	# Portes
	for d in _world.find_children("*", "", true, false):
		if not (d is BuildingDoor):
			continue
		var door: BuildingDoor = d
		if door.destination == Vector2.ZERO:
			continue
		if not _point_reached(door.destination):
			ko += 1
			print("TELEPORT KO | porte %-40s | %s -> %s (%s)" % [str(_world.get_path_to(door)).right(40),
				_region_name_of(door), door.destination, "sortie" if door.is_exit else "entrée"])
	# Sorties piétonnes
	for e in _world.find_children("*", "Area2D", true, false):
		if not (e is DistrictExit):
			continue
		var ex: DistrictExit = e
		if ex.seamless:
			continue
		var from_id: String = _district_id_of(_owner_of(ex))
		var target: Vector2 = DistrictManager._walk_target(ex.target_district, from_id)
		if not _point_reached(target):
			ko += 1
			print("TELEPORT KO | sortie %-40s | %s -> %s @ %s" % [str(_world.get_path_to(ex)).right(40), from_id, ex.target_district, target])
	# Taxi / spawns par défaut
	for id in DistrictManager.DISTRICTS:
		var p: Vector2 = DistrictManager._resolve_spawn(id)
		if not _point_reached(p):
			ko += 1
			print("TELEPORT KO | taxi -> %-16s @ %s" % [id, p])
	print("== TÉLÉPORTS KO : %d" % ko)
	return ko
