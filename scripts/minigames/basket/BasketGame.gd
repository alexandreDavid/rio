class_name BasketGame
extends MinigameBase

# Mini-jeu de basket de rue à l'Aterro do Flamengo. Le joueur effectue 10 tirs.
# Pour chaque tir, un curseur oscille horizontalement sur une jauge de puissance.
# Espace pour tirer : sweet spot vert = swish (3 pts), zone jaune = panier rim (1 pt),
# zone rouge = airball (0). Score >= 18/30 = victoire (objectif coché). Pourboires
# gradués via TIP_PER_POINT.

signal match_ended(qualifies: bool, tips: int)

# Tir en deux temps : la jauge horizontale fixe la visée (gauche/droite), puis
# la jauge verticale la force (court/long). Vert + vert = swish (3 pts), un
# jaune = rim-in (1 pt), deux jaunes = bate e sai (0), un rouge = airball.
# Score >= QUALIFY_SCORE/30 = victoire. Pourboires gradués via TIP_PER_POINT.

const SHOTS_TOTAL: int = 10
const QUALIFY_SCORE: int = 15  # 5 swishes, ou un mix
const POINTS_SWISH: int = 3
const POINTS_RIM: int = 1
# Pelada de rua : on joue pour la gloire, la caixinha reste symbolique
# (30 pts max → 180 R$). Non qualifié = moitié ; abandon = rien.
const TIP_PER_POINT: int = 6
const METER_WIDTH: float = 480.0
const METER_CENTER_PX: float = 260.0
const POWER_HEIGHT: float = 340.0
const POWER_CENTER_PX: float = 190.0
# La série se durcit : les curseurs accélèrent et les zones rétrécissent du
# 1er au 10e tir (valeurs interpolées). Deux jauges : zones plus larges qu'à une.
const METER_PERIOD_START: float = 1.4  # secondes pour une oscillation A/R complète
const METER_PERIOD_END: float = 0.9
const POWER_PERIOD_FACTOR: float = 0.85
const SWISH_HALF_START: float = 0.10
const SWISH_HALF_END: float = 0.06
const RIM_HALF_START: float = 0.22
const RIM_HALF_END: float = 0.15
const FEED_DELAY: float = 0.9   # délai avant l'apparition du tir suivant
const RESOLVE_DELAY: float = 1.0  # le ballon finit sa course avant le tir suivant

const BasketArt := preload("res://scripts/minigames/basket/BasketArt.gd")

enum State { AIM, POWER, RESOLVED, ENDED }
enum Shot { SWISH, RIM, AIRBALL, RIM_OUT }

var _shot_index: int = 0
var _score: int = 0
var _swishes: int = 0
var _rims: int = 0
var _airballs: int = 0
var _state: int = State.AIM
var _meter_t: float = 0.0
var _power_t: float = 0.0
var _aim: float = 0.5
var _resolve_until: float = 0.0
var _feed_until: float = 0.0
var _art: BasketArt = null
var _action_btn: Button = null

@onready var meter_root: Control = $UI/Meter
@onready var meter_cursor: ColorRect = $UI/Meter/Cursor
@onready var rim_zone: ColorRect = $UI/Meter/RimZone
@onready var swish_zone: ColorRect = $UI/Meter/SwishZone
@onready var meter_caption: Label = $UI/Meter/MeterCaption
@onready var status_label: Label = $UI/Status
@onready var score_label: Label = $UI/Score
@onready var shots_label: Label = $UI/Shots
@onready var ball: ColorRect = $Court/Ball

var power_root: Control = null
var power_cursor: Control = null
var power_rim: ColorRect = null
var power_swish: ColorRect = null

func _ready() -> void:
	EventBus.minigame_started.emit("aterro_basket")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	# Boutons tactiles (mobile-first ; ui_accept reste en bonus dev).
	_action_btn = get_node_or_null("UI/ActionButton") as Button
	if _action_btn:
		_action_btn.pressed.connect(_on_action_pressed)
	_build_power_meter()
	# Décor, joueur, panier et ballon : tout le rendu vit dans BasketArt.
	_art = BasketArt.new()
	add_child(_art)
	_art.build(self)
	_layout_zones()
	_enter_aim()

func _on_action_pressed() -> void:
	_press()

func _press() -> void:
	if _state == State.AIM:
		_aim = _triangle(_meter_t, _period())
		_update_cursor()
		_enter_power()
	elif _state == State.POWER:
		_resolve_shot()

