class_name BasketGame
extends Node2D

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
const TIP_PER_POINT: int = 18  # 30 pts max → 540 R$ ; 18 pts (qualif) → 324 R$
const METER_WIDTH: float = 480.0
const METER_PERIOD: float = 1.4  # secondes pour une oscillation A/R complète
const SWISH_HALF_RANGE: float = 0.07  # ±7 % autour du centre
const RIM_HALF_RANGE: float = 0.18    # ±18 % autour du centre
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
@onready var status_label: Label = $UI/Status
@onready var score_label: Label = $UI/Score
@onready var shots_label: Label = $UI/Shots
@onready var ball: ColorRect = $Court/Ball

func _ready() -> void:
	EventBus.minigame_started.emit("aterro_basket")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_status("Espace pour tirer — vise le centre vert")

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

func _update_cursor() -> void:
	if meter_cursor == null:
		return
	# Oscillation triangulaire (0..1..0) — plus lisible qu'une sinusoïde pour le timing.
	var phase: float = fmod(_meter_t / METER_PERIOD, 1.0)
	var x: float = phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0
	meter_cursor.position.x = x * METER_WIDTH

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.READY:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not Input.is_action_pressed("ui_accept"):
		return
	_resolve_shot()

func _resolve_shot() -> void:
	var phase: float = fmod(_meter_t / METER_PERIOD, 1.0)
	var x: float = phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0
	# Distance au centre 0..0.5 (0 = parfait, 0.5 = bord).
	var dist: float = abs(x - 0.5)
	_shot_index += 1
	if dist <= SWISH_HALF_RANGE:
		_score += POINTS_SWISH
		_swishes += 1
		_status("SWISH ! +3")
	elif dist <= RIM_HALF_RANGE:
		_score += POINTS_RIM
		_rims += 1
		_status("Rim-in +1")
	else:
		_airballs += 1
		_status("Airball")
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
	_state = State.ENDED
	var qualifies: bool = _score >= QUALIFY_SCORE
	var tips: int = _score * TIP_PER_POINT
	if qualifies:
		_status("Vitória ! %d pts · R$ %d" % [_score, tips])
	else:
		_status("Pas assez (%d/%d) · R$ %d" % [_score, QUALIFY_SCORE, tips])
	_update_labels()
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("aterro_basket", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
