extends Node2D

# Habillage pixel de la Padaria São Sebastião (1 px natif = 3 px monde,
# NEAREST, comme GroundPainter et les autres mini-jeux) : salle en damier,
# mur de faïence et lambris vert, porte sur la rue, tableau à la craie, four
# à pain en briques, plan de travail fariné, vitrine de salgados, file de
# fregueses (CharacterSpriteFactory). Aucune règle ici : PadariaGame lui passe
# son état à chaque image (`tick`), les stations gardent leur ColorRect
# (taille nulle, posé au pied) qui porte le surlignage par modulate.

const D: int = 3
const INK: Color = Color(0.13, 0.10, 0.12)
const VIEW_L: int = -360
const VIEW_R: int = 2280
const ROOM_H: int = 1080
# Rangées natives du mur du fond : lambris vert, faïence, plinthe, puis sol.
const ROW_FAIENCE: int = 41
const ROW_PLINTH: int = 76
const ROW_FLOOR: int = 79
const DOOR_X0: int = 1734
const DOOR_X1: int = 1884

const CHAR_H: float = 144.0
# Pieds du joueur dans le repère du ColorRect Player (coin = pos - 24).
const PLAYER_FEET: Vector2 = Vector2(24, 74)
const SLOTS: Array[Vector2] = [Vector2(1500, 624), Vector2(1688, 560), Vector2(1782, 470), Vector2(1851, 384)]
const DOOR_IN: Vector2 = Vector2(1809, 270)
const CUSTOMER_SPEED: float = 230.0
const FAN_POS: Vector2 = Vector2(1218, 402)
const OVEN_BASE: Vector2 = Vector2(700, 950)
const OVEN_W: int = 96
const OVEN_H: int = 104
const CHIMNEY_TOP: Vector2 = Vector2(768, 640)
const MOUTH_TOP: Vector2 = Vector2(700, 786)

const BURLAP: Color = Color(0.86, 0.78, 0.6)
const FLOUR: Color = Color(0.98, 0.97, 0.93)
const WOOD: Color = Color(0.8, 0.6, 0.38)
const STEEL: Color = Color(0.72, 0.74, 0.78)
const CHEESE: Color = Color(0.97, 0.9, 0.62)
const WATER: Color = Color(0.42, 0.68, 0.94)
const BRICK: Color = Color(0.72, 0.34, 0.22)
const RAW_BALL: Color = Color(0.96, 0.9, 0.74)

var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player_node: CanvasItem = null
var _player: Sprite2D = null
var _item: Sprite2D = null
var _item_tex: Dictionary = {}
var _last_pos: Vector2 = Vector2.INF
var _facing: int = CharacterSpriteFactory.DIR_DOWN
var _flip: bool = false
var _walk_t: float = 0.0
var _plate: Sprite2D = null
var _tray_cache: Dictionary = {}
var _mouth: Node2D = null
var _fx: Node2D = null
var _fan: Node2D = null
var _fan_shadow: Node2D = null
var _stations: Dictionary = {}
var _counter_hl: CanvasItem = null
var _customers: Array[Dictionary] = []
var _next_seed: int = 4100
var _puffs: Array = []
var _puff_acc: float = 0.0
var _coins: Array = []
var _state: Dictionary = {}
var _last_tips: int = 0
var _last_lost: int = 0

# --- Construction ---

# `refs` : player (ColorRect), plate (Node2D), counter_hl, stations
# {nom: ColorRect posé au pied de la station}.
func build(refs: Dictionary) -> void:
	_rng.seed = 1565
	y_sort_enabled = true
	var room: Sprite2D = _sprite_at(ImageTexture.create_from_image(paint_room()), Vector2(VIEW_L, 0), false)
	room.z_index = -5
	add_child(room)
	_stations = refs.get("stations", {})
	_counter_hl = refs.get("counter_hl") as CanvasItem
	var station_imgs: Dictionary = {
		"flour": paint_flour(), "water": paint_water(), "queijo": paint_queijo(),
		"basket": paint_basket(), "trash": paint_trash(),
	}
	for k: String in station_imgs:
		var host: Node = _stations.get(k)
		if host:
			host.add_child(_sprite_at(ImageTexture.create_from_image(station_imgs[k]), Vector2.ZERO))
	add_child(_sprite_at(ImageTexture.create_from_image(paint_bench()), Vector2(700, 621)))
	add_child(_sprite_at(ImageTexture.create_from_image(paint_vitrine()), Vector2(1500, 774)))
	add_child(_sprite_at(ImageTexture.create_from_image(paint_logs()), Vector2(498, 951)))
	var oven: Sprite2D = _sprite_at(ImageTexture.create_from_image(paint_oven()), OVEN_BASE)
	add_child(oven)
	_mouth = Node2D.new()
	_mouth.draw.connect(_draw_mouth)
	oven.add_child(_mouth)
	_build_player(refs.get("player") as CanvasItem)
	_build_plate(refs.get("plate") as Node2D)
	for i in SLOTS.size():
		_spawn_customer(SLOTS[i], i, 1.0)
	_fan_shadow = Node2D.new()
	_fan_shadow.z_index = -4
	_fan_shadow.position = FAN_POS + Vector2(36, 96)
	_fan_shadow.draw.connect(_draw_fan.bind(true))
	add_child(_fan_shadow)
	_fx = Node2D.new()
	_fx.z_index = 3
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_fan = Node2D.new()
	_fan.z_index = 4
	_fan.position = FAN_POS
	_fan.draw.connect(_draw_fan.bind(false))
	add_child(_fan)


# Sprite ×3 ancré par le pied (milieu du bord bas) — ou par le coin haut-gauche.
func _sprite_at(tex: Texture2D, pos: Vector2, foot: bool = true) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(D, D)
	if foot:
		s.offset = Vector2(-float(tex.get_width() / 2), -float(tex.get_height()))
	s.position = pos
	return s


func _build_player(host: CanvasItem) -> void:
	if host == null:
		return
	_player_node = host
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	_player = Sprite2D.new()
	_player.texture = baker_sheet(cfg)
	_player.region_enabled = true
	_player.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
	var s: float = CHAR_H / float(CharacterSpriteFactory.CELL_H)
	_player.scale = Vector2(s, s)
	_player.position = PLAYER_FEET
	host.add_child(_player)
	_item = Sprite2D.new()
	_item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item.scale = Vector2(D, D)
	_item.visible = false
	host.add_child(_item)
	for k in ["flour", "water", "queijo"]:
		_item_tex[k] = ImageTexture.create_from_image(paint_hand_item(k))


func _build_plate(host: Node2D) -> void:
	if host == null:
		return
	_plate = Sprite2D.new()
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.scale = Vector2(D, D)
	_plate.z_index = 1
	host.add_child(_plate)


func _spawn_customer(at: Vector2, slot: int, alpha: float) -> void:
	_next_seed += 37
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(_next_seed))
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
	var s: float = CHAR_H / float(CharacterSpriteFactory.CELL_H)
	spr.scale = Vector2(s, s)
	spr.position = at
	spr.modulate.a = alpha
	add_child(spr)
	_customers.append({"spr": spr, "pos": at, "slot": slot, "leaving": false, "angry": false,
		"walk": 0.0, "phase": _rng.randf() * TAU})


# --- Boucle ---

func tick(delta: float, s: Dictionary) -> void:
	_t += delta
	_state = s
	_tick_player(delta)
	_tick_plate()
	_tick_queue(delta)
	_tick_smoke(delta)
	for c in _coins:
		c["age"] = float(c["age"]) + delta
	_coins = _coins.filter(func(c: Dictionary) -> bool: return float(c["age"]) < 1.1)
	_mouth.queue_redraw()
	_fx.queue_redraw()
	_fan.queue_redraw()
	_fan_shadow.queue_redraw()


