class_name MilhoGame
extends MinigameBase

# Hora do rush — la carrocinha de Zé après l'acte 1. Le milho n'est plus une
# tournée de 3 épis à 5 R$ : c'est un service sous pression où l'on gagne en
# CONNAISSANT ses fregueses.
#   - La panela : 3 épis qui cuisent. Cru (< 5 s), NO PONTO (5-11 s),
#     passado (11-16 s), desmanchou (> 16 s, invendable). Toucher un épi le
#     prend en main ; toucher une case vide y plonge un épi cru.
#   - En main : 🧈 manteiga / 🧂 sal / 🧀 queijo (bascules), 🗑 pour jeter.
#   - Les clients font la queue (3 places), avec une patience qui fond.
#     Toucher un client le sert. Bonne garniture + no ponto = Perfeito (3 pts),
#     bonne garniture mal cuite = Boa (1 pt), mauvaise = Mole (il refuse).
#   - Les habitués (Jorge, Ramos, le concierge…) disent leur commande tant que
#     tu ne les connais pas. Servis deux fois Perfeito, ils ne disent plus que
#     « o de sempre » — à toi de t'en souvenir. Un freguês fidèle bien servi
#     rapporte plus et nourrit l'affinité (le carburant du jeitinho).
# Contrat : match_ended(qualifies, cash) ; minigame_ended("milho", {...}).

signal match_ended(qualifies: bool, cash: int)

enum Cook { EMPTY, CRU, PONTO, PASSADO, DESMANCHOU }
enum Grade { MOLE, BOA, PERFEITO }

const DURATION: float = 90.0
const QUALIFY_SCORE: int = 24
const POT_SLOTS: int = 3
const QUEUE_SLOTS: int = 3
const COOK_PONTO: float = 5.0
const COOK_PASSADO: float = 11.0
const COOK_DESMANCHOU: float = 16.0
const PATIENCE: float = 22.0
const SPAWN_START: float = 6.5
const SPAWN_END: float = 3.8
const PRICE: int = 6
const TIP_PASSERBY: int = 3
const TIP_REGULAR: int = 5
const TIP_DE_SEMPRE: int = 8
# Servis Perfeito ce nombre de fois (toutes parties confondues), un habitué
# ne dit plus sa commande.
const KNOWN_AFTER: int = 2
const TOPPINGS: Array[String] = ["manteiga", "sal", "queijo"]
const TOPPING_ICONS: Dictionary = {"manteiga": "🧈", "sal": "🧂", "queijo": "🧀"}
const ART_SCRIPT: Script = preload("res://scripts/minigames/milho/MilhoArt.gd")

# Les fregueses de la carrocinha : ids d'affinité réels (jeitinho).
const REGULARS: Array = [
	{"id": "jorge", "name": "Jorge", "order": ["manteiga", "sal"], "line": "Manteiga e sal, como sempre foi."},
	{"id": "ramos", "name": "Capitão Ramos", "order": ["sal"], "line": "Só sal. Rápido, moço."},
	{"id": "concierge", "name": "Le concierge", "order": ["manteiga", "sal", "queijo"], "line": "Manteiga, sal e queijo… como o velho fazia."},
	{"id": "diego", "name": "Mestre Diego", "order": ["manteiga"], "line": "Manteiga, e muita."},
	{"id": "roberto_maia", "name": "Roberto Maia", "order": ["sal", "queijo"], "line": "Queijo e sal, sem manteiga — o colesterol."},
	{"id": "padeiro", "name": "Seu Tonio", "order": ["manteiga", "queijo"], "line": "Manteiga e queijo. Pão eu já tenho."},
]
const PASSERBY: Array = [
	{"kind": "gringo", "name": "Gringa", "seed": 7101},
	{"kind": "carioca", "name": "Carioca", "seed": 7102},
	{"kind": "gamin", "name": "Gamin", "seed": 7103},
]

var _time_left: float = DURATION
var _elapsed: float = 0.0
var _score: int = 0
var _cash: int = 0
var _served: int = 0
var _perfeitos: int = 0
var _ended: bool = false
var _spawn_timer: float = 1.0
var _pot: Array = []          # [{t: float}] ou {} si vide
var _queue: Array = []        # [{...client}] ou {} si vide
var _hand: Dictionary = {}    # {} ou {cook: int, toppings: Array}
var _seen_this_rush: Dictionary = {}
var _bumped_this_rush: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _hud: Label
var _status: Label
var _hand_label: Label
var _pot_buttons: Array[Button] = []
var _queue_buttons: Array[Button] = []
var _queue_sprites: Array[Sprite2D] = []
var _topping_buttons: Dictionary = {}
var _art: Node2D
# Outil de capture : « 1 » remplit panela, file et main au lancement ; « 2 » sert en plus Jorge à 1 s.
var vitrine: String = ""

