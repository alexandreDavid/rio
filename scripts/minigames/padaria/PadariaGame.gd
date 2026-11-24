class_name PadariaGame
extends MinigameBase

# Rush du matin à la Padaria São Sebastião : cuisine en grille, comptoirs qui
# bloquent, commandes chronométrées au balcão. Un objet en main ; on pose et
# reprend sur n'importe quel comptoir, deux ingrédients compatibles s'y
# assemblent. Recettes :
#   pão de queijo : polvilho + queijo → sovar (bancada) → forno
#   pão francês   : farinha + água    → sovar (bancada) → forno
#   misto quente  : pão francês + queijo → chapa
# PEGAR/LARGAR = prendre, poser, assembler, servir ; SOVAR (tenu) = pétrir.

signal match_ended(qualifies: bool, tips: int)

const KitchenArt := preload("res://scripts/minigames/padaria/PadariaKitchenArt.gd")

const DURATION: float = 150.0
const CELL: float = 96.0
const ORIGIN: Vector2 = Vector2(48, 240)
# . sol · # comptoir · P polvilho · F farinha · Q queijo · A água · K bancada
# O forno · G chapa · T lixo · S balcão (service)
const GRID: Array[String] = [
	"#PFQA#KK#OO##",
	"#...........S",
	"#...........S",
	"T...##G#....S",
	"#...........S",
	"#...........S",
	"#############",
]
const CRATES: Dictionary = {"P": "polvilho", "F": "farinha", "Q": "queijo", "A": "agua"}

const PLAYER_RADIUS: float = 26.0
const PLAYER_SPEED: float = 420.0
const REACH: float = 110.0

const KNEAD_TIME: float = 2.2
const OVEN_BAKE: float = 7.0
const OVEN_BURN: float = 16.0
const CHAPA_COOK: float = 4.0
const CHAPA_BURN: float = 11.0

# Deux objets posés l'un sur l'autre (ordre indifférent) → résultat.
const MERGE: Dictionary = {
	"polvilho+queijo": "mix_pq",
	"agua+farinha": "mix_pf",
	"pf+queijo": "misto_cru",
}
const KNEAD: Dictionary = {"mix_pq": "pq_cru", "mix_pf": "pf_cru"}
const OVEN_IN: Dictionary = {"pq_cru": "pq", "pf_cru": "pf"}
const CHAPA_IN: Dictionary = {"misto_cru": "misto"}

const ORDER_KINDS: Array[String] = ["pq", "pf", "misto"]
# Guidage : produit fini ← cuisson ← sova (bancada) ← assemblage de deux parts.
const GUIDE: Dictionary = {
	"pq": {"raw": "pq_cru", "station": "O", "mix": "mix_pq", "parts": ["polvilho", "queijo"]},
	"pf": {"raw": "pf_cru", "station": "O", "mix": "mix_pf", "parts": ["farinha", "agua"]},
	"misto": {"raw": "misto_cru", "station": "G", "mix": "", "parts": ["pf", "queijo"]},
}
const CRATE_OF: Dictionary = {"polvilho": "P", "farinha": "F", "queijo": "Q", "agua": "A"}
const PATIENCE: Dictionary = {"pq": 60.0, "pf": 60.0, "misto": 85.0}
const TIP: Dictionary = {"pq": 9, "pf": 7, "misto": 14}
const TIP_SPEED_BONUS: int = 6
const MAX_ORDERS: int = 4
# Écart entre deux fregueses : assez serré pour obliger à mener deux recettes
# de front (un bot qui enchaîne une commande à la fois en perd).
const ORDER_GAP_MIN: float = 11.0
const ORDER_GAP_MAX: float = 15.0
# Étoiles au bilan (R$ gagnés) ; 2 étoiles = service réussi.
const STARS: Array[int] = [25, 55, 100]
const QUALIFY_STARS: int = 2