func _process(delta: float) -> void:
	if _art:
		_art.tick(delta, (_state == State.AIM or _state == State.POWER) and ball != null and ball.visible)
	if _state == State.ENDED:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if _state == State.AIM:
		_meter_t += delta
		_update_cursor()
	elif _state == State.POWER:
		_power_t += delta
		_update_power_cursor()
	elif _state == State.RESOLVED and now >= _resolve_until:
		# Repart en visée après le délai d'affichage du résultat.
		if _shot_index >= SHOTS_TOTAL:
			_end_game()
			return
		_feed_until = now + FEED_DELAY
		_status("Tir n° %d/%d — concentre-toi" % [_shot_index + 1, SHOTS_TOTAL])
		_meter_t = 0.0
		_show_ball(true)
		_enter_aim()

func _enter_aim() -> void:
	_state = State.AIM
	_power_t = 0.0
	_dim_meter(meter_root, false)
	if power_root:
		power_root.modulate = Color(1, 1, 1, 0.45)
	_update_power_cursor()
	if meter_caption:
		meter_caption.text = "1. VISE : arrête l'aiguille dans le VERT"
	if _action_btn:
		_action_btn.text = "VISER"
	if _shot_index == 0:
		_status("Vise, puis dose la force")

func _enter_power() -> void:
	_state = State.POWER
	_power_t = 0.0
	sfx("mg_hit")
	_dim_meter(meter_root, true)
	if power_root:
		power_root.modulate = Color.WHITE
	if meter_caption:
		meter_caption.text = "2. FORCE : arrête la jauge dans le VERT"
	if _action_btn:
		_action_btn.text = "TIRER"

# Jauge de visée verrouillée : estompée, sauf la légende qui guide l'étape.
func _dim_meter(m: Control, dim: bool) -> void:
	if m == null:
		return
	for c: Node in m.get_children():
		if c is CanvasItem and c != meter_caption:
			(c as CanvasItem).modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE

func _difficulty() -> float:
	return clampf(float(_shot_index) / float(SHOTS_TOTAL - 1), 0.0, 1.0)

func _period() -> float:
	return lerpf(METER_PERIOD_START, METER_PERIOD_END, _difficulty())

func _swish_half() -> float:
	return lerpf(SWISH_HALF_START, SWISH_HALF_END, _difficulty())

func _rim_half() -> float:
	return lerpf(RIM_HALF_START, RIM_HALF_END, _difficulty())

# Oscillation triangulaire (0..1..0) — plus lisible qu'une sinusoïde pour le timing.
func _triangle(t: float, period: float) -> float:
	var phase: float = fmod(t / period, 1.0)
	return phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0

# 2 = vert, 1 = jaune, 0 = rouge (distance au centre 0..0.5).
func _grade(v: float) -> int:
	var dist: float = absf(v - 0.5)
	if dist <= _swish_half():
		return 2
	if dist <= _rim_half():
		return 1
	return 0

