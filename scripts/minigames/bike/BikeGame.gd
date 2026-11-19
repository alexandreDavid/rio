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

const Art: GDScript = preload("res://scripts/minigames/bike/BikeArt.gd")
const Cfg: GDScript = preload("res://scripts/world/CopacabanaConfig.gd")

# Habillage (rendu seul — la logique de voies et de collisions est ci-dessus).
# Abscisses monde, multiples de 3 (1 px natif = 3 px monde) : côté plage à
# gauche (mer, sable, calçadão, ciclovia), immeubles à droite.
const PX: float = 3.0
const SEA_X1: float = -120.0
const CALC_X0: float = 54.0
const CICLO_X0: float = 168.0
const CURB_L_X0: float = 228.0
const CURB_R_X1: float = 1692.0
const WALK_X1: float = 1812.0
const SAND_PAL: Array = [
	Color(0.90, 0.22, 0.22), Color(0.18, 0.48, 0.85), Color(0.98, 0.78, 0.15),
	Color(0.20, 0.68, 0.45), Color(0.95, 0.45, 0.65),
]
const ROOF_PAL: Array = [
	Color(0.93, 0.84, 0.70), Color(0.95, 0.72, 0.62), Color(0.78, 0.86, 0.80),
	Color(0.96, 0.88, 0.62), Color(0.80, 0.80, 0.86), Color(0.88, 0.70, 0.74),
]
const AWNING_PAL: Array = [
	Color(0.85, 0.20, 0.20), Color(0.15, 0.50, 0.40), Color(0.20, 0.40, 0.80), Color(0.95, 0.60, 0.15),
]
const BUS_PAL: Array = [
	[Color(0.95, 0.95, 0.92), Color(0.15, 0.40, 0.80)],
	[Color(0.98, 0.80, 0.20), Color(0.15, 0.55, 0.30)],
	[Color(0.90, 0.92, 0.95), Color(0.85, 0.25, 0.20)],
]
const PED_SEEDS: Array = [11, 23, 37, 51, 68, 74, 89, 97]
const PED_H: float = 90.0
const RIDER_H: float = 108.0
const BAG_RED: Color = Color(0.86, 0.15, 0.17)

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
var _road_off: float = 0.0
var _t: float = 0.0
var _tex: Dictionary = {}
var _rider_tex: Texture2D = null
var _rider: Node2D = null

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
	_setup_art()

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
	_animate_actors()

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
	_road_off += _scroll * delta
	_t += delta
	queue_redraw()
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
	var paint: Color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
	car.color = Color(paint, 0.0)
	car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car.set_meta("kind", "car")
	# Les voitures roulent dans le même sens, un peu plus lentement que la rue.
	car.set_meta("extra", -_rng.randf_range(40.0, 120.0))
	var roll: float = _rng.randf()
	var tex: Texture2D
	if roll < 0.18:
		var pal: Array = BUS_PAL[_rng.randi() % BUS_PAL.size()]
		tex = Art.bus(pal[0], pal[1])
	else:
		# Le jaune de la palette, c'est le táxi carioca.
		tex = Art.car(paint, paint.r > 0.9 and paint.b < 0.4)
	_art_sprite(car, tex, Vector2((w - 74.0 * PX) * 0.5, 0.0))
	obstacle_layer.add_child(car)