const NAMES: Dictionary = {
	"polvilho": "polvilho", "farinha": "farinha", "queijo": "queijo", "agua": "água",
	"mix_pq": "massa de pão de queijo", "mix_pf": "massa de pão", "pq_cru": "pão de queijo cru",
	"pf_cru": "pão cru", "pq": "pão de queijo", "pf": "pão francês", "misto_cru": "misto cru",
	"misto": "misto quente", "queimado": "queimado",
}

var cells: Dictionary = {}       # Vector2i → objet posé ("" = vide)
var progress: Dictionary = {}    # Vector2i → sova (0..1) ou cuisson (s)
var hand: String = ""
var player_pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var target: Vector2i = Vector2i(-1, -1)
var orders: Array = []           # {id, kind, left, max}
var tips: int = 0
var served: int = 0
var lost: int = 0
var kneading: bool = false
var time_left: float = DURATION
var started: bool = false
# Prochaine action conseillée (texte + poste fléché).
var hint_text: String = ""
var hint_cell: Vector2i = Vector2i(-1, -1)
var _hint_wait: bool = false

## Captures hors jeu : "play" saute la carte des recettes ; "busy" pose une
## cuisine en plein rush (four, chapa, bancada, commandes).
@export var preview: String = ""

var _ended: bool = false
var _next_order: float = 1.0
var _order_seq: int = 0
var _elapsed: float = 0.0
var _art: Node2D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fingers: Dictionary = {}
var _btn_a_held: bool = false
var _btn_b_held: bool = false
var _key_a_held: bool = false
var _key_b_held: bool = false
var _a_was: bool = false
var _status_t: float = 0.0

var _ui: CanvasLayer = null
var _btn_a: Button = null
var _btn_b: Button = null
var _clock: Label = null
var _money: Label = null
var _status: Label = null
var _tickets: HBoxContainer = null
var _intro: Control = null
var _hint_label: Label = null


func _ready() -> void:
	EventBus.minigame_started.emit("padaria")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
		# Cadré sur la cuisine et la fila : personnages lisibles au téléphone.
		cam.zoom = Vector2(1.25, 1.25)
		cam.position = Vector2(760, 566)
	for r in GRID.size():
		for c in GRID[r].length():
			var ch: String = GRID[r][c]
			if ch != "." and not CRATES.has(ch):
				cells[Vector2i(c, r)] = ""
	player_pos = cell_center(Vector2i(6, 2))
	_art = KitchenArt.new()
	add_child(_art)
	_art.call("build", self)
	_build_ui()
	if preview != "":
		_apply_preview.call_deferred()


# --- Grille ---

func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func cell_at(p: Vector2) -> Vector2i:
	var q: Vector2 = (p - ORIGIN) / CELL
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


func kind_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= GRID.size() or c.x < 0 or c.x >= GRID[c.y].length():
		return "X"
	return GRID[c.y][c.x]


func _solid(c: Vector2i) -> bool:
	return kind_at(c) != "."


# --- Boucle ---

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if _art:
		_art.call("tick", self, delta)
	if _ended or not started:
		_update_hud()
		return
	_elapsed += delta
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_game()
		return
	_move(delta)
	_find_target()
	_read_buttons(delta)
	_cook(delta)
	_tick_orders(delta)
	_compute_hint()
	_update_hud()


func _move(delta: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if dir.length() > 0.2:
		facing = dir.normalized()
	var step: Vector2 = dir.limit_length(1.0) * PLAYER_SPEED * delta
	# Axe par axe : on glisse le long des comptoirs au lieu de s'y coller.
	player_pos.x += step.x
	_resolve(true)
	player_pos.y += step.y
	_resolve(false)


func _resolve(x_axis: bool) -> void:
	var c0: Vector2i = cell_at(player_pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = c0 + Vector2i(dx, dy)
			if not _solid(c):
				continue
			var r: Rect2 = Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL))
			var nearest: Vector2 = Vector2(clampf(player_pos.x, r.position.x, r.end.x), clampf(player_pos.y, r.position.y, r.end.y))
			var d: Vector2 = player_pos - nearest
			if d.length() >= PLAYER_RADIUS:
				continue
			if x_axis:
				player_pos.x = (r.position.x - PLAYER_RADIUS) if player_pos.x < r.get_center().x else (r.end.x + PLAYER_RADIUS)
			else:
				player_pos.y = (r.position.y - PLAYER_RADIUS) if player_pos.y < r.get_center().y else (r.end.y + PLAYER_RADIUS)


