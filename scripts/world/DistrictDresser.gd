class_name DistrictDresser
extends RefCounted

# Habillage runtime des districts. Les scènes de `scenes/districts/` sont faites
# de ColorRect plats ; on superpose aux dalles de sol taguées par groupe les
# tuiles de l'atlas de Copacabana, sans toucher à la géométrie, aux chemins de
# nœuds ni aux collisions. Pourquoi des groupes plutôt qu'une heuristique
# couleur : c'est explicite dans le .tscn et ça ne surprend personne au runtime.
#
# Groupes reconnus sur un ColorRect :
#   ground_road / ground_calcadao / ground_sidewalk / ground_grass
#                  → tuile de l'atlas répétée par-dessus la dalle (cellules
#                    64×64 monde, comme _spawn_tile_strip côté Copa)
#   ground_sand / ground_sea → sable et mer PEINTS (GroundPainter, palette
#                    Cfg.SAND_COLOR / SEA_COLOR commune à Copa) ; la mer défile
#                    et scintille par shader, sans déformer la grille de pixels
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
#   ground_forest  → mata peinte (cimes vues de haut) dans la couleur de la
#                    dalle : collines qui ferment un quartier
#   prop_morro     → le rectangle est la boîte englobante d'un dôme de granit
#                    (couleur = la roche) : remplacé par GroundPainter.dome
#   prop_rock      → le rectangle est la boîte englobante d'un affleurement
#                    rocheux (couleur = la roche) : GroundPainter.outcrop
#   prop_towel     → serviette à plat, centrée sur le rectangle, au même rang de
#                    dessin (c'est du sol, pas un volume).
# L'écume (peinte, animée) est posée automatiquement sur chaque couture
# sable/mer (4 orientations), à cheval sur les deux dalles.

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")
const GRASS_TEXTURE: String = "res://assets/sprites/grass.png"
const GRASS_TILE_REGION: Rect2 = Rect2(0, 80, 96, 32)
const CELL: Vector2 = Vector2(64.0, 64.0)
const FOAM_THICK: float = GroundPainter.FOAM_H * GroundPainter.DENSITY  # 36 px, couture au milieu
const SEA_SCROLL: Vector2 = Vector2(0.0, -1.0)  # la houle remonte d'un pixel natif par pas
const SEA_SCROLL_FPS: float = 1.5
const SEA_FPS: float = 0.8    # alternance des reflets
const FOAM_FPS: float = 2.0   # 4 frames ping-pong → une vague toutes les 2 s
const SEAM_TOLERANCE: float = 12.0
const MIN_SEAM_LEN: float = 32.0
const BACKDROP_MARGIN: float = 1400.0
const GROUND_GROUPS: Array = ["ground_forest", "ground_sand", "ground_sea", "ground_road", "ground_calcadao", "ground_sidewalk", "ground_grass", "ground_plaza", "ground_dirt", "ground_stairs"]
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
// Tuiles peintes (crisp) : chaque texel couvre exactement cell/region px, la
// grille de la tuile est calée sur `origin` (position monde du sprite) pour
// que deux dalles voisines se raccordent ; `mirror` retourne une cellule sur
// deux (hachage) pour casser la répétition ; `frames` tuiles côte à côte
// alternent à `fps` ; `scroll` décale la tuile d'un texel entier par pas
// (elle boucle, donc aucune couture) — tout reste sur la grille de pixels.
uniform bool crisp = false;
uniform vec2 origin = vec2(0.0);
uniform int mirror = 0;
uniform int frames = 1;
uniform float fps = 1.0;
uniform float phase = 0.0;
uniform vec2 scroll = vec2(0.0);
uniform float scroll_fps = 0.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec2 world_px = UV / TEXTURE_PIXEL_SIZE + origin;
	vec2 cell_id = floor(world_px / cell);
	vec2 t = fract(world_px / cell);
	vec4 reg = region;
	if (frames > 1) {
		float f = mod(floor(TIME * fps + phase), float(frames));
		reg.x += f * reg.z;
	}
	vec2 px;
	if (crisp) {
		if (mirror > 0 && fract(sin(dot(mod(cell_id, 16.0), vec2(12.9898, 78.233))) * 43758.5453) > 0.5) {
			t.x = 1.0 - t.x;
		}
		vec2 texel = floor(t * reg.zw);
		if (scroll_fps > 0.0) {
			texel = mod(texel + floor(TIME * scroll_fps) * scroll, reg.zw);
		}
		px = reg.xy + texel + 0.5;
	} else {
		// demi-pixel de marge pour ne pas échantillonner le cadre décoratif voisin
		px = reg.xy + 0.5 + t * (reg.zw - 1.0);
	}
	vec4 c = texture(TEXTURE, px * TEXTURE_PIXEL_SIZE);
	if (mean_lum > 0.0) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) / mean_lum;
		c.rgb = tint.rgb * mix(1.0, l, grain);
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
		elif cr.is_in_group("prop_morro"):
			_replace_with_morro(cr)
		elif cr.is_in_group("prop_rock"):
			var parent: Node = cr.get_parent()
			var rs: Sprite2D = rock_sprite(Rect2(cr.position, cr.size), cr.color, int(absf(cr.position.x + cr.position.y)) % 97 + 1)
			rs.name = cr.name + "Sprite"
			rs.z_index = cr.z_index
			parent.add_child(rs)
			parent.move_child(rs, cr.get_index() + 1)
			cr.visible = false
	for cr in rects:
		if cr.is_in_group("district_backdrop"):
			_expand_backdrop(cr, rects)
	# Intérieurs instanciés dans le district (rendu H) et étiquettes du monde en
	# police pixel (rendu G) — idempotent : une Label déjà stylée est laissée.
	InteriorDresser.dress_all_under(root)
	style_world_labels(root)