func _spawn_pedestrian() -> void:
	var p: ColorRect = ColorRect.new()
	p.size = Vector2(36, 52)
	var from_left: bool = _rng.randf() < 0.5
	p.position = Vector2(LANE_LEFT - 60.0 if from_left else LANE_RIGHT + 24.0, -60.0)
	p.color = Color(1, 1, 1, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("kind", "ped")
	p.set_meta("drift", 260.0 if from_left else -260.0)
	# Figurant pixel (même usine que le monde), qui traverse de profil.
	var cfg: Dictionary = CharacterSpriteFactory.random_config(int(PED_SEEDS[_rng.randi() % PED_SEEDS.size()]))
	var spr: Sprite2D = char_sprite(PED_H, cfg)
	spr.position = Vector2(18.0, 54.0)
	spr.flip_h = not from_left
	spr.region_rect = Rect2(0, CharacterSpriteFactory.DIR_RIGHT * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	spr.set_meta("phase", _rng.randf() * 10.0)
	var sh: ColorRect = ColorRect.new()
	sh.color = Art.SHADOW
	sh.position = Vector2(3.0, 48.0)
	sh.size = Vector2(33.0, 9.0)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sh)
	p.add_child(spr)
	p.set_meta("spr", spr)
	obstacle_layer.add_child(p)

func _spawn_parcel(lane: int) -> void:
	var c: ColorRect = ColorRect.new()
	c.size = Vector2(56, 56)
	c.position = Vector2(_lane_x(lane) - 28.0, -260.0)
	c.color = Color(1, 1, 1, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("kind", "parcel")
	# Halo qui pulse : « ramasse-moi », lisible même dans la circulation.
	var halo: Node2D = Node2D.new()
	halo.draw.connect(_draw_parcel_halo.bind(halo))
	c.add_child(halo)
	var spr: Sprite2D = _art_sprite(c, Art.parcel(), Vector2(1.0, 1.0))
	c.set_meta("spr", spr)
	c.set_meta("halo", halo)
	obstacle_layer.add_child(c)

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

# ---------------------------------------------------------------------------
# Habillage : l'Av. Atlântica vue de haut, peinte en _draw (sous les acteurs).
# ---------------------------------------------------------------------------

func _setup_art() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	obstacle_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_tex = {
		"sea": GroundPainter.sea(Cfg.SEA_COLOR),
		"foam": GroundPainter.foam(Cfg.SEA_COLOR),
		"sand": GroundPainter.sand(Cfg.SAND_COLOR),
		"calc": Art.calcadao(int((CICLO_X0 - CALC_X0) / PX)),
		"ciclo": Art.ciclovia(int((CURB_L_X0 - CICLO_X0) / PX)),
		"asphalt": Art.asphalt(),
		"walk": GroundPainter.cobble(Color(0.84, 0.82, 0.78), 3),
	}
	for c in SAND_PAL:
		Art.umbrella(c)
	for k in PED_SEEDS:
		CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(int(k)))
	for l in [integrity_label, timer_label, status_label]:
		var lab: Label = l
		if lab:
			lab.add_theme_constant_override("outline_size", 12)
			lab.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.12))
	if status_label:
		status_label.add_theme_font_size_override("font_size", 30)
	if bike:
		bike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bike.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		var tmp: Sprite2D = char_sprite(RIDER_H)
		_rider_tex = tmp.texture
		tmp.free()
		_rider = Node2D.new()
		_rider.name = "Rider"
		_rider.draw.connect(_draw_rider)
		bike.add_child(_rider)
	queue_redraw()

func _art_sprite(parent: Node, tex: Texture2D, pos: Vector2) -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(PX, PX)
	spr.position = pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(spr)
	return spr

# Piétons qui marchent, colis qui flottent, vélo qui pédale.
func _animate_actors() -> void:
	for child in obstacle_layer.get_children():
		var kind: String = String(child.get_meta("kind", ""))
		if kind == "ped":
			var spr: Sprite2D = child.get_meta("spr") as Sprite2D
			var ph: float = float(spr.get_meta("phase", 0.0))
			spr.region_rect.position.x = float(1 + int((_t + ph) * 7.0) % 2) * CharacterSpriteFactory.CELL_W
		elif kind == "parcel":
			var box: Sprite2D = child.get_meta("spr") as Sprite2D
			box.position.y = 1.0 - PX * float(int(_t * 5.0) % 2)
			(child.get_meta("halo") as Node2D).queue_redraw()
	if _rider:
		_rider.queue_redraw()

func _draw_parcel_halo(n: Node2D) -> void:
	var k: int = int(_t * 6.0) % 3
	var g: float = 6.0 + PX * float(k)
	var col: Color = Color(1.0, 0.92, 0.35, 0.9 - 0.2 * float(k))
	var r: Rect2 = Rect2(-g, -g, 56.0 + g * 2.0, 56.0 + g * 2.0)
	var arm: float = 15.0
	var t: float = PX * 2.0
	# Quatre équerres, pas un cadre : on voit le colis à travers.
	n.draw_rect(Rect2(r.position.x, r.position.y, arm, t), col)
	n.draw_rect(Rect2(r.position.x, r.position.y, t, arm), col)
	n.draw_rect(Rect2(r.end.x - arm, r.position.y, arm, t), col)
	n.draw_rect(Rect2(r.end.x - t, r.position.y, t, arm), col)
	n.draw_rect(Rect2(r.position.x, r.end.y - t, arm, t), col)
	n.draw_rect(Rect2(r.position.x, r.end.y - arm, t, arm), col)
	n.draw_rect(Rect2(r.end.x - arm, r.end.y - t, arm, t), col)
	n.draw_rect(Rect2(r.end.x - t, r.end.y - arm, t, arm), col)