# Poste visé : le plus proche dans la direction du regard (tolérant au doigt).
func _find_target() -> void:
	var best: Vector2i = Vector2i(-1, -1)
	var best_s: float = -INF
	var c0: Vector2i = cell_at(player_pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = c0 + Vector2i(dx, dy)
			var k: String = kind_at(c)
			if k == "." or k == "X":
				continue
			var r: Rect2 = Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL))
			var nearest: Vector2 = Vector2(clampf(player_pos.x, r.position.x, r.end.x), clampf(player_pos.y, r.position.y, r.end.y))
			var dist: float = player_pos.distance_to(nearest)
			if dist > REACH - PLAYER_RADIUS:
				continue
			var to: Vector2 = (cell_center(c) - player_pos).normalized()
			var s: float = facing.dot(to) * 2.0 - dist / 60.0
			if s > best_s:
				best_s = s
				best = c
	target = best


# --- Commandes du joueur ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_fingers[st.index] = st.position
		else:
			_fingers.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _fingers.has(sd.index):
			_fingers[sd.index] = sd.position
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_fingers[-1] = mb.position
			else:
				_fingers.erase(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _fingers.has(-1):
			_fingers[-1] = (event as InputEventMouseMotion).position
	elif event.is_action("interact") and not event.is_echo():
		_key_a_held = event.is_pressed()
	elif event.is_action("jump") and not event.is_echo():
		_key_b_held = event.is_pressed()
	_btn_a_held = _held(_btn_a)
	_btn_b_held = _held(_btn_b)


func _held(btn: Button) -> bool:
	if btn == null or not btn.is_visible_in_tree():
		return false
	var rect: Rect2 = btn.get_global_rect()
	var on: bool = false
	for f in _fingers.values():
		if rect.has_point(f as Vector2):
			on = true
	btn.button_pressed = on
	return on


func _read_buttons(delta: float) -> void:
	var a: bool = _btn_a_held or _key_a_held
	if a and not _a_was:
		interact()
	_a_was = a
	kneading = false
	if _btn_b_held or _key_b_held:
		work(delta)


# PEGAR / LARGAR sur le poste visé.
func interact() -> void:
	var t: Vector2i = target
	var k: String = kind_at(t)
	if k == "." or k == "X":
		return
	if CRATES.has(k):
		if hand == "":
			hand = CRATES[k]
			sfx("item_pickup")
		elif hand == CRATES[k]:
			hand = ""
			sfx("cart_drop", 1.2)
		else:
			_say("Mãos ocupadas : pose d'abord.")
		return
	match k:
		"T":
			if hand != "":
				_say("Jogou fora : " + String(NAMES.get(hand, hand)))
				hand = ""
				sfx("mg_drop", 0.8)
		"S":
			_serve()
		"O", "G":
			_station_swap(t, OVEN_IN if k == "O" else CHAPA_IN)
		_:
			_counter_swap(t)


func _counter_swap(t: Vector2i) -> void:
	var on: String = cells.get(t, "")
	if hand == "" and on != "":
		hand = on
		cells[t] = ""
		progress.erase(t)
		sfx("item_pickup")
	elif hand != "" and on == "":
		cells[t] = hand
		hand = ""
		progress.erase(t)
		sfx("cart_drop")
	elif hand != "" and on != "":
		var m: String = merge(hand, on)
		if m == "":
			_say("Isso não combina.")
			sfx("mg_miss", 1.3)
			return
		cells[t] = m
		hand = ""
		progress.erase(t)
		sfx("mg_good")
		_say(_cap(NAMES[m]) + (" — sova na bancada !" if KNEAD.has(m) else ""))


func _station_swap(t: Vector2i, accepts: Dictionary) -> void:
	var on: String = cells.get(t, "")
	if hand == "" and on != "":
		hand = on
		cells[t] = ""
		progress.erase(t)
		sfx("item_pickup")
	elif hand != "" and on == "":
		if not accepts.has(hand):
			_say("Isso não vai " + ("no forno." if kind_at(t) == "O" else "na chapa."))
			sfx("mg_miss", 1.3)
			return
		cells[t] = hand
		progress[t] = 0.0
		hand = ""
		sfx("cart_drop", 0.8)


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func merge(a: String, b: String) -> String:
	var key: String = (a + "+" + b) if a < b else (b + "+" + a)
	return MERGE.get(key, "")


# SOVAR (tenu) : la massa avance tant qu'on tient face à la bancada.
func work(delta: float) -> void:
	var t: Vector2i = target
	if kind_at(t) != "K":
		return
	var on: String = cells.get(t, "")
	if not KNEAD.has(on):
		return
	kneading = true
	var p: float = float(progress.get(t, 0.0)) + delta / KNEAD_TIME
	if p >= 1.0:
		cells[t] = KNEAD[on]
		progress.erase(t)
		sfx("mg_perfect")
		pulse(0.3, 0.05)
		_say(_cap(NAMES[KNEAD[on]]) + " : au four !")
	else:
		progress[t] = p


# Four et chapa cuisent tout seuls : prêt → alarme, trop long → queimado.
func _cook(delta: float) -> void:
	for t: Vector2i in cells.keys():
		var k: String = kind_at(t)
		if k != "O" and k != "G":
			continue
		var on: String = cells[t]
		if on == "" or on == "queimado":
			continue
		var ready_at: float = OVEN_BAKE if k == "O" else CHAPA_COOK
		var burn_at: float = OVEN_BURN if k == "O" else CHAPA_BURN
		var before: float = float(progress.get(t, 0.0))
		var now: float = before + delta
		progress[t] = now
		var table: Dictionary = OVEN_IN if k == "O" else CHAPA_IN
		if before < ready_at and now >= ready_at and table.has(on):
			cells[t] = table[on]
			sfx("oven_ding")
			_say(_cap(NAMES[table[on]]) + " prêt !")
		elif before < burn_at and now >= burn_at:
			cells[t] = "queimado"
			sfx("mg_miss")
			pulse(0.5, 0.1)
			_say("Queimou ! À la poubelle…")


# --- Guidage : la prochaine action pour la commande la plus pressée ---

func _compute_hint() -> void:
	hint_cell = Vector2i(-1, -1)
	if orders.is_empty():
		hint_text = "Attends la prochaine freguesa…" if hand == "" else ""
		return
	# Commande la plus pressée d'abord ; si elle ne fait que cuire, on
	# propose d'avancer la suivante pendant l'attente.
	var sorted_orders: Array = orders.duplicate()
	sorted_orders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["left"]) < float(b["left"]))
	var first_text: String = ""
	var first_cell: Vector2i = Vector2i(-1, -1)
	var seen: Dictionary = {}
	for o in sorted_orders:
		var k: String = o["kind"]
		if seen.has(k):
			continue
		seen[k] = true
		_hint_wait = false
		_guide(k)
		if first_text == "":
			first_text = hint_text
			first_cell = hint_cell
		if not _hint_wait:
			return
	hint_text = first_text
	hint_cell = first_cell


