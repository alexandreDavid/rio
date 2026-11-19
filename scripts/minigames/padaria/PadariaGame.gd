class_name PadariaGame
extends MinigameBase

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

const ART := preload("res://scripts/minigames/padaria/PadariaArt.gd")

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

# La fila : les fregueses attendent leur pão de queijo. Sans fournée vendue
# dans ce délai, une freguesa abandonne (et le délai repart, plus court).
const FILA_PATIENCE: float = 32.0
const FILA_PATIENCE_MIN: float = 20.0
const FILA_SHRINK: float = 3.0
# Qualifié : 3 fournées vendues dont 1 parfaite, et la fila jamais vidée 2 fois.
const QUALIFY_BATCHES: int = 3
const MAX_FILA_LOST: int = 1
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
@onready var touch_controls: CanvasLayer = get_node_or_null("TouchControls")

const COOK_BAR_WIDTH: float = 360.0

var _tutorial_visible: bool = true
var _art: ART = null
# Captures hors jeu uniquement (outil de capture) : "play" saute le tutoriel ;
# "carry" / "oven" / "burn" posent en plus une situation à photographier.
var preview: String = ""

func _ready() -> void:
	EventBus.minigame_started.emit("padaria")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_set_status("Bom dia ! Trois ingrédients sur la plaque, puis four, puis panier.")
	if prompt_label:
		prompt_label.text = "Joystick : bouger · Bouton Action : prendre / déposer / vendre"
	_position_perfect_markers()
	_build_art()
	_refresh_plate_visuals()
	_refresh_oven_smoke()
	if tutorial_button:
		tutorial_button.pressed.connect(_close_tutorial)
	if help_button:
		help_button.pressed.connect(_open_tutorial)
		# Fond sombre : la pastille translucide se perdait sur le décor peint.
		var help_box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.82))
		help_button.add_theme_stylebox_override("normal", help_box)
		help_button.add_theme_stylebox_override("hover", help_box)
	if tutorial_root:
		tutorial_root.add_to_group("gamepad_menu")
		tutorial_root.visible = true
		GamepadBridge.focus_first.call_deferred(tutorial_root)
	if help_button:
		help_button.visible = false  # caché tant que le tuto est ouvert
	if touch_controls:
		touch_controls.visible = false
	if preview != "":
		_apply_preview.call_deferred()

func _build_art() -> void:
	_art = ART.new()
	arena.add_child(_art)
	_art.build({
		"player": player_node, "plate": plate_root, "counter_hl": counter_highlight,
		"stations": {"flour": flour_bin, "water": water_tap, "queijo": queijo_box, "basket": basket, "trash": trash},
	})
	for n in ["FlourLabel", "WaterLabel", "QueijoLabel", "CounterLabel", "OvenLabel", "BasketLabel", "TrashLabel"]:
		var l: Label = arena.get_node_or_null(n) as Label
		if l:
			PixelFont.style_world_label(l)
	if context_label:
		PixelFont.style_world_label(context_label)
	_illustrate_tutorial()

# Rangée d'icônes peintes en tête du tutoriel : la recette en images.
func _illustrate_tutorial() -> void:
	var layout: Node = get_node_or_null("UI/Tutorial/Panel/Margin/Layout")
	if layout == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var imgs: Array[Image] = [ART.paint_flour(), ART.paint_water(), ART.paint_queijo(),
		ART.paint_tray(7, 0), ART.paint_oven(), ART.paint_tray(7, 2), ART.paint_basket()]
	for i in imgs.size():
		if i == 3 or i == 4 or i == 5 or i == 6:
			var arrow: Label = Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 33)
			arrow.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
			row.add_child(arrow)
		var tr: TextureRect = TextureRect.new()
		tr.texture = ImageTexture.create_from_image(imgs[i])
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(150, 120)
		row.add_child(tr)
	layout.add_child(row)
	layout.move_child(row, 2)

func _apply_preview() -> void:
	_close_tutorial()
	match preview:
		"carry":
			_plate_ingredients = {"flour": true, "water": true, "queijo": false}
			_carry = "queijo"
			_player_pos = Vector2(900, 420)
		"oven", "burn":
			_plate_ingredients = {"flour": true, "water": true, "queijo": true}
			_plate_in_oven = true
			_plate_status = "BAKING"
			_plate_cook_time = 5.0 if preview == "oven" else 9.0
			if plate_root:
				plate_root.position = OVEN_INSIDE
			_player_pos = Vector2(820, 640)
			_fila_left = 6.0
		"sell":
			_plate_ingredients = {"flour": true, "water": true, "queijo": true}
			_plate_status = "CARRIED"
			_plate_cook_time = 6.0
			_carry = "plate_baked"
			_player_pos = Vector2(1500, 920)
			_fila_left = 5.0
			get_tree().create_timer(1.0).timeout.connect(_act_at_basket)
	_refresh_plate_visuals()

func _position_perfect_markers() -> void:
	if cook_perfect_marker_a:
		cook_perfect_marker_a.position.x = COOK_BAR_WIDTH * (COOK_PERFECT_MIN / COOK_BURN)
	if cook_perfect_marker_b:
		cook_perfect_marker_b.position.x = COOK_BAR_WIDTH * (COOK_PERFECT_MAX / COOK_BURN) - 4.0

