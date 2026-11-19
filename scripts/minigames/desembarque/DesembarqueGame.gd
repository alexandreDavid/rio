class_name DesembarqueGame
extends MinigameBase

# Desembarque — le hall des arrivées de Santos Dumont, plaque de chauffeur en
# main. Les passagers sortent UN PAR UN et s'arrêtent devant toi le temps d'un
# regard : compare avec ta plaque (chemise, couvre-chef, valise) et appelle
# « É ELE ! » si c'est ton client, sinon laisse-le passer. Un seul passager de
# la file a les trois indices ; les leurres en partagent deux, de plus en plus
# nombreux, et l'arrêt raccourcit à chaque manche.
# Appelé dès son arrivée (avant la moitié de l'arrêt) = Perfeito (3 pts),
# plus tard = Boa (2) ; laissé partir = raté (0) ; mauvais appel = −1 pt.
# Contrat : match_ended(qualifies, cash) ; minigame_ended("desembarque", {...}).

signal match_ended(qualifies: bool, cash: int)

const Art := preload("res://scripts/minigames/desembarque/DesembarqueArt.gd")

const ROUNDS: int = 6
const QUALIFY_SCORE: int = 14       # max 18 : au moins 2 Perfeitos sur 6
# Arrêt devant toi : 2,4 s en 1re manche, −0,2 s par manche (plancher 1,3 s).
const STOP_TIME_START: float = 2.4
const STOP_TIME_STEP: float = 0.2
const STOP_TIME_MIN: float = 1.3
const WRONG_PENALTY: int = 1
const FARE: int = 18
const FAST_TIP: int = 7
const GATE_POS: Vector2 = Vector2(260.0, -330.0)
const STOP_POS: Vector2 = Vector2(260.0, 300.0)
const WALK_IN_TIME: float = 0.7
const WALK_OUT_SPEED: float = 900.0
const TAP_RADIUS: float = 170.0
const SCALE_FAR: float = 1.4
const SCALE_NEAR: float = 3.4

const SHIRTS: Dictionary = {
	"vermelha": Color(0.86, 0.2, 0.2, 1), "azul": Color(0.22, 0.42, 0.88, 1),
	"amarela": Color(0.96, 0.82, 0.2, 1), "verde": Color(0.2, 0.66, 0.32, 1),
	"branca": Color(0.96, 0.96, 0.94, 1),
}
const HATS: Dictionary = {"sem chapéu": "none", "boné branco": "cap", "chapéu-panamá": "fedora"}
# Couleurs franches : un couvre-chef ne doit pas se confondre avec des cheveux.
const HAT_COLORS: Dictionary = {"boné branco": Color(0.98, 0.98, 0.98, 1), "chapéu-panamá": Color(0.93, 0.84, 0.5, 1)}
const BAGS: Dictionary = {
	"mala preta": Color(0.12, 0.12, 0.14, 1), "mala rosa": Color(0.95, 0.45, 0.7, 1),
	"mala azul": Color(0.2, 0.55, 0.95, 1), "mala laranja": Color(1.0, 0.55, 0.1, 1),
}
# Qui on attend : une touche de ponte aérea.
const CLIENTS: Array[String] = [
	"o executivo da ponte aérea", "a tia de Minas (com goiabada)", "o gringo que acha que é verão",
	"o deputado discreto", "a noiva atrasada", "o técnico do Mengão",
]

var _round: int = 0
var _score: int = 0
var _cash: int = 0
var _found_fast: int = 0
var _ended: bool = false
var _client: Dictionary = {}
var _passengers: Array = []      # [{attrs, sprite, state, t}] — au plus 2 (l'un part, l'autre arrive)
var _spawn_queue: Array = []
var _between: float = 0.0
var _queue_total: int = 0
var _stop_time: float = STOP_TIME_START
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _hud: Label
var _card: Label
var _status: Label
var _call_btn: Button
var _stop_bar: ColorRect
var _chips: Array[ColorRect] = []
var _hat_icon: Sprite2D
var _chip_caps: Array[Label] = []
var _door_l: Sprite2D
var _door_r: Sprite2D
var _door_tween: Tween
var _player_sign: Sprite2D

enum PState { ARRIVING, PRESENTING, LEAVING }

const BAG_X: float = 14.0

# --- Règles pures (testées sans scène) ---

static func matches(p: Dictionary, c: Dictionary) -> bool:
	return p.shirt == c.shirt and p.hat == c.hat and p.bag == c.bag