func _hint(text: String, cell: Vector2i) -> void:
	hint_text = text
	hint_cell = cell


func _guide(k: String) -> void:
	var g: Dictionary = GUIDE[k]
	# 1. Le produit fini.
	if hand == k:
		_hint("Sers le %s au BALCÃO" % NAMES[k], _nearest_kind("S", false))
		return
	var done: Vector2i = _find_item(k, "")
	if done.x >= 0:
		_take_or_drop(done, "Prends le %s" % NAMES[k])
		return
	# 2. La version crue : en cuisson, en main ou posée.
	var raw: String = g["raw"]
	var st: String = g["station"]
	var station_name: String = "FORNO" if st == "O" else "CHAPA"
	var cooking: Vector2i = _find_item(raw, st)
	if cooking.x >= 0:
		_hint_wait = true
		_hint("Ça cuit… attends le sino du %s" % station_name, cooking)
		return
	if hand == raw:
		_hint("Mets-le dans le %s" % station_name, _nearest_kind(st, true))
		return
	var raw_at: Vector2i = _find_item(raw, "")
	if raw_at.x >= 0:
		_take_or_drop(raw_at, "Prends le %s" % NAMES[raw])
		return
	# 3. La massa à pétrir.
	var mix: String = g["mix"]
	if mix != "":
		var m: Vector2i = _find_item(mix, "K")
		if m.x >= 0:
			_hint("Tiens SOVAR face à la BANCADA", m)
			return
		if hand == mix:
			_hint("Pose la massa sur une BANCADA", _nearest_kind("K", true))
			return
		var m2: Vector2i = _find_item(mix, "")
		if m2.x >= 0:
			_take_or_drop(m2, "Prends la massa")
			return
	# 4. L'assemblage des deux parts. Une part qui se fabrique (le pão du
	# misto) et qui n'existe pas encore : on suit d'abord sa propre recette.
	var parts: Array = g["parts"]
	for part: String in parts:
		if not CRATE_OF.has(part) and hand != part and _find_item(part, "").x < 0:
			_guide(part)
			return
	var where: String = "K" if mix != "" else "#"
	var base: Vector2i = Vector2i(-1, -1)
	var other: String = ""
	for i in 2:
		var at: Vector2i = _find_item(parts[i], where)
		if at.x >= 0:
			base = at
			other = parts[1 - i]
			break
	if base.x >= 0:
		if hand == other:
			_hint("Pose le %s sur le %s" % [NAMES[other], NAMES[cells[base]]], base)
			return
		if hand != "":
			_hint("Pose ce que tu tiens sur un comptoir", _nearest_kind("#", true))
			return
		_fetch(other)
		return
	var place_on: String = "une BANCADA" if where == "K" else "un comptoir"
	if hand in parts:
		_hint("Pose le %s sur %s" % [NAMES[hand], place_on], _nearest_kind(where, true))
		return
	if hand != "":
		_hint("Pose ce que tu tiens sur un comptoir", _nearest_kind("#", true))
		return
	_fetch(parts[0])


