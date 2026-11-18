class_name CarnavalSamba
extends MinigameBase

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

const PERFECT_WINDOW: float = 0.12
const GOOD_WINDOW: float = 0.22
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
# ~moitié des ~85 notes justes (mix perfect/good) : un vrai desfile, pas un tap.
const QUALIFY_SCORE: int = 480
# La caixinha du bloco (≈ 150-250 R$ pour un bon desfile).
const TIP_DIVISOR: float = 5.0
# Deux temps de silence avant la 1re note (elle tombait déjà sur la ligne).
const LEAD_IN: float = 2.0

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
# Virada : la bateria accélère, doubles de tamborim et cuíca qui répond.
const PATTERN_VIRADA: Array = [
	[0.00, 1], [0.25, 0], [0.375, 0], [0.50, 0], [0.75, 2],
	[1.00, 1], [1.25, 0], [1.375, 0], [1.50, 3], [1.75, 2],
	[2.00, 1], [2.25, 0], [2.50, 3], [2.625, 3], [2.75, 2],
	[3.00, 1], [3.25, 0], [3.375, 0], [3.50, 0], [3.75, 2],
]
# Breque : le mestre coupe, seuls les surdos et un agogô tiennent le temps.
const PATTERN_BREQUE: Array = [
	[0.00, 1], [1.00, 1], [1.50, 3], [2.00, 1], [3.00, 1], [3.50, 3], [3.75, 3],
]
# Mesures jouées en boucle : base, base, virada, breque.
const CYCLE_ORDER: Array = [0, 0, 1, 2]

var _time_left: float = DURATION
var _ended: bool = false
var _score: int = 0
var _perfects: int = 0
var _goods: int = 0
var _misses: int = 0
var _notes: Array = []
var _spawn_idx: int = 0
var _next_pattern_t: float = LEAD_IN

@onready var note_layer: Node2D = $NoteLayer
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo

var _lane_buttons: Array[Button] = []

func _ready() -> void:
	EventBus.minigame_started.emit("carnaval_samba")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	# Boutons tactiles 4 lanes (mobile-first ; A/S/D/F restent en bonus dev).
	for i in range(4):
		var btn: Button = get_node_or_null("UI/Lane%dButton" % i) as Button
		_lane_buttons.append(btn)
		if btn:
			# Affiche l'instrument de la lane (mobile : sinon le joueur devine).
			btn.text = LANE_LABELS[i]
			btn.pivot_offset = btn.size * 0.5
			# Sous sa lane, et réactif à l'appui (pas au relâché : c'est du rythme).
			align_under_world_x(btn, LANE_X[i])
			btn.add_theme_font_size_override("font_size", 33)
			var lane_idx: int = i
			btn.button_down.connect(func(): hit_lane(lane_idx))
	_set_status("Suis le rythme du bloc — touche les boutons colorés")

# Appelable depuis un bouton mobile.
func hit_lane(lane: int) -> void:
	if _ended:
		return
	_punch_lane_button(lane)
	_resolve_lane_press(lane)

func _punch_lane_button(lane: int) -> void:
	if lane < 0 or lane >= _lane_buttons.size():
		return
	var btn: Button = _lane_buttons[lane]
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.06)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.14)

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
		_spawn_pattern_cycle(_next_pattern_t)
		_next_pattern_t += PATTERN_DURATION

func _spawn_pattern_cycle(cycle_start: float) -> void:
	var cycle: int = int(round((cycle_start - LEAD_IN) / PATTERN_DURATION))
	var which: int = int(CYCLE_ORDER[cycle % CYCLE_ORDER.size()])
	var pattern: Array = [PATTERN, PATTERN_VIRADA, PATTERN_BREQUE][which]
	for entry in pattern:
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
			sfx("mg_miss")
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
	hit_lane(lane)  # passe par la version publique → animation punch

# Chaque frappe sonne son instrument : la bateria, c'est toi.
const LANE_SFX: Array[String] = ["samba_tamborim", "samba_surdo", "samba_cuica", "samba_agogo"]
const EMPTY_TAP_PENALTY: int = 4

func _resolve_lane_press(lane: int) -> void:
	sfx(LANE_SFX[lane])
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
		# Atravessar o samba : frappe hors temps, le bloc le sent.
		_score = maxi(_score - EMPTY_TAP_PENALTY, 0)
		_set_status("ATRAVESSOU")
		pulse(0.2, 0.05)
		return
	best.hit = true
	if best_delta <= PERFECT_WINDOW:
		_score += POINTS_PERFECT
		_perfects += 1
		_set_status("PERFECT!")
		sfx("mg_perfect")
		pulse(0.35, 0.05)
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
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	var tips: int = int(round(_score / TIP_DIVISOR))
	if status_label:
		if qualifies:
			status_label.text = "REINADO ! %d pts · R$ %d" % [_score, tips]
		else:
			status_label.text = "Bloco em queda (%d/%d) · R$ %d" % [_score, QUALIFY_SCORE, tips]
	await get_tree().create_timer(2.6).timeout
	EventBus.minigame_ended.emit("carnaval_samba", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
