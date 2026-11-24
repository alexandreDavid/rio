extends Node2D

# Rendu de la cuisine de la padaria (aucune règle ici) : pièce peinte
# (PadariaArt), comptoirs par case de grille (inox, bancadas en bois, caisses
# d'ingrédients, chapa, lixo, balcão), four en briques, objets posés,
# boulanger en tenue, fregueses qui font la fila au balcão. Natifs ×3, NEAREST.

const ART := preload("res://scripts/minigames/padaria/PadariaArt.gd")

const D: int = 3
const N: int = 32  # une case = 32 px natifs
const INK: Color = Color(0.13, 0.10, 0.12)
const STEEL: Color = Color(0.74, 0.76, 0.80)
const WOOD: Color = Color(0.80, 0.60, 0.38)
const CRATE: Color = Color(0.62, 0.42, 0.24)
const DOOR_IN: Vector2 = Vector2(1809, 300)
const CUSTOMER_SPEED: float = 260.0

static var _items: Dictionary = {}

var _game: Node = null
var _player: Sprite2D = null
var _carry: Sprite2D = null
var _walk_t: float = 0.0
var _last_pos: Vector2 = Vector2.INF
var _cell_sprites: Dictionary = {}   # Vector2i → Sprite2D
var _cell_cache: Dictionary = {}     # Vector2i → objet affiché
var _overlay: Node2D = null
var _customers: Dictionary = {}      # id commande → {spr, pos, leaving, angry, walk}
var _seed: int = 7100
var _t: float = 0.0
var _puffs: Array = []


func build(game: Node) -> void:
	_game = game
	var room: Sprite2D = _sprite(ImageTexture.create_from_image(ART.paint_room()), Vector2(ART.VIEW_L, 0))
	room.z_index = -10
	add_child(room)
	var vit: Sprite2D = _foot_sprite(ImageTexture.create_from_image(ART.paint_vitrine()), Vector2(1640, 1040))
	vit.z_index = -2
	add_child(vit)
	var tiles: Sprite2D = _sprite(ImageTexture.create_from_image(_paint_counters()), game.ORIGIN)
	tiles.z_index = -6
	add_child(tiles)
	# Four en briques posé sur ses deux cases, adossé au mur.
	var oven_cells: Array = _cells_of("O")
	if not oven_cells.is_empty():
		var a: Vector2 = game.cell_center(oven_cells[0])
		var b: Vector2 = game.cell_center(oven_cells[oven_cells.size() - 1])
		var oven: Sprite2D = Sprite2D.new()
		oven.texture = ImageTexture.create_from_image(ART.paint_oven())
		oven.centered = false
		oven.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		oven.scale = Vector2(2, 2)
		oven.offset = Vector2(-ART.OVEN_W / 2.0, -float(ART.OVEN_H))
		oven.position = Vector2((a.x + b.x) * 0.5, a.y + 44.0)
		oven.z_index = -5
		add_child(oven)
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	_player = Sprite2D.new()
	_player.texture = ART.baker_sheet(cfg)
	_player.region_enabled = true
	_player.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5 + 8)
	_player.z_index = 2
	add_child(_player)
	_carry = Sprite2D.new()
	_carry.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carry.scale = Vector2(D, D)
	_carry.z_index = 3
	add_child(_carry)
	_add_station_labels()
	_overlay = Node2D.new()
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


# Noms des postes sur la façade des comptoirs : on sait où est quoi.
func _add_station_labels() -> void:
	var names: Dictionary = {"P": "POLVILHO", "F": "FARINHA", "Q": "QUEIJO", "A": "ÁGUA",
		"K": "BANCADA", "O": "FORNO", "G": "CHAPA", "T": "LIXO", "S": "BALCÃO"}
	for k: String in names:
		var cs: Array = _cells_of(k)
		if cs.is_empty():
			continue
		# Une étiquette par groupe : au milieu des cases (le balcão : en haut).
		var a: Vector2 = _game.cell_center(cs[0])
		var b: Vector2 = _game.cell_center(cs[cs.size() - 1])
		var at: Vector2 = (a + b) * 0.5 + Vector2(0, 30)
		if k == "S":
			at = a + Vector2(0, -60)
		elif k == "F" or k == "A":
			# Caisses voisines : une étiquette sur deux passe au-dessus.
			at = a + Vector2(0, -62)
		elif k == "T":
			at = a + Vector2(0, 46)
		var l: Label = Label.new()
		l.text = names[k]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(160, 20)
		l.position = at - Vector2(80, 10)
		l.add_theme_font_size_override("font_size", 11)
		l.z_index = 4
		add_child(l)
		PixelFont.style_world_label(l)