# Va chercher une part : à la caisse, ou en la fabriquant (le pão du misto).
func _fetch(part: String) -> void:
	if CRATE_OF.has(part):
		_hint("Prends du %s à la caisse" % NAMES[part], _crate_cell(part))
		return
	var at: Vector2i = _find_item(part, "")
	if at.x >= 0:
		_hint("Prends le %s" % NAMES[part], at)
		return
	_guide(part)


func _take_or_drop(cell: Vector2i, take_text: String) -> void:
	if hand == "":
		_hint(take_text, cell)
	else:
		_hint("Pose ce que tu tiens sur un comptoir", _nearest_kind("#", true))


func _find_item(item: String, kind: String) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = INF
	for c: Vector2i in cells.keys():
		if cells[c] != item or (kind != "" and kind_at(c) != kind):
			continue
		var d: float = cell_center(c).distance_to(player_pos)
		if d < bd:
			bd = d
			best = c
	return best


func _nearest_kind(kind: String, empty_only: bool) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bd: float = INF
	for c: Vector2i in cells.keys():
		if kind_at(c) != kind or (empty_only and cells[c] != "") or not _reachable(c):
			continue
		var d: float = cell_center(c).distance_to(player_pos)
		if d < bd:
			bd = d
			best = c
	return best


# Un poste d'angle sans case de sol voisine ne se touche pas.
func _reachable(c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if kind_at(c + d) == ".":
			return true
	return false


func _crate_cell(part: String) -> Vector2i:
	var ch: String = CRATE_OF[part]
	for r in GRID.size():
		var i: int = GRID[r].find(ch)
		if i >= 0:
			return Vector2i(i, r)
	return Vector2i(-1, -1)


# --- Commandes des fregueses ---

func _tick_orders(delta: float) -> void:
	_next_order -= delta
	if orders.is_empty() and _next_order > 3.0:
		_next_order = 3.0
	# Début doux : la 2e freguesa attend que la 1re soit servie (ou 40 s).
	var warming: bool = served == 0 and not orders.is_empty() and _elapsed < 40.0
	if _next_order <= 0.0 and not warming and orders.size() < MAX_ORDERS and time_left > 20.0:
		_add_order(_pick_kind())
		_next_order = _rng.randf_range(ORDER_GAP_MIN, ORDER_GAP_MAX)
	for o in orders.duplicate():
		o["left"] = float(o["left"]) - delta
		if float(o["left"]) <= 0.0:
			orders.erase(o)
			lost += 1
			sfx("mg_miss")
			pulse(0.5, 0.15)
			_say("Uma freguesa desistiu…")


func _pick_kind() -> String:
	if _order_seq == 0:
		return "pq"
	if _order_seq == 1:
		return "pf"
	if _elapsed > 30.0 and _rng.randf() < 0.4:
		return "misto"
	return "pq" if _rng.randf() < 0.55 else "pf"


func _add_order(kind: String) -> void:
	_order_seq += 1
	var p: float = PATIENCE[kind] * (1.8 if _order_seq == 1 else 1.0)
	orders.append({"id": _order_seq, "kind": kind, "left": p, "max": p})
	sfx("customer_cling")


func _serve() -> void:
	if hand == "":
		return
	for o in orders:
		if o["kind"] == hand:
			var ratio: float = clampf(float(o["left"]) / float(o["max"]), 0.0, 1.0)
			var gain: int = int(TIP[hand]) + int(round(TIP_SPEED_BONUS * ratio))
			tips += gain
			served += 1
			orders.erase(o)
			hand = ""
			sfx("coin")
			sfx("mg_perfect")
			pulse(0.4, 0.06)
			_say(("Rapidinho ! " if ratio > 0.5 else "") + "+R$ %d" % gain)
			return
	_say("Ninguém pediu " + String(NAMES.get(hand, hand)) + ".")
	sfx("mg_miss", 1.3)


func stars() -> int:
	var s: int = 0
	for th in STARS:
		if tips >= th:
			s += 1
	return s


# --- Interface ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_tickets = HBoxContainer.new()
	_tickets.position = Vector2(24, 16)
	_tickets.add_theme_constant_override("separation", 12)
	_ui.add_child(_tickets)
	SafeArea.apply(_tickets)
	# Chrono et caisse dans une pastille sombre (l'ardoise peinte est derrière).
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.85)))
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.offset_left = -640.0
	pill.offset_right = -340.0
	pill.offset_top = 16.0
	pill.offset_bottom = 140.0
	_ui.add_child(pill)
	SafeArea.apply(pill)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(col)
	_clock = _label(44, Color(1, 0.97, 0.88))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock)
	_money = _label(33, Color(1, 0.88, 0.35))
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_money)
	_status = _label(30, Color(1, 0.95, 0.7))
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = -560.0
	_status.offset_right = 560.0
	_status.offset_top = -190.0
	_status.offset_bottom = -140.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_status)
	# Consigne permanente, dans une pastille au bas de l'écran.
	var pill2: PanelContainer = PanelContainer.new()
	pill2.add_theme_stylebox_override("panel", UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.85)))
	pill2.anchor_left = 0.5
	pill2.anchor_right = 0.5
	pill2.anchor_top = 1.0
	pill2.anchor_bottom = 1.0
	pill2.offset_left = -470.0
	pill2.offset_right = 470.0
	pill2.offset_top = -120.0
	pill2.offset_bottom = -30.0
	pill2.name = "HintPill"
	_ui.add_child(pill2)
	SafeArea.apply(pill2)
	_hint_label = _label(36, Color(1, 0.88, 0.35))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill2.add_child(_hint_label)
	pill2.visible = false
	_btn_a = _button("PEGAR", Vector2(-480, -250), Vector2(-280, -90))
	_btn_b = _button("SOVAR", Vector2(-260, -330), Vector2(-40, -110))
	_build_intro()


