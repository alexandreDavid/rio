class_name PadariaGame
extends Node2D

# Mini-jeu fournil de la Padaria São Sebastião.
# Cycle :
#   1) ramasser farine / eau / queijo, les déposer sur la plaque (3 ingrédients)
#   2) prendre la plaque crue, l'enfourner
#   3) cuisson : 0-4 s = cru ; 4-8 s = parfait ; 8-11 s = trop cuit ; > 11 s = brûlé
#   4) sortie du four → la plaque arrive directement en main
#   5) déposer dans le panier (vente) ou dans la poubelle (jeter)
# Affordances : labels contextuels au-dessus du joueur, stations highlights selon
# l'action possible, plaque qui change de teinte avec le temps de cuisson.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 100.0
const MAX_BATCHES: int = 5

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const PLAYER_RADIUS: float = 24.0
const PLAYER_SPEED: float = 540.0
const INTERACT_RANGE: float = 120.0

const COOK_PERFECT_MIN: float = 4.0
const COOK_PERFECT_MAX: float = 8.0
const COOK_BURN: float = 11.0

const TIP_RAW: int = 6
const TIP_PERFECT: int = 22
const TIP_OVERCOOK: int = 10
const PENALTY_BURNT: int = 0
const PENALTY_RAW_DUMP: int = 0

const PLATE_HOME: Vector2 = Vector2(700, 540)
const OVEN_INSIDE: Vector2 = Vector2(700, 820)

const STATIONS: Dictionary = {
	"flour":  Vector2(260, 280),
	"water":  Vector2(660, 280),
	"queijo": Vector2(1060, 280),
	"plate":  Vector2(700, 540),
	"oven":   Vector2(700, 820),
	"basket": Vector2(1500, 820),
	"trash":  Vector2(1740, 820),
}

const RECIPE: Array[String] = ["flour", "water", "queijo"]

const INGREDIENT_COLORS: Dictionary = {
	"flour":  Color(0.95, 0.92, 0.85, 1),
	"water":  Color(0.4, 0.65, 0.95, 1),
	"queijo": Color(0.95, 0.85, 0.45, 1),
}

const INGREDIENT_LABELS: Dictionary = {
	"flour":  "Farine",
	"water":  "Eau",
	"queijo": "Queijo",
}

var _time_left: float = DURATION
var _ended: bool = false
var _batches_sold: int = 0
var _total_tips: int = 0

var _player_pos: Vector2 = Vector2(960.0, 540.0)
var _carry: String = ""  # "" / "flour" / "water" / "queijo" / "plate_raw" / "plate_baked" / "plate_burnt"

var _plate_ingredients: Dictionary = {"flour": false, "water": false, "queijo": false}
var _plate_status: String = "ASSEMBLY"  # ASSEMBLY / BAKING (in oven) / BAKED (on counter) / CARRIED
var _plate_in_oven: bool = false
var _plate_cook_time: float = 0.0

@onready var arena: Node2D = $Arena
@onready var player_node: ColorRect = $Arena/Player
@onready var carry_dot: ColorRect = $Arena/Player/CarryDot
@onready var context_label: Label = $Arena/Player/Context
@onready var plate_root: Node2D = $Arena/Plate
@onready var plate_base: ColorRect = $Arena/Plate/Base
@onready var plate_flour: ColorRect = $Arena/Plate/Flour
@onready var plate_water: ColorRect = $Arena/Plate/Water
@onready var plate_queijo: ColorRect = $Arena/Plate/Queijo
@onready var oven_glow: ColorRect = $Arena/Oven/Glow
@onready var oven_smoke: ColorRect = $Arena/Oven/Smoke
@onready var flour_bin: ColorRect = $Arena/FlourBin
@onready var water_tap: ColorRect = $Arena/WaterTap
@onready var queijo_box: ColorRect = $Arena/QueijoBox
@onready var counter_highlight: ColorRect = $Arena/CounterHighlight
@onready var basket: ColorRect = $Arena/Basket
@onready var trash: ColorRect = $Arena/Trash
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var tip_label: Label = $UI/Tips
@onready var prompt_label: Label = $UI/Prompt
@onready var cook_label: Label = $UI/CookLabel
@onready var cook_bar_fill: ColorRect = $UI/CookBar/Fill
@onready var cook_bar_root: Control = $UI/CookBar
@onready var cook_perfect_marker_a: ColorRect = $UI/CookBar/PerfectStart
@onready var cook_perfect_marker_b: ColorRect = $UI/CookBar/PerfectEnd
@onready var tutorial_root: Control = $UI/Tutorial
@onready var tutorial_button: Button = $UI/Tutorial/Panel/Margin/Layout/StartButton
@onready var help_button: Button = $UI/HelpButton