func _tick_player(delta: float) -> void:
	if _player == null:
		return
	var pos: Vector2 = _state.get("pos", Vector2.ZERO)
	var moved: Vector2 = Vector2.ZERO if _last_pos == Vector2.INF else pos - _last_pos
	_last_pos = pos
	var frame: int = 0
	if moved.length() > 0.5:
		if absf(moved.x) > absf(moved.y) * 0.8:
			_facing = CharacterSpriteFactory.DIR_RIGHT
			_flip = moved.x < 0.0
		else:
			_facing = CharacterSpriteFactory.DIR_DOWN if moved.y > 0.0 else CharacterSpriteFactory.DIR_UP
			_flip = false
		_walk_t += delta
		frame = 1 + int(_walk_t / 0.14) % 2
	else:
		_walk_t = 0.0
	_player.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, _facing * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_player.flip_h = _flip
	# L'ingrédient tenu devant soi (au-dessus de la tête de dos, sinon caché).
	var carry: String = _state.get("carry", "")
	_item.visible = _item_tex.has(carry)
	if _item.visible:
		_item.texture = _item_tex[carry]
		var side: float = 0.0
		if _facing == CharacterSpriteFactory.DIR_RIGHT:
			side = -24.0 if _flip else 24.0
		var bob: float = 3.0 if frame == 1 else 0.0
		_item.position = PLAYER_FEET + Vector2(side, -60.0 + bob)
		_item.z_index = -1 if _facing == CharacterSpriteFactory.DIR_UP else 0
		if _facing == CharacterSpriteFactory.DIR_UP:
			_item.position.y = PLAYER_FEET.y - 160.0


func _tick_plate() -> void:
	if _plate == null:
		return
	var ing: Dictionary = _state.get("ingredients", {})
	var flags: int = (1 if ing.get("flour", false) else 0) | (2 if ing.get("water", false) else 0) \
		| (4 if ing.get("queijo", false) else 0)
	var step: int = _cook_step(float(_state.get("cook", 0.0)))
	var key: String = "%d_%d" % [flags, step]
	if not _tray_cache.has(key):
		_tray_cache[key] = ImageTexture.create_from_image(paint_tray(flags, step))
	_plate.texture = _tray_cache[key]
	var carried: bool = String(_state.get("carry", "")).begins_with("plate_")
	_plate.position = Vector2(0, -6) if carried else Vector2.ZERO
	# Dans le four, la plaque prend la lueur des braises.
	if _state.get("in_oven", false):
		var f: float = 0.05 * sin(_t * 17.0)
		_plate.modulate = Color(1.0, 0.82 + f, 0.66 + f, 1)
	else:
		_plate.modulate = Color.WHITE


# 0 cru, 1-3 doré (de plus en plus), 4-5 trop cuit, 6 brûlé.
func _cook_step(t: float) -> int:
	var a: float = float(_state.get("perfect_min", 4.0))
	var b: float = float(_state.get("perfect_max", 8.0))
	var burn: float = float(_state.get("burn", 11.0))
	if t < a:
		return 0
	if t <= b:
		return 1 + mini(int((t - a) / (b - a) * 3.0), 2)
	if t < burn:
		return 4 if t < (b + burn) * 0.5 else 5
	return 6


func _tick_queue(delta: float) -> void:
	var tips: int = _state.get("tips", 0)
	var lost: int = _state.get("lost", 0)
	if tips > _last_tips:
		_serve_front(false)
		_coins.append({"p": Vector2(1500, 760), "age": 0.0})
	elif lost > _last_lost:
		_serve_front(true)
	_last_tips = tips
	_last_lost = lost
	var urgent: bool = _patience_ratio() < 0.25
	for c in _customers:
		var spr: Sprite2D = c["spr"]
		var pos: Vector2 = c["pos"]
		var target: Vector2 = DOOR_IN if c["leaving"] else SLOTS[int(c["slot"])]
		var to: Vector2 = target - pos
		var row: int = CharacterSpriteFactory.DIR_DOWN
		var frame: int = 0
		var flip: bool = false
		if to.length() > 2.0:
			var step: Vector2 = to.limit_length(CUSTOMER_SPEED * delta)
			pos += step
			c["walk"] = float(c["walk"]) + delta
			frame = 1 + int(float(c["walk"]) / 0.15) % 2
			if absf(step.x) > absf(step.y):
				row = CharacterSpriteFactory.DIR_RIGHT
				flip = step.x < 0.0
			else:
				row = CharacterSpriteFactory.DIR_DOWN if step.y > 0.0 else CharacterSpriteFactory.DIR_UP
		else:
			pos = target
			c["walk"] = 0.0
		c["pos"] = pos
		var hop: float = 0.0
		if urgent and int(c["slot"]) == 0 and not c["leaving"]:
			# La freguesa de tête tape du pied.
			hop = absf(sin(_t * 9.0 + float(c["phase"]))) * 9.0
			frame = 1 + int(_t * 5.0) % 2
		spr.position = Vector2(pos.x, pos.y - snappedf(hop, 3.0))
		spr.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		spr.flip_h = flip
		if c["leaving"] and to.length() <= 2.0:
			spr.modulate.a = maxf(spr.modulate.a - delta * 3.0, 0.0)
		elif spr.modulate.a < 1.0:
			spr.modulate.a = minf(spr.modulate.a + delta * 2.5, 1.0)
	for c in _customers.duplicate():
		if c["leaving"] and (c["spr"] as Sprite2D).modulate.a <= 0.0:
			(c["spr"] as Sprite2D).queue_free()
			_customers.erase(c)


func _serve_front(angry: bool) -> void:
	var front: Dictionary = {}
	for c in _customers:
		if not c["leaving"] and int(c["slot"]) == 0:
			front = c
	if front.is_empty():
		return
	front["leaving"] = true
	front["angry"] = angry
	for c in _customers:
		if not c["leaving"]:
			c["slot"] = int(c["slot"]) - 1
	_spawn_customer(DOOR_IN, SLOTS.size() - 1, 0.0)


func _patience_ratio() -> float:
	var p: float = maxf(float(_state.get("fila_patience", 1.0)), 0.01)
	return clampf(float(_state.get("fila_left", p)) / p, 0.0, 1.0)


func _tick_smoke(delta: float) -> void:
	var in_oven: bool = _state.get("in_oven", false)
	var step: int = _cook_step(float(_state.get("cook", 0.0)))
	var rate: float = 0.0
	if in_oven:
		rate = 1.2 if step <= 3 else (5.0 if step < 6 else 11.0)
	_puff_acc += rate * delta
	while _puff_acc >= 1.0:
		_puff_acc -= 1.0
		var dark: float = 0.82 if step <= 3 else (0.5 if step < 6 else 0.16)
		_puffs.append({"p": CHIMNEY_TOP + Vector2(_rng.randf_range(-6, 6), 0), "v": Vector2(_rng.randf_range(4, 22), -52),
			"age": 0.0, "life": 2.2, "col": Color(dark, dark, dark * 1.02), "r": 2.0})
		if step >= 4:
			_puffs.append({"p": MOUTH_TOP + Vector2(_rng.randf_range(-48, 48), 6), "v": Vector2(_rng.randf_range(-12, 12), -64),
				"age": 0.0, "life": 1.6, "col": Color(dark, dark, dark), "r": 2.0})
	for pf in _puffs:
		pf["age"] = float(pf["age"]) + delta
		pf["p"] = (pf["p"] as Vector2) + (pf["v"] as Vector2) * delta
	_puffs = _puffs.filter(func(pf: Dictionary) -> bool: return float(pf["age"]) < float(pf["life"]))


# --- Dessins animés ---

func _cell(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2((p / D).floor() * D, Vector2(D, D)), col)


func _disc(ci: CanvasItem, c: Vector2, r: int, col: Color) -> void:
	var o: Vector2 = (c / D).floor() * D
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if i * i + j * j <= r * r + r / 2:
				ci.draw_rect(Rect2(o + Vector2(i, j) * D, Vector2(D, D)), col)