func _cells_of(k: String) -> Array:
	var out: Array = []
	for r in _game.GRID.size():
		for c in String(_game.GRID[r]).length():
			if String(_game.GRID[r])[c] == k:
				out.append(Vector2i(c, r))
	return out


func _sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(D, D)
	s.position = pos
	return s


func _foot_sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s: Sprite2D = _sprite(tex, pos)
	s.offset = Vector2(-float(tex.get_width() / 2), -float(tex.get_height()))
	return s


# --- Boucle ---

func tick(game: Node, delta: float) -> void:
	_t += delta
	_tick_player(game, delta)
	_tick_cells(game)
	_tick_customers(game, delta)
	_tick_smoke(game, delta)
	_overlay.queue_redraw()


func _tick_player(game: Node, delta: float) -> void:
	var p: Vector2 = game.player_pos
	var moved: bool = _last_pos != Vector2.INF and p.distance_to(_last_pos) > 0.5
	_last_pos = p
	var f: Vector2 = game.facing
	var row: int = CharacterSpriteFactory.DIR_DOWN
	var flip: bool = false
	if absf(f.x) > absf(f.y):
		row = CharacterSpriteFactory.DIR_RIGHT
		flip = f.x < 0.0
	elif f.y < 0.0:
		row = CharacterSpriteFactory.DIR_UP
	var frame: int = 0
	if moved:
		_walk_t += delta
		frame = 1 + int(_walk_t / 0.13) % 2
	elif bool(game.kneading):
		frame = 1 + int(_t / 0.12) % 2
	_player.position = p.snapped(Vector2(D, D))
	_player.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_player.flip_h = flip
	var h: String = game.hand
	_carry.visible = h != ""
	if h != "":
		_carry.texture = item_texture(h)
		var front: Vector2 = Vector2(0, -42)
		if row == CharacterSpriteFactory.DIR_RIGHT:
			front = Vector2(30 if not flip else -30, -40)
		elif row == CharacterSpriteFactory.DIR_UP:
			front = Vector2(0, -52)
		_carry.position = (p + front).snapped(Vector2(D, D))
		# De dos, le plat passe derrière le boulanger.
		_carry.z_index = 1 if row == CharacterSpriteFactory.DIR_UP else 3


func _tick_cells(game: Node) -> void:
	var cells: Dictionary = game.cells
	for c: Vector2i in cells.keys():
		var item: String = cells[c]
		if _cell_cache.get(c, "") == item:
			continue
		_cell_cache[c] = item
		var spr: Sprite2D = _cell_sprites.get(c)
		if spr == null:
			spr = Sprite2D.new()
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(D, D)
			spr.z_index = -4
			add_child(spr)
			_cell_sprites[c] = spr
		spr.visible = item != "" and game.kind_at(c) != "O"
		if item != "":
			spr.texture = item_texture(item)
			spr.position = game.cell_center(c) + Vector2(0, -14)