static func _random_attrs(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"shirt": SHIRTS.keys()[rng.randi() % SHIRTS.size()],
		"hat": HATS.keys()[rng.randi() % HATS.size()],
		"bag": BAGS.keys()[rng.randi() % BAGS.size()],
	}

# Une manche : le client + n passagers dont exactement UN correspond. Les
# `decoys` premiers leurres partagent deux indices sur trois avec le client.
static func make_round(rng: RandomNumberGenerator, n: int, decoys: int) -> Dictionary:
	var client: Dictionary = _random_attrs(rng)
	var list: Array = [client.duplicate()]
	var keys: Array = ["shirt", "hat", "bag"]
	var pools: Dictionary = {"shirt": SHIRTS.keys(), "hat": HATS.keys(), "bag": BAGS.keys()}
	while list.size() < n:
		var p: Dictionary
		if list.size() - 1 < decoys:
			p = client.duplicate()
			var k: String = keys[rng.randi() % keys.size()]
			var options: Array = pools[k].filter(func(v): return v != client[k])
			p[k] = options[rng.randi() % options.size()]
		else:
			p = _random_attrs(rng)
		if not matches(p, client):
			list.append(p)
	# Mélange (Fisher-Yates) avec le rng fourni : rejouable.
	for i in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp
	return {"client": client, "passengers": list}

static func describe(c: Dictionary) -> String:
	return "camisa %s · %s · %s" % [c.shirt, c.hat, c.bag]

# --- Scène ---

func _ready() -> void:
	EventBus.minigame_started.emit("desembarque")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_build_hall()
	_hud = _label(Vector2(-900, -530), Vector2(1800, 46), 28, Color(0.98, 0.97, 0.92, 1))
	_hud.add_theme_constant_override("outline_size", 8)
	_hud.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.18, 1))
	_build_card()
	# Bilan du coup : blanc contouré, à gauche du bouton « É ELE ! ».
	_status = _label(Vector2(-390, 436), Vector2(840, 100), 26, Color(1, 1, 1, 1))
	_status.add_theme_constant_override("outline_size", 8)
	_status.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1, 1))
	# Le repère au sol (traces de pas) est peint dans le hall ; reste le temps d'arrêt.
	_stop_bar = ColorRect.new()
	_stop_bar.position = STOP_POS + Vector2(-90, 30)
	_stop_bar.size = Vector2(180, 14)
	_stop_bar.color = Color(0.35, 0.8, 0.45, 1)
	_stop_bar.z_index = 90
	_stop_bar.visible = false
	add_child(_stop_bar)
	_build_call_button()
	_start_round()

# Plaque du chauffeur (fiche de la cooperativa) : nom + les trois indices en
# grandes pastilles de la couleur EXACTE, chacune avec son icône.
func _build_card() -> void:
	add_child(Art.layer(Art.card(), Art.CARD_POS, 99))
	_card = _label(Art.CARD_POS + Vector2(18, 66), Vector2(604, 84), 33, Color(0.1, 0.1, 0.12, 1))
	_card.add_theme_constant_override("outline_size", 0)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icons: Array[String] = ["shirt", "none", "bag"]
	for i in 3:
		var r: Rect2 = Art.chip_world_rect(i)
		var chip: ColorRect = ColorRect.new()
		chip.position = r.position
		chip.size = r.size
		chip.z_index = 100
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		_chips.append(chip)
		var ic: Sprite2D = Art.layer(Art.icon(icons[i]), r.position + Vector2(6, 6), 101)
		add_child(ic)
		if i == 1:
			_hat_icon = ic
		var cap: Label = _label(r.position + Vector2(-12, r.size.y + 8), Vector2(r.size.x + 24, 60), 22, Color(0.1, 0.1, 0.12, 1))
		cap.add_theme_constant_override("outline_size", 0)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_chip_caps.append(cap)