# Cycliste vu de dos : roue arrière, guidon, l'entregador et son bag
# isotherme rouge sur le porte-bagages (repère local = la hitbox 54×90).
func _draw_rider() -> void:
	var n: Node2D = _rider
	var cx: float = BIKE_W * 0.5
	var pedal: int = 1 + int(_t * 8.0) % 2
	n.draw_rect(Rect2(cx - 24.0, 84.0, 54.0, 9.0), Art.SHADOW)
	# Roue avant qui dépasse devant, guidon (derrière le buste).
	n.draw_rect(Rect2(cx - 4.5, -12.0, 9.0, 24.0), Art.TYRE)
	n.draw_rect(Rect2(cx - 33.0, 24.0, 66.0, 6.0), Color(0.30, 0.30, 0.34))
	n.draw_rect(Rect2(cx - 39.0, 21.0, 9.0, 12.0), Art.TYRE)
	n.draw_rect(Rect2(cx + 30.0, 21.0, 9.0, 12.0), Art.TYRE)
	# Roue arrière.
	n.draw_rect(Rect2(cx - 4.5, 51.0, 9.0, 42.0), Art.TYRE)
	n.draw_rect(Rect2(cx - 1.5, 54.0, 3.0, 36.0), Color(0.55, 0.56, 0.6))
	if _rider_tex:
		var src: Rect2 = Rect2(pedal * CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		var s: float = RIDER_H / float(CharacterSpriteFactory.CELL_H)
		var w: float = CharacterSpriteFactory.CELL_W * s
		n.draw_texture_rect_region(_rider_tex, Rect2(cx - w * 0.5, 84.0 - RIDER_H, w, RIDER_H), src)
	# Bag isotherme : couvercle clair, sangle, logo.
	var bag: Rect2 = Rect2(cx - 18.0, 45.0, 36.0, 30.0)
	n.draw_rect(bag.grow(3.0), Art.OUTLINE)
	n.draw_rect(bag, BAG_RED)
	n.draw_rect(Rect2(bag.position, Vector2(bag.size.x, 9.0)), BAG_RED.lightened(0.25))
	n.draw_rect(Rect2(bag.position.x, bag.position.y + 9.0, bag.size.x, 3.0), BAG_RED.darkened(0.3))
	n.draw_rect(Rect2(cx - 9.0, 57.0, 18.0, 12.0), Color(0.98, 0.96, 0.9))
	n.draw_rect(Rect2(cx - 6.0, 60.0, 12.0, 3.0), BAG_RED)
	n.draw_rect(Rect2(cx - 3.0, 63.0, 6.0, 3.0), BAG_RED)
	# Catadioptre arrière.
	n.draw_rect(Rect2(cx - 4.5, 78.0, 9.0, 6.0), Color(1.0, 0.3, 0.2) if int(_t * 3.0) % 2 == 0 else Color(0.6, 0.12, 0.1))

func _hash(k: int, salt: int) -> int:
	return absi(hash(k * 7919 + salt * 104729))

# Objets récurrents le long de la rue : indices k visibles pour un pas donné
# (l'objet k est à y = off - k·pas, il descend quand off grandit).
func _slots(off: float, step: float, vt: float, vb: float, margin: float) -> Array[int]:
	var out: Array[int] = []
	var k0: int = int(floor((off - vb - margin) / step))
	var k1: int = int(ceil((off - vt + margin) / step))
	for k in range(k0, k1 + 1):
		out.append(k)
	return out

func _snap(v: float) -> float:
	return floorf(v / PX) * PX

# Bande verticale d'une texture répétée, défilant de `off`.
func _strip(tex: Texture2D, x0: float, x1: float, vt: float, vb: float, off: float) -> void:
	var th: float = float(tex.get_height()) * PX
	var y0: float = fposmod(_snap(off), th) - th
	while y0 > vt:
		y0 -= th
	draw_set_transform(Vector2(x0, y0), 0.0, Vector2(PX, PX))
	draw_texture_rect(tex, Rect2(0, 0, (x1 - x0) / PX, (vb - y0) / PX + 1.0), true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if _tex.is_empty():
		return
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var tl: Vector2 = inv * Vector2.ZERO
	var br: Vector2 = inv * vs
	var vl: float = tl.x - 12.0
	var vr: float = br.x + 12.0
	var vt: float = tl.y - 12.0
	var vb: float = br.y + 12.0
	var off: float = _snap(_road_off)
	_draw_beach(vl, vt, vb, off)
	_draw_road_bed(vt, vb, off)
	_draw_city(vr, vt, vb, off)
	_draw_canopies(vt, vb, off)

func _draw_beach(vl: float, vt: float, vb: float, off: float) -> void:
	# Mer (2 frames de reflets), écume pivotée sur la couture verticale.
	var sea: Texture2D = _tex["sea"]
	var frame: int = int(_t * 1.5) % 2
	var tile: float = 64.0 * PX
	var sy0: float = fposmod(off, tile) - tile
	while sy0 > vt:
		sy0 -= tile
	var x: float = SEA_X1 - tile
	while x + tile > vl:
		var y: float = sy0
		while y < vb:
			draw_texture_rect_region(sea, Rect2(x, y, tile, tile), Rect2(frame * 64, 0, 64, 64))
			y += tile
		x -= tile
	_strip(_tex["sand"], SEA_X1, CALC_X0, vt, vb, off)
	var foam: Texture2D = _tex["foam"]
	var ff: int = int(_t * 3.0) % GroundPainter.FOAM_FRAMES
	var seg: float = GroundPainter.FOAM_W * PX
	var fy: float = fposmod(off, seg) - seg
	while fy > vt:
		fy -= seg
	while fy < vb:
		draw_set_transform(Vector2(SEA_X1, fy), PI * 0.5, Vector2(PX, PX))
		draw_texture_rect_region(foam, Rect2(0, -GroundPainter.FOAM_H * 0.5, GroundPainter.FOAM_W, GroundPainter.FOAM_H),
			Rect2(ff * GroundPainter.FOAM_W, 0, GroundPainter.FOAM_W, GroundPainter.FOAM_H))
		fy += seg
	draw_set_transform(Vector2.ZERO)
	# Serviettes et parasols sur le sable.
	for k in _slots(off, 270.0, vt, vb, 90.0):
		var hk: int = _hash(k, 1)
		if hk % 5 == 0:
			continue
		var y: float = _snap(off - float(k) * 270.0)
		var ux: float = _snap(-87.0 + float(hk % 7) * 12.0)
		var col: Color = SAND_PAL[(hk / 7) % SAND_PAL.size()]
		var tw: Color = SAND_PAL[(hk / 13) % SAND_PAL.size()]
		var tx: float = ux + 42.0
		draw_rect(Rect2(tx + 3.0, y + 18.0, 30.0, 60.0), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(tx, y + 15.0, 30.0, 60.0), tw)
		for s in 4:
			draw_rect(Rect2(tx, y + 21.0 + s * 15.0, 30.0, 6.0), Color(0.97, 0.96, 0.92))
		var umb: Texture2D = Art.umbrella(col)
		draw_set_transform(Vector2(ux + 12.0, y + 12.0), 0.0, Vector2(PX, PX))
		draw_texture(umb, Vector2.ZERO, Color(0, 0, 0.05, 0.28))
		draw_set_transform(Vector2(ux, y), 0.0, Vector2(PX, PX))
		draw_texture(umb, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	# Calçadão, ciclovia, bordure.
	_strip(_tex["calc"], CALC_X0, CICLO_X0, vt, vb, off)
	_strip(_tex["ciclo"], CICLO_X0, CURB_L_X0, vt, vb, off)
	var white: Color = Color(0.96, 0.95, 0.9)
	draw_rect(Rect2(CICLO_X0, vt, PX, vb - vt), white)
	draw_rect(Rect2(CURB_L_X0 - PX * 2.0, vt, PX, vb - vt), white)
	var mid: float = (CICLO_X0 + CURB_L_X0) * 0.5 - PX * 0.5
	for k in _slots(off, 90.0, vt, vb, 60.0):
		draw_rect(Rect2(_snap(mid), _snap(off - float(k) * 90.0), PX, 45.0), Color(0.98, 0.85, 0.3))
	# Pictogramme vélo peint sur la ciclovia.
	for k in _slots(off, 720.0, vt, vb, 60.0):
		var y: float = _snap(off - float(k) * 720.0)
		var cxp: float = _snap(mid - 18.0)
		draw_rect(Rect2(cxp, y + 9.0, 12.0, 12.0), white)
		draw_rect(Rect2(cxp + 24.0, y + 9.0, 12.0, 12.0), white)
		draw_rect(Rect2(cxp + 3.0, y + 12.0, 6.0, 6.0), Color(0.70, 0.33, 0.24))
		draw_rect(Rect2(cxp + 27.0, y + 12.0, 6.0, 6.0), Color(0.70, 0.33, 0.24))
		draw_rect(Rect2(cxp + 9.0, y + 6.0, 18.0, 3.0), white)
		draw_rect(Rect2(cxp + 15.0, y, 3.0, 9.0), white)
	draw_rect(Rect2(CURB_L_X0, vt, LANE_LEFT - CURB_L_X0, vb - vt), Color(0.78, 0.77, 0.74))
	draw_rect(Rect2(CURB_L_X0, vt, PX, vb - vt), Color(0.92, 0.91, 0.88))

func _draw_road_bed(vt: float, vb: float, off: float) -> void:
	_strip(_tex["asphalt"], LANE_LEFT, LANE_RIGHT, vt, vb, off)
	var white: Color = Color(0.95, 0.95, 0.92)
	# Taches, plaques d'égout, rustines : la vitesse se lit au sol.
	for k in _slots(off, 330.0, vt, vb, 90.0):
		var hk: int = _hash(k, 2)
		var y: float = _snap(off - float(k) * 330.0)
		var x: float = _snap(LANE_LEFT + 30.0 + float(hk % 1290))
		match hk % 4:
			0:
				draw_rect(Rect2(x, y, 36.0, 36.0), Color(0.18, 0.18, 0.2))
				draw_rect(Rect2(x + 3.0, y + 3.0, 30.0, 30.0), Color(0.40, 0.39, 0.40))
				for s in 4:
					draw_rect(Rect2(x + 6.0, y + 6.0 + s * 6.0, 24.0, PX), Color(0.30, 0.30, 0.32))
			1:
				draw_rect(Rect2(x, y, 48.0, 21.0), Color(0.17, 0.17, 0.2, 0.55))
				draw_rect(Rect2(x + 9.0, y + 21.0, 24.0, 9.0), Color(0.17, 0.17, 0.2, 0.55))
			2:
				draw_rect(Rect2(x, y, 90.0, 54.0), Color(0.24, 0.24, 0.27))
				draw_rect(Rect2(x, y, 90.0, PX), Color(0.20, 0.20, 0.22))
	# Lignes de rive, tirets entre les voies.
	draw_rect(Rect2(LANE_LEFT + 9.0, vt, 9.0, vb - vt), white)
	draw_rect(Rect2(LANE_RIGHT - 18.0, vt, 9.0, vb - vt), white)
	for lane in range(1, LANES):
		var lx: float = _snap(LANE_LEFT + LANE_W * float(lane) - 4.5)
		for k in _slots(off, 270.0, vt, vb, 150.0):
			var dy: float = _snap(off - float(k) * 270.0)
			if not _crosses_zebra(off, dy, dy + 126.0):
				draw_rect(Rect2(lx, dy, 9.0, 126.0), white)
	# Faixa de pedestres de temps en temps.
	for k in _slots(off, 1980.0, vt, vb, 120.0):
		var y: float = _snap(off - float(k) * 1980.0)
		draw_rect(Rect2(LANE_LEFT, y + 108.0, LANE_RIGHT - LANE_LEFT, 9.0), white)
		var x: float = LANE_LEFT + 18.0
		while x < LANE_RIGHT - 30.0:
			draw_rect(Rect2(x, y, 36.0, 96.0), white)
			x += 72.0

# Les tirets s'arrêtent avant la faixa de pedestres.
func _crosses_zebra(off: float, y0: float, y1: float) -> bool:
	var k: int = int(round((off - y0) / 1980.0))
	for kk in [k - 1, k, k + 1]:
		var zy: float = _snap(off - float(kk) * 1980.0)
		if y1 > zy - 12.0 and y0 < zy + 129.0:
			return true
	return false

func _draw_city(vr: float, vt: float, vb: float, off: float) -> void:
	draw_rect(Rect2(LANE_RIGHT, vt, CURB_R_X1 - LANE_RIGHT, vb - vt), Color(0.78, 0.77, 0.74))
	draw_rect(Rect2(CURB_R_X1 - PX, vt, PX, vb - vt), Color(0.92, 0.91, 0.88))
	_strip(_tex["walk"], CURB_R_X1, WALK_X1, vt, vb, off)
	# Façades vues du dessus : toit, parapet, caixa d'água, clim, piscine ;
	# la face sud (en bas) est visible en biais, avec ses fenêtres.
	var step: float = 312.0
	var roof_x: float = WALK_X1
	var roof_w: float = maxf(vr - roof_x, 60.0)
	draw_rect(Rect2(roof_x, vt, roof_w, vb - vt), Color(0.22, 0.20, 0.24))
	for k in _slots(off, step, vt, vb, step):
		var hk: int = _hash(k, 3)
		var y: float = _snap(off - float(k) * step)
		var len: float = step - 18.0 - float(hk % 3) * 9.0
		var face: float = 42.0
		var col: Color = ROOF_PAL[hk % ROOF_PAL.size()]
		var bx: float = roof_x + float((hk / 5) % 3) * 9.0
		var top: float = y - len
		draw_rect(Rect2(bx, top, roof_w, len - face), col.darkened(0.35))
		draw_rect(Rect2(bx + PX, top + PX, roof_w, len - face - PX * 2.0), col.lightened(0.12))
		draw_rect(Rect2(bx + PX * 3.0, top + PX * 3.0, roof_w, len - face - PX * 6.0), col.darkened(0.05))
		# Face sud en biais : mur plus sombre et rangées de fenêtres.
		var wall: Color = col.darkened(0.28)
		draw_rect(Rect2(bx, y - face, roof_w, face), wall)
		var wx: float = bx + 18.0
		while wx < bx + roof_w - 24.0:
			draw_rect(Rect2(wx, y - face + 9.0, 18.0, 24.0), Color(0.22, 0.32, 0.48))
			draw_rect(Rect2(wx, y - face + 9.0, 18.0, PX), Color(0.55, 0.70, 0.85))
			wx += 39.0
		# Toiture.
		var rx: float = bx + 30.0
		var ry: float = top + 24.0
		match (hk / 3) % 4:
			0:
				draw_rect(Rect2(rx + 6.0, ry + 6.0, 66.0, 66.0), Color(0, 0, 0, 0.18))
				draw_rect(Rect2(rx, ry, 66.0, 66.0), Color(0.16, 0.38, 0.62))
				draw_rect(Rect2(rx + PX, ry + PX, 60.0, 60.0), Color(0.24, 0.52, 0.80))
				draw_rect(Rect2(rx + 9.0, ry + 9.0, 24.0, 6.0), Color(0.55, 0.75, 0.95))
			1:
				draw_rect(Rect2(rx, ry, 150.0, 96.0), Color(0.90, 0.92, 0.94))
				draw_rect(Rect2(rx + 6.0, ry + 6.0, 138.0, 84.0), Color(0.30, 0.70, 0.85))
				draw_rect(Rect2(rx + 12.0, ry + 12.0, 45.0, PX), Color(0.70, 0.92, 0.98))
				draw_rect(Rect2(rx + 60.0, ry + 45.0, 30.0, PX), Color(0.70, 0.92, 0.98))
			2:
				for s in 3:
					draw_rect(Rect2(rx + float(s) * 45.0, ry, 39.0, 60.0), Color(0.12, 0.18, 0.32))
					draw_rect(Rect2(rx + float(s) * 45.0 + PX, ry + PX, 33.0, 54.0), Color(0.22, 0.32, 0.55))
					draw_rect(Rect2(rx + float(s) * 45.0 + 18.0, ry, PX, 60.0), Color(0.12, 0.18, 0.32))
			_:
				for s in 2:
					var ax: float = rx + float(s) * 54.0
					draw_rect(Rect2(ax + 6.0, ry + 6.0, 39.0, 30.0), Color(0, 0, 0, 0.18))
					draw_rect(Rect2(ax, ry, 39.0, 30.0), Color(0.70, 0.72, 0.74))
					draw_rect(Rect2(ax + 9.0, ry + 6.0, 21.0, 18.0), Color(0.45, 0.47, 0.50))
		if len - face > 150.0:
			draw_rect(Rect2(bx + 210.0, top + 36.0, 6.0, 48.0), Color(0.3, 0.3, 0.33))
			draw_rect(Rect2(bx + 198.0, top + 36.0, 30.0, PX), Color(0.3, 0.3, 0.33))
		# Marquise du rez-de-chaussée qui avance sur le trottoir.
		var aw: Color = AWNING_PAL[(hk / 11) % AWNING_PAL.size()]
		var ay: float = y - face - 90.0
		draw_rect(Rect2(roof_x - 33.0, ay + 6.0, 36.0, 84.0), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(roof_x - 36.0, ay, 36.0, 84.0), aw.darkened(0.4))
		for s in 4:
			draw_rect(Rect2(roof_x - 33.0, ay + 3.0 + float(s) * 21.0, 33.0, 9.0), aw)
			draw_rect(Rect2(roof_x - 33.0, ay + 12.0 + float(s) * 21.0, 33.0, 9.0), Color(0.97, 0.95, 0.9))

# Ce qui est haut passe par-dessus et défile un poil plus vite (parallaxe).
func _draw_canopies(vt: float, vb: float, off: float) -> void:
	var hi_off: float = _snap(_road_off * 1.06)
	for k in _slots(hi_off, 420.0, vt, vb, 150.0):
		var hk: int = _hash(k, 4)
		var y: float = _snap(hi_off - float(k) * 420.0)
		var tex: Texture2D = Art.palm_crown(hk % 5)
		var x: float = _snap(-36.0 + float(hk % 4) * 9.0)
		draw_set_transform(Vector2(x + 15.0, y + 18.0), 0.0, Vector2(PX, PX))
		draw_texture(tex, Vector2.ZERO, Color(0, 0, 0.05, 0.25))
		draw_set_transform(Vector2(x, y), 0.0, Vector2(PX, PX))
		draw_texture(tex, Vector2.ZERO)
	for k in _slots(hi_off, 510.0, vt, vb, 150.0):
		var hk: int = _hash(k, 5)
		var y: float = _snap(hi_off - float(k) * 510.0 + 200.0)
		if hk % 4 == 0:
			# Banca de jornal : kiosque vert, revues en devanture.
			var bx: float = CURB_R_X1 + 24.0
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(bx + 6.0, y + 6.0, 72.0, 90.0), Color(0, 0, 0, 0.2))
			draw_rect(Rect2(bx, y, 72.0, 90.0), Color(0.10, 0.30, 0.18))
			draw_rect(Rect2(bx + PX, y + PX, 66.0, 84.0), Color(0.18, 0.50, 0.30))
			draw_rect(Rect2(bx + PX, y + PX, 66.0, 12.0), Color(0.30, 0.65, 0.40))
			for s in 3:
				draw_rect(Rect2(bx + 6.0, y + 24.0 + float(s) * 21.0, 18.0, 15.0), SAND_PAL[(hk + s) % SAND_PAL.size()])
			continue
		var tex: Texture2D = Art.tree_crown(hk % 4)
		var x: float = _snap(CURB_R_X1 + 6.0 + float(hk % 3) * 6.0)
		draw_set_transform(Vector2(x + 15.0, y + 15.0), 0.0, Vector2(PX, PX))
		draw_texture(tex, Vector2.ZERO, Color(0, 0, 0.05, 0.25))
		draw_set_transform(Vector2(x, y), 0.0, Vector2(PX, PX))
		draw_texture(tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)

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
	await get_tree().create_timer(bilan_delay(1.8)).timeout
	EventBus.minigame_ended.emit("bike", {"integrity": _integrity, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, _integrity)