const COOK_BAR_WIDTH: float = 360.0

var _tutorial_visible: bool = true

func _ready() -> void:
	EventBus.minigame_started.emit("padaria")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_set_status("Bom dia ! Trois ingrédients sur la plaque, puis four, puis panier.")
	if prompt_label:
		prompt_label.text = "[E] Prendre · Déposer · Sortir du four · Vendre · Jeter"
	_position_perfect_markers()
	_refresh_plate_visuals()
	_refresh_oven_smoke()
	if tutorial_button:
		tutorial_button.pressed.connect(_close_tutorial)
	if help_button:
		help_button.pressed.connect(_open_tutorial)
	if tutorial_root:
		tutorial_root.visible = true
	if help_button:
		help_button.visible = false  # caché tant que le tuto est ouvert

func _position_perfect_markers() -> void:
	if cook_perfect_marker_a:
		cook_perfect_marker_a.position.x = COOK_BAR_WIDTH * (COOK_PERFECT_MIN / COOK_BURN)
	if cook_perfect_marker_b:
		cook_perfect_marker_b.position.x = COOK_BAR_WIDTH * (COOK_PERFECT_MAX / COOK_BURN) - 4.0

func _process(delta: float) -> void:
	if _ended:
		return
	# Tutoriel ouvert : la session est gelée, le timer ne défile pas, le joueur ne bouge pas.
	if _tutorial_visible:
		return
	_time_left -= delta
	if _time_left <= 0.0 or _batches_sold >= MAX_BATCHES:
		_end_game()
		return
	_update_player(delta)
	_update_oven(delta)
	_update_visuals()
	_update_labels()

func _close_tutorial() -> void:
	_tutorial_visible = false
	if tutorial_root:
		tutorial_root.visible = false
	if help_button:
		help_button.visible = true

func _open_tutorial() -> void:
	_tutorial_visible = true
	if tutorial_root:
		tutorial_root.visible = true
	if help_button:
		help_button.visible = false