# --- Règles pures (testées sans scène) ---

static func cook_state(t: float) -> int:
	if t < COOK_PONTO:
		return Cook.CRU
	if t < COOK_PASSADO:
		return Cook.PONTO
	if t < COOK_DESMANCHOU:
		return Cook.PASSADO
	return Cook.DESMANCHOU

static func grade(order: Array, toppings: Array, cook: int) -> int:
	if cook == Cook.DESMANCHOU or cook == Cook.EMPTY:
		return Grade.MOLE
	var a: Array = order.duplicate()
	var b: Array = toppings.duplicate()
	a.sort()
	b.sort()
	if a != b:
		return Grade.MOLE
	return Grade.PERFEITO if cook == Cook.PONTO else Grade.BOA

# Un habitué dit sa commande tant que tu ne le connais pas — et pas une 2e fois
# dans le même rush : tu viens de l'entendre.
static func shows_order(known_count: int, seen_this_rush: bool) -> bool:
	return known_count < KNOWN_AFTER and not seen_this_rush

static func known_key(npc_id: String) -> String:
	return "milho_conhece_%s" % npc_id

static func tip_for(client: Dictionary, g: int) -> int:
	if g != Grade.PERFEITO or client.get("kind", "") == "gamin":
		return 0
	if client.get("regular", false):
		return TIP_DE_SEMPRE if not client.get("shows_order", true) else TIP_REGULAR
	return TIP_PASSERBY

# --- Scène ---

func _ready() -> void:
	EventBus.minigame_started.emit("milho")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	for i in POT_SLOTS:
		_pot.append({})
	for i in QUEUE_SLOTS:
		_queue.append({})
	_build_ui()
	if vitrine != "":
		_fill_vitrine()
	add_to_group("gamepad_menu")
	GamepadBridge.focus_first.call_deferred(self)
	_set_status("Hora do rush ! Plonge les épis, sers NO PONTO, et retiens tes fregueses.")
	_refresh_all()

func _build_ui() -> void:
	_art = ART_SCRIPT.new()
	add_child(_art)
	move_child(_art, 0)
	_art.call("build")
	_hud = _label(Vector2(-470, -532), Vector2(940, 60), 26, HORIZONTAL_ALIGNMENT_CENTER)
	_hud.theme_type_variation = &"Pastille"
	_status = _label(Vector2(-720, 448), Vector2(1440, 72), 24, HORIZONTAL_ALIGNMENT_CENTER)
	_status.theme_type_variation = &"Pastille"
	_queue_sprites = _art.get("client_sprites")
	var x_slots: Array = [-560.0, 0.0, 560.0]
	for i in QUEUE_SLOTS:
		# Toute la silhouette et sa bulle : toucher le client le sert.
		var b: Button = _button(Vector2(x_slots[i] - 210, -450), Vector2(420, 372), 22)
		b.flat = true
		b.pressed.connect(_on_client_pressed.bind(i))
		_queue_buttons.append(b)
	for i in POT_SLOTS:
		var p: Button = _button(Vector2(-390 + i * 270, -60), Vector2(240, 240), 24)
		p.flat = true
		p.pressed.connect(_on_pot_pressed.bind(i))
		_pot_buttons.append(p)
	_hand_label = _label(Vector2(-650, 336), Vector2(330, 64), 22, HORIZONTAL_ALIGNMENT_CENTER)
	var tx: float = -300.0
	for t in TOPPINGS:
		var tb: Button = _button(Vector2(tx, 222), Vector2(190, 150), 22)
		_dress_button(tb, t)
		tb.pressed.connect(_on_topping_pressed.bind(t))
		_topping_buttons[t] = tb
		tx += 215.0
	var trash: Button = _button(Vector2(370, 222), Vector2(190, 150), 22)
	_dress_button(trash, "lixo")
	trash.text = "Jeter"
	trash.pressed.connect(_on_trash_pressed)