func _label(size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.13, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", 9)
	return l


func _button(text: String, tl: Vector2, br: Vector2) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_font_size_override("font_size", 33)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = tl.x
	b.offset_top = tl.y
	b.offset_right = br.x
	b.offset_bottom = br.y
	var box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.8))
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("pressed", UITheme.pastille_box(UITheme.CREAM, Color(0.3, 0.55, 0.25, 0.9)))
	b.visible = false
	_ui.add_child(b)
	SafeArea.apply(b)
	return b


# Carte des recettes, en images : ouvrir la padaria lance le chrono.
func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_to_group("gamepad_menu")
	_ui.add_child(_intro)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560.0
	panel.offset_right = 560.0
	panel.offset_top = -380.0
	panel.offset_bottom = 380.0
	_intro.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title: Label = _label(44, Color(1, 0.86, 0.38))
	title.text = "Padaria São Sebastião — rush da manhã"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for row: Array in [["polvilho", "+", "queijo", "→ SOVAR →", "pq_cru", "→ forno →", "pq"],
			["farinha", "+", "agua", "→ SOVAR →", "pf_cru", "→ forno →", "pf"],
			["pf", "+", "queijo", "→", "misto_cru", "→ chapa →", "misto"]]:
		var h: HBoxContainer = HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		for part: String in row:
			if NAMES.has(part):
				var tr: TextureRect = TextureRect.new()
				tr.texture = KitchenArt.item_texture(part)
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(84, 84)
				h.add_child(tr)
			else:
				var l: Label = _label(28, Color(1, 0.97, 0.88))
				l.text = part
				h.add_child(l)
		box.add_child(h)
	var tip: Label = _label(28, Color(1, 0.97, 0.88))
	tip.text = "PEGAR : prendre, poser, assembler, servir au balcão · tiens SOVAR à la bancada.\nTout comptoir sert de plan de travail. Sers vite : la fila n'attend pas !"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(1000, 0)
	box.add_child(tip)
	var go: Button = Button.new()
	go.text = "Abrir a padaria !"
	go.add_theme_font_size_override("font_size", 36)
	go.custom_minimum_size = Vector2(520, 120)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_start)
	box.add_child(go)
	GamepadBridge.focus_first.call_deferred(_intro)


