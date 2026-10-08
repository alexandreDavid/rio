class_name DistrictDresser
extends RefCounted

# Habillage runtime des districts. Les scènes de `scenes/districts/` sont faites
# de ColorRect plats ; on superpose aux dalles de sol taguées par groupe les
# tuiles de l'atlas de Copacabana, sans toucher à la géométrie, aux chemins de
# nœuds ni aux collisions. Pourquoi des groupes plutôt qu'une heuristique
# couleur : c'est explicite dans le .tscn et ça ne surprend personne au runtime.
#
# Groupes reconnus sur un ColorRect :
#   ground_sand / ground_sea / ground_road / ground_calcadao / ground_sidewalk /
#   ground_grass   → tuile répétée par-dessus la dalle (cellules 64×64 monde,
#                    comme _spawn_tile_strip côté Copa)
#   ground_plaza / ground_dirt / ground_stairs → tuile PEINTE (GroundPainter,
#                    pixel-art à la densité du jeu) dans la couleur de la dalle :
#                    pavés des esplanades et ruelles, terre du morro, marches
#                    d'escalier (la largeur de la dalle = la largeur des marches)
#   district_backdrop → la dalle est étendue à toute la bbox du district + marge
#                    et envoyée à z=-10 : plus de gris Godot hors carte
#   building / building_favela → relief de façade via BuildingDressing (ombre,
#                    arête, fondation, toit ; grille de fenêtres + porte si la
#                    façade est nue ; décor de toit aléatoire pour la favela, qui
#                    dessine déjà ses toits)
#   prop_palm / prop_umbrella / prop_beach_cart → le rectangle est l'EMPREINTE du
#                    prop (du haut au pied) : il est masqué et remplacé par le
#                    sprite de l'atlas ancré au pied, dessiné au-dessus des sols.
#                    La couleur du rectangle choisit la toile du parasol ; les
#                    deux palmiers de l'atlas alternent.
#   prop_towel     → serviette à plat, centrée sur le rectangle, au même rang de
#                    dessin (c'est du sol, pas un volume).
# L'écume est posée automatiquement sur chaque couture sable/mer (4 orientations).

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")
const GRASS_TEXTURE: String = "res://assets/sprites/grass.png"
const GRASS_TILE_REGION: Rect2 = Rect2(0, 80, 96, 32)
const CELL: Vector2 = Vector2(64.0, 64.0)
const FOAM_LEN: float = 96.0
const FOAM_THICK: float = 32.0
const FOAM_SEA_OFFSET: float = 8.0   # l'écume mord surtout sur l'eau (cf. _spawn_sea_foam)
const SEAM_TOLERANCE: float = 12.0
const MIN_SEAM_LEN: float = 32.0
const BACKDROP_MARGIN: float = 1400.0
const GROUND_GROUPS: Array = ["ground_sand", "ground_sea", "ground_road", "ground_calcadao", "ground_sidewalk", "ground_grass", "ground_plaza", "ground_dirt", "ground_stairs"]
# Contraste du grain recoloré : 1 = contraste brut de la tuile, 0 = aplat. Le pavé
# a des joints marqués (on l'adoucit), le sable est très doux (on l'amplifie).
const PLAZA_GRAIN: float = 0.65
const DIRT_GRAIN: float = 1.8