# Icône pixel de l'ingrédient au-dessus de son nom, cadre du thème.
func _dress_button(b: Button, id: String) -> void:
	b.icon = _art.call("button_icon", id, 64)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _label(pos: Vector2, size: Vector2, font: int, align: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 10
	add_child(l)
	return l

func _button(pos: Vector2, size: Vector2, font: int) -> Button:
	var b: Button = Button.new()
	b.position = pos
	b.size = size
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", font)
	# Focusable : à la manette, la croix navigue entre panela, garnitures et
	# clients, A sert (GamepadBridge.focus_first + groupe gamepad_menu).
	b.focus_mode = Control.FOCUS_ALL
	b.z_index = 10
	add_child(b)
	return b

func _process(delta: float) -> void:
	if _ended:
		return
	_elapsed += delta
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_end_game()
		return
	for i in POT_SLOTS:
		if not _pot[i].is_empty():
			_pot[i].t += delta
	for i in QUEUE_SLOTS:
		var c: Dictionary = _queue[i]
		if c.is_empty():
			continue
		c.patience -= delta
		if c.patience <= 0.0:
			_queue[i] = {}
			_set_status("😤 %s est parti·e — « Demorou, moço ! »" % c.name)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_client()
		var k: float = clampf(_elapsed / DURATION, 0.0, 1.0)
		_spawn_timer = lerpf(SPAWN_START, SPAWN_END, k) + _rng.randf_range(-0.8, 0.8)
	_refresh_all()

func _spawn_client() -> void:
	var slot: int = -1
	for i in QUEUE_SLOTS:
		if _queue[i].is_empty():
			slot = i
			break
	if slot == -1:
		return
	var c: Dictionary
	# Un habitué ne fait pas la queue deux fois en même temps.
	var free_regulars: Array = []
	for r in REGULARS:
		var waiting: bool = false
		for q in _queue:
			if not q.is_empty() and q.get("id", "") == r.id:
				waiting = true
		if not waiting:
			free_regulars.append(r)
	if _rng.randf() < 0.45 and not free_regulars.is_empty():
		var r: Dictionary = free_regulars[_rng.randi() % free_regulars.size()]
		var known: int = int(CampaignManager.flags.get(known_key(r.id), 0))
		var seen: bool = _seen_this_rush.has(r.id)
		c = {"regular": true, "id": r.id, "name": r.name, "order": r.order, "line": r.line,
			"shows_order": shows_order(known, seen), "seed": hash(r.id)}
		_seen_this_rush[r.id] = true
	else:
		var p: Dictionary = PASSERBY[_rng.randi() % PASSERBY.size()]
		var order: Array = []
		for t in TOPPINGS:
			if _rng.randf() < 0.5:
				order.append(t)
		if order.is_empty():
			order.append("manteiga")
		c = {"regular": false, "kind": p.kind, "name": p.name, "order": order,
			"shows_order": true, "seed": int(p.seed) + _rng.randi_range(0, 50)}
	c["patience"] = PATIENCE
	_queue[slot] = c

func _on_pot_pressed(i: int) -> void:
	if _ended:
		return
	if _pot[i].is_empty():
		_pot[i] = {"t": 0.0}
		sfx("splash", 1.6)
		if _art:
			_art.call("splash", i)
		return
	if not _hand.is_empty():
		_set_status("Tu as déjà un épi en main — sers-le ou jette-le.")
		return
	_hand = {"cook": cook_state(float(_pot[i].t)), "toppings": []}
	sfx("item_pickup")
	_pot[i] = {}
	_refresh_all()

func _on_topping_pressed(t: String) -> void:
	if _ended or _hand.is_empty():
		return
	var tops: Array = _hand.toppings
	if tops.has(t):
		tops.erase(t)
	else:
		tops.append(t)
	_refresh_all()

func _on_trash_pressed() -> void:
	if _ended or _hand.is_empty():
		return
	_hand = {}
	_refresh_all()

func _on_client_pressed(i: int) -> void:
	if _ended:
		return
	var c: Dictionary = _queue[i]
	if c.is_empty():
		return
	if _hand.is_empty():
		_set_status("Prends d'abord un épi dans la panela.")
		return
	var g: int = grade(c.order, _hand.toppings, int(_hand.cook))
	if _art:
		_art.call("serve", i, g, c.get("regular", false) and not c.get("shows_order", true))
	_hand = {}
	_queue[i] = {}
	var is_kid: bool = c.get("kind", "") == "gamin"
	match g:
		Grade.PERFEITO:
			sfx("mg_perfect")
			sfx("coin")
			pulse(0.35, 0.06)
			_score += 3
			_perfeitos += 1
			_served += 1
			var gain: int = 0 if is_kid else PRICE + tip_for(c, g)
			_cash += gain
			if c.regular:
				_remember_regular(c)
				if not c.shows_order:
					_set_status("✨ PERFEITO — « O de sempre ! Tu me conheces, hein ? » (+R$ %d)" % gain)
				else:
					_set_status("✨ PERFEITO — %s repart content·e (+R$ %d)" % [c.name, gain])
			elif is_kid:
				_set_status("✨ PERFEITO — le gamin repart avec un sourire. Ça, ça ne se paie pas.")
			else:
				_set_status("✨ PERFEITO — no ponto ! (+R$ %d)" % gain)
		Grade.BOA:
			sfx("mg_good")
			_score += 1
			_served += 1
			var paid: int = 0 if is_kid else PRICE
			_cash += paid
			_set_status("✔ Boa — bonne garniture, mais pas no ponto. (+R$ %d)" % paid)
		_:
			sfx("mg_miss")
			pulse(0.4, 0.1)
			_set_status("✖ Mole — « Isso não é o meu milho ! » %s repart sans payer." % c.name)
	_refresh_all()

# Un habitué servi Perfeito : la carrocinha le connaît un peu plus (persisté),
# et une fois par rush, l'affinité monte — le jeitinho se construit ici.
func _remember_regular(c: Dictionary) -> void:
	var key: String = known_key(String(c.id))
	var before: int = int(CampaignManager.flags.get(key, 0))
	CampaignManager.set_flag(key, before + 1)
	if before + 1 == KNOWN_AFTER:
		EventBus.notification_requested.emit("🌽 %s est devenu un freguês — la prochaine fois : « o de sempre »." % c.name,
			Color(0.98, 0.85, 0.35, 1))
	if not _bumped_this_rush.has(c.id):
		_bumped_this_rush[c.id] = true
		NPCAffinity.bump(String(c.id))

func _refresh_all() -> void:
	if _hud:
		_hud.text = "Hora do rush · %ds · %d pts · R$ %d" % [int(ceil(_time_left)), _score, _cash]
	if _art:
		_art.call("sync", _pot, _queue, _hand, cook_state)
	if _hand.is_empty():
		_hand_label.text = "Mão vazia"
	else:
		var cook_names: Dictionary = {Cook.CRU: "cru", Cook.PONTO: "no ponto", Cook.PASSADO: "passado", Cook.DESMANCHOU: "desmanchou"}
		var tops: String = ", ".join(PackedStringArray(_hand.toppings)) if not _hand.toppings.is_empty() else "puro"
		_hand_label.text = "%s · %s" % [cook_names.get(int(_hand.cook), "?"), tops]
	for t in TOPPINGS:
		var tb: Button = _topping_buttons[t]
		var on: bool = not _hand.is_empty() and _hand.toppings.has(t)
		tb.text = t.capitalize()
		tb.modulate = Color(1.0, 0.9, 0.45, 1) if on else Color(1, 1, 1, 1)

# Capture : un rush déjà lancé (une habituée connue, un habitué, une passante).
func _fill_vitrine() -> void:
	_pot[0] = {"t": 2.0}
	_pot[1] = {"t": 7.0}
	_pot[2] = {"t": 12.5}
	_hand = {"cook": Cook.PONTO, "toppings": ["manteiga", "sal"]}
	var r0: Dictionary = REGULARS[0]
	var r1: Dictionary = REGULARS[2]
	_queue[0] = {"regular": true, "id": r0.id, "name": r0.name, "order": r0.order, "line": r0.line, "shows_order": false, "patience": 18.0, "seed": 1}
	_queue[1] = {"regular": true, "id": r1.id, "name": r1.name, "order": r1.order, "line": r1.line, "shows_order": true, "patience": 11.0, "seed": 2}
	_queue[2] = {"regular": false, "kind": "gringo", "name": "Gringa", "order": ["sal", "queijo"], "shows_order": true, "patience": 5.0, "seed": 7101}
	_spawn_timer = 99.0
	if vitrine == "2":
		get_tree().create_timer(1.0).timeout.connect(_on_client_pressed.bind(0))

func _set_status(text: String) -> void:
	if _status:
		_status.text = text

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_end_game()
		get_viewport().set_input_as_handled()

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if qualifies:
		_set_status("Fim do rush — %d servis, %d Perfeitos, R$ %d. A carrocinha do Zé tá viva !" % [_served, _perfeitos, _cash])
	else:
		_set_status("Fim do rush — %d pts (min. %d). R$ %d quand même. O freguês volta amanhã." % [_score, QUALIFY_SCORE, _cash])
	await get_tree().create_timer(bilan_delay(2.0)).timeout
	EventBus.minigame_ended.emit("milho",
		{"score": _score, "served": _served, "perfeitos": _perfeitos, "cash": _cash, "qualifies": qualifies})
	match_ended.emit(qualifies, _cash)