# Hall d'arrivée du Santos Dumont : dehors, avion, porte, hall, figurants,
# garde-corps, chariot et le joueur de dos, pancarte en main.
func _build_hall() -> void:
	add_child(Art.layer(Art.outside(), Art.ORIGIN, -14))
	var plane: Sprite2D = Art.layer(Art.plane(), Art.world(-40, 6), -13)
	add_child(plane)
	var fly: Tween = create_tween().set_loops()
	fly.tween_property(plane, "position", Art.world(Art.W + 10, 26), 7.0).from(Art.world(-40, 4))
	fly.tween_interval(5.0)
	var half: float = float((Art.OPEN_X1 - Art.OPEN_X0) / 2 * Art.N)
	_door_l = Art.layer(Art.door_panel(), Art.world(Art.OPEN_X0, Art.OPEN_T), -13)
	_door_r = Art.layer(Art.door_panel(), Art.world(Art.OPEN_X0, Art.OPEN_T) + Vector2(half, 0), -13)
	add_child(_door_l)
	add_child(_door_r)
	add_child(Art.layer(Art.hall(), Art.ORIGIN, -12))
	_build_crowd()
	add_child(Art.layer(Art.rails(), Art.ORIGIN, -9))
	add_child(Art.layer(Art.trolley(), Vector2(-360, 170), -8))
	var cart2: Sprite2D = Art.layer(Art.trolley(), Vector2(1000, -190), -11)
	cart2.flip_h = true
	add_child(cart2)
	_build_player()

# Chauffeurs de la cooperativa derrière les garde-corps, pancarte levée.
func _build_crowd() -> void:
	var spots: Array = [
		[Vector2(-170, 90), 2.1, false], [Vector2(-40, 20), 1.9, false], [Vector2(-230, -60), 1.7, false],
		[Vector2(40, 140), 2.2, false],
		[Vector2(520, 130), 2.2, true], [Vector2(660, 60), 2.0, true], [Vector2(800, 140), 2.2, true],
		[Vector2(930, 40), 1.9, true], [Vector2(1080, 120), 2.1, true], [Vector2(590, -60), 1.7, true],
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2024
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
	for i in spots.size():
		var feet: Vector2 = spots[i][0]
		var k: float = spots[i][1]
		var cfg: Dictionary = CharacterSpriteFactory.random_config(rng.randi())
		var spr: Sprite2D = char_sprite(CharacterSpriteFactory.CELL_H * k, cfg)
		# De profil vers l'allée, ou de face : ils guettent la porte.
		var row: int = CharacterSpriteFactory.DIR_RIGHT if i % 3 != 0 else CharacterSpriteFactory.DIR_DOWN
		spr.region_rect = Rect2(0, row * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		spr.flip_h = spots[i][2]
		spr.position = feet
		spr.z_index = -11
		add_child(spr)
		var placa: Sprite2D = Sprite2D.new()
		placa.texture = Art.driver_sign(i)
		placa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		placa.scale = Vector2(3.0 / k, 3.0 / k)
		placa.position = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.4)
		spr.add_child(placa)
		var bob: Tween = create_tween().set_loops()
		bob.tween_interval(rng.randf_range(0.2, 2.5))
		bob.tween_property(placa, "position:y", placa.position.y - 4.0, 0.35)
		bob.tween_property(placa, "position:y", placa.position.y, 0.35)

# Toi, chauffeur, de dos au premier plan : pancarte levée vers la porte.
func _build_player() -> void:
	var me: Sprite2D = char_sprite(CharacterSpriteFactory.CELL_H * 4.4)
	me.region_rect = Rect2(0, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	me.position = Vector2(-560, 700)
	me.z_index = 60
	add_child(me)
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var skin: Color = cfg.get("skin", Color(0.85, 0.65, 0.48))
	_player_sign = Art.layer(Art.player_sign_back(skin), Vector2(-680, 200), 61, 6.0)
	add_child(_player_sign)

# Porte automatique : les vantaux s'écartent à chaque passager puis se referment.
func _open_door() -> void:
	if _door_l == null:
		return
	var base: Vector2 = Art.world(Art.OPEN_X0, Art.OPEN_T)
	var half: float = float((Art.OPEN_X1 - Art.OPEN_X0) / 2 * Art.N)
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.set_parallel(true)
	_door_tween.tween_property(_door_l, "position:x", base.x - half + 9.0, 0.22)
	_door_tween.tween_property(_door_r, "position:x", base.x + half * 2.0 - 9.0, 0.22)
	_door_tween.chain().tween_interval(0.55)
	_door_tween.chain().tween_property(_door_l, "position:x", base.x, 0.3)
	_door_tween.parallel().tween_property(_door_r, "position:x", base.x + half, 0.3)

func _build_call_button() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_call_btn = Button.new()
	_call_btn.text = "É ELE ! 🙋"
	_call_btn.theme_type_variation = &"TouchButton"
	_call_btn.add_theme_font_size_override("font_size", 44)
	_call_btn.focus_mode = Control.FOCUS_NONE
	# Fond sombre : la pastille translucide se perdait sur le granito peint.
	var box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.82))
	_call_btn.add_theme_stylebox_override("normal", box)
	_call_btn.add_theme_stylebox_override("hover", box)
	_call_btn.anchor_left = 1.0
	_call_btn.anchor_right = 1.0
	_call_btn.anchor_top = 1.0
	_call_btn.anchor_bottom = 1.0
	_call_btn.offset_left = -470.0
	_call_btn.offset_right = -40.0
	_call_btn.offset_top = -210.0
	_call_btn.offset_bottom = -40.0
	_call_btn.button_down.connect(_call_current)
	ui.add_child(_call_btn)
	SafeArea.apply(_call_btn)