func _start() -> void:
	if started:
		return
	started = true
	if _intro:
		_intro.queue_free()
		_intro = null
	_btn_a.visible = true
	_btn_b.visible = true
	if _hint_label:
		_hint_label.get_parent().visible = true
	_say("Bom dia ! Primeira freguesa chegando…")
	sfx("prompt_chime")


func _say(text: String) -> void:
	if _status:
		_status.text = text
	_status_t = 2.6


func _update_hud() -> void:
	if _clock:
		var c: int = int(ceilf(time_left))
		_clock.text = "%d:%02d" % [c / 60, c % 60]
	if _money:
		var s: int = stars()
		_money.text = "R$ %d  %s" % [tips, "★".repeat(s) + "·".repeat(3 - s)]
	_status_t -= get_process_delta_time()
	if _status and _status_t <= 0.0 and started and not _ended:
		_status.text = ""
	if _hint_label:
		_hint_label.text = "→ " + hint_text if hint_text != "" else ""
		_hint_label.get_parent().visible = started and not _ended and hint_text != ""
	_refresh_buttons()
	_refresh_tickets()


func _refresh_buttons() -> void:
	if _btn_a == null:
		return
	var k: String = kind_at(target)
	var on: String = cells.get(target, "")
	var a: String = "PEGAR"
	if k == "S" and hand != "":
		a = "SERVIR"
	elif k == "T" and hand != "":
		a = "JOGAR"
	elif hand != "" and on != "" and merge(hand, on) != "":
		a = "JUNTAR"
	elif hand != "":
		a = "LARGAR"
	_btn_a.text = a
	_btn_b.modulate.a = 1.0 if (k == "K" and KNEAD.has(on)) else 0.55