# Toutes les Labels du sous-arbre passent en police pixel (échelle entière,
# contour cuit) ; celles qui ont déjà une police surchargée sont laissées.
static func style_world_labels(root: Node) -> void:
	for l in root.find_children("*", "Label", true, false):
		var label: Label = l as Label
		if label != null and not label.has_theme_font_override("font"):
			PixelFont.style_world_label(label)


static func _is_ground(c: Node) -> bool:
	for g in GROUND_GROUPS:
		if c.is_in_group(g):
			return true
	return false


static func _collect_color_rects(node: Node, out: Array[ColorRect]) -> void:
	for child in node.get_children():
		if child is ColorRect:
			out.append(child as ColorRect)
		_collect_color_rects(child, out)


static func _ground_spec(group: String) -> Dictionary:
	match group:
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


# Shader de tuiles partagé (InteriorDresser s'en sert aussi).
static func tile_shader() -> Shader:
	return _tile_shader_res()


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
		"ground_forest":
			cr.add_child(painted_sprite(GroundPainter.forest(cr.color, seed % 5 + 1), cr.size, {"origin": cr.global_position, "mirror": true}))
			return
		"ground_sand":
			cr.add_child(painted_sprite(GroundPainter.sand(Cfg.SAND_COLOR), cr.size, {"origin": cr.global_position, "mirror": true}))
			return
		"ground_sea":
			cr.add_child(painted_sprite(GroundPainter.sea(Cfg.SEA_COLOR), cr.size, sea_anim(cr.global_position)))
			return
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
	s.material = mat
	cr.add_child(s)


# Paramètres d'animation de la mer peinte (partagés avec Copa).
static func sea_anim(origin: Vector2) -> Dictionary:
	return {"origin": origin, "mirror": true, "frames": GroundPainter.SEA_FRAMES, "fps": SEA_FPS, "scroll": SEA_SCROLL, "scroll_fps": SEA_SCROLL_FPS}


# Sprite non centré de `size` px couvert par la tuile peinte `tex` répétée à
# la densité du jeu (un texel = DENSITY px monde), via le shader partagé.
# `anim` : origin (calage de la grille sur le monde), mirror, frames / fps /
# phase (frames côte à côte dans la texture), scroll / scroll_fps (défilement
# entier). Copa et les districts s'en servent pour le sable, la mer et l'écume.
static func painted_sprite(tex: Texture2D, size: Vector2, anim: Dictionary = {}) -> Sprite2D:
	var frames: int = int(anim.get("frames", 1))
	var frame_w: float = float(tex.get_width()) / float(frames)
	var s: Sprite2D = Sprite2D.new()
	s.name = "TileOverlay"
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _tile_shader_res()
	mat.set_shader_parameter("crisp", true)
	mat.set_shader_parameter("region", Vector4(0.0, 0.0, frame_w, float(tex.get_height())))
	var cell: Vector2 = Vector2(frame_w, float(tex.get_height())) * float(GroundPainter.DENSITY)
	mat.set_shader_parameter("cell", cell)
	# L'origine monde ne compte que modulo 16 cellules (période du hachage du
	# miroir) : on la borne côté CPU. Les quartiers vivent à -36 000 px et plus ;
	# un GPU mobile en demi-précision y perdrait la grille des texels.
	var o: Vector2 = anim.get("origin", Vector2.ZERO)
	mat.set_shader_parameter("origin", Vector2(fposmod(o.x, cell.x * 16.0), fposmod(o.y, cell.y * 16.0)))
	mat.set_shader_parameter("mirror", 1 if anim.get("mirror", false) else 0)
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("fps", float(anim.get("fps", 1.0)))
	mat.set_shader_parameter("phase", float(anim.get("phase", 0.0)))
	mat.set_shader_parameter("scroll", anim.get("scroll", Vector2.ZERO))
	mat.set_shader_parameter("scroll_fps", float(anim.get("scroll_fps", 0.0)))
	s.material = mat
	return s


