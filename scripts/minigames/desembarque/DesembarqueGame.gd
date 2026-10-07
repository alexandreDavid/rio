class_name DesembarqueGame
extends Node2D

# Desembarque — le hall des arrivées de Santos Dumont, plaque de chauffeur en
# main. La ponte aérea crache ses passagers : une fiche donne trois indices
# (chemise, chapeau, valise) et UN SEUL passager les a tous. Touche-le avant
# qu'il ne passe la sortie — sinon la cooperativa te le prend. Les leurres
# partagent deux indices sur trois, de plus en plus nombreux.
# Trouvé en moins de FAST_SEC = Perfeito (3 pts), sinon Boa (2) ; raté = 0.
# Un mauvais passager touché = « Não sou eu, moço » et du temps perdu.
# Contrat : match_ended(qualifies, cash) ; minigame_ended("desembarque", {...}).

signal match_ended(qualifies: bool, cash: int)

const ROUNDS: int = 6
const QUALIFY_SCORE: int = 12       # max 18
const FAST_SEC: float = 5.0
const WRONG_PENALTY: float = 2.5
const FARE: int = 18
const FAST_TIP: int = 7
const GATE_Y: float = -330.0
const EXIT_Y: float = 420.0
const WALK_SPEED: Vector2 = Vector2(70.0, 110.0)
const TAP_RADIUS: float = 90.0
const SPRITE_SCALE: float = 1.6

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
var _round_time: float = 0.0
var _client: Dictionary = {}
var _passengers: Array = []      # [{attrs, sprite, bag, vel}]
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _between: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _hud: Label
var _card: Label
var _status: Label

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
	var quit_btn: CanvasLayer = get_node_or_null("MinigameQuitButton")
	if quit_btn and quit_btn.has_signal("quit_pressed"):
		quit_btn.quit_pressed.connect(_end_game)
	_hud = _label(Vector2(-900, -530), Vector2(1800, 46), 28, Color(0.98, 0.97, 0.92, 1))
	_card = _label(Vector2(-560, -470), Vector2(1120, 110), 30, Color(0.1, 0.1, 0.12, 1))
	_card.add_theme_constant_override("outline_size", 0)
	var card_bg: ColorRect = ColorRect.new()
	card_bg.position = _card.position
	card_bg.size = _card.size
	card_bg.color = Color(0.98, 0.95, 0.82, 1)
	card_bg.z_index = 99
	add_child(card_bg)
	_status = _label(Vector2(-900, 470), Vector2(1800, 56), 24, Color(0.16, 0.14, 0.12, 1))
	_status.add_theme_constant_override("outline_size", 0)
	_start_round()

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
	_spawn_timer = 0.0
	_round_time = 0.0
	if _card:
		_card.text = "🪧 %s\n%s" % [_client.name, describe(_client)]
	_set_status("Le vol de São Paulo débarque… Trouve %s !" % _client.name)

func _clear_passengers() -> void:
	for p in _passengers:
		if is_instance_valid(p.sprite):
			p.sprite.queue_free()
	_passengers.clear()

func _spawn_passenger(attrs: Dictionary) -> void:
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
	spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	spr.position = Vector2(_rng.randf_range(-700, 700), GATE_Y)
	add_child(spr)
	var bag: ColorRect = ColorRect.new()
	bag.color = BAGS[attrs.bag]
	bag.size = Vector2(34, 44)
	bag.position = Vector2(26, 6)
	spr.add_child(bag)
	bag.scale = Vector2(1.0 / SPRITE_SCALE, 1.0 / SPRITE_SCALE)
	var vel: Vector2 = Vector2(_rng.randf_range(-35, 35), _rng.randf_range(WALK_SPEED.x, WALK_SPEED.y) * (1.0 + _round * 0.08))
	_passengers.append({"attrs": attrs, "sprite": spr, "vel": vel})

func _process(delta: float) -> void:
	if _ended:
		return
	if _between > 0.0:
		_between -= delta
		if _between <= 0.0:
			_start_round()
		return
	_round_time += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
		_spawn_passenger(_spawn_queue.pop_front())
		_spawn_timer = maxf(0.45, 1.1 - _round * 0.1)
	for p in _passengers.duplicate():
		var spr: Sprite2D = p.sprite
		spr.position += p.vel * delta
		# Le plus bas (le plus proche) passe devant.
		spr.z_index = clampi(int((spr.position.y - GATE_Y) / 20.0), 0, 60)
		if spr.position.x < -880.0 or spr.position.x > 880.0:
			p.vel.x = -p.vel.x
		if spr.position.y > EXIT_Y:
			if matches(p.attrs, _client):
				_set_status("😤 %s est parti avec un chauffeur de la cooperativa…" % _client.name)
				_next_round()
				return
			spr.queue_free()
			_passengers.erase(p)
	if _hud:
		_hud.text = "🛬 Desembarque · client %d/%d · %d pts · R$ %d" % [mini(_round + 1, ROUNDS), ROUNDS, _score, _cash]

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_end_game()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(get_global_mouse_position())
		get_viewport().set_input_as_handled()

# Touche le passager le plus proche du point (monde). Public pour les tests.
func tap_at(world: Vector2) -> void:
	if _ended or _between > 0.0:
		return
	var best: Dictionary = {}
	var best_d: float = TAP_RADIUS
	for p in _passengers:
		var d: float = (p.sprite.position + Vector2(0, 0)).distance_to(world)
		if d < best_d:
			best_d = d
			best = p
	if best.is_empty():
		return
	if matches(best.attrs, _client):
		var fast: bool = _round_time <= FAST_SEC
		_score += 3 if fast else 2
		_cash += FARE + (FAST_TIP if fast else 0)
		if fast:
			_found_fast += 1
			_set_status("✨ PERFEITO — « Sou eu ! Que motorista esperto. » (+R$ %d)" % (FARE + FAST_TIP))
		else:
			_set_status("✔ Boa — trouvé, il monte. (+R$ %d)" % FARE)
		_next_round()
	else:
		_round_time += WRONG_PENALTY
		_set_status("✖ « Não sou eu, moço. » Relis la fiche : %s" % describe(_client))

func _next_round() -> void:
	_round += 1
	_between = 1.2
	_clear_passengers()

func _set_status(text: String) -> void:
	if _status:
		_status.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	_clear_passengers()
	var qualifies: bool = _score >= QUALIFY_SCORE
	if qualifies:
		_set_status("Fin du service — %d pts, R$ %d. A cooperativa já sabe teu nome." % [_score, _cash])
	else:
		_set_status("Fin du service — %d pts (min. %d), R$ %d. Le hall d'arrivée, ça s'apprend." % [_score, QUALIFY_SCORE, _cash])
	await get_tree().create_timer(2.0).timeout
	EventBus.minigame_ended.emit("desembarque",
		{"score": _score, "cash": _cash, "fast": _found_fast, "qualifies": qualifies})
	match_ended.emit(qualifies, _cash)