func _label(pos: Vector2, size: Vector2, font: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 100
	add_child(l)
	return l

func _start_round() -> void:
	_clear_passengers()
	if _round >= ROUNDS:
		_end_game()
		return
	var n: int = 6 + _round
	var decoys: int = 1 + _round / 2
	var data: Dictionary = make_round(_rng, n, decoys)
	_client = data.client
	_client["name"] = CLIENTS[_round % CLIENTS.size()]
	_spawn_queue = data.passengers
	_queue_total = _spawn_queue.size()
	_stop_time = maxf(STOP_TIME_START - STOP_TIME_STEP * _round, STOP_TIME_MIN)
	if _card:
		_card.text = _client.name
	if _chips.size() == 3:
		_chips[0].color = SHIRTS[_client.shirt]
		# Sans chapéu = pastille « vide » (cheveux nus), sinon la couleur du couvre-chef.
		_chips[1].color = HAT_COLORS.get(_client.hat, Color(0.55, 0.5, 0.45, 0.35))
		_chips[2].color = BAGS[_client.bag]
	if _hat_icon:
		_hat_icon.texture = Art.icon(HATS[_client.hat])
	if _chip_caps.size() == 3:
		_chip_caps[0].text = "camisa\n%s" % _client.shirt
		_chip_caps[1].text = "cabeça\n%s" % _client.hat
		_chip_caps[2].text = "%s" % _client.bag.replace("mala ", "mala\n")
	_set_status("Ils sortent un par un. C'est ton client ? « É ELE ! » — sinon laisse passer.")
	_spawn_next()

func _clear_passengers() -> void:
	for p in _passengers:
		if is_instance_valid(p.sprite):
			p.sprite.queue_free()
	_passengers.clear()
	if _stop_bar:
		_stop_bar.visible = false

func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		return
	var attrs: Dictionary = _spawn_queue.pop_front()
	var config: Dictionary = CharacterSpriteFactory.random_config(_rng.randi())
	config["shirt_color"] = SHIRTS[attrs.shirt]
	config["shirt_pattern"] = "solid"
	config["hat_style"] = HATS[attrs.hat]
	config["hat_color"] = HAT_COLORS.get(attrs.hat, Color(0.2, 0.18, 0.2, 1))
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = CharacterSpriteFactory.build_sheet(config)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
	spr.scale = Vector2(SCALE_FAR, SCALE_FAR)
	spr.position = GATE_POS
	spr.z_index = 10
	add_child(spr)
	# Ombre au sol et valise peinte (corps de la couleur exacte de la carte).
	var shadow: Sprite2D = Art.layer(Art.shadow(), Vector2(-24, -6), -1, 3.0)
	shadow.z_as_relative = true
	spr.add_child(shadow)
	var bag: Sprite2D = Art.layer(Art.suitcase(BAGS[attrs.bag]), Vector2(BAG_X, -40), 0, 3.0)
	bag.name = "Mala"
	spr.add_child(bag)
	_open_door()
	_passengers.append({"attrs": attrs, "sprite": spr, "state": PState.ARRIVING, "t": 0.0, "called": false})

func _current() -> Dictionary:
	for p in _passengers:
		if p.state != PState.LEAVING:
			return p
	return {}

func _process(delta: float) -> void:
	if _ended:
		return
	if _between > 0.0:
		_between -= delta
		if _between <= 0.0:
			_start_round()
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_call_current()
	for p in _passengers.duplicate():
		_advance(p, delta)
		if _between > 0.0 or _ended:
			return
	if _hud:
		var idx: int = _queue_total - _spawn_queue.size()
		_hud.text = "🛬 client %d/%d · passager %d/%d · %d pts · R$ %d" \
			% [mini(_round + 1, ROUNDS), ROUNDS, idx, _queue_total, _score, _cash]

func _advance(p: Dictionary, delta: float) -> void:
	var spr: Sprite2D = p.sprite
	p.t += delta
	_pose(p)
	match p.state:
		PState.ARRIVING:
			var k: float = clampf(p.t / WALK_IN_TIME, 0.0, 1.0)
			spr.position = GATE_POS.lerp(STOP_POS, k)
			var sc: float = lerpf(SCALE_FAR, SCALE_NEAR, k)
			spr.scale = Vector2(sc, sc)
			if k >= 1.0:
				p.state = PState.PRESENTING
				p.t = 0.0
				sfx("prompt_chime", 1.2)
		PState.PRESENTING:
			if _stop_bar:
				_stop_bar.visible = true
				_stop_bar.size.x = 180.0 * clampf(1.0 - p.t / _stop_time, 0.0, 1.0)
				_stop_bar.color = Color(0.35, 0.8, 0.45, 1) if p.t <= _stop_time * 0.5 else Color(0.95, 0.8, 0.3, 1)
			if p.t >= _stop_time:
				_send_off(p)
		PState.LEAVING:
			spr.position.x += WALK_OUT_SPEED * delta
			if spr.position.x > 1200.0:
				spr.queue_free()
				_passengers.erase(p)
				if matches(p.attrs, _client) and not p.called:
					sfx("mg_miss")
					pulse(0.5, 0.15)
					_set_status("😤 %s est parti avec un chauffeur de la cooperativa…" % _client.name)
					_pop_word("PERDEU…", Color(0.8, 0.82, 0.88), STOP_POS + Vector2(0, -380))
					_next_round()

# Le passager reprend sa route ; le suivant sort de la porte.
func _send_off(p: Dictionary) -> void:
	p.state = PState.LEAVING
	p.t = 0.0
	if _stop_bar:
		_stop_bar.visible = false
	_spawn_next()

func _call_current() -> void:
	var p: Dictionary = _current()
	if not p.is_empty():
		_call(p)

# Toucher un passager à l'écran = l'appeler (même geste que le bouton).
func tap_at(world: Vector2) -> void:
	if _ended or _between > 0.0:
		return
	var best: Dictionary = {}
	var best_d: float = TAP_RADIUS
	for p in _passengers:
		var spr: Sprite2D = p.sprite
		var centre: Vector2 = spr.position + Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5 * spr.scale.y)
		var d: float = minf(centre.distance_to(world), spr.position.distance_to(world))
		if d < best_d:
			best_d = d
			best = p
	if not best.is_empty():
		_call(best)

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(get_global_mouse_position())