func _update_player(delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	_player_pos += dir * PLAYER_SPEED * delta
	_player_pos.x = clamp(_player_pos.x, PLAYER_RADIUS, ARENA_W - PLAYER_RADIUS)
	_player_pos.y = clamp(_player_pos.y, PLAYER_RADIUS, ARENA_H - PLAYER_RADIUS)
	if player_node:
		player_node.position = _player_pos - Vector2(PLAYER_RADIUS, PLAYER_RADIUS)
	# Si la plaque est portée, elle suit le joueur.
	if _carry.begins_with("plate_") and plate_root:
		plate_root.position = _player_pos
	if Input.is_action_just_pressed("interact"):
		_handle_interact()

# --- Interaction contextuelle ---

func _handle_interact() -> void:
	var station: String = _nearest_station()
	if station == "":
		return
	match station:
		"flour", "water", "queijo":
			_act_at_ingredient_bin(station)
		"plate":
			_act_at_plate_counter()
		"oven":
			_act_at_oven()
		"basket":
			_act_at_basket()
		"trash":
			_act_at_trash()

func _nearest_station() -> String:
	var best: String = ""
	var best_dist: float = INTERACT_RANGE
	for k in STATIONS:
		var d: float = _player_pos.distance_to(STATIONS[k])
		if d < best_dist:
			best_dist = d
			best = k
	return best

func _act_at_ingredient_bin(ingredient: String) -> void:
	# Sans rien : on prend l'ingrédient.
	if _carry == "":
		_carry = ingredient
		_set_status("Tu portes : %s. Direction la plaque." % INGREDIENT_LABELS[ingredient])
		return
	# Avec le même ingrédient en main : on le repose (mains libres).
	if _carry == ingredient:
		_carry = ""
		_set_status("Ingrédient reposé.")
		return
	# Avec un autre ingrédient en main : on échange.
	if _carry in RECIPE:
		_carry = ingredient
		_set_status("Tu portes : %s." % INGREDIENT_LABELS[ingredient])

func _act_at_plate_counter() -> void:
	# Plaque dans le four : pas d'action ici.
	if _plate_in_oven:
		_set_status("La plaque est dans le four — sors-la avant.")
		return
	# Plaque cuite posée sur le plan, mains libres : on la prend.
	if _plate_status == "BAKED" and _carry == "":
		_carry = _carry_kind_for_baked()
		_set_status("Plaque cuite en main. Vente au panier, ou poubelle si brûlée.")
		return
	# Plaque en assemblage : dépose un ingrédient.
	if _plate_status == "ASSEMBLY":
		if _carry in RECIPE:
			if _plate_ingredients.get(_carry, false):
				_set_status("Cet ingrédient est déjà sur la plaque.")
				return
			_plate_ingredients[_carry] = true
			_carry = ""
			_refresh_plate_visuals()
			if _all_ingredients_in():
				_set_status("Plaque prête. Prends-la (E) puis enfourne.")
			else:
				_set_status("Continue à assembler la plaque.")
			return
		# Plaque pleine + mains libres : on la prend.
		if _carry == "" and _all_ingredients_in():
			_carry = "plate_raw"
			_plate_status = "CARRIED"
			_set_status("Plaque crue en main. Direction le four.")

func _act_at_oven() -> void:
	# Enfourner.
	if _carry == "plate_raw" and not _plate_in_oven:
		_plate_in_oven = true
		_plate_status = "BAKING"
		_plate_cook_time = 0.0
		_carry = ""
		if plate_root:
			plate_root.position = OVEN_INSIDE
		if oven_glow:
			oven_glow.modulate = Color(1.0, 0.55, 0.15, 0.95)
		_set_status("Cuisson lancée. Sors la plaque entre 4 s et 8 s.")
		return
	# Sortir du four → directement en main, sans étape intermédiaire.
	if _carry == "" and _plate_in_oven and _plate_status == "BAKING":
		_plate_in_oven = false
		_plate_status = "CARRIED"
		_carry = _carry_kind_for_baked()
		if oven_glow:
			oven_glow.modulate = Color(0.4, 0.4, 0.4, 0.4)
		_refresh_oven_smoke()
		_set_status(_label_for_baked() + " Direction le panier de vente.")

func _act_at_basket() -> void:
	if not _carry.begins_with("plate_"):
		return
	var tip: int = 0
	match _carry:
		"plate_baked":
			var t: float = _plate_cook_time
			if t < COOK_PERFECT_MIN:
				tip = TIP_RAW
			elif t <= COOK_PERFECT_MAX:
				tip = TIP_PERFECT
			elif t < COOK_BURN:
				tip = TIP_OVERCOOK
			else:
				tip = PENALTY_BURNT
		"plate_burnt":
			tip = PENALTY_BURNT
		"plate_raw":
			tip = PENALTY_RAW_DUMP
	_total_tips += tip
	_batches_sold += 1
	_carry = ""
	_reset_plate()
	if tip > 0:
		_set_status("+R$ %d ! Fournée %d/%d." % [tip, _batches_sold, MAX_BATCHES])
	else:
		_set_status("Vendue 0 — recommence (%d/%d)." % [_batches_sold, MAX_BATCHES])

func _act_at_trash() -> void:
	# Jeter une plaque ratée sans pénaliser le compteur de fournées (on perd juste le temps).
	if _carry.begins_with("plate_"):
		_carry = ""
		_reset_plate()
		_set_status("Plaque jetée. Recommence quand tu veux.")
		return
	# Permet aussi de jeter un ingrédient (utile si tu t'es trompé pendant que le four tourne).
	if _carry in RECIPE:
		_carry = ""
		_set_status("Ingrédient jeté.")

# --- État interne / cuisson ---

func _update_oven(delta: float) -> void:
	if not _plate_in_oven:
		return
	_plate_cook_time += delta

func _carry_kind_for_baked() -> String:
	return "plate_burnt" if _plate_cook_time >= COOK_BURN else "plate_baked"

func _label_for_baked() -> String:
	var t: float = _plate_cook_time
	if t < COOK_PERFECT_MIN:
		return "Trop crue."
	if t <= COOK_PERFECT_MAX:
		return "Parfaite !"
	if t < COOK_BURN:
		return "Trop cuite."
	return "Brûlée."

func _all_ingredients_in() -> bool:
	for k in RECIPE:
		if not _plate_ingredients.get(k, false):
			return false
	return true

func _reset_plate() -> void:
	_plate_ingredients = {"flour": false, "water": false, "queijo": false}
	_plate_status = "ASSEMBLY"
	_plate_in_oven = false
	_plate_cook_time = 0.0
	if plate_root:
		plate_root.position = PLATE_HOME
	_refresh_plate_visuals()
	_refresh_oven_smoke()

# --- Affordances visuelles ---

func _update_visuals() -> void:
	# Carry-dot au-dessus du joueur.
	if carry_dot:
		if _carry in RECIPE:
			carry_dot.visible = true
			carry_dot.color = INGREDIENT_COLORS[_carry]
		else:
			carry_dot.visible = false
	# Highlights des stations selon ce que le joueur peut faire.
	_highlight_station(flour_bin, _carry == "" and not _plate_ingredients.flour, Color(0.95, 0.92, 0.85, 1))
	_highlight_station(water_tap, _carry == "" and not _plate_ingredients.water, Color(0.4, 0.65, 0.95, 1))
	_highlight_station(queijo_box, _carry == "" and not _plate_ingredients.queijo, Color(0.95, 0.85, 0.45, 1))
	# Plan de travail : highlight si on porte un ingrédient utile, ou si la plaque est cuite et on n'a rien.
	var counter_active: bool = false
	if _carry in RECIPE and not _plate_ingredients[_carry] and _plate_status == "ASSEMBLY":
		counter_active = true
	elif _carry == "" and _plate_status == "ASSEMBLY" and _all_ingredients_in():
		counter_active = true
	elif _carry == "" and _plate_status == "BAKED":
		counter_active = true
	if counter_highlight:
		counter_highlight.visible = counter_active
	# Panier : actif quand on porte une plaque cuite/brûlée/crue.
	_highlight_station(basket, _carry.begins_with("plate_"), Color(0.85, 0.55, 0.3, 1))
	# Poubelle : accepte une plaque ratée OU un ingrédient mal pris.
	_highlight_station(trash, _carry.begins_with("plate_") or (_carry in RECIPE), Color(0.45, 0.45, 0.5, 1))
	# Plaque : tinte la base + ingrédients selon la cuisson.
	_tint_plate_for_cooking()
	_refresh_oven_smoke()

func _highlight_station(node: ColorRect, active: bool, base: Color) -> void:
	if node == null:
		return
	if active:
		var pulse: float = 1.15 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
		node.modulate = Color(pulse, pulse, pulse, 1)
	else:
		node.modulate = Color(0.85, 0.85, 0.85, 1)

func _tint_plate_for_cooking() -> void:
	# Calcule un facteur de cuisson 0..1.5 selon le temps passé au four (ou final).
	var t: float = _plate_cook_time
	var tint: Color = Color(1, 1, 1, 1)
	if t > 0.0:
		if t < COOK_PERFECT_MIN:
			tint = Color(1, 1, 1, 1)
		elif t <= COOK_PERFECT_MAX:
			# Doré : ingrédients prennent une teinte chaude.
			var k: float = (t - COOK_PERFECT_MIN) / (COOK_PERFECT_MAX - COOK_PERFECT_MIN)
			tint = Color(1.0, 0.92 - 0.15 * k, 0.7 - 0.3 * k, 1)
		elif t < COOK_BURN:
			tint = Color(0.85, 0.55, 0.35, 1)
		else:
			tint = Color(0.25, 0.18, 0.15, 1)
	for n in [plate_flour, plate_water, plate_queijo]:
		if n:
			n.modulate = tint

func _refresh_oven_smoke() -> void:
	if oven_smoke == null:
		return
	if not _plate_in_oven:
		oven_smoke.visible = false
		return
	# Fumée visible quand on dépasse la zone parfaite, intensifie au-delà.
	if _plate_cook_time < COOK_PERFECT_MAX:
		oven_smoke.visible = false
		return
	oven_smoke.visible = true
	var k: float = clamp((_plate_cook_time - COOK_PERFECT_MAX) / (COOK_BURN - COOK_PERFECT_MAX), 0.0, 1.0)
	oven_smoke.color = Color(0.35 + 0.3 * k, 0.35 + 0.1 * k, 0.35, 0.5 + 0.4 * k)

func _refresh_plate_visuals() -> void:
	if plate_flour:
		plate_flour.visible = _plate_ingredients.get("flour", false)
	if plate_water:
		plate_water.visible = _plate_ingredients.get("water", false)
	if plate_queijo:
		plate_queijo.visible = _plate_ingredients.get("queijo", false)
	if not _carry.begins_with("plate_") and not _plate_in_oven and plate_root:
		plate_root.position = PLATE_HOME

# Label contextuel au-dessus du joueur — "[E] Prendre la farine", "[E] Enfourner", etc.

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if tip_label:
		tip_label.text = "💰 R$ %d (%d/%d)" % [_total_tips, _batches_sold, MAX_BATCHES]
	# Cook bar visible uniquement quand four allumé.
	if cook_bar_root:
		cook_bar_root.visible = _plate_in_oven
	if cook_bar_fill and _plate_in_oven:
		var ratio: float = clamp(_plate_cook_time / COOK_BURN, 0.0, 1.0)
		cook_bar_fill.size.x = COOK_BAR_WIDTH * ratio
		var c: Color = Color(0.55, 0.85, 0.95, 1)
		if _plate_cook_time < COOK_PERFECT_MIN:
			c = Color(0.55, 0.85, 0.95, 1)
		elif _plate_cook_time <= COOK_PERFECT_MAX:
			c = Color(0.55, 0.95, 0.55, 1)
		elif _plate_cook_time < COOK_BURN:
			c = Color(0.95, 0.85, 0.45, 1)
		else:
			c = Color(0.95, 0.4, 0.4, 1)
		cook_bar_fill.color = c
	if cook_label:
		cook_label.visible = _plate_in_oven
		if _plate_in_oven:
			cook_label.text = "Four : %.1fs · %s" % [_plate_cook_time, _label_for_baked()]
	if context_label:
		context_label.text = _context_text()

func _context_text() -> String:
	var station: String = _nearest_station()
	if station == "":
		return ""
	match station:
		"flour", "water", "queijo":
			if _carry == "":
				if _plate_ingredients[station]:
					return ""
				return "[E] Prendre %s" % INGREDIENT_LABELS[station]
			if _carry == station:
				return "[E] Reposer %s" % INGREDIENT_LABELS[station]
			if _carry in RECIPE:
				return "[E] Échanger pour %s" % INGREDIENT_LABELS[station]
		"plate":
			if _plate_in_oven:
				return ""
			if _carry in RECIPE:
				if _plate_ingredients[_carry]:
					return "Déjà ajouté"
				return "[E] Déposer %s" % INGREDIENT_LABELS[_carry]
			if _carry == "":
				if _plate_status == "BAKED":
					return "[E] Prendre la plaque cuite"
				if _plate_status == "ASSEMBLY" and _all_ingredients_in():
					return "[E] Prendre la plaque crue"
		"oven":
			if _carry == "plate_raw":
				return "[E] Enfourner"
			if _carry == "" and _plate_in_oven:
				return "[E] Sortir du four"
		"basket":
			if _carry.begins_with("plate_"):
				return "[E] Vendre"
		"trash":
			if _carry.begins_with("plate_"):
				return "[E] Jeter la plaque"
			if _carry in RECIPE:
				return "[E] Jeter l'ingrédient"
	return ""

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _batches_sold > 0 and _total_tips > 0
	_set_status("Service terminé · %d fournées · R$ %d en tips" % [_batches_sold, _total_tips])
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("padaria", {"tips": _total_tips, "batches": _batches_sold, "qualifies": qualifies})
	match_ended.emit(qualifies, _total_tips)