# Gueule du four (repère natif du sprite, origine au pied) : braises au
# repos, flammes et lueur quand la plaque cuit.
func _draw_mouth() -> void:
	var ox: float = -float(OVEN_W / 2)
	var oy: float = -float(OVEN_H)
	var in_oven: bool = _state.get("in_oven", false)
	var step: int = _cook_step(float(_state.get("cook", 0.0)))
	if in_oven:
		var glow: Color = Color(1.0, 0.55, 0.15, 0.32 + 0.06 * sin(_t * 13.0))
		if step >= 1 and step <= 3:
			glow = Color(1.0, 0.75, 0.25, 0.42 + 0.08 * sin(_t * 9.0))
		elif step >= 6:
			glow = Color(0.6, 0.12, 0.05, 0.4)
		for y in range(48, 74):
			var hw: int = 25 if y >= 58 else int(sqrt(maxf(0.0, 1.0 - pow(float(58 - y) / 12.0, 2.0))) * 25.0)
			_mouth.draw_rect(Rect2(ox + 48 - hw, oy + y, hw * 2, 1), glow)
	# Braises / flammes au fond.
	for i in 24:
		var x: int = 25 + i * 2
		var h: int = 1 + int(absf(sin(_t * (4.0 + float(i % 5)) + float(i) * 1.7)) * (6.0 if in_oven else 1.5))
		for k in h:
			var col: Color = Color(1.0, 0.9, 0.4) if k >= h - 1 and in_oven else Color(0.95, 0.45, 0.12)
			if not in_oven:
				col = Color(0.75, 0.2, 0.08) if k == 0 else Color(0.95, 0.45, 0.12)
			_mouth.draw_rect(Rect2(ox + x, oy + 73 - k, 2, 1), col)


func _draw_fx() -> void:
	# Fumée (au-dessus de tout : elle monte devant le mur).
	for pf in _puffs:
		var u: float = float(pf["age"]) / float(pf["life"])
		var col: Color = pf["col"]
		col.a = 0.75 * (1.0 - u)
		_disc(_fx, pf["p"], int(2.0 + u * 5.0), col)
	# Étincelles « no ponto » autour de la gueule.
	var in_oven: bool = _state.get("in_oven", false)
	var step: int = _cook_step(float(_state.get("cook", 0.0)))
	if in_oven and step >= 1 and step <= 3:
		for i in 4:
			var a: float = _t * 2.2 + float(i) * TAU / 4.0
			var p: Vector2 = MOUTH_TOP + Vector2(cos(a) * 96.0, 36.0 + sin(a) * 40.0)
			var blink: bool = int(_t * 6.0 + float(i)) % 2 == 0
			var c: Color = Color(1, 0.95, 0.5) if blink else Color(1, 1, 1)
			_cell(_fx, p, c)
			_cell(_fx, p + Vector2(D, 0), c)
			_cell(_fx, p - Vector2(D, 0), c)
			_cell(_fx, p + Vector2(0, D), c)
			_cell(_fx, p - Vector2(0, D), c)
	# Flèches au-dessus des stations où Action fait quelque chose.
	var tops: Dictionary = {"flour": Vector2(260, 222), "water": Vector2(660, 190), "queijo": Vector2(1060, 230),
		"basket": Vector2(1500, 768), "trash": Vector2(1740, 772)}
	for k: String in tops:
		var host: CanvasItem = _stations.get(k) as CanvasItem
		if host and host.modulate.r > 0.9:
			_arrow(tops[k])
	if _counter_hl and _counter_hl.visible:
		_arrow(Vector2(700, 470))
	var carry: String = _state.get("carry", "")
	if carry == "plate_raw" and not in_oven or (carry == "" and in_oven and step >= 1):
		_arrow(Vector2(700, 772))
	# Fregueses : jauge de patience au-dessus de la tête de file, bulles.
	for c in _customers:
		var pos: Vector2 = (c["spr"] as Sprite2D).position
		var head: Vector2 = pos - Vector2(0, CHAR_H + 6)
		if c["leaving"]:
			if c["angry"]:
				_bubble(head + Vector2(30, -12), Color(0.9, 0.2, 0.15))
			else:
				_bag(pos + Vector2(27, -66))
		elif int(c["slot"]) == 0 and (c["pos"] as Vector2).distance_to(SLOTS[0]) < 4.0:
			_gauge(head)
			if _patience_ratio() < 0.25:
				_bubble(head + Vector2(-12, -78), Color(0.9, 0.2, 0.15))
	for co in _coins:
		var u2: float = float(co["age"]) / 1.1
		var cp: Vector2 = (co["p"] as Vector2) - Vector2(0, u2 * 90.0)
		var gold: Color = Color(1, 0.82, 0.25, 1.0 - u2 * u2)
		_disc(_fx, cp, 3, Color(0.55, 0.38, 0.1, gold.a))
		_disc(_fx, cp, 2, gold)
		_cell(_fx, cp - Vector2(D, D), Color(1, 1, 0.85, gold.a))


func _arrow(at: Vector2) -> void:
	var p: Vector2 = at + Vector2(0, -absf(sin(_t * 5.0)) * 12.0)
	var rows: Array[String] = [".#######.", "#yyyyyyy#", ".#yyyyy#.", "..#yyy#..", "...#y#...", "....#...."]
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if row[i] == ".":
				continue
			var col: Color = INK if row[i] == "#" else Color(1, 0.86, 0.25)
			if row[i] == "y" and j == 1 and i < 5:
				col = Color(1, 0.97, 0.7)
			_cell(_fx, p + Vector2((i - 4) * D, (j - 6) * D), col)


# Jauge : cadre bois, horloge, remplissage vert → jaune → rouge.
func _gauge(head: Vector2) -> void:
	var r: float = _patience_ratio()
	var o: Vector2 = ((head + Vector2(-60, -24)) / D).floor() * D
	var w: int = 36
	_fx.draw_rect(Rect2(o + Vector2(-D, -D), Vector2((w + 10) * D, 9 * D)), INK)
	_fx.draw_rect(Rect2(o, Vector2((w + 8) * D, 7 * D)), Color(0.55, 0.36, 0.2))
	# Horloge.
	_disc(_fx, o + Vector2(4 * D, 3.5 * D), 2, Color(0.98, 0.96, 0.9))
	_cell(_fx, o + Vector2(4 * D, 2 * D), INK)
	_cell(_fx, o + Vector2(4 * D, 3 * D), INK)
	_cell(_fx, o + Vector2(5 * D, 3 * D), INK)
	var bar: Rect2 = Rect2(o + Vector2(8 * D, D), Vector2(w * D, 5 * D))
	_fx.draw_rect(bar, Color(0.18, 0.12, 0.1))
	var col: Color = Color(0.4, 0.85, 0.35).lerp(Color(1, 0.82, 0.25), clampf((0.75 - r) / 0.4, 0.0, 1.0))
	if r < 0.35:
		col = Color(1, 0.82, 0.25).lerp(Color(0.92, 0.22, 0.18), clampf((0.35 - r) / 0.2, 0.0, 1.0))
	var fw: float = floorf(float(w) * r) * D
	_fx.draw_rect(Rect2(bar.position, Vector2(fw, 5 * D)), col)
	_fx.draw_rect(Rect2(bar.position, Vector2(fw, D)), col.lightened(0.35))


func _bubble(at: Vector2, col: Color) -> void:
	var o: Vector2 = (at / D).floor() * D
	var rows: Array[String] = [".#####.", "#wwrww#", "#wwrww#", "#wwrww#", "#wwwww#", "#wwrww#", ".##w##.", "...#..."]
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var ch: String = row[i]
			if ch == ".":
				continue
			var c: Color = INK if ch == "#" else (col if ch == "r" else Color(1, 1, 1))
			_fx.draw_rect(Rect2(o + Vector2(i, j) * D, Vector2(D, D)), c)