func _tick_customers(game: Node, delta: float) -> void:
	var ids: Dictionary = {}
	var slot: int = 0
	for o in game.orders:
		ids[int(o["id"])] = slot
		if not _customers.has(int(o["id"])):
			_seed += 37
			var spr: Sprite2D = Sprite2D.new()
			spr.texture = CharacterSpriteFactory.build_sheet(CharacterSpriteFactory.random_config(_seed))
			spr.region_enabled = true
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5 + 8)
			spr.z_index = 1
			spr.modulate.a = 0.0
			add_child(spr)
			_customers[int(o["id"])] = {"spr": spr, "pos": DOOR_IN, "leaving": false, "walk": 0.0, "kind": o["kind"]}
		slot += 1
	for id: int in _customers.keys():
		var cu: Dictionary = _customers[id]
		var spr: Sprite2D = cu["spr"]
		if not ids.has(id) and not cu["leaving"]:
			cu["leaving"] = true
		var tgt: Vector2 = DOOR_IN
		if not cu["leaving"]:
			var s: int = ids[id]
			var bal: Vector2 = game.cell_center(Vector2i(12, 1 + s))
			tgt = bal + Vector2(102, 40)
		var pos: Vector2 = cu["pos"]
		var to: Vector2 = tgt - pos
		var row: int = CharacterSpriteFactory.DIR_RIGHT
		var flip: bool = true
		var frame: int = 0
		if to.length() > 3.0:
			var step: Vector2 = to.limit_length(CUSTOMER_SPEED * delta)
			pos += step
			cu["walk"] = float(cu["walk"]) + delta
			frame = 1 + int(float(cu["walk"]) / 0.15) % 2
			if absf(step.x) > absf(step.y):
				flip = step.x < 0.0
			else:
				row = CharacterSpriteFactory.DIR_DOWN if step.y > 0.0 else CharacterSpriteFactory.DIR_UP
				flip = false
		else:
			pos = tgt
		cu["pos"] = pos
		spr.position = pos.snapped(Vector2(D, D))
		spr.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		spr.flip_h = flip
		if cu["leaving"] and to.length() <= 3.0:
			spr.modulate.a = maxf(spr.modulate.a - delta * 3.0, 0.0)
			if spr.modulate.a <= 0.0:
				spr.queue_free()
				_customers.erase(id)
		elif spr.modulate.a < 1.0:
			spr.modulate.a = minf(spr.modulate.a + delta * 3.0, 1.0)


# Fumée au-dessus d'un four ou d'une chapa qui surcuit.
func _tick_smoke(game: Node, delta: float) -> void:
	for c: Vector2i in game.cells.keys():
		var k: String = game.kind_at(c)
		if k != "O" and k != "G":
			continue
		var it: String = game.cells[c]
		if it == "":
			continue
		var ready_at: float = game.OVEN_BAKE if k == "O" else game.CHAPA_COOK
		var cook: float = float(game.progress.get(c, 0.0))
		if (it == "queimado" or cook > ready_at + 2.0) and randf() < delta * (9.0 if it == "queimado" else 4.0):
			_puffs.append({"p": game.cell_center(c) + Vector2(randf_range(-24, 24), -40 - (60 if k == "O" else 0)), "age": 0.0, "dark": it == "queimado"})
	for pf in _puffs:
		pf["age"] = float(pf["age"]) + delta
		pf["p"] = (pf["p"] as Vector2) + Vector2(sin(float(pf["age"]) * 4.0) * 12.0, -50.0) * delta
	_puffs = _puffs.filter(func(pf: Dictionary) -> bool: return float(pf["age"]) < 1.4)