func _call(p: Dictionary) -> void:
	if _ended or _between > 0.0 or p.called:
		return
	if matches(p.attrs, _client):
		p.called = true
		# Appelé pendant l'approche ou la 1re moitié de l'arrêt = Perfeito.
		var fast: bool = p.state == PState.ARRIVING \
				or (p.state == PState.PRESENTING and p.t <= _stop_time * 0.5)
		_score += 3 if fast else 2
		_cash += FARE + (FAST_TIP if fast else 0)
		sfx("coin")
		if fast:
			sfx("mg_perfect")
			pulse(0.35, 0.06)
			_found_fast += 1
			_set_status("✨ PERFEITO — « Sou eu ! Que motorista esperto. » (+R$ %d)" % (FARE + FAST_TIP))
		else:
			sfx("mg_good")
			_set_status("✔ Boa — c'est lui, il te suit. (+R$ %d)" % FARE)
		_cheer(p, fast)
		_next_round()
	else:
		p.called = true
		_score = maxi(_score - WRONG_PENALTY, 0)
		sfx("mg_miss")
		pulse(0.4, 0.1)
		_set_status("✖ « Não sou eu, moço. » Relis ta plaque.")
		_frown(p)
		if p.state != PState.LEAVING:
			_send_off(p)

# --- Mise en scène (aucune règle) ---

# Pas de marche : vers toi en descendant, de profil en repartant vers la sortie.
func _pose(p: Dictionary) -> void:
	var spr: Sprite2D = p.sprite
	if not is_instance_valid(spr):
		return
	var row: int = CharacterSpriteFactory.DIR_DOWN
	var frame: int = 0
	if p.state == PState.ARRIVING:
		frame = 1 + int(p.t / 0.12) % 2
	elif p.state == PState.LEAVING:
		row = CharacterSpriteFactory.DIR_RIGHT
		frame = 1 + int(p.t / 0.1) % 2
	spr.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	var bag: Node2D = spr.get_node_or_null("Mala")
	if bag:
		bag.position.x = -44.0 if p.state == PState.LEAVING else BAG_X

