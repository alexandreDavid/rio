class_name DjMinigame
extends Node2D

# Mini-jeu de rythme 4 lanes au sommet du Pão de Açúcar.
# Des notes tombent du haut, le joueur doit les frapper pile sur la ligne cible
# avec les touches A/S/D/F (ou les boutons mobiles). Score Perfect/Good/Miss.
# Le total des points = pourboires versés à la fin.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 60.0
const FALL_DURATION: float = 1.6
const SPAWN_TOP_Y: float = 80.0
const TARGET_LINE_Y: float = 720.0
const FALL_DIST: float = TARGET_LINE_Y - SPAWN_TOP_Y
const FALL_SPEED: float = FALL_DIST / FALL_DURATION

const PERFECT_WINDOW: float = 0.13  # secondes autour du target
const GOOD_WINDOW: float = 0.28
const MISS_GRACE: float = 0.15      # tolérance après target avant disparition

const NOTE_W: float = 130.0
const NOTE_H: float = 36.0

# 4 lanes — A/S/D/F par défaut, ou flèches pour mobile / claviers FR.
const LANE_X: Array = [560.0, 800.0, 1040.0, 1280.0]
const LANE_KEYS: Array = [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_KEYS_ALT: Array = [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const LANE_COLORS: Array = [
	Color(0.85, 0.3, 0.5, 1),   # rose
	Color(0.4, 0.65, 0.95, 1),  # bleu
	Color(0.55, 0.95, 0.55, 1), # vert
	Color(0.95, 0.85, 0.4, 1),  # jaune
]

const POINTS_PERFECT: int = 14
const POINTS_GOOD: int = 7
const TIP_DIVISOR: float = 2.0  # tip = score / 2 (max ~30 notes × 14 / 2 ≈ 210 R$)

var _time_left: float = DURATION
var _ended: bool = false
var _score: int = 0
var _perfects: int = 0
var _goods: int = 0
var _misses: int = 0
var _notes: Array = []          # éléments {node, lane, target_time, hit}
var _pattern: Array = []        # [target_time, lane] à venir
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var note_layer: Node2D = $NoteLayer
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo

func _ready() -> void:
	EventBus.minigame_started.emit("dj_paoacucar")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_rng.randomize()
	_generate_pattern()

func _generate_pattern() -> void:
	# Une note toutes les 0.55 à 0.95 s, lane aléatoire mais évite la même 2 fois de suite.
	var t: float = 1.5
	var last_lane: int = -1
	while t < DURATION - 1.0:
		var lane: int = _rng.randi() % 4
		if lane == last_lane and _rng.randf() < 0.6:
			lane = (lane + 1 + _rng.randi() % 3) % 4
		_pattern.append([t, lane])
		last_lane = lane
		t += _rng.randf_range(0.55, 0.95)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	var elapsed: float = DURATION - _time_left
	# Spawn ce qui doit apparaître maintenant (FALL_DURATION secondes avant target).
	while _pattern.size() > 0 and _pattern[0][0] - FALL_DURATION <= elapsed:
		var p: Array = _pattern.pop_front()
		_spawn_note(p[1], p[0])
	# Anime les notes : position en fonction du temps restant avant target.
	for n in _notes:
		if n.hit:
			continue
		var node: ColorRect = n.node as ColorRect
		if not is_instance_valid(node):
			n.hit = true
			continue
		var time_until: float = n.target_time - elapsed
		node.position.y = TARGET_LINE_Y - time_until * FALL_SPEED - NOTE_H * 0.5
		# Auto-miss si dépassée la cible + marge.
		if elapsed - n.target_time > MISS_GRACE:
			n.hit = true
			_misses += 1
			node.modulate = Color(0.55, 0.25, 0.25, 0.5)
			_set_status("MISS")
	_update_labels()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	for i in range(4):
		if key == LANE_KEYS[i] or key == LANE_KEYS_ALT[i]:
			_hit_lane(i)
			return

# Appelable depuis un bouton mobile aussi.
func hit_lane(lane: int) -> void:
	if _ended:
		return
	_hit_lane(lane)

func _hit_lane(lane: int) -> void:
	var elapsed: float = DURATION - _time_left
	var best_idx: int = -1
	var best_dist: float = GOOD_WINDOW + 0.2
	for i in range(_notes.size()):
		var n = _notes[i]
		if n.hit or n.lane != lane:
			continue
		var dist: float = abs(n.target_time - elapsed)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	if best_idx < 0:
		return
	var n = _notes[best_idx]
	if best_dist <= PERFECT_WINDOW:
		_score += POINTS_PERFECT
		_perfects += 1
		n.node.modulate = Color(0.4, 1.0, 0.4, 1)
		_set_status("PERFECT")
	elif best_dist <= GOOD_WINDOW:
		_score += POINTS_GOOD
		_goods += 1
		n.node.modulate = Color(0.95, 0.85, 0.4, 1)
		_set_status("GOOD")
	else:
		return
	n.hit = true
	# Petit "punch" visuel.
	var t: Tween = create_tween()
	t.tween_property(n.node, "scale", Vector2(1.3, 1.3), 0.08)
	t.tween_property(n.node, "scale", Vector2(1.0, 1.0), 0.16)

func _spawn_note(lane: int, target_time: float) -> void:
	var note: ColorRect = ColorRect.new()
	note.size = Vector2(NOTE_W, NOTE_H)
	note.color = LANE_COLORS[lane]
	note.pivot_offset = Vector2(NOTE_W * 0.5, NOTE_H * 0.5)
	note.position = Vector2(LANE_X[lane] - NOTE_W * 0.5, SPAWN_TOP_Y)
	if note_layer:
		note_layer.add_child(note)
	_notes.append({"node": note, "lane": lane, "target_time": target_time, "hit": false})

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if score_label:
		score_label.text = "Score : %d" % _score
	if combo_label:
		combo_label.text = "✓ %d  ★ %d  ✗ %d" % [_goods, _perfects, _misses]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var tips: int = int(round(_score / TIP_DIVISOR))
	if status_label:
		status_label.text = "Fim do set ! %d perfects · %d goods · R$ %d en tips" % [_perfects, _goods, tips]
	await get_tree().create_timer(2.5).timeout
	EventBus.minigame_ended.emit("dj_paoacucar", {"score": _score, "tips": tips, "qualifies": tips > 0})
	match_ended.emit(tips > 0, tips)