func _draw_overlay() -> void:
	var g: Node = _game
	for pf in _puffs:
		var a: float = 1.0 - float(pf["age"]) / 1.4
		var col: Color = Color(0.2, 0.18, 0.18, 0.7 * a) if pf["dark"] else Color(0.9, 0.9, 0.9, 0.55 * a)
		var r: float = 9.0 + float(pf["age"]) * 14.0
		_overlay.draw_rect(Rect2((pf["p"] as Vector2) - Vector2(r, r), Vector2(r * 2, r * 2)).abs(), col)
	# Jauges : sova sur les bancadas, cuisson au four et à la chapa.
	for c: Vector2i in g.cells.keys():
		var k: String = g.kind_at(c)
		var it: String = g.cells[c]
		var top: Vector2 = g.cell_center(c) + Vector2(-40, -62)
		if k == "K" and g.progress.has(c):
			_bar(top, float(g.progress[c]), Color(0.95, 0.85, 0.4))
		elif (k == "O" or k == "G") and it != "" and it != "queimado":
			var ready_at: float = g.OVEN_BAKE if k == "O" else g.CHAPA_COOK
			var burn_at: float = g.OVEN_BURN if k == "O" else g.CHAPA_BURN
			var cook: float = float(g.progress.get(c, 0.0))
			if k == "O":
				top.y -= 70.0
			if cook < ready_at:
				_bar(top, cook / ready_at, Color(0.55, 0.85, 0.95))
			else:
				var danger: float = (cook - ready_at) / (burn_at - ready_at)
				var col: Color = Color(0.5, 0.95, 0.5) if danger < 0.5 else Color(1.0, 0.35, 0.25)
				if danger >= 0.5 and int(_t * 6.0) % 2 == 0:
					col = Color(1, 0.9, 0.3)
				_bar(top, 1.0 - danger, col)
				# Ce qui est prêt dans le four se voit au-dessus de la bouche.
				if k == "O":
					var tex: Texture2D = item_texture(it)
					_overlay.draw_texture_rect(tex, Rect2(top + Vector2(16, -54), Vector2(48, 48)), false)
	# Case visée.
	var t: Vector2i = g.target
	if g.kind_at(t) != "." and g.kind_at(t) != "X" and bool(g.started):
		var r: Rect2 = Rect2(g.ORIGIN + Vector2(t) * g.CELL, Vector2(g.CELL, g.CELL)).grow(-3)
		var pulse_a: float = 0.65 + 0.35 * sin(_t * 8.0)
		var col2: Color = Color(1.0, 0.88, 0.3, pulse_a)
		for i in 3:
			_overlay.draw_rect(r.grow(-i), col2, false, 1.0)
		_overlay.draw_rect(Rect2(r.position, Vector2(18, 6)), col2)
		_overlay.draw_rect(Rect2(r.position, Vector2(6, 18)), col2)
		_overlay.draw_rect(Rect2(r.end - Vector2(18, 6), Vector2(18, 6)), col2)
		_overlay.draw_rect(Rect2(r.end - Vector2(6, 18), Vector2(6, 18)), col2)
	# Flèche du guidage : le poste à utiliser maintenant.
	var hc: Vector2i = g.hint_cell
	if hc.x >= 0 and bool(g.started):
		var tip: Vector2 = g.cell_center(hc) + Vector2(0, -58 - (92 if g.kind_at(hc) == "O" else 0))
		tip.y -= snappedf(absf(sin(_t * 5.0)) * 16.0, D)
		_overlay.draw_colored_polygon(PackedVector2Array([tip + Vector2(-27, -33), tip + Vector2(27, -33), tip]), INK)
		_overlay.draw_colored_polygon(PackedVector2Array([tip + Vector2(-19, -28), tip + Vector2(19, -28), tip + Vector2(0, -7)]), Color(1, 0.86, 0.3))
	# Bulle de commande au-dessus de chaque freguesa arrivée.
	for o in g.orders:
		var cu: Dictionary = _customers.get(int(o["id"]), {})
		if cu.is_empty() or cu["leaving"]:
			continue
		var head: Vector2 = (cu["pos"] as Vector2) + Vector2(70, -66)
		_overlay.draw_rect(Rect2(head - Vector2(33, 30), Vector2(66, 60)), INK)
		_overlay.draw_rect(Rect2(head - Vector2(30, 27), Vector2(60, 54)), Color(1, 0.98, 0.92))
		_overlay.draw_texture_rect(item_texture(o["kind"]), Rect2(head - Vector2(24, 24), Vector2(48, 48)), false)


func _bar(at: Vector2, v: float, col: Color) -> void:
	var r: Rect2 = Rect2(at, Vector2(80, 12))
	_overlay.draw_rect(r.grow(3), INK)
	_overlay.draw_rect(r, Color(0.25, 0.22, 0.22))
	_overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)


# --- Comptoirs peints ---

func _paint_counters() -> Image:
	var rows: int = _game.GRID.size()
	var cols: int = String(_game.GRID[0]).length()
	var img: Image = ART._img(cols * N, rows * N + 4)
	for r in rows:
		for c in cols:
			var k: String = String(_game.GRID[r])[c]
			if k == ".":
				continue
			_paint_cell(img, c * N, r * N, k, Vector2i(c, r))
	ART._outline(img)
	return img


func _solid(cell: Vector2i) -> bool:
	var k: String = _game.kind_at(cell)
	return k != "." and k != "X"