# Jauge de force : construite en code à côté de la visée (même facture).
func _build_power_meter() -> void:
	var ui: Node = get_node_or_null("UI")
	if ui == null:
		return
	power_root = Control.new()
	power_root.name = "PowerMeter"
	power_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_root.anchor_left = 0.5
	power_root.anchor_right = 0.5
	power_root.anchor_top = 1.0
	power_root.anchor_bottom = 1.0
	power_root.offset_left = -400.0
	power_root.offset_right = -352.0
	power_root.offset_bottom = -148.0
	power_root.offset_top = -148.0 - POWER_HEIGHT
	ui.add_child(power_root)
	var frame: Panel = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(-22, -22)
	frame.size = Vector2(92, POWER_HEIGHT + 44)
	power_root.add_child(frame)
	var bg: ColorRect = _zone_rect("Bg", Color(0.8, 0.24, 0.22))
	bg.position = Vector2.ZERO
	bg.size = Vector2(48, POWER_HEIGHT)
	power_rim = _zone_rect("RimZone", Color(0.98, 0.78, 0.22))
	power_swish = _zone_rect("SwishZone", Color(0.3, 0.82, 0.36))
	power_cursor = Control.new()
	power_cursor.name = "Cursor"
	power_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_cursor.size = Vector2(78, 40)
	power_root.add_child(power_cursor)
	for spec: Array in [[Vector2(6, 13), Vector2(66, 14), Color(0.13, 0.1, 0.12)],
			[Vector2(9, 17), Vector2(60, 6), Color(1, 0.97, 0.88)],
			[Vector2(0, 5), Vector2(9, 30), Color(0.13, 0.1, 0.12)],
			[Vector2(69, 5), Vector2(9, 30), Color(0.13, 0.1, 0.12)]]:
		var r: ColorRect = ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = spec[0]
		r.size = spec[1]
		r.color = spec[2]
		power_cursor.add_child(r)
	power_cursor.position.x = -15.0
	for spec2: Array in [["LONG", -60.0], ["COURT", POWER_HEIGHT + 24.0]]:
		var lab: Label = Label.new()
		lab.text = spec2[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector2(-56, float(spec2[1]))
		lab.size = Vector2(160, 32)
		lab.add_theme_font_size_override("font_size", 22)
		lab.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
		lab.add_theme_color_override("font_outline_color", Color(0.13, 0.1, 0.12))
		lab.add_theme_constant_override("outline_size", 8)
		power_root.add_child(lab)

func _zone_rect(n: String, c: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.name = n
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = c
	r.size = Vector2(48, 0)
	power_root.add_child(r)
	return r

# Les zones dessinées suivent les fenêtres réelles du tir courant.
func _layout_zones() -> void:
	for pair in [[rim_zone, _rim_half()], [swish_zone, _swish_half()]]:
		var z: ColorRect = pair[0]
		if z:
			var half: float = float(pair[1]) * METER_WIDTH
			z.offset_left = METER_CENTER_PX - half
			z.offset_right = METER_CENTER_PX + half
	for pair2 in [[power_rim, _rim_half()], [power_swish, _swish_half()]]:
		var pz: ColorRect = pair2[0]
		if pz:
			var ph: float = float(pair2[1]) * POWER_HEIGHT
			pz.position = Vector2(0, POWER_CENTER_PX - ph)
			pz.size = Vector2(48, ph * 2.0)

func _update_cursor() -> void:
	if meter_cursor == null:
		return
	var x: float = _aim if _state != State.AIM else _triangle(_meter_t, _period())
	meter_cursor.position.x = x * METER_WIDTH

func _power_value() -> float:
	return _triangle(_power_t, _period() * POWER_PERIOD_FACTOR)

# 0 = en bas (court), 1 = en haut (long).
func _update_power_cursor() -> void:
	if power_cursor == null:
		return
	var v: float = _power_value() if _state == State.POWER else 0.0
	power_cursor.position.y = (1.0 - v) * POWER_HEIGHT - 20.0

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.AIM and _state != State.POWER:
		return
	if event.is_echo():
		return
	# Clavier (Espace/Entrée/E) et manette (A = E via GamepadBridge).
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_press()

func _resolve_shot() -> void:
	var power: float = _power_value()
	_update_power_cursor()
	var aim_q: int = _grade(_aim)
	var pow_q: int = _grade(power)
	var side: float = 1.0 if _aim >= 0.5 else -1.0
	_shot_index += 1
	var outcome: int = Shot.AIRBALL
	# Raté : 0 = à côté, 1 = court, 2 = long (pour l'animation).
	var miss: int = 0
	if aim_q == 0 or pow_q == 0:
		_airballs += 1
		if pow_q == 0:
			miss = 1 if power < 0.5 else 2
			_status("Trop court !" if miss == 1 else "Trop long, ça tape la planche")
		else:
			_status("Airball — trop à %s" % ("droite" if side > 0.0 else "gauche"))
		sfx("mg_miss")
	elif aim_q == 2 and pow_q == 2:
		outcome = Shot.SWISH
		_score += POINTS_SWISH
		_swishes += 1
		_status("SWISH ! +3")
		sfx("basket_swish")
		sfx("mg_perfect")
		pulse(0.4, 0.06)
	elif aim_q + pow_q == 3:
		outcome = Shot.RIM
		_score += POINTS_RIM
		_rims += 1
		_status("Rim-in +1")
		sfx("mg_hit")
	else:
		outcome = Shot.RIM_OUT
		_airballs += 1
		_status("Bate e sai… presque")
		sfx("mg_miss")
	_layout_zones()
	_show_ball(false)
	if _art:
		_art.shoot(outcome, side, miss)
	_state = State.RESOLVED
	_resolve_until = Time.get_ticks_msec() / 1000.0 + RESOLVE_DELAY
	_update_labels()

func _show_ball(visible_now: bool) -> void:
	if ball:
		ball.visible = visible_now

func _update_labels() -> void:
	if score_label:
		score_label.text = "Score : %d" % _score
	if shots_label:
		shots_label.text = "Tir %d/%d  ★ %d  ✓ %d  ✗ %d" % [_shot_index, SHOTS_TOTAL, _swishes, _rims, _airballs]

func _status(text: String) -> void:
	if status_label:
		status_label.text = text

func _end_game() -> void:
	if _state == State.ENDED:
		return
	_state = State.ENDED
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	var tips: int = 0 if forfeited else _score * TIP_PER_POINT
	if not qualifies:
		tips /= 2
	if qualifies:
		_status("Vitória ! %d pts · R$ %d" % [_score, tips])
	else:
		_status("Pas assez (%d/%d) · R$ %d" % [_score, QUALIFY_SCORE, tips])
	_update_labels()
	await get_tree().create_timer(bilan_delay(2.4)).timeout
	EventBus.minigame_ended.emit("aterro_basket", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
