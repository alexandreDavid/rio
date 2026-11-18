class_name DjMinigame
extends MinigameBase

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

const PERFECT_WINDOW: float = 0.12  # secondes autour du target
const GOOD_WINDOW: float = 0.22
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
# Combo jusqu'à ×3 : un set propre fait ~1500-2000 pts → 200-250 R$.
const TIP_DIVISOR: float = 8.0
# Qualifié = un set qui tient la piste (~35 notes justes avec un peu de combo).
const QUALIFY_SCORE: int = 500

var _time_left: float = DURATION
var _ended: bool = false
var _score: int = 0
var _perfects: int = 0
var _goods: int = 0
var _misses: int = 0
# Combo : ce qui distingue le DJ du Carnaval. Le set électronique récompense le
# FLOW — une série de hits sans rater fait monter un multiplicateur ; une note
# manquée le casse. (Le Carnaval, lui, teste la mémoire d'un pattern fixe.)
var _combo: int = 0
var _max_combo: int = 0

# x1 (0-4) · x1.5 (5-9) · x2 (10-14) · x2.5 (15-19) · x3 (20+).
func _combo_mult() -> float:
	return 1.0 + min(_combo / 5, 4) * 0.5
var _notes: Array = []          # éléments {node, lane, target_time, hit}
var _pattern: Array = []        # [target_time, lane] à venir
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var note_layer: Node2D = $NoteLayer
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var score_label: Label = $UI/Score
@onready var combo_label: Label = $UI/Combo

var _lane_buttons: Array[Button] = []

# Lanes électroniques (≠ instruments samba du Carnaval) — affichées sur les boutons.
const LANE_LABELS: Array = ["Kick", "Snare", "Hat", "Synth"]

func _ready() -> void:
	EventBus.minigame_started.emit("dj_paoacucar")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	# Boutons tactiles 4 lanes (mobile-first ; les touches A/S/D/F restent en bonus dev).
	for i in range(4):
		var btn: Button = get_node_or_null("UI/Lane%dButton" % i) as Button
		_lane_buttons.append(btn)
		if btn:
			btn.text = LANE_LABELS[i]
			btn.pivot_offset = btn.size * 0.5
			# Sous sa lane, et réactif à l'appui (pas au relâché : c'est du rythme).
			align_under_world_x(btn, LANE_X[i])
			btn.add_theme_font_size_override("font_size", 33)
			var lane_idx: int = i
			btn.button_down.connect(func(): hit_lane(lane_idx))
	_rng.randomize()
	_generate_pattern()

# Animation "punch" : le bouton de la lane scale up brièvement quand le joueur
# tape. Donne un feedback tactile clair.
func _punch_lane_button(lane: int) -> void:
	if lane < 0 or lane >= _lane_buttons.size():
		return
	var btn: Button = _lane_buttons[lane]
	if btn == null:
		return
	# pivot_offset déjà calé en _ready ; recalibre au cas où la taille a changé.
	btn.pivot_offset = btn.size * 0.5
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.06)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.14)

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
		# Auto-miss si dépassée la cible + marge → casse le combo.
		if elapsed - n.target_time > MISS_GRACE:
			n.hit = true
			_misses += 1
			_combo = 0
			node.modulate = Color(0.55, 0.25, 0.25, 0.5)
			_set_status("MISS")
			sfx("mg_miss")
	_update_labels()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	for i in range(4):
		if key == LANE_KEYS[i] or key == LANE_KEYS_ALT[i]:
			hit_lane(i)  # passe par la version publique → animation punch
			return

# Appelable depuis un bouton mobile aussi.
func hit_lane(lane: int) -> void:
	if _ended:
		return
	_punch_lane_button(lane)
	_hit_lane(lane)

# Chaque pad sonne, même à vide : c'est le joueur qui fait la musique.
const LANE_SFX: Array[String] = ["dj_kick", "dj_snare", "dj_hat", "dj_synth"]
# Taper hors note casse le combo : le spam des 4 pads ne paie plus.
const EMPTY_TAP_PENALTY: int = 4

func _empty_tap() -> void:
	_combo = 0
	_score = maxi(_score - EMPTY_TAP_PENALTY, 0)
	_set_status("CONTRATEMPO")
	pulse(0.2, 0.05)

func _hit_lane(lane: int) -> void:
	sfx(LANE_SFX[lane])
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
		_empty_tap()
		return
	var n = _notes[best_idx]
	if best_dist <= PERFECT_WINDOW:
		_combo += 1
		_score += int(round(POINTS_PERFECT * _combo_mult()))
		_perfects += 1
		n.node.modulate = Color(0.4, 1.0, 0.4, 1)
		_set_status("PERFECT x%d" % _combo)
		sfx("mg_perfect")
		pulse(0.35, 0.05)
	elif best_dist <= GOOD_WINDOW:
		_combo += 1
		_score += int(round(POINTS_GOOD * _combo_mult()))
		_goods += 1
		n.node.modulate = Color(0.95, 0.85, 0.4, 1)
		_set_status("GOOD x%d" % _combo)
		sfx("mg_good")
	else:
		_empty_tap()
		return
	_max_combo = max(_max_combo, _combo)
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
		if _combo >= 2:
			combo_label.text = "COMBO x%d  (x%.1f)" % [_combo, _combo_mult()]
		else:
			combo_label.text = "✓ %d  ★ %d  ✗ %d" % [_goods, _perfects, _misses]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var tips: int = int(round(_score / TIP_DIVISOR))
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if status_label:
		status_label.text = "Fim do set ! combo max x%d · %d perfects · R$ %d en tips" % [_max_combo, _perfects, tips]
	await get_tree().create_timer(2.5).timeout
	EventBus.minigame_ended.emit("dj_paoacucar", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)