func _paint_cell(img: Image, x: int, y: int, k: String, cell: Vector2i) -> void:
	var top_c: Color = STEEL
	var front_c: Color = Color(0.56, 0.58, 0.62)
	match k:
		"K":
			top_c = WOOD.lightened(0.08)
			front_c = WOOD.darkened(0.3)
		"S":
			top_c = Color(0.86, 0.66, 0.44)
			front_c = Color(0.72, 0.2, 0.18)
		"O":
			top_c = Color(0.30, 0.22, 0.20)
			front_c = Color(0.62, 0.30, 0.20)
		"G":
			top_c = Color(0.22, 0.22, 0.25)
			front_c = Color(0.48, 0.50, 0.54)
		"P", "F", "Q", "A":
			top_c = CRATE
			front_c = CRATE.darkened(0.3)
	var below_open: bool = not _solid(cell + Vector2i(0, 1))
	var top_h: int = 24 if below_open else N
	ART._fill(img, x, y, N, top_h, top_c)
	# Joints entre cases et liseré éclairé.
	ART._fill(img, x, y, N, 1, top_c.lightened(0.22))
	if not _solid(cell + Vector2i(-1, 0)):
		ART._fill(img, x, y, 1, top_h, top_c.lightened(0.15))
	if _solid(cell + Vector2i(1, 0)):
		ART._fill(img, x + N - 1, y + 2, 1, top_h - 3, top_c.darkened(0.12))
	if below_open:
		ART._fill(img, x, y + 24, N, N - 24 + 4, front_c)
		ART._fill(img, x, y + 24, N, 1, front_c.lightened(0.25))
		ART._fill(img, x, y + N + 3, N, 1, front_c.darkened(0.3))
	match k:
		"#":
			for i in 5:
				ART._dot(img, x + 4 + i * 6, y + 6 + (i % 2) * 9, top_c.lightened(0.18))
			if below_open:
				ART._fill(img, x + 13, y + 28, 6, 1, front_c.darkened(0.3))
		"K":
			# Bancada de madeira : veines et farine.
			for yy in range(y + 3, y + top_h - 2, 4):
				ART._fill(img, x + 1, yy, N - 2, 1, top_c.darkened(0.08))
			for i in 14:
				ART._dot(img, x + 3 + (i * 7) % 27, y + 4 + (i * 5) % 17, Color(1, 1, 0.96))
		"S":
			ART._fill(img, x + 2, y + 3, N - 4, 3, top_c.lightened(0.15))
			if below_open:
				ART._fill(img, x, y + 28, N, 2, Color(0.95, 0.93, 0.88))
		"G":
			for xx in range(x + 3, x + N - 3, 4):
				ART._fill(img, xx, y + 4, 2, top_h - 8, Color(0.36, 0.36, 0.40))
			ART._fill(img, x + 2, y + 2, N - 4, 1, Color(0.5, 0.5, 0.55))
			if below_open:
				ART._fill(img, x + 6, y + 27, 3, 3, INK)
				ART._fill(img, x + 22, y + 27, 3, 3, INK)
		"O":
			if below_open:
				for yy in range(y + 25, y + N + 3, 3):
					for xx in range(x + ((yy / 3) % 2) * 3, x + N, 6):
						ART._fill(img, xx, yy, 5, 2, front_c.lightened(0.08))
		"T":
			var bin: Image = ART.paint_trash()
			img.blend_rect(bin, Rect2i(Vector2i.ZERO, bin.get_size()), Vector2i(x + 2, y - 8))
		"P", "F", "Q", "A":
			# Caisse ouverte remplie de l'ingrédient, icône par-dessus.
			ART._fill(img, x + 2, y + 2, N - 4, top_h - 4, CRATE.darkened(0.45))
			var fill: Color = {"P": Color(0.98, 0.98, 0.97), "F": Color(0.92, 0.86, 0.7),
				"Q": Color(0.97, 0.88, 0.5), "A": Color(0.45, 0.7, 0.95)}[k]
			ART._fill(img, x + 4, y + 4, N - 8, top_h - 8, fill)
			for i in 8:
				ART._dot(img, x + 5 + (i * 7) % 22, y + 5 + (i * 3) % 13, fill.darkened(0.1))
			var icon: Image = paint_item({"P": "polvilho", "F": "farinha", "Q": "queijo", "A": "agua"}[k])
			img.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(x + 8, y + 4))


# --- Objets ---

static func item_texture(kind: String) -> Texture2D:
	if not _items.has(kind):
		_items[kind] = ImageTexture.create_from_image(paint_item(kind))
	return _items[kind]