var _fila_left: float = FILA_PATIENCE
var _fila_patience: float = FILA_PATIENCE
var _fila_lost: int = 0
var _perfect_batches: int = 0

func _process(delta: float) -> void:
	if _art:
		_art.tick(delta, _art_state())
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
	_update_fila(delta)
	_update_visuals()
	_update_labels()

func _update_fila(delta: float) -> void:
	var before: float = _fila_left
	_fila_left -= delta
	if before > 8.0 and _fila_left <= 8.0:
		sfx("prompt_chime", 0.8)
		_set_status("A fila resmunga… vite, une fournée !")
	if _fila_left <= 0.0:
		_fila_lost += 1
		_fila_patience = maxf(_fila_patience - FILA_SHRINK, FILA_PATIENCE_MIN)
		_fila_left = _fila_patience
		sfx("mg_miss")
		pulse(0.5, 0.15)
		_set_status("😤 Une freguesa a abandonné la fila (%d)." % _fila_lost)

func _art_state() -> Dictionary:
	return {
		"pos": _player_pos, "carry": _carry, "ingredients": _plate_ingredients,
		"in_oven": _plate_in_oven, "cook": _plate_cook_time,
		"perfect_min": COOK_PERFECT_MIN, "perfect_max": COOK_PERFECT_MAX, "burn": COOK_BURN,
		"fila_left": _fila_left, "fila_patience": _fila_patience,
		"tips": _total_tips, "lost": _fila_lost,
	}

func _close_tutorial() -> void:
	_tutorial_visible = false
	if tutorial_root:
		tutorial_root.visible = false
	if help_button:
		help_button.visible = true
	if touch_controls:
		touch_controls.visible = true

func _open_tutorial() -> void:
	_tutorial_visible = true
	if tutorial_root:
		tutorial_root.visible = true
		GamepadBridge.focus_first.call_deferred(tutorial_root)
	if help_button:
		help_button.visible = false
	if touch_controls:
		touch_controls.visible = false

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
	if tip >= TIP_PERFECT:
		_perfect_batches += 1
	# Une vente (même ratée) calme la fila : elle repart, de plus en plus pressée.
	if tip > 0:
		_fila_patience = maxf(_fila_patience - FILA_SHRINK, FILA_PATIENCE_MIN)
		_fila_left = _fila_patience
	_carry = ""
	_reset_plate()
	if tip >= TIP_PERFECT:
		sfx("mg_perfect")
	sfx("coin" if tip > 0 else "mg_miss")
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
	var before: float = _plate_cook_time
	_plate_cook_time += delta
	# Le four parle : ding à « no ponto », grésillement à la brûlure.
	if before < COOK_PERFECT_MIN and _plate_cook_time >= COOK_PERFECT_MIN:
		sfx("oven_ding")
		pulse(0.3, 0.06)
	elif before < COOK_BURN and _plate_cook_time >= COOK_BURN:
		sfx("mg_miss")

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
	# Pulsation douce : les sprites peints saturent au-delà (la flèche fait le reste).
	if active:
		var glow: float = 1.04 + 0.08 * sin(Time.get_ticks_msec() / 150.0)
		node.modulate = Color(glow, glow, glow, 1)
	else:
		node.modulate = Color(0.8, 0.8, 0.8, 1)

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
		tip_label.text = "💰 R$ %d (%d/%d) · fila %ds" % [_total_tips, _batches_sold, MAX_BATCHES, int(ceil(maxf(_fila_left, 0.0)))]
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
				return InputHints.act() + " Prendre %s" % INGREDIENT_LABELS[station]
			if _carry == station:
				return InputHints.act() + " Reposer %s" % INGREDIENT_LABELS[station]
			if _carry in RECIPE:
				return InputHints.act() + " Échanger pour %s" % INGREDIENT_LABELS[station]
		"plate":
			if _plate_in_oven:
				return ""
			if _carry in RECIPE:
				if _plate_ingredients[_carry]:
					return "Déjà ajouté"
				return InputHints.act() + " Déposer %s" % INGREDIENT_LABELS[_carry]
			if _carry == "":
				if _plate_status == "BAKED":
					return InputHints.act() + " Prendre la plaque cuite"
				if _plate_status == "ASSEMBLY" and _all_ingredients_in():
					return InputHints.act() + " Prendre la plaque crue"
		"oven":
			if _carry == "plate_raw":
				return InputHints.act() + " Enfourner"
			if _carry == "" and _plate_in_oven:
				return InputHints.act() + " Sortir du four"
		"basket":
			if _carry.begins_with("plate_"):
				return InputHints.act() + " Vendre"
		"trash":
			if _carry.begins_with("plate_"):
				return InputHints.act() + " Jeter la plaque"
			if _carry in RECIPE:
				return InputHints.act() + " Jeter l'ingrédient"
	return ""

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = final_qualifies(_batches_sold >= QUALIFY_BATCHES and _perfect_batches >= 1 \
			and _fila_lost <= MAX_FILA_LOST)
	_set_status("Service terminé · %d fournées (%d parfaites) · fila perdue %d× · R$ %d" \
			% [_batches_sold, _perfect_batches, _fila_lost, _total_tips])
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("padaria", {"tips": _total_tips, "batches": _batches_sold, "qualifies": qualifies})
	match_ended.emit(qualifies, _total_tips)