# Un seul shader partagé : chaque dalle reçoit son propre ShaderMaterial (région
# + cellule), le sampler reste l'atlas entier — aucune copie d'image.
const TILE_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 region = vec4(0.0, 0.0, 64.0, 64.0);
uniform vec2 cell = vec2(64.0, 64.0);
uniform vec4 tint = vec4(1.0);
uniform float mean_lum = 0.0;  // > 0 : recolorise (luminance relative × tint)
uniform float grain = 1.0;
uniform float wave = 0.0;      // > 0 : ondulation (mer)
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec2 world_px = UV / TEXTURE_PIXEL_SIZE;
	if (wave > 0.0) {
		world_px.x += sin(TIME * 1.2 + world_px.y * 0.08) * wave * 2.0;
		world_px.y += cos(TIME * 0.9 + world_px.x * 0.07) * wave * 1.5;
	}
	vec2 t = fract(world_px / cell);
	// demi-pixel de marge pour ne pas échantillonner le cadre décoratif voisin
	vec2 px = region.xy + 0.5 + t * (region.zw - 1.0);
	vec4 c = texture(TEXTURE, px * TEXTURE_PIXEL_SIZE);
	if (mean_lum > 0.0) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) / mean_lum;
		c.rgb = tint.rgb * mix(1.0, l, grain);
	}
	if (wave > 0.0) {
		c.rgb += 0.05 * sin(TIME * 2.0 + world_px.x * 0.11 + world_px.y * 0.09);
	}
	COLOR = c * vcol;
}
"""

static var _tile_shader: Shader = null
static var _lum_cache: Dictionary = {}  # "tex|region" -> luminance moyenne


static func dress(root: Node) -> void:
	var rects: Array[ColorRect] = []
	_collect_color_rects(root, rects)
	var sands: Array[ColorRect] = []
	var seas: Array[ColorRect] = []
	for cr in rects:
		for group in GROUND_GROUPS:
			if cr.is_in_group(group):
				_overlay_tiles(cr, group)
				if group == "ground_sand":
					sands.append(cr)
				elif group == "ground_sea":
					seas.append(cr)
				break
	_spawn_foam_on_seams(root, sands, seas)
	for cr in rects:
		if cr.is_in_group("building") or cr.is_in_group("building_favela"):
			_dress_building(cr, rects)
	for cr in rects:
		if cr.is_in_group("prop_palm"):
			_replace_with_prop(cr, PropSprites.palm_region_at(cr.position), _palm_height(cr))
		elif cr.is_in_group("prop_umbrella"):
			var variant: Dictionary = PropSprites.umbrella_variant_for(cr.color)
			_replace_with_prop(cr, variant.region, clampf(cr.size.y * 1.8, 50.0, variant.h))
		elif cr.is_in_group("prop_beach_cart"):
			_replace_with_prop(cr, Cfg.BEACH_CART_REGION, clampf(cr.size.y * 1.8, 60.0, 90.0))
		elif cr.is_in_group("prop_towel"):
			_replace_with_towel(cr)
	for cr in rects:
		if cr.is_in_group("district_backdrop"):
			_expand_backdrop(cr, rects)


static func _collect_color_rects(node: Node, out: Array[ColorRect]) -> void:
	for child in node.get_children():
		if child is ColorRect:
			out.append(child as ColorRect)
		_collect_color_rects(child, out)


static func _ground_spec(group: String) -> Dictionary:
	match group:
		"ground_sand":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.SAND_TILE_REGION}
		"ground_sea":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.WATER_TILE_REGION}
		"ground_road":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.ROAD_TILE_REGION}
		"ground_calcadao":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.CALCADAO_TILE_REGION}
		"ground_sidewalk":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.SIDEWALK_TILE_REGION}
		"ground_grass":
			return {"tex": GRASS_TEXTURE, "region": GRASS_TILE_REGION}
		"ground_plaza":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.SIDEWALK_TILE_REGION, "recolor": true, "grain": PLAZA_GRAIN}
		"ground_dirt":
			return {"tex": Cfg.TILESET_TEXTURE, "region": Cfg.SAND_TILE_REGION, "recolor": true, "grain": DIRT_GRAIN}
	return {}


# Luminance moyenne d'une région (une fois par région) : sert de pivot à la
# recolorisation, pour que la teinte moyenne du résultat soit celle de la dalle.
static func _mean_luminance(tex: Texture2D, region: Rect2) -> float:
	var key: String = "%s|%s" % [tex.resource_path, region]
	if _lum_cache.has(key):
		return _lum_cache[key]
	var img: Image = tex.get_image()
	var total: float = 0.0
	var count: int = 0
	if img != null:
		if img.is_compressed():
			img.decompress()
		var r: Rect2i = Rect2i(region)
		for y in range(r.position.y, r.end.y, 2):
			for x in range(r.position.x, r.end.x, 2):
				var c: Color = img.get_pixel(x, y)
				total += c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				count += 1
	var mean: float = total / float(count) if count > 0 else 0.5
	_lum_cache[key] = maxf(mean, 0.05)
	return _lum_cache[key]


static func _tile_shader_res() -> Shader:
	if _tile_shader == null:
		_tile_shader = Shader.new()
		_tile_shader.code = TILE_SHADER_CODE
	return _tile_shader


# Sprite enfant de la dalle : il hérite de sa position, de son z et de son
# ordre de dessin (dessiné juste après elle), donc l'empilement existant tient.
static func _overlay_tiles(cr: ColorRect, group: String) -> void:
	var tex: Texture2D = null
	var region: Rect2
	var cell: Vector2 = CELL
	var spec: Dictionary = {}
	# Sols peints (GroundPainter, densité GBA) : la tuile native est générée
	# dans la couleur de la dalle — pavés des esplanades, terre du morro,
	# escaliers (rendu B, docs/VISUEL_ETUDE_2026-10-08.md).
	var seed: int = int(absf(cr.position.x * 7.0 + cr.position.y * 13.0)) % 977 + 1
	match group:
		"ground_plaza":
			tex = GroundPainter.cobble(cr.color, seed)
			region = Rect2(0, 0, GroundPainter.TILE, GroundPainter.TILE)
			cell = Vector2(GroundPainter.TILE * GroundPainter.DENSITY, GroundPainter.TILE * GroundPainter.DENSITY)
		"ground_dirt":
			tex = GroundPainter.dirt(cr.color, seed)
			region = Rect2(0, 0, GroundPainter.TILE, GroundPainter.TILE)
			cell = Vector2(GroundPainter.TILE * GroundPainter.DENSITY, GroundPainter.TILE * GroundPainter.DENSITY)
		"ground_stairs":
			tex = GroundPainter.stairs(cr.size.x, cr.color)
			region = Rect2(0, 0, tex.get_width(), tex.get_height())
			cell = Vector2(tex.get_width(), tex.get_height()) * GroundPainter.DENSITY
		_:
			spec = _ground_spec(group)
			if spec.is_empty():
				return
			tex = load(spec.tex)
			region = spec.region
	if tex == null:
		return
	var s: Sprite2D = Sprite2D.new()
	s.name = "TileOverlay"
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, cr.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if spec.is_empty():
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _tile_shader_res()
	mat.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	mat.set_shader_parameter("cell", cell)
	if spec.get("recolor", false):
		mat.set_shader_parameter("tint", cr.color)
		mat.set_shader_parameter("mean_lum", _mean_luminance(tex, region))
		mat.set_shader_parameter("grain", spec.get("grain", 1.0))
	if group == "ground_sea":
		mat.set_shader_parameter("wave", 1.0)
	s.material = mat
	cr.add_child(s)


# Couture = bord d'une dalle sable collé (± tolérance) à un bord d'une dalle
# mer, avec recouvrement suffisant sur l'autre axe. On pose la bande d'écume le
# long de la couture, tournée pour que l'eau du sprite soit du côté mer.
static func _spawn_foam_on_seams(root: Node, sands: Array[ColorRect], seas: Array[ColorRect]) -> void:
	if sands.is_empty() or seas.is_empty():
		return
	var tex: Texture2D = load(Cfg.TILESET_TEXTURE)
	if tex == null:
		return
	for sand in sands:
		var a: Rect2 = sand.get_global_rect()
		for sea in seas:
			var b: Rect2 = sea.get_global_rect()
			var x0: float = max(a.position.x, b.position.x)
			var x1: float = min(a.end.x, b.end.x)
			var y0: float = max(a.position.y, b.position.y)
			var y1: float = min(a.end.y, b.end.y)
			var container: Node2D = null
			if x1 - x0 >= MIN_SEAM_LEN:
				if absf(a.end.y - b.position.y) <= SEAM_TOLERANCE:
					# Mer au sud du sable
					var seam_y: float = (a.end.y + b.position.y) * 0.5
					container = _foam_strip(tex, Vector2(x0, seam_y), Vector2(x1, seam_y), Vector2.DOWN)
				elif absf(a.position.y - b.end.y) <= SEAM_TOLERANCE:
					# Mer au nord du sable
					var seam_y2: float = (a.position.y + b.end.y) * 0.5
					container = _foam_strip(tex, Vector2(x0, seam_y2), Vector2(x1, seam_y2), Vector2.UP)
			if container == null and y1 - y0 >= MIN_SEAM_LEN:
				if absf(a.end.x - b.position.x) <= SEAM_TOLERANCE:
					# Mer à l'est du sable
					var seam_x: float = (a.end.x + b.position.x) * 0.5
					container = _foam_strip(tex, Vector2(seam_x, y0), Vector2(seam_x, y1), Vector2.RIGHT)
				elif absf(a.position.x - b.end.x) <= SEAM_TOLERANCE:
					# Mer à l'ouest du sable
					var seam_x2: float = (a.position.x + b.end.x) * 0.5
					container = _foam_strip(tex, Vector2(seam_x2, y0), Vector2(seam_x2, y1), Vector2.LEFT)
			if container != null:
				_insert_after_later(root, container, sand, sea)
				container.global_position = Vector2.ZERO


static func _foam_strip(tex: Texture2D, from: Vector2, to: Vector2, sea_normal: Vector2) -> Node2D:
	var container: Node2D = Node2D.new()
	container.name = "SeaFoam"
	var dir: Vector2 = (to - from).normalized()
	var total: float = from.distance_to(to)
	var rot: float = sea_normal.angle() - PI * 0.5  # le « bas » du sprite (eau) pointe vers la mer
	var region: Rect2 = Cfg.FOAM_TILE_REGION
	var scale_x: float = FOAM_LEN / region.size.x
	var scale_y: float = FOAM_THICK / region.size.y
	var done: float = 0.0
	while done < total:
		var seg: float = minf(FOAM_LEN, total - done)
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		# Dernier segment tronqué : on rogne la région au prorata, pas d'écume qui déborde.
		s.region_rect = Rect2(region.position, Vector2(region.size.x * seg / FOAM_LEN, region.size.y))
		s.scale = Vector2(scale_x, scale_y)
		s.rotation = rot
		s.position = from + dir * (done + seg * 0.5) + sea_normal * FOAM_SEA_OFFSET
		s.material = WorldFx.foam_material(from + s.position)
		container.add_child(s)
		done += seg
	return container


# L'écume doit couvrir le sable ET la mer : on l'insère juste après celle des
# deux dalles qui est dessinée en dernier, avec le même z.
static func _insert_after_later(root: Node, container: Node2D, sand: ColorRect, sea: ColorRect) -> void:
	var later: ColorRect = sand
	if sand.get_parent() == root and sea.get_parent() == root:
		later = sea if sea.get_index() > sand.get_index() else sand
	elif sea.get_parent() == root:
		later = sea
	container.z_index = maxi(sand.z_index, sea.z_index)
	if later.get_parent() == root:
		root.add_child(container)
		root.move_child(container, later.get_index() + 1)
	else:
		root.add_child(container)


# Une façade est « nue » si aucun ColorRect dessiné après elle ne tombe dedans
# (fenêtres, balcons, enseignes…) : on lui offre alors fenêtres et porte.
static func _dress_building(cr: ColorRect, rects: Array[ColorRect]) -> void:
	var parent: Node = cr.get_parent()
	if parent == null:
		return
	var r: Rect2 = Rect2(cr.position, cr.size)
	var bare: bool = true
	var mine: Rect2 = cr.get_global_rect()
	for other in rects:
		if other == cr or other.get_parent() != parent or other.get_index() < cr.get_index():
			continue
		var o: Rect2 = other.get_global_rect()
		if mine.encloses(o) and o.get_area() < mine.get_area() * 0.3:
			bare = false
			break
	var favela: bool = cr.is_in_group("building_favela")
	var seed: int = int(absf(r.position.x * 7.0 + r.position.y * 13.0))
	# Le peintre dessine toujours fenêtres et porte ; les petits rects que la
	# scène avait posés dans la façade (fenêtres, portes en aplat) sont masqués,
	# sauf ceux qui portent un enfant (enseigne avec Label).
	var opts: Dictionary = {"windows": true, "door": true, "seed": seed, "door_left": (seed % 2) == 0,
		"style": "favela" if favela else "copa", "shop": (not favela) and (seed % 4) == 0}
	if favela:
		# La scène dessine déjà des toits de 10 px : pas de bande, décor par-dessus.
		opts["roof_band"] = false
		opts["roof_offset"] = 10.0
		opts["roof_kind"] = seed % 4
	if not bare:
		for other in rects:
			if other == cr or other.get_parent() != parent or other.get_index() < cr.get_index():
				continue
			var o: Rect2 = other.get_global_rect()
			if mine.encloses(o) and o.get_area() < mine.get_area() * 0.3 and other.get_child_count() == 0:
				other.visible = false
	BuildingDressing.paint_relief(parent, cr.get_index(), r, cr.color, opts)
	# Tri en Y : un Control est classé par son coin haut-gauche, donc une
	# enseigne posée sur le haut de la façade passerait sous le sprite (ancré
	# au pied). Tout ce que la scène dessine après la façade et qui la touche
	# remonte d'un cran, comme il l'était en ordre d'arbre.
	for child in parent.get_children():
		if not (child is Control) or child.get_index() <= cr.get_index() or not child.visible:
			continue
		var c: Control = child as Control
		if c.name.begins_with("Roof") or c.name == "Shadow":
			continue
		if mine.intersects(c.get_global_rect()):
			c.z_index = maxi(c.z_index, 1)


# Les districts sont plus compacts que Copa (bandes de 30-50 px contre 64) :
# la hauteur suit l'empreinte dessinée, bornée à la fourchette de Copa.
static func _palm_height(cr: ColorRect) -> float:
	var jitter: float = PropSprites.palm_height_at(cr.position) - PropSprites.PALM_MIN_H  # 0..25
	return clampf(cr.size.y * 2.2 + jitter - 12.0, 60.0, PropSprites.PALM_MAX_H)


static func _replace_with_prop(cr: ColorRect, region: Rect2, target_h: float) -> void:
	var parent: Node = cr.get_parent()
	if parent == null:
		return
	var r: Rect2 = cr.get_global_rect()
	var s: Sprite2D = PropSprites.spawn(parent, region, Vector2.ZERO, target_h)
	s.name = cr.name + "Sprite"
	s.z_index = cr.z_index
	s.global_position = Vector2(r.get_center().x, r.end.y) + s.position
	# En fin de fratrie : le sprite dépasse largement l'empreinte (couronne,
	# toile) et ne doit pas être recouvert par les dalles dessinées après —
	# même logique qu'à Copa où les props sont posés après les sols.
	parent.move_child(s, parent.get_child_count() - 1)
	cr.visible = false


static func _replace_with_towel(cr: ColorRect) -> void:
	var parent: Node = cr.get_parent()
	if parent == null:
		return
	var r: Rect2 = cr.get_global_rect()
	var region: Rect2 = PropSprites.TOWEL_REGIONS[int(absf(r.position.x)) % PropSprites.TOWEL_REGIONS.size()]
	var s: Sprite2D = PropSprites.spawn_flat(parent, region, Vector2.ZERO, r.size.x * 1.25)
	s.name = cr.name + "Sprite"
	s.z_index = cr.z_index
	s.global_position = r.get_center()
	parent.move_child(s, cr.get_index() + 1)
	cr.visible = false


static func _expand_backdrop(backdrop: ColorRect, rects: Array[ColorRect]) -> void:
	var bbox: Rect2 = Rect2()
	var first: bool = true
	for cr in rects:
		if cr == backdrop:
			continue
		var r: Rect2 = cr.get_global_rect()
		if first:
			bbox = r
			first = false
		else:
			bbox = bbox.merge(r)
	if first:
		return
	bbox = bbox.grow(BACKDROP_MARGIN)
	backdrop.global_position = bbox.position
	backdrop.size = bbox.size
	backdrop.z_index = -10