static func paint_item(kind: String) -> Image:
	var img: Image = ART._img(16, 16)
	var dough: Color = Color(0.96, 0.9, 0.74)
	var gold: Color = Color(0.9, 0.62, 0.28)
	match kind:
		"polvilho":
			_bag(img, Color(0.98, 0.98, 0.97), Color(0.25, 0.45, 0.8))
		"farinha":
			_bag(img, Color(0.86, 0.78, 0.6), Color(0.75, 0.25, 0.2))
		"queijo":
			img = ART.paint_hand_item("queijo")
		"agua":
			img = ART.paint_hand_item("water")
		"mix_pq":
			_bowl(img, Color(0.98, 0.96, 0.9), Color(0.97, 0.85, 0.4))
		"mix_pf":
			_bowl(img, Color(0.9, 0.84, 0.68), Color(0.6, 0.8, 0.98))
		"pq_cru", "pq":
			ART._fill(img, 1, 9, 14, 5, Color(0.55, 0.57, 0.62))
			ART._fill(img, 1, 9, 14, 1, Color(0.82, 0.84, 0.88))
			var col: Color = ART.ball_color(0 if kind == "pq_cru" else 2)
			for p: Vector2i in [Vector2i(4, 8), Vector2i(8, 7), Vector2i(12, 8), Vector2i(6, 11), Vector2i(10, 11)]:
				ART._ellipse(img, p.x + 0.5, p.y + 0.5, 2.4, 2.0, col)
				ART._dot(img, p.x - 1, p.y - 1, col.lightened(0.35))
		"pf_cru", "pf":
			var c2: Color = dough if kind == "pf_cru" else gold
			ART._ellipse(img, 8, 9, 7, 4, c2)
			ART._ellipse(img, 7, 8, 5, 2, c2.lightened(0.18))
			ART._fill(img, 6, 6, 4, 1, c2.darkened(0.25) if kind == "pf" else c2.darkened(0.12))
			ART._fill(img, 9, 8, 3, 1, c2.darkened(0.2))
		"misto_cru", "misto":
			var bread: Color = gold if kind == "misto_cru" else Color(0.78, 0.48, 0.2)
			ART._fill(img, 2, 5, 12, 3, bread)
			ART._fill(img, 1, 8, 14, 2, Color(0.98, 0.84, 0.3))
			ART._fill(img, 2, 10, 12, 3, bread)
			if kind == "misto":
				for xx in range(3, 13, 3):
					ART._fill(img, xx, 5, 1, 3, bread.darkened(0.35))
				ART._dot(img, 13, 9, Color(1, 0.9, 0.4))
				ART._dot(img, 2, 10, Color(1, 0.9, 0.4))
		"queimado":
			ART._ellipse(img, 8, 10, 6.5, 4, Color(0.16, 0.12, 0.11))
			ART._ellipse(img, 7, 9, 3, 1.6, Color(0.3, 0.24, 0.2))
			ART._dot(img, 5, 4, Color(0.45, 0.45, 0.45))
			ART._dot(img, 9, 2, Color(0.45, 0.45, 0.45))
	if img.get_size() != Vector2i(16, 16):
		var sq: Image = ART._img(16, 16)
		sq.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, 16 - img.get_height()))
		return sq
	ART._outline(img)
	return img


static func _bag(img: Image, cloth: Color, band: Color) -> void:
	ART._fill(img, 3, 4, 10, 10, cloth)
	ART._fill(img, 4, 2, 8, 2, cloth.darkened(0.08))
	ART._fill(img, 5, 1, 6, 1, cloth.darkened(0.2))
	ART._fill(img, 3, 8, 10, 2, band)
	ART._fill(img, 12, 4, 1, 10, cloth.darkened(0.15))
	ART._dot(img, 5, 5, cloth.lightened(0.3))


static func _bowl(img: Image, a: Color, b: Color) -> void:
	ART._ellipse(img, 8, 10, 7, 4.5, Color(0.72, 0.5, 0.3))
	ART._fill(img, 1, 8, 15, 2, Color(0.72, 0.5, 0.3))
	ART._ellipse(img, 8, 7.5, 6, 2.8, a)
	ART._ellipse(img, 10, 7, 2.5, 1.4, b)
	ART._dot(img, 5, 6, a.lightened(0.3))
