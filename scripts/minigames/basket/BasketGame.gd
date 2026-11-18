class_name BasketGame
extends MinigameBase

# Mini-jeu de basket de rue à l'Aterro do Flamengo. Le joueur effectue 10 tirs.
# Pour chaque tir, un curseur oscille horizontalement sur une jauge de puissance.
# Espace pour tirer : sweet spot vert = swish (3 pts), zone jaune = panier rim (1 pt),
# zone rouge = airball (0). Score >= 18/30 = victoire (objectif coché). Pourboires
# gradués via TIP_PER_POINT.

signal match_ended(qualifies: bool, tips: int)

const SHOTS_TOTAL: int = 10
const QUALIFY_SCORE: int = 18  # ~6 swishes, ou un mix
const POINTS_SWISH: int = 3
const POINTS_RIM: int = 1
# Pelada de rua : on joue pour la gloire, la caixinha reste symbolique
# (30 pts max → 180 R$). Non qualifié = moitié ; abandon = rien.
const TIP_PER_POINT: int = 6
const METER_WIDTH: float = 480.0
const METER_CENTER_PX: float = 260.0
# La série se durcit : le curseur accélère et les zones rétrécissent du 1er
# au 10e tir (valeurs interpolées).
const METER_PERIOD_START: float = 1.4  # secondes pour une oscillation A/R complète
const METER_PERIOD_END: float = 0.85
const SWISH_HALF_START: float = 0.075
const SWISH_HALF_END: float = 0.045
const RIM_HALF_START: float = 0.19
const RIM_HALF_END: float = 0.12
const FEED_DELAY: float = 0.9   # délai avant l'apparition du tir suivant
const RESOLVE_DELAY: float = 0.6  # affichage du résultat avant feed

enum State { READY, RESOLVED, ENDED }

var _shot_index: int = 0
var _score: int = 0
var _swishes: int = 0
var _rims: int = 0
var _airballs: int = 0
var _state: int = State.READY
var _meter_t: float = 0.0
var _resolve_until: float = 0.0
var _feed_until: float = 0.0

@onready var meter_root: Control = $UI/Meter
@onready var meter_cursor: ColorRect = $UI/Meter/Cursor
@onready var rim_zone: ColorRect = $UI/Meter/RimZone
@onready var swish_zone: ColorRect = $UI/Meter/SwishZone
@onready var status_label: Label = $UI/Status
@onready var score_label: Label = $UI/Score
@onready var shots_label: Label = $UI/Shots
@onready var ball: ColorRect = $Court/Ball

func _ready() -> void:
	EventBus.minigame_started.emit("aterro_basket")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	# Boutons tactiles (mobile-first ; ui_accept reste en bonus dev).
	var action_btn: Button = get_node_or_null("UI/ActionButton") as Button
	if action_btn:
		action_btn.pressed.connect(_on_action_pressed)
	_status("Touche TIRER quand le curseur passe au centre vert")
	_layout_zones()

func _on_action_pressed() -> void:
	if _state != State.READY:
		return
	_resolve_shot()

func _process(delta: float) -> void:
	if _state == State.ENDED:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if _state == State.READY:
		_meter_t += delta
		_update_cursor()
	elif _state == State.RESOLVED and now >= _resolve_until:
		# Repart en READY après le délai d'affichage du résultat.
		if _shot_index >= SHOTS_TOTAL:
			_end_game()
			return
		_feed_until = now + FEED_DELAY
		_status("Tir n° %d/%d — concentre-toi" % [_shot_index + 1, SHOTS_TOTAL])
		_state = State.READY
		_meter_t = 0.0
		_show_ball(true)

func _difficulty() -> float:
	return clampf(float(_shot_index) / float(SHOTS_TOTAL - 1), 0.0, 1.0)

func _period() -> float:
	return lerpf(METER_PERIOD_START, METER_PERIOD_END, _difficulty())

func _swish_half() -> float:
	return lerpf(SWISH_HALF_START, SWISH_HALF_END, _difficulty())

func _rim_half() -> float:
	return lerpf(RIM_HALF_START, RIM_HALF_END, _difficulty())

# Les zones dessinées suivent les fenêtres réelles du tir courant.
func _layout_zones() -> void:
	for pair in [[rim_zone, _rim_half()], [swish_zone, _swish_half()]]:
		var z: ColorRect = pair[0]
		if z:
			var half: float = float(pair[1]) * METER_WIDTH
			z.offset_left = METER_CENTER_PX - half
			z.offset_right = METER_CENTER_PX + half

func _update_cursor() -> void:
	if meter_cursor == null:
		return
	# Oscillation triangulaire (0..1..0) — plus lisible qu'une sinusoïde pour le timing.
	var phase: float = fmod(_meter_t / _period(), 1.0)
	var x: float = phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0
	meter_cursor.position.x = x * METER_WIDTH

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.READY:
		return
	if event.is_echo():
		return
	# Clavier (Espace/Entrée/E) et manette (A = E via GamepadBridge).
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_resolve_shot()

func _resolve_shot() -> void:
	var phase: float = fmod(_meter_t / _period(), 1.0)
	var x: float = phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0
	# Distance au centre 0..0.5 (0 = parfait, 0.5 = bord).
	var dist: float = abs(x - 0.5)
	var swish_half: float = _swish_half()
	var rim_half: float = _rim_half()
	_shot_index += 1
	if dist <= swish_half:
		_score += POINTS_SWISH
		_swishes += 1
		_status("SWISH ! +3")
		sfx("basket_swish")
		sfx("mg_perfect")
		pulse(0.4, 0.06)
	elif dist <= rim_half:
		_score += POINTS_RIM
		_rims += 1
		_status("Rim-in +1")
		sfx("mg_hit")
	else:
		_airballs += 1
		_status("Airball")
		sfx("mg_miss")
	_layout_zones()
	_show_ball(false)
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
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("aterro_basket", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
