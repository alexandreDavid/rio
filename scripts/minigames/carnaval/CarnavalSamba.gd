class_name CarnavalSamba
extends Node2D

# Mini-jeu rythmique du Carnaval (Sambódromo). 4 instruments — tamborim, surdo,
# cuíca, agogô — sur 4 lanes. Pattern scripté en boucle samba (3-3-2 syncopé).
# Le joueur tape A/S/D/F (ou flèches) sur la ligne cible. Score >= QUALIFY_SCORE
# clôt la quête act4_carnaval_desfile.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 90.0
const FALL_DURATION: float = 1.5
const SPAWN_TOP_Y: float = 80.0
const TARGET_LINE_Y: float = 720.0
const FALL_DIST: float = TARGET_LINE_Y - SPAWN_TOP_Y
const FALL_SPEED: float = FALL_DIST / FALL_DURATION

const PERFECT_WINDOW: float = 0.13
const GOOD_WINDOW: float = 0.28
const MISS_GRACE: float = 0.15

const NOTE_W: float = 130.0
const NOTE_H: float = 36.0

const LANE_X: Array = [560.0, 800.0, 1040.0, 1280.0]
const LANE_KEYS: Array = [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_KEYS_ALT: Array = [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const LANE_LABELS: Array = ["Tamborim", "Surdo", "Cuíca", "Agogô"]
const LANE_COLORS: Array = [
	Color(0.95, 0.85, 0.4, 1),   # jaune (tamborim)
	Color(0.4, 0.55, 0.95, 1),   # bleu (surdo)
	Color(0.95, 0.5, 0.7, 1),    # rose (cuíca)
	Color(0.4, 0.85, 0.55, 1),   # vert (agogô)
]

const POINTS_PERFECT: int = 16
const POINTS_GOOD: int = 8
const QUALIFY_SCORE: int = 240   # ~15 perfects + 5 goods sur 90 s
const TIP_DIVISOR: float = 1.5

# Pattern samba sur 8 temps (2 mesures), scripté pour avoir une vibe carnaval.
# Format : [offset_dans_le_pattern_en_secondes, lane].
const PATTERN: Array = [
	[0.00, 1],  # surdo grave (1)
	[0.25, 0],  # tamborim
	[0.50, 0],  # tamborim
	[0.75, 3],  # agogô
	[1.00, 1],  # surdo (3)
	[1.25, 2],  # cuíca syncope
	[1.50, 0],  # tamborim
	[1.75, 3],  # agogô
	[2.00, 1],  # surdo
	[2.25, 0],  # tamborim double
	[2.50, 0],
	[2.75, 2],  # cuíca
	[3.00, 1],  # surdo
	[3.25, 3],  # agogô
	[3.50, 2],  # cuíca
	[3.75, 0],  # tamborim de fin
]
const PATTERN_DURATION: float = 4.0

var _time_left: float = DURATION
var _ended: bool = false
var _score: int = 0
var _perfects: int = 0
var _goods: int = 0
var _misses: int = 0
var _notes: Array = []
var _spawn_idx: int = 0
var _next_pattern_t: float = 0.0

@onready var note_layer: Node2D = $NoteLayer
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo

func _ready() -> void:
	EventBus.minigame_started.emit("carnaval_samba")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_set_status("Suis le rythme du bloc — A S D F (ou ← ↓ ↑ →)")

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	var elapsed: float = DURATION - _time_left
	_spawn_due(elapsed)
	_advance_notes(elapsed)
	_update_labels()

func _spawn_due(elapsed: float) -> void:
	# Génère les notes d'avance pour qu'elles atteignent la ligne cible au bon temps.
	var lookahead: float = FALL_DURATION + 0.05
	while _next_pattern_t < elapsed + lookahead and _next_pattern_t < DURATION:
		var pattern_offset: float = fmod(_next_pattern_t, PATTERN_DURATION)
		# Trouve les notes du pattern qui correspondent à cette tranche [t, t+0.05].
		# Plus simple : on génère le pattern complet par cycle.
		_spawn_pattern_cycle(_next_pattern_t)
		_next_pattern_t += PATTERN_DURATION

func _spawn_pattern_cycle(cycle_start: float) -> void:
	for entry in PATTERN:
		var beat_t: float = cycle_start + float(entry[0])
		if beat_t >= DURATION:
			continue
		var lane: int = int(entry[1])
		_spawn_note(lane, beat_t)

func _spawn_note(lane: int, target_time: float) -> void:
	var note: ColorRect = ColorRect.new()
	note.size = Vector2(NOTE_W, NOTE_H)
	note.position = Vector2(LANE_X[lane] - NOTE_W / 2.0, SPAWN_TOP_Y - NOTE_H)
	note.color = LANE_COLORS[lane]
	if note_layer:
		note_layer.add_child(note)
	_notes.append({"node": note, "lane": lane, "target_time": target_time, "hit": false})

func _advance_notes(elapsed: float) -> void:
	var to_remove: Array = []
	for n in _notes:
		if n.hit:
			to_remove.append(n)
			continue
		var time_to_target: float = n.target_time - elapsed
		var y: float = TARGET_LINE_Y - time_to_target * FALL_SPEED - NOTE_H / 2.0
		n.node.position.y = y
		# Note ratée si elle dépasse la fenêtre de grâce.
		if time_to_target < -MISS_GRACE:
			_misses += 1
			_set_status("MISS")
			to_remove.append(n)
	for n in to_remove:
		if is_instance_valid(n.node):
			n.node.queue_free()
		_notes.erase(n)

func _unhandled_input(event: InputEvent) -> void:
	if _ended or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event
	var lane: int = -1
	for i in range(LANE_KEYS.size()):
		if key_event.keycode == LANE_KEYS[i] or key_event.keycode == LANE_KEYS_ALT[i]:
			lane = i
			break
	if lane < 0:
		return
	_resolve_lane_press(lane)

func _resolve_lane_press(lane: int) -> void:
	var elapsed: float = DURATION - _time_left
	# Trouve la note la plus proche dans cette lane.
	var best: Dictionary = {}
	var best_delta: float = 999.0
	for n in _notes:
		if n.hit or n.lane != lane:
			continue
		var d: float = abs(n.target_time - elapsed)
		if d < best_delta:
			best_delta = d
			best = n
	if best.is_empty() or best_delta > GOOD_WINDOW:
		return
	best.hit = true
	if best_delta <= PERFECT_WINDOW:
		_score += POINTS_PERFECT
		_perfects += 1
		_set_status("PERFECT!")
	else:
		_score += POINTS_GOOD
		_goods += 1
		_set_status("GOOD")

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if score_label:
		score_label.text = "Score : %d" % _score
	if combo_label:
		combo_label.text = "★ %d  ✓ %d  ✗ %d" % [_perfects, _goods, _misses]

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _score >= QUALIFY_SCORE
	var tips: int = int(round(_score / TIP_DIVISOR))
	if status_label:
		if qualifies:
			status_label.text = "REINADO ! %d pts · R$ %d" % [_score, tips]
		else:
			status_label.text = "Bloco em queda (%d/%d) · R$ %d" % [_score, QUALIFY_SCORE, tips]
	await get_tree().create_timer(2.6).timeout
	EventBus.minigame_ended.emit("carnaval_samba", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