# Bande d'écume peinte : sprite centré sur la couture, tourné pour que le bas
# de la texture (la mer) pointe vers `sea_normal` ; la longueur est couverte
# par répétition de la tuile 32 natifs. Phase tirée de la position pour que
# deux coutures ne respirent pas en chœur.
static func foam_sprite(from: Vector2, to: Vector2, sea_normal: Vector2) -> Sprite2D:
	var length: float = from.distance_to(to)
	var s: Sprite2D = painted_sprite(GroundPainter.foam(Cfg.SEA_COLOR), Vector2(length, FOAM_THICK),
		{"frames": GroundPainter.FOAM_FRAMES, "fps": FOAM_FPS, "phase": WorldFx.phase_at(from) * 0.7})
	s.name = "Foam"
	s.centered = true
	s.rotation = sea_normal.angle() - PI * 0.5
	s.position = (from + to) * 0.5
	return s


# Couture = bord d'une dalle sable collé (± tolérance) à un bord d'une dalle
# mer, avec recouvrement suffisant sur l'autre axe. On pose la bande d'écume le
# long de la couture, tournée pour que l'eau du sprite soit du côté mer.
static func _spawn_foam_on_seams(root: Node, sands: Array[ColorRect], seas: Array[ColorRect]) -> void:
	if sands.is_empty() or seas.is_empty():
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
					container = _foam_strip(Vector2(x0, seam_y), Vector2(x1, seam_y), Vector2.DOWN)
				elif absf(a.position.y - b.end.y) <= SEAM_TOLERANCE:
					# Mer au nord du sable
					var seam_y2: float = (a.position.y + b.end.y) * 0.5
					container = _foam_strip(Vector2(x0, seam_y2), Vector2(x1, seam_y2), Vector2.UP)
			if container == null and y1 - y0 >= MIN_SEAM_LEN:
				if absf(a.end.x - b.position.x) <= SEAM_TOLERANCE:
					# Mer à l'est du sable
					var seam_x: float = (a.end.x + b.position.x) * 0.5
					container = _foam_strip(Vector2(seam_x, y0), Vector2(seam_x, y1), Vector2.RIGHT)
				elif absf(a.position.x - b.end.x) <= SEAM_TOLERANCE:
					# Mer à l'ouest du sable
					var seam_x2: float = (a.position.x + b.end.x) * 0.5
					container = _foam_strip(Vector2(seam_x2, y0), Vector2(seam_x2, y1), Vector2.LEFT)
			if container != null:
				_insert_after_later(root, container, sand, sea)
				container.global_position = Vector2.ZERO


static func _foam_strip(from: Vector2, to: Vector2, sea_normal: Vector2) -> Node2D:
	var container: Node2D = Node2D.new()
	container.name = "SeaFoam"
	container.add_child(foam_sprite(from, to, sea_normal))
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
		if _is_ground(c):
			continue  # une dalle de sol qui frôle la façade reste du sol
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


# Dôme de granit peint (Pão de Açúcar, Morro da Urca) : le rect est la boîte
# englobante, sa couleur celle de la roche. Origine en haut du rect : un
# morne est un fond, il se trie derrière tout ce qui vit à son pied.
static func _replace_with_morro(cr: ColorRect) -> void:
	var parent: Node = cr.get_parent()
	if parent == null:
		return
	var d: int = GroundPainter.DENSITY
	var s: Sprite2D = Sprite2D.new()
	s.name = cr.name + "Sprite"
	s.texture = GroundPainter.dome(int(cr.size.x) / d, int(cr.size.y) / d, cr.color, GroundPainter.FOREST_COLOR, int(absf(cr.position.x)) % 97 + 1)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2(d, d)
	s.position = cr.position
	s.z_index = cr.z_index
	parent.add_child(s)
	parent.move_child(s, cr.get_index() + 1)
	cr.visible = false


# Affleurement rocheux peint couvrant `rect` (coordonnées du parent), origine
# en haut à gauche comme le rect qu'il remplace. Partagé avec Copa (Arpoador).
static func rock_sprite(rect: Rect2, color: Color, seed: int = 1) -> Sprite2D:
	var d: int = GroundPainter.DENSITY
	var s: Sprite2D = Sprite2D.new()
	s.texture = GroundPainter.outcrop(maxi(4, int(rect.size.x) / d), maxi(4, int(rect.size.y) / d), color, seed)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2(d, d)
	s.position = rect.position
	return s


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