# Sachet de pão kraft dans la main d'une freguesa servie.
func _bag(at: Vector2) -> void:
	var o: Vector2 = (at / D).floor() * D
	_fx.draw_rect(Rect2(o - Vector2(D, D), Vector2(8 * D, 9 * D)), INK)
	_fx.draw_rect(Rect2(o, Vector2(6 * D, 7 * D)), Color(0.78, 0.6, 0.4))
	_fx.draw_rect(Rect2(o, Vector2(6 * D, D)), Color(0.9, 0.76, 0.55))
	_fx.draw_rect(Rect2(o + Vector2(D, -2 * D), Vector2(4 * D, D)), Color(0.95, 0.75, 0.38))


# Ventilateur de plafond (pales qui tournent) ou son ombre portée au sol.
func _draw_fan(shadow: bool) -> void:
	var ci: Node2D = _fan_shadow if shadow else _fan
	var ang: float = snappedf(_t * 2.6, TAU / 24.0)
	var blade: Color = Color(0, 0, 0, 0.12) if shadow else Color(0.55, 0.37, 0.22)
	var edge: Color = Color(0, 0, 0, 0.12) if shadow else INK
	for k in 4:
		var a: float = ang + float(k) * TAU / 4.0
		var dir: Vector2 = Vector2(cos(a), sin(a) * 0.55)
		var nrm: Vector2 = Vector2(-dir.y, dir.x).normalized()
		for s in range(4, 26):
			for w in range(-3, 4):
				var p: Vector2 = dir * float(s * D) + nrm * float(w) * D * 0.7
				var c: Color = edge if absi(w) == 3 or s == 25 else blade
				if not shadow and w == -1 and s > 5:
					c = blade.lightened(0.2)
				_cell(ci, p, c)
	if not shadow:
		_disc(ci, Vector2.ZERO, 4, INK)
		_disc(ci, Vector2.ZERO, 3, Color(0.85, 0.68, 0.3))
		_cell(ci, Vector2(-D, -D), Color(1, 0.92, 0.6))
	else:
		_disc(ci, Vector2.ZERO, 4, Color(0, 0, 0, 0.12))


# --- Peintures statiques (Image natives) ---

static func _img(w: int, h: int) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, blend: bool = false) -> void:
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				if blend:
					_blend(img, x, y, c)
				else:
					_dot(img, x, y, c)