func _refresh_tickets() -> void:
	if _tickets == null:
		return
	while _tickets.get_child_count() < orders.size():
		var t: VBoxContainer = VBoxContainer.new()
		t.custom_minimum_size = Vector2(150, 0)
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(150, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.add_child(icon)
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 18)
		bar.max_value = 1.0
		t.add_child(bar)
		_tickets.add_child(t)
	for i in _tickets.get_child_count():
		var t: Control = _tickets.get_child(i) as Control
		t.visible = i < orders.size()
		if i >= orders.size():
			continue
		var o: Dictionary = orders[i]
		var icon: TextureRect = t.get_child(0) as TextureRect
		icon.texture = KitchenArt.item_texture(o["kind"])
		var bar: ProgressBar = t.get_child(1) as ProgressBar
		var ratio: float = float(o["left"]) / float(o["max"])
		bar.value = ratio
		bar.modulate = Color(0.5, 0.95, 0.5) if ratio > 0.5 else (Color(1, 0.85, 0.3) if ratio > 0.25 else Color(1, 0.35, 0.3))


# --- Aperçu (captures) ---

func _apply_preview() -> void:
	_start()
	if preview == "busy":
		cells[Vector2i(9, 0)] = "pq_cru"
		progress[Vector2i(9, 0)] = 4.5
		cells[Vector2i(10, 0)] = "pf"
		progress[Vector2i(10, 0)] = 10.5
		cells[Vector2i(6, 3)] = "misto_cru"
		progress[Vector2i(6, 3)] = 2.0
		cells[Vector2i(6, 0)] = "mix_pq"
		progress[Vector2i(6, 0)] = 0.55
		cells[Vector2i(4, 3)] = "queijo"
		hand = "farinha"
		player_pos = cell_center(Vector2i(7, 1))
		facing = Vector2.LEFT
		_add_order("pq")
		_add_order("misto")
		_add_order("pf")
		orders[0]["left"] = 14.0


# --- Fin ---

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	kneading = false
	var s: int = stars()
	var qualifies: bool = final_qualifies(s >= QUALIFY_STARS)
	if _btn_a:
		_btn_a.visible = false
		_btn_b.visible = false
	if forfeited:
		_say("Padaria fechada.")
	else:
		_say("Fim do rush · %d servidos · %d perdidos · R$ %d  %s" % [served, lost, tips, "★".repeat(s) + "·".repeat(3 - s)])
		_status_t = 99.0
		sfx("minigame_win" if qualifies else "minigame_lose")
	await get_tree().create_timer(bilan_delay(2.8)).timeout
	EventBus.minigame_ended.emit("padaria", {"tips": tips, "batches": served, "qualifies": qualifies})
	match_ended.emit(qualifies, 0 if forfeited else tips)