func _bubble(spr: Sprite2D, kind: String) -> void:
	var b: Sprite2D = Art.layer(Art.bubble(kind), Vector2(10, -CharacterSpriteFactory.CELL_H - 30), 5, 2.0)
	spr.add_child(b)
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "position:y", b.position.y - 6.0, 0.15)
	tw.tween_property(b, "position:y", b.position.y, 0.15)

# Mot qui éclate au-dessus de la scène (Perfeito / Boa / raté).
func _pop_word(text: String, color: Color, at: Vector2) -> void:
	var l: Label = _label(at - Vector2(400, 40), Vector2(800, 80), 66, color)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1, 1))
	l.z_index = 95
	l.pivot_offset = l.size * 0.5
	l.text = text
	l.scale = Vector2(0.4, 0.4)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

# Le bon client te reconnaît : il saute, fait coucou ; ta pancarte s'agite.
func _cheer(p: Dictionary, fast: bool) -> void:
	var spr: Sprite2D = p.sprite
	if not is_instance_valid(spr):
		return
	_pose(p)
	_bubble(spr, "wave")
	var head: Vector2 = spr.position + Vector2(0, -CharacterSpriteFactory.CELL_H * spr.scale.y)
	var hop: Tween = spr.create_tween()
	var base_y: float = spr.offset.y
	for i in 2:
		hop.tween_property(spr, "offset:y", base_y - 7.0, 0.11)
		hop.tween_property(spr, "offset:y", base_y, 0.11)
	if fast:
		var star: Sprite2D = Sprite2D.new()
		star.texture = Art.burst()
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.position = head + Vector2(0, 60)
		star.z_index = 94
		star.scale = Vector2(3, 3)
		add_child(star)
		var st: Tween = star.create_tween().set_parallel(true)
		st.tween_property(star, "scale", Vector2(8, 8), 0.45).set_ease(Tween.EASE_OUT)
		st.tween_property(star, "modulate:a", 0.0, 0.45).set_delay(0.15)
		st.chain().tween_callback(star.queue_free)
		_pop_word("PERFEITO !", Color(1.0, 0.85, 0.2), head + Vector2(0, -90))
	else:
		_pop_word("BOA !", Color(0.55, 0.95, 0.55), head + Vector2(0, -90))
	if _player_sign:
		var ps: Tween = _player_sign.create_tween()
		ps.tween_property(_player_sign, "position:y", 172.0, 0.1)
		ps.tween_property(_player_sign, "position:y", 200.0, 0.12)
		ps.tween_property(_player_sign, "position:y", 172.0, 0.1)
		ps.tween_property(_player_sign, "position:y", 200.0, 0.12)

# Le mauvais passager fronce les sourcils et secoue la tête.
func _frown(p: Dictionary) -> void:
	var spr: Sprite2D = p.sprite
	if not is_instance_valid(spr):
		return
	_bubble(spr, "frown")
	var tw: Tween = spr.create_tween()
	for i in 3:
		tw.tween_property(spr, "offset:x", 4.0, 0.04)
		tw.tween_property(spr, "offset:x", -4.0, 0.04)
	tw.tween_property(spr, "offset:x", 0.0, 0.04)
	var tint: Tween = spr.create_tween()
	tint.tween_property(spr, "modulate", Color(1.0, 0.7, 0.7), 0.08)
	tint.tween_property(spr, "modulate", Color.WHITE, 0.3)
	_pop_word("NÃO É ELE !", Color(1.0, 0.45, 0.4), spr.position + Vector2(0, -CharacterSpriteFactory.CELL_H * spr.scale.y - 90))

func _next_round() -> void:
	_round += 1
	_between = 1.4

func _set_status(text: String) -> void:
	if _status:
		_status.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	_clear_passengers()
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if qualifies:
		_set_status("Fin du service — %d pts, R$ %d. A cooperativa já sabe teu nome." % [_score, _cash])
	else:
		_set_status("Fin du service — %d pts (min. %d), R$ %d. Le hall d'arrivée, ça s'apprend." % [_score, QUALIFY_SCORE, _cash])
	await get_tree().create_timer(bilan_delay(2.0)).timeout
	EventBus.minigame_ended.emit("desembarque",
		{"score": _score, "cash": _cash, "fast": _found_fast, "qualifies": qualifies})
	match_ended.emit(qualifies, _cash)