static func _shadow(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_ellipse(img, cx, cy, rx, ry, Color(0.1, 0.05, 0.03, 0.3), true)


# Contour encre autour de tout ce qui est opaque (l'ombre portée s'efface
# sous le contour, comme chez les personnages).
static func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= 0.9:
				continue
			for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n: Color = img.get_pixel(nx, ny)
				if n.a >= 0.9 and n != INK:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixel(m.x, m.y, INK)


static func _text(img: Image, x: int, y: int, text: String, c: Color) -> void:
	var cx: int = x
	for ch in text:
		if ch == " ":
			cx += PixelFont.SPACE_ADVANCE
			continue
		var rows: Array = PixelFont._rows(ch)
		if rows.is_empty():
			cx += 4
			continue
		var gw: int = 0
		for r in rows.size():
			var row: String = rows[r]
			gw = maxi(gw, row.length())
			for i in row.length():
				if row[i] == "#":
					_dot(img, cx + i, y + r, c)
		cx += gw + 1


static func _hash(a: int, b: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663)
	return float(posmod(h, 1000)) / 1000.0


# Salle : lambris vert, faïence et frise d'azulejos, plinthe, damier.
static func paint_room() -> Image:
	var w: int = (VIEW_R - VIEW_L) / D
	var h: int = ROOM_H / D
	var img: Image = _img(w, h)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1565
	var green: Color = Color(0.16, 0.4, 0.31)
	_fill(img, 0, 0, w, 38, green)
	for x in range(0, w, 16):
		_fill(img, x, 2, 1, 35, green.darkened(0.18))
		_fill(img, x + 1, 2, 1, 35, green.lightened(0.08))
	_fill(img, 0, 0, w, 2, green.darkened(0.35))
	_fill(img, 0, 37, w, 1, green.darkened(0.35))
	_fill(img, 0, 38, w, 3, Color(0.93, 0.88, 0.72))
	_fill(img, 0, 40, w, 1, Color(0.7, 0.62, 0.48))
	# Faïence 6×6 : blanc cassé, joints gris-bleu, frise bleue (azulejos).
	var grout: Color = Color(0.7, 0.77, 0.8)
	var white: Color = Color(0.95, 0.96, 0.93)
	var blue: Color = Color(0.17, 0.33, 0.68)
	for y in range(ROW_FAIENCE, ROW_PLINTH):
		var ly: int = (y - ROW_FAIENCE) % 6
		var ty: int = (y - ROW_FAIENCE) / 6
		for x in w:
			var lx: int = x % 6
			var col: Color = white
			if lx == 0 or ly == 0:
				col = grout
			elif ty == 2:
				var md: int = absi(lx - 3) + absi(ly - 3)
				col = blue if md == 2 or md == 0 else Color(0.86, 0.9, 0.97)
				if (lx == 1 or lx == 5) and (ly == 1 or ly == 5):
					col = Color(0.45, 0.6, 0.85)
			elif lx == 1 and ly == 1:
				col = Color(1, 1, 1)
			img.set_pixel(x, y, col)
	_fill(img, 0, ROW_PLINTH, w, 3, Color(0.36, 0.22, 0.14))
	_fill(img, 0, ROW_PLINTH, w, 1, Color(0.5, 0.33, 0.2))
	# Damier de ladrilhos crème / rouge brique.
	var cream: Color = Color(0.89, 0.85, 0.75)
	var red: Color = Color(0.7, 0.35, 0.28)
	var tile: int = 12
	for ty in range((h - ROW_FLOOR) / tile + 1):
		for tx in range(w / tile + 1):
			var base: Color = cream if (tx + ty) % 2 == 0 else red
			var v: float = _hash(tx, ty) * 0.06 - 0.03
			base = base.lightened(v) if v > 0.0 else base.darkened(-v)
			var x0: int = tx * tile
			var y0: int = ROW_FLOOR + ty * tile
			_fill(img, x0, y0, tile, tile, base)
			_fill(img, x0, y0, tile, 1, base.darkened(0.14))
			_fill(img, x0, y0, 1, tile, base.darkened(0.14))
			_fill(img, x0 + 1, y0 + 1, tile - 2, 1, base.lightened(0.06))
	for i in w * 2:
		var x: int = rng.randi_range(0, w - 1)
		var y: int = rng.randi_range(ROW_FLOOR, h - 1)
		_blend(img, x, y, Color(0, 0, 0, 0.08))
	# Ombre de contact au pied du mur.
	for k in 4:
		for x in w:
			_blend(img, x, ROW_FLOOR + k, Color(0.08, 0.04, 0.02, 0.22 - 0.05 * float(k)))
	# Farine tombée autour du plan de travail.
	for i in 260:
		var fx: float = rng.randfn(700.0, 110.0)
		var fy: float = rng.randfn(612.0, 34.0)
		_blend(img, int((fx - VIEW_L) / D), int(fy / D), Color(1, 1, 0.97, 0.65))
	_paint_door(img)
	_paint_shelf(img, rng)
	_paint_chalkboard(img)
	return img


# Porte sur la rue : rideau de fer roulé, ciel, morro, calçadão en vagues.
static func _paint_door(img: Image) -> void:
	var x0: int = (DOOR_X0 - VIEW_L) / D
	var x1: int = (DOOR_X1 - VIEW_L) / D
	var top: int = 6
	for y in range(top, ROW_FLOOR):
		for x in range(x0, x1):
			var col: Color = Color(0.55, 0.8, 0.98).lerp(Color(0.8, 0.92, 1.0), float(y - top) / 30.0)
			var lx: int = x - x0
			var mh: float = 36.0 - 9.0 * exp(-pow((float(lx) - 30.0) / 9.0, 2.0)) - 4.0 * sin(float(lx) * 0.2)
			if float(y) > mh:
				col = Color(0.3, 0.55, 0.32)
			if y >= 44:
				col = Color(0.42, 0.42, 0.45)  # rua
			if y >= 54:
				var k: int = y - 54 + int(round(2.0 * sin(float(lx) * TAU / 16.0)))
				col = Color(0.16, 0.16, 0.18) if posmod(k, 7) < 3 else Color(0.95, 0.93, 0.86)
			img.set_pixel(x, y, col)
	# Rideau de fer roulé, montants, seuil.
	_fill(img, x0, top, x1 - x0, 6, Color(0.6, 0.62, 0.66))
	for y in range(top, top + 6, 2):
		_fill(img, x0, y, x1 - x0, 1, Color(0.44, 0.46, 0.5))
	_fill(img, x0 - 3, top - 1, 3, ROW_FLOOR - top + 1, Color(0.36, 0.22, 0.14))
	_fill(img, x1, top - 1, 3, ROW_FLOOR - top + 1, Color(0.36, 0.22, 0.14))
	_fill(img, x0 - 3, top - 2, x1 - x0 + 6, 1, INK)
	_fill(img, x0 - 3, ROW_FLOOR - 1, x1 - x0 + 6, 3, Color(0.75, 0.73, 0.68))


# Étagère de faïence : guaraná, goiabada, biscoitos de polvilho.
static func _paint_shelf(img: Image, rng: RandomNumberGenerator) -> void:
	var y: int = 70
	var x0: int = (-300 - VIEW_L) / D
	var x1: int = (1200 - VIEW_L) / D
	_fill(img, x0, y, x1 - x0, 2, Color(0.55, 0.36, 0.2))
	_fill(img, x0, y + 2, x1 - x0, 1, Color(0.3, 0.18, 0.1))
	var x: int = x0 + 3
	while x < x1 - 8:
		var kind: int = rng.randi() % 4
		match kind:
			0:  # latas de guaraná
				for k in 3:
					_fill(img, x + k * 3, y - 5, 2, 5, Color(0.2, 0.6, 0.25))
					_dot(img, x + k * 3, y - 5, Color(0.85, 0.85, 0.85))
				x += 10
			1:  # pote de goiabada
				_fill(img, x, y - 6, 5, 6, Color(0.75, 0.2, 0.25))
				_fill(img, x, y - 7, 5, 1, Color(0.95, 0.8, 0.3))
				x += 7
			2:  # saco de biscoito de polvilho
				_fill(img, x, y - 8, 5, 8, Color(0.97, 0.97, 0.95))
				_fill(img, x + 1, y - 5, 3, 2, Color(0.9, 0.3, 0.3))
				x += 7
			_:  # pão francês empilhado
				for k in 3:
					_ellipse(img, float(x) + 3.0 + float(k) * 4.0, float(y) - 2.0, 2.5, 1.6, Color(0.9, 0.62, 0.3))
					_dot(img, x + 3 + k * 4, y - 3, Color(0.98, 0.85, 0.55))
				x += 14
		x += rng.randi_range(2, 6)


# Tableau à la craie des prix (texte cuit en pixels natifs).
static func _paint_chalkboard(img: Image) -> void:
	var x0: int = (1236 - VIEW_L) / D
	var bw: int = 116
	var y0: int = 43
	var bh: int = 31
	_fill(img, x0 - 1, y0 - 1, bw + 2, bh + 2, INK)
	_fill(img, x0, y0, bw, bh, Color(0.55, 0.36, 0.2))
	_fill(img, x0 + 2, y0 + 2, bw - 4, bh - 4, Color(0.14, 0.21, 0.18))
	var chalk: Color = Color(0.94, 0.94, 0.88)
	var l1: String = "PÃO DE QUEIJO 1,50"
	var l2: String = "CAFEZINHO 3,00"
	_text(img, x0 + (bw - PixelFont.native_width(l1)) / 2, y0 + 2, l1, chalk)
	_text(img, x0 + (bw - PixelFont.native_width(l2)) / 2, y0 + 15, l2, Color(1, 0.88, 0.5))
	_fill(img, x0 + 6, y0 + 14, bw - 12, 1, Color(0.4, 0.46, 0.43))


static func _burlap(img: Image, x0: int, y0: int, x1: int, y1: int, round_px: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cut: int = 0
			if y > y1 - round_px:
				cut = y - (y1 - round_px)
			if x < x0 + cut or x > x1 - cut:
				continue
			var c: Color = BURLAP
			if (x + y * 2) % 3 == 0:
				c = BURLAP.darkened(0.07)
			if x <= x0 + 1 + cut:
				c = BURLAP.darkened(0.16)
			elif x >= x1 - 1 - cut:
				c = BURLAP.darkened(0.1)
			_dot(img, x, y, c)


# Farine : un sac fermé, un sac ouvert (farine en dôme, pelle en inox).
static func paint_flour() -> Image:
	var img: Image = _img(48, 42)
	_shadow(img, 24, 38, 22, 4)
	# Sac du fond, fermé, noué.
	_burlap(img, 4, 10, 22, 34, 3)
	_fill(img, 9, 5, 9, 6, BURLAP.darkened(0.05))
	_fill(img, 8, 3, 11, 3, BURLAP)
	_fill(img, 9, 8, 9, 1, Color(0.5, 0.3, 0.16))
	_fill(img, 5, 18, 17, 2, Color(0.25, 0.4, 0.75))
	for k in 5:
		_dot(img, 13, 22 + k * 2, Color(0.6, 0.42, 0.18))
		_dot(img, 12, 21 + k * 2, Color(0.8, 0.6, 0.25))
		_dot(img, 14, 21 + k * 2, Color(0.8, 0.6, 0.25))
	# Sac ouvert devant : col roulé et farine.
	_burlap(img, 19, 17, 43, 38, 3)
	_fill(img, 19, 15, 25, 3, BURLAP.lightened(0.08))
	_fill(img, 19, 17, 25, 1, BURLAP.darkened(0.2))
	_ellipse(img, 31, 15, 10.5, 3.2, FLOUR)
	_ellipse(img, 30, 13, 6.5, 3.0, FLOUR)
	_fill(img, 26, 12, 3, 1, Color(1, 1, 1))
	_fill(img, 22, 16, 18, 1, Color(0.86, 0.85, 0.82))
	# Étiquette TRIGO.
	_fill(img, 24, 24, 15, 9, Color(0.97, 0.95, 0.88))
	_fill(img, 24, 24, 15, 1, Color(0.8, 0.2, 0.18))
	_fill(img, 24, 32, 15, 1, Color(0.8, 0.2, 0.18))
	for k in 3:
		_dot(img, 31, 27 + k * 2, Color(0.6, 0.42, 0.18))
		_dot(img, 30, 26 + k * 2, Color(0.85, 0.65, 0.25))
		_dot(img, 32, 26 + k * 2, Color(0.85, 0.65, 0.25))
	# Pelle.
	_fill(img, 34, 9, 5, 4, STEEL)
	_fill(img, 34, 9, 5, 1, STEEL.lightened(0.3))
	for k in 5:
		_dot(img, 39 + k, 8 - k, Color(0.4, 0.4, 0.44))
	_outline(img)
	for k in 9:
		_dot(img, 8 + k * 4, 40, Color(1, 1, 0.96, 0.8))
	return img


# Eau : galão bleu de 20 L retourné sur sa fontaine.
static func paint_water() -> Image:
	var img: Image = _img(34, 54)
	_shadow(img, 17, 51, 14, 3)
	var white: Color = Color(0.93, 0.93, 0.9)
	_fill(img, 6, 24, 22, 26, white)
	_fill(img, 6, 24, 22, 2, Color(1, 1, 1))
	_fill(img, 26, 24, 2, 26, white.darkened(0.18))
	_fill(img, 6, 24, 1, 26, white.darkened(0.08))
	_fill(img, 9, 34, 16, 2, Color(0.6, 0.62, 0.66))
	_fill(img, 7, 38, 20, 1, white.darkened(0.12))
	_fill(img, 10, 28, 3, 3, Color(0.25, 0.45, 0.85))
	_fill(img, 21, 28, 3, 3, Color(0.85, 0.25, 0.2))
	_fill(img, 11, 31, 1, 2, Color(0.4, 0.4, 0.44))
	_fill(img, 22, 31, 1, 2, Color(0.4, 0.4, 0.44))
	# Galão.
	_fill(img, 13, 19, 8, 5, WATER.darkened(0.25))
	for y in range(1, 19):
		var inset: int = 2 if y == 1 or y == 18 else (1 if y == 2 or y == 17 else 0)
		_fill(img, 6 + inset, y, 22 - inset * 2, 1, WATER)
	_fill(img, 8, 2, 18, 3, WATER.lightened(0.35))
	_fill(img, 6, 7, 22, 1, WATER.darkened(0.15))
	_fill(img, 6, 13, 22, 1, WATER.darkened(0.15))
	_fill(img, 9, 4, 2, 13, Color(0.82, 0.93, 1))
	_fill(img, 24, 3, 2, 14, WATER.darkened(0.2))
	_fill(img, 14, 9, 8, 3, Color(1, 1, 1))
	_fill(img, 16, 10, 4, 1, Color(0.25, 0.45, 0.85))
	_outline(img)
	return img


# Queijo : meule de queijo Minas entamée sur un caixote, râpe et râpé.
static func paint_queijo() -> Image:
	var img: Image = _img(48, 40)
	_shadow(img, 24, 37, 22, 3)
	var wd: Color = WOOD.darkened(0.08)
	_fill(img, 3, 18, 42, 4, wd.lightened(0.12))
	for y in range(22, 36):
		var c: Color = wd if (y - 22) % 5 != 4 else wd.darkened(0.3)
		_fill(img, 3, y, 42, 1, c)
	_fill(img, 3, 18, 3, 18, wd.darkened(0.2))
	_fill(img, 42, 18, 3, 18, wd.darkened(0.2))
	# Meule : flanc puis dessus, part manquante côté droit.
	var side: Color = Color(0.93, 0.82, 0.48)
	_fill(img, 6, 11, 26, 8, side)
	_fill(img, 6, 17, 26, 2, side.darkened(0.15))
	_ellipse(img, 19, 11, 13, 4.6, CHEESE)
	_ellipse(img, 16, 10, 6, 2, CHEESE.lightened(0.3))
	for y in range(7, 19):
		for x in range(26, 33):
			if x - 26 > (y - 7) / 2 + 1:
				_dot(img, x, y, Color(0, 0, 0, 0))
	_fill(img, 26, 12, 1, 7, Color(1, 0.96, 0.78))
	# Part coupée posée à côté.
	for j in 6:
		_fill(img, 30, 12 + j, j + 2, 1, Color(1, 0.95, 0.72))
	_fill(img, 30, 17, 8, 1, side.darkened(0.1))
	# Râpe en inox.
	_fill(img, 37, 3, 6, 13, STEEL)
	_fill(img, 37, 3, 1, 13, STEEL.lightened(0.25))
	for y in range(5, 15, 2):
		for x in range(39, 43, 2):
			_dot(img, x, y, STEEL.darkened(0.35))
	_fill(img, 38, 1, 4, 2, Color(0.25, 0.25, 0.3))
	_outline(img)
	for k in 7:
		_dot(img, 8 + k * 3, 21, Color(1, 0.92, 0.5))
	return img


# Plan de travail en bois fariné : rouleau, pâte, bol.
static func paint_bench() -> Image:
	var img: Image = _img(150, 46)
	_shadow(img, 75, 43, 74, 3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for y in range(2, 31):
		var c: Color = WOOD
		if (y - 2) % 7 == 6:
			c = WOOD.darkened(0.2)
		elif y == 2:
			c = WOOD.lightened(0.18)
		_fill(img, 1, y, 148, 1, c)
	for y in range(2, 31):
		for x in range(1, 149):
			var d: float = absf(float(x) - 75.0) / 75.0
			if rng.randf() < 0.22 * (1.0 - d * 0.7):
				_dot(img, x, y, FLOUR if rng.randf() < 0.6 else Color(0.95, 0.9, 0.8))
	_fill(img, 1, 2, 2, 29, WOOD.darkened(0.15))
	_fill(img, 147, 2, 2, 29, WOOD.darkened(0.25))
	# Façade et tiroirs.
	var front: Color = Color(0.6, 0.42, 0.26)
	_fill(img, 1, 31, 148, 11, front)
	_fill(img, 1, 31, 148, 1, front.darkened(0.3))
	for dx: int in [16, 90]:
		_fill(img, dx, 33, 44, 7, front.lightened(0.08))
		_fill(img, dx, 39, 44, 1, front.darkened(0.25))
		_fill(img, dx + 20, 35, 4, 2, Color(0.85, 0.75, 0.4))
	_fill(img, 3, 42, 5, 3, front.darkened(0.4))
	_fill(img, 142, 42, 5, 3, front.darkened(0.4))
	# Rouleau à pâtisserie.
	_fill(img, 9, 8, 26, 4, Color(0.9, 0.75, 0.5))
	_fill(img, 9, 8, 26, 1, Color(0.97, 0.88, 0.66))
	_fill(img, 4, 9, 5, 2, Color(0.6, 0.4, 0.22))
	_fill(img, 35, 9, 5, 2, Color(0.6, 0.4, 0.22))
	# Pâte qui repose, bol de queijo râpé.
	_ellipse(img, 126, 12, 10, 5, RAW_BALL)
	_ellipse(img, 124, 11, 5, 2, RAW_BALL.lightened(0.4))
	_ellipse(img, 126, 23, 8, 4, STEEL)
	_ellipse(img, 126, 22, 6, 2.4, CHEESE)
	_outline(img)
	return img


# Four à pain : dôme et façade en briques, gueule voûtée, cheminée, socle.
static func paint_oven() -> Image:
	var img: Image = _img(OVEN_W, OVEN_H)
	_shadow(img, 48, 101, 47, 3)
	var mortar: Color = Color(0.56, 0.45, 0.38)
	var cx: float = 48.0
	for y in range(8, 90):
		for x in range(3, 93):
			var inside: bool = y >= 24
			if y < 24:
				var dy: float = (24.0 - float(y)) / 16.0
				inside = absf(float(x) + 0.5 - cx) <= 45.0 * sqrt(maxf(0.0, 1.0 - dy * dy))
			if not inside:
				continue
			var row: int = y / 4
			var off: int = (row % 2) * 4
			var c: Color = mortar
			if y % 4 != 3 and (x + off) % 8 != 7:
				var hsh: float = _hash((x + off) / 8, row)
				c = BRICK if hsh < 0.5 else (BRICK.darkened(0.12) if hsh < 0.8 else BRICK.lightened(0.1))
				# Lumière en haut à gauche sur le dôme.
				if y < 24 and float(x) < cx:
					c = c.lightened(0.12)
				if x > 84:
					c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	# Gueule : voûte en claveaux clairs, intérieur sombre, sole.
	for y in range(42, 76):
		for x in range(18, 78):
			var dx: float = float(x) + 0.5 - cx
			var r_in: float = 25.0
			var mouth: bool = false
			var ring: bool = false
			if y >= 58:
				mouth = absf(dx) <= r_in and y < 74
				ring = not mouth and absf(dx) <= r_in + 3.0 and y < 74
			else:
				var e: float = pow(dx / r_in, 2.0) + pow((58.0 - float(y)) / 12.0, 2.0)
				var e2: float = pow(dx / (r_in + 3.0), 2.0) + pow((58.0 - float(y)) / 15.0, 2.0)
				mouth = e <= 1.0
				ring = not mouth and e2 <= 1.0
			if mouth:
				var k: float = clampf(float(y - 46) / 28.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.12, 0.06, 0.05).lerp(Color(0.3, 0.13, 0.07), k))
			elif ring:
				var joint: bool = int(absf(dx) + float(y)) % 5 == 0
				img.set_pixel(x, y, Color(0.6, 0.45, 0.36) if joint else Color(0.86, 0.55, 0.38))
	_fill(img, 20, 74, 56, 3, Color(0.72, 0.7, 0.66))
	_fill(img, 20, 74, 56, 1, Color(0.85, 0.83, 0.78))
	# Socle en pierre.
	var stone: Color = Color(0.62, 0.6, 0.56)
	for y in range(89, 100):
		for x in range(1, 95):
			var c: Color = stone
			if y == 89:
				c = stone.lightened(0.2)
			elif (y - 90) % 5 == 4 or (x + ((y - 90) / 5) * 7) % 14 == 0:
				c = stone.darkened(0.2)
			img.set_pixel(x, y, c)
	# Cheminée en tôle.
	_fill(img, 66, 2, 9, 14, Color(0.32, 0.32, 0.35))
	_fill(img, 66, 2, 2, 14, Color(0.48, 0.48, 0.52))
	_fill(img, 65, 0, 11, 3, Color(0.25, 0.25, 0.28))
	_fill(img, 66, 8, 9, 1, Color(0.22, 0.22, 0.25))
	_outline(img)
	return img


# Petite pile de bûches (lenha) au pied du four.
static func paint_logs() -> Image:
	var img: Image = _img(30, 18)
	_shadow(img, 15, 15, 14, 2)
	var bark: Color = Color(0.45, 0.28, 0.16)
	for p: Vector2i in [Vector2i(5, 12), Vector2i(13, 12), Vector2i(21, 12), Vector2i(9, 7), Vector2i(17, 7)]:
		_ellipse(img, p.x + 0.5, p.y + 0.5, 4.2, 3.6, bark)
		_ellipse(img, p.x + 0.5, p.y + 0.5, 2.6, 2.2, Color(0.86, 0.68, 0.45))
		_dot(img, p.x, p.y, Color(0.7, 0.5, 0.3))
	_outline(img)
	return img


# Vitrine de salgados : pão de queijo, coxinhas, pão francês sous verre.
static func paint_vitrine() -> Image:
	var img: Image = _img(110, 62)
	_shadow(img, 55, 59, 54, 2)
	var frame: Color = Color(0.78, 0.8, 0.84)
	_fill(img, 1, 1, 108, 36, frame)
	_fill(img, 3, 3, 104, 31, Color(0.95, 0.93, 0.86))
	for dx: int in [37, 72]:
		_fill(img, dx, 3, 2, 31, frame.darkened(0.15))
	# Pão de queijo.
	for j in 4:
		for i in 5:
			var cx: int = 6 + i * 6 + (j % 2) * 2
			var cy: int = 7 + j * 6
			_ellipse(img, cx + 0.5, cy + 0.5, 2.6, 2.4, Color(0.93, 0.7, 0.33))
			_dot(img, cx - 1, cy - 1, Color(1, 0.9, 0.6))
	# Coxinhas (gouttes dorées).
	for j in 3:
		for i in 4:
			var x0: int = 42 + i * 7 + (j % 2) * 3
			var y0: int = 6 + j * 9
			var rows: Array[int] = [0, 1, 1, 2, 2, 2]
			for r in rows.size():
				_fill(img, x0 + 2 - rows[r], y0 + r, rows[r] * 2 + 1, 1, Color(0.82, 0.48, 0.2))
			_dot(img, x0 + 2, y0, Color(0.95, 0.7, 0.35))
			_dot(img, x0 + 1, y0 + 3, Color(0.95, 0.68, 0.36))
	# Pães franceses.
	for j in 4:
		for i in 3:
			var cx2: int = 80 + i * 9 + (j % 2) * 2
			var cy2: int = 7 + j * 7
			_ellipse(img, cx2 + 0.5, cy2 + 0.5, 4.2, 2.4, Color(0.88, 0.6, 0.28))
			_fill(img, cx2 - 2, cy2, 4, 1, Color(0.98, 0.86, 0.6))
	# Étiquettes de prix.
	for tx: int in [16, 52, 88]:
		_fill(img, tx, 30, 7, 3, Color(1, 1, 1))
		_fill(img, tx + 1, 31, 5, 1, Color(0.8, 0.2, 0.18))
	# Verre : teinte froide et reflets en diagonale.
	for y in range(3, 34):
		for x in range(3, 107):
			_blend(img, x, y, Color(0.7, 0.88, 1.0, 0.16))
			var dg: int = posmod(x - y * 2, 46)
			if dg < 2 or dg == 5:
				_blend(img, x, y, Color(1, 1, 1, 0.45))
	_fill(img, 1, 34, 108, 3, frame.darkened(0.1))
	_fill(img, 1, 34, 108, 1, Color(1, 1, 1))
	# Façade émaillée, bande rouge, enseigne.
	var enamel: Color = Color(0.95, 0.94, 0.89)
	_fill(img, 1, 37, 108, 21, enamel)
	_fill(img, 1, 52, 108, 3, Color(0.8, 0.15, 0.15))
	_fill(img, 106, 37, 3, 21, enamel.darkened(0.14))
	var label: String = "SALGADOS"
	_text(img, (110 - PixelFont.native_width(label)) / 2, 38, label, Color(0.75, 0.13, 0.13))
	_fill(img, 1, 58, 108, 2, Color(0.25, 0.25, 0.28))
	_outline(img)
	return img


# Panier d'osier : tressage, torchon à carreaux et quelques pães de queijo.
static func paint_basket() -> Image:
	var img: Image = _img(50, 32)
	_shadow(img, 25, 29, 23, 3)
	for y in range(8, 28):
		var hw: float = 22.5 - float(y - 8) * 0.28
		for x in range(int(25.0 - hw), int(25.0 + hw) + 1):
			var c: Color = Color(0.82, 0.62, 0.36) if ((x / 2) + (y / 2)) % 2 == 0 else Color(0.66, 0.46, 0.24)
			if (y - 8) % 5 == 4:
				c = Color(0.55, 0.38, 0.2)
			if float(x) > 25.0 + hw - 3.0:
				c = c.darkened(0.15)
			_dot(img, x, y, c)
	_ellipse(img, 25, 8, 23, 6, Color(0.74, 0.54, 0.3))
	for x in range(3, 48, 2):
		_dot(img, x, 3 if absi(x - 25) < 14 else 5, Color(0.9, 0.72, 0.45))
	_ellipse(img, 25, 8, 20, 4.4, Color(0.98, 0.97, 0.94))
	for y in range(3, 14):
		for x in range(4, 47):
			var dx: float = (float(x) + 0.5 - 25.0) / 20.0
			var dy: float = (float(y) + 0.5 - 8.0) / 4.4
			if dx * dx + dy * dy <= 1.0 and ((x / 2) + (y / 2)) % 2 == 0:
				_dot(img, x, y, Color(0.85, 0.2, 0.2))
	for p: Vector2i in [Vector2i(18, 8), Vector2i(24, 7), Vector2i(30, 8), Vector2i(21, 10), Vector2i(27, 10)]:
		_ellipse(img, p.x + 0.5, p.y + 0.5, 2.6, 2.2, Color(0.93, 0.7, 0.33))
		_dot(img, p.x - 1, p.y - 1, Color(1, 0.9, 0.6))
	_outline(img)
	return img


# Lixeira à pédale en inox.
static func paint_trash() -> Image:
	var img: Image = _img(28, 38)
	_shadow(img, 14, 35, 13, 2)
	for y in range(8, 33):
		for x in range(3, 25):
			var c: Color = STEEL
			if x % 4 == 0:
				c = STEEL.darkened(0.12)
			if x <= 4:
				c = STEEL.darkened(0.22)
			elif x >= 22:
				c = STEEL.lightened(0.18)
			_dot(img, x, y, c)
	_fill(img, 3, 8, 22, 1, STEEL.darkened(0.3))
	_ellipse(img, 14, 6.5, 12, 4, STEEL.lightened(0.12))
	_ellipse(img, 13, 5.5, 7, 2, STEEL.lightened(0.3))
	_fill(img, 12, 2, 4, 2, Color(0.35, 0.35, 0.4))
	_fill(img, 9, 33, 10, 2, Color(0.3, 0.3, 0.34))
	_fill(img, 10, 18, 8, 6, Color(0.3, 0.65, 0.35))
	_fill(img, 12, 20, 4, 2, Color(0.95, 0.95, 0.9))
	_outline(img)
	return img


# Plaque de cuisson : tas d'ingrédients, puis 8 boules qui dorent et brûlent.
static func paint_tray(flags: int, step: int) -> Image:
	var img: Image = _img(46, 22)
	_fill(img, 1, 1, 44, 20, Color(0.62, 0.64, 0.68))
	_fill(img, 1, 1, 44, 1, Color(0.85, 0.87, 0.9))
	_fill(img, 3, 3, 40, 16, Color(0.38, 0.4, 0.44))
	_fill(img, 3, 3, 40, 1, Color(0.3, 0.32, 0.36))
	_fill(img, 1, 20, 44, 1, Color(0.45, 0.47, 0.5))
	if flags == 7:
		var col: Color = ball_color(step)
		for j in 2:
			for i in 4:
				var cx: int = 7 + i * 10 + j * 4
				var cy: int = 7 + j * 7
				_ball(img, cx, cy, col)
	else:
		if flags & 1:
			_ellipse(img, 10, 11, 6, 4.5, FLOUR)
			_ellipse(img, 9, 9.5, 3, 2, Color(1, 1, 1))
			_dot(img, 13, 13, Color(0.86, 0.85, 0.82))
		if flags & 2:
			_ellipse(img, 23, 11.5, 6, 4, WATER)
			_fill(img, 20, 10, 3, 1, Color(0.82, 0.93, 1))
		if flags & 4:
			_ellipse(img, 36, 11, 6, 4.5, Color(0.95, 0.82, 0.4))
			for k in 6:
				_dot(img, 33 + (k * 3) % 7, 8 + (k * 2) % 6, CHEESE.lightened(0.3))
	_outline(img)
	return img


static func ball_color(step: int) -> Color:
	match step:
		1:
			return Color(0.97, 0.8, 0.46)
		2:
			return Color(0.93, 0.68, 0.32)
		3:
			return Color(0.86, 0.57, 0.24)
		4:
			return Color(0.66, 0.4, 0.2)
		5:
			return Color(0.48, 0.28, 0.15)
		6:
			return Color(0.2, 0.15, 0.13)
	return RAW_BALL


static func _ball(img: Image, cx: int, cy: int, col: Color) -> void:
	var rows: Array[String] = [".###.", "#####", "#####", "#####", ".###."]
	for j in 5:
		for i in 5:
			if rows[j][i] == "#":
				var c: Color = col
				if j >= 3 and i >= 2:
					c = col.darkened(0.18)
				_dot(img, cx - 2 + i, cy - 2 + j, c)
	_dot(img, cx - 1, cy - 1, col.lightened(0.4))
	_dot(img, cx - 2 + 2, cy + 3, col.darkened(0.35))


# Ce que le boulanger tient en main : bol de farine, pichet d'eau, part de queijo.
static func paint_hand_item(kind: String) -> Image:
	var img: Image = _img(16, 14)
	match kind:
		"flour":
			_ellipse(img, 8, 9, 6.5, 4, Color(0.75, 0.55, 0.32))
			_fill(img, 2, 7, 13, 2, Color(0.75, 0.55, 0.32))
			_ellipse(img, 8, 6.5, 5.5, 2.6, FLOUR)
			_ellipse(img, 7, 5.5, 2.5, 1.3, Color(1, 1, 1))
		"water":
			_fill(img, 4, 3, 8, 9, WATER)
			_fill(img, 4, 3, 8, 2, WATER.lightened(0.35))
			_fill(img, 5, 5, 1, 6, Color(0.85, 0.94, 1))
			_fill(img, 12, 5, 2, 4, Color(0.3, 0.5, 0.8))
			_fill(img, 3, 2, 3, 1, WATER.darkened(0.2))
		"queijo":
			for j in 7:
				_fill(img, 3, 4 + j, 3 + j + (j / 2), 1, CHEESE if j < 5 else CHEESE.darkened(0.15))
			_fill(img, 3, 10, 11, 1, Color(0.85, 0.7, 0.35))
			_dot(img, 5, 6, Color(1, 0.97, 0.8))
	_outline(img)
	return img


# Planche du joueur en tenue de boulanger : toque et tablier peints en
# surcouche native sur la planche de l'usine (même grain, même contour).
static func baker_sheet(cfg: Dictionary) -> ImageTexture:
	var src: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	var sheet: Image = src.duplicate() as Image
	var nw: int = CharacterSpriteFactory.NAT_W
	var nh: int = CharacterSpriteFactory.NAT_H
	var sc: int = CharacterSpriteFactory.SCALE
	for dir in CharacterSpriteFactory.ROWS:
		for frame in CharacterSpriteFactory.COLS:
			var ox: int = frame * CharacterSpriteFactory.CELL_W
			var oy: int = dir * CharacterSpriteFactory.CELL_H
			var n: Image = _img(nw, nh)
			for y in nh:
				for x in nw:
					n.set_pixel(x, y, src.get_pixel(ox + x * sc + 1, oy + y * sc + 1))
			var over: Image = _img(nw, nh)
			_baker_overlay(over, dir, frame)
			for y in nh:
				for x in nw:
					var c: Color = over.get_pixel(x, y)
					if c.a > 0.0:
						n.set_pixel(x, y, c)
			# Contour du blanc là où il dépasse de la silhouette.
			for y in nh:
				for x in nw:
					if n.get_pixel(x, y).a > 0.01:
						continue
					for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var px: int = x + v.x
						var py: int = y + v.y
						if px >= 0 and py >= 0 and px < nw and py < nh and over.get_pixel(px, py).a > 0.0:
							n.set_pixel(x, y, CharacterSpriteFactory.LINE_COLOR)
							break
			for y in nh:
				for x in nw:
					sheet.fill_rect(Rect2i(ox + x * sc, oy + y * sc, sc, sc), n.get_pixel(x, y))
	return ImageTexture.create_from_image(sheet)


static func _baker_overlay(n: Image, dir: int, frame: int) -> void:
	var cloth: Color = Color(0.98, 0.98, 0.96)
	var sh: Color = Color(0.82, 0.83, 0.86)
	# Toque : bandeau sur le front, champignon bouffant au-dessus.
	var x0: int = 5 if dir != CharacterSpriteFactory.DIR_RIGHT else 6
	var x1: int = 15 if dir != CharacterSpriteFactory.DIR_RIGHT else 14
	_fill(n, x0 + 1, 0, x1 - x0 - 1, 1, cloth)
	_fill(n, x0, 1, x1 - x0 + 1, 3, cloth)
	_fill(n, x0, 3, x1 - x0 + 1, 1, sh)
	_fill(n, x0 + 1, 4, x1 - x0 - 1, 2, cloth)
	_fill(n, x0 + 1, 5, x1 - x0 - 1, 1, sh)
	_dot(n, x0 + 2, 1, Color(1, 1, 1))
	# Tablier.
	if dir == CharacterSpriteFactory.DIR_DOWN:
		_fill(n, 8, 16, 5, 3, cloth)
		_fill(n, 7, 19, 7, 7, cloth)
		_fill(n, 7, 25, 7, 1, sh)
		_fill(n, 13, 19, 1, 7, sh)
		_fill(n, 9, 21, 3, 2, Color(0.88, 0.88, 0.9))
	elif dir == CharacterSpriteFactory.DIR_UP:
		_fill(n, 6, 20, 9, 1, cloth)
		_dot(n, 10, 21, cloth)
		_dot(n, 9, 22, cloth)
		_dot(n, 11, 22, cloth)
	else:
		var sway: int = 1 if frame == 1 else 0
		_fill(n, 12, 17, 2, 3, cloth)
		_fill(n, 12 + sway, 20, 3, 6, cloth)
		_fill(n, 12 + sway, 25, 3, 1, sh)
		_fill(n, 7, 20, 5, 1, cloth)
