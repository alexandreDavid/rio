class_name DjMinigame
extends MinigameBase

# Mini-jeu de rythme 4 lanes au sommet du Pão de Açúcar.
# Des notes tombent du haut, le joueur doit les frapper pile sur la ligne cible
# avec les touches A/S/D/F (ou les boutons mobiles). Score Perfect/Good/Miss.
# Le total des points = pourboires versés à la fin.

signal match_ended(qualifies: bool, tips: int)

const Art := preload("res://scripts/minigames/dj/DjArt.gd")

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

# --- Décor vivant (purement visuel) ---
# Pulsation de la soirée : la foule, les enceintes et les lasers battent à
# 124 BPM, et chaque frappe du joueur en rajoute.
const BEAT: float = 60.0 / 124.0
const MISS_COLOR: Color = Color(0.95, 0.25, 0.25, 1)
# Vagues de lumières de la ville : [début (s), durée du fondu].
const LIGHT_WAVES: Array = [[1.0, 2.0], [8.0, 4.0], [20.0, 4.0], [34.0, 5.0]]
var _clock: float = 0.0
var _beat_acc: float = 0.0
var _beat_count: int = 0
var _hype: float = 0.0           # 0..1, monte avec le combo
var _lane_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lane_flash_col: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
var _laser_boost: float = 0.0
var _screen_flash: float = 0.0
var _screen_flash_col: Color = Color.WHITE
var _sparks: Array = []          # {p, v, life, col}
var _vu: Array[float] = [0.0, 0.0]
var _dj_pump: float = 0.0
var _crowd: Array = []           # {spr, base_y, phase, hop}
var _speakers: Array[Sprite2D] = []
var _lights: Array[Sprite2D] = []
var _dusk: Node2D = null
var _fx_back: Node2D = null
var _fx_front: Node2D = null
var _cabin: Sprite2D = null
var _dj: Sprite2D = null
var _dj_base_y: float = 0.0
var _crowd_tex: Dictionary = {}

func _ready() -> void:
	EventBus.minigame_started.emit("dj_paoacucar")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_build_stage()
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
			_style_lane_button(btn, i)
			var lane_idx: int = i
			btn.button_down.connect(func(): hit_lane(lane_idx))
	_rng.randomize()
	_generate_pattern()
	_style_hud()

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
	_animate_stage(delta)
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
		var node: Node2D = n.node as Node2D
		if not is_instance_valid(node):
			n.hit = true
			continue
		var time_until: float = n.target_time - elapsed
		# Pad centré : même trajectoire que l'ancien rectangle (centre sur la ligne).
		node.position.y = snappedf(TARGET_LINE_Y - time_until * FALL_SPEED, 3.0)
		# Auto-miss si dépassée la cible + marge → casse le combo.
		if elapsed - n.target_time > MISS_GRACE:
			n.hit = true
			_misses += 1
			_combo = 0
			_retire_note(node, false)
			_fx_judge(n.lane, "miss")
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
	_fx_press(lane)
	_hit_lane(lane)

# Chaque pad sonne, même à vide : c'est le joueur qui fait la musique.
const LANE_SFX: Array[String] = ["dj_kick", "dj_snare", "dj_hat", "dj_synth"]
# Taper hors note casse le combo : le spam des 4 pads ne paie plus.
const EMPTY_TAP_PENALTY: int = 4

func _empty_tap() -> void:
	_combo = 0
	_score = maxi(_score - EMPTY_TAP_PENALTY, 0)
	_set_status("CONTRATEMPO")
	_hype = maxf(_hype - 0.1, 0.0)
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
		_fx_judge(lane, "perfect")
		_set_status("PERFECT x%d" % _combo)
		sfx("mg_perfect")
		pulse(0.35, 0.05)
	elif best_dist <= GOOD_WINDOW:
		_combo += 1
		_score += int(round(POINTS_GOOD * _combo_mult()))
		_goods += 1
		_fx_judge(lane, "good")
		_set_status("GOOD x%d" % _combo)
		sfx("mg_good")
	else:
		_empty_tap()
		return
	_max_combo = max(_max_combo, _combo)
	n.hit = true
	_retire_note(n.node as Node2D, true)

func _spawn_note(lane: int, target_time: float) -> void:
	# Pad pixel 43×12 natifs ×3 ≈ NOTE_W × NOTE_H, centré sur la lane.
	var note: Sprite2D = Sprite2D.new()
	note.texture = Art.pad(lane, LANE_COLORS[lane])
	note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	note.scale = Vector2(Art.N, Art.N)
	note.position = Vector2(LANE_X[lane], SPAWN_TOP_Y + NOTE_H * 0.5)
	if note_layer:
		note_layer.add_child(note)
	_notes.append({"node": note, "lane": lane, "target_time": target_time, "hit": false})

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
		var col: Color = Color(1, 0.92, 0.5, 1)
		if text.begins_with("MISS") or text.begins_with("CONTRATEMPO"):
			col = Color(1.0, 0.45, 0.45, 1)
		elif text.begins_with("GOOD"):
			col = Color(0.55, 0.9, 1.0, 1)
		status_label.add_theme_color_override("font_color", col)
		status_label.pivot_offset = status_label.size * 0.5
		var t: Tween = create_tween()
		t.tween_property(status_label, "scale", Vector2(1.25, 1.25), 0.05)
		t.tween_property(status_label, "scale", Vector2.ONE, 0.15)

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
		status_label.add_theme_color_override("font_color", Color(1, 0.92, 0.5, 1))
		status_label.text = "Fim do set ! combo max x%d · %d perfects · R$ %d en tips" % [_max_combo, _perfects, tips]
	await get_tree().create_timer(2.5).timeout
	EventBus.minigame_ended.emit("dj_paoacucar", {"score": _score, "tips": tips, "qualifies": qualifies})
	match_ended.emit(qualifies, tips)

# --- Décor : soirée électro au sommet de l'Urca ------------------------------

func _build_stage() -> void:
	var colors: Array = LANE_COLORS
	var back: Sprite2D = Art.sprite(Art.backdrop(LANE_X, colors, TARGET_LINE_Y), Art.ORIGIN)
	back.name = "Backdrop"
	add_child(back)
	move_child(back, 0)
	var at: int = 1
	# La nuit tombe sur le ciel pendant le set (voile uni, sous les lumières).
	_dusk = Node2D.new()
	_dusk.draw.connect(_draw_dusk)
	add_child(_dusk)
	move_child(_dusk, at)
	at += 1
	for g in LIGHT_WAVES.size():
		var l: Sprite2D = Art.sprite(Art.lights(g), Vector2(Art.ORIGIN.x, Art.LIGHTS_TOP))
		l.modulate.a = 0.0
		add_child(l)
		move_child(l, at)
		at += 1
		_lights.append(l)
	_cabin = Art.sprite(Art.cabin(), Vector2.ZERO)
	add_child(_cabin)
	move_child(_cabin, at)
	at += 1
	# Lasers et récepteurs sous les notes ; éclats et VU-mètres au-dessus.
	_fx_back = Node2D.new()
	_fx_back.draw.connect(_draw_fx_back)
	add_child(_fx_back)
	move_child(_fx_back, at)
	at += 1
	# Enceintes : deux à gauche (la plus éloignée hors champ en 16:9), deux à droite.
	for sx in [-170.0, -30.0, 1396.0, 1510.0]:
		var sp: Sprite2D = Art.sprite(Art.speaker(), Vector2.ZERO)
		sp.centered = true
		sp.offset = Vector2(0, -36)
		sp.position = Vector2(sx + 51.0, Art.DECK_Y + 6.0)
		add_child(sp)
		move_child(sp, at)
		at += 1
		_speakers.append(sp)
	# Le DJ (apparence du joueur, casque) derrière sa console.
	_dj = char_sprite(192.0)
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	_dj.texture = Art.dj_sheet(cfg, LANE_COLORS[0])
	_dj.scale = Vector2(2, 2)
	_dj_base_y = 824.0
	_dj.position = Vector2(255, _dj_base_y)
	add_child(_dj)
	move_child(_dj, at)
	at += 1
	var desk: Sprite2D = Art.sprite(Art.console(colors), Vector2(87, 756))
	desk.name = "Console"
	add_child(desk)
	move_child(desk, at)
	at += 1
	# Notes par-dessus le décor, puis éclats, puis la foule au premier plan.
	if note_layer:
		move_child(note_layer, at)
		at += 1
	_fx_front = Node2D.new()
	_fx_front.draw.connect(_draw_fx_front)
	add_child(_fx_front)
	move_child(_fx_front, at)
	at += 1
	_build_crowd(at)


func _build_crowd(at: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 124
	# Rangée du fond (taille 1) puis rangée de devant (×1.5, coupée par le bas).
	var rows: Array = [[-330.0, 2260.0, 70.0, 968.0, 1.0], [-300.0, 2260.0, 118.0, 1104.0, 1.5]]
	var idx: int = 0
	for r in rows:
		var x: float = r[0]
		while x < float(r[1]):
			var key: int = idx % 14
			if not _crowd_tex.has(key):
				_crowd_tex[key] = Art.crowd_sheet(CharacterSpriteFactory.random_config(4100 + key * 37))
			var spr: Sprite2D = Sprite2D.new()
			spr.texture = _crowd_tex[key]
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, Art.CW, Art.CH)
			spr.offset = Vector2(0, -Art.CH * 0.5)
			spr.scale = Vector2(r[4], r[4])
			spr.flip_h = rng.randf() < 0.5
			var by: float = float(r[3]) + rng.randf_range(-8.0, 8.0)
			spr.position = Vector2(snappedf(x + rng.randf_range(-14.0, 14.0), 3.0), by)
			add_child(spr)
			move_child(spr, at)
			at += 1
			_crowd.append({"spr": spr, "base_y": by, "phase": rng.randi() % 2, "hop": 0.0, "fan": rng.randf()})
			x += float(r[2])
			idx += 1


func _style_lane_button(btn: Button, i: int) -> void:
	var col: Color = LANE_COLORS[i]
	btn.add_theme_stylebox_override("normal", UITheme.frame_box(col.darkened(0.6), Color(col.darkened(0.25), 0.92)))
	btn.add_theme_stylebox_override("hover", UITheme.frame_box(col.darkened(0.6), Color(col.darkened(0.15), 0.95)))
	btn.add_theme_stylebox_override("pressed", UITheme.frame_box(Color(1, 1, 1, 1), col.lightened(0.3)))
	btn.add_theme_stylebox_override("focus", UITheme.frame_box(Color(1, 1, 1, 1), Color(0, 0, 0, 0)))
	btn.icon = Art.icon_texture(i, col)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_color_override("font_color", Color(0.99, 0.98, 0.95, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.12, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.09, 1))
	btn.add_theme_constant_override("outline_size", 6)


func _style_hud() -> void:
	for path in ["UI/Timer", "UI/Score", "UI/Combo", "UI/Status", "UI/Prompt"]:
		var l: Label = get_node_or_null(path) as Label
		if l:
			l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.10, 0.95))
			l.add_theme_constant_override("outline_size", 10 if path == "UI/Status" else 6)


# Note frappée : éclair blanc puis fondu ; note manquée : tombe et s'éteint.
func _retire_note(node: Node2D, ok: bool) -> void:
	if not is_instance_valid(node):
		return
	var t: Tween = create_tween()
	if ok:
		node.modulate = Color(2.0, 2.0, 2.0, 1)
		t.set_parallel(true)
		t.tween_property(node, "scale", Vector2(Art.N * 1.35, Art.N * 1.35), 0.12)
		t.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.2)
	else:
		node.modulate = Color(0.55, 0.3, 0.35, 0.8)
		t.set_parallel(true)
		t.tween_property(node, "position:y", node.position.y + 60.0, 0.35)
		t.tween_property(node, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(node.queue_free)


func _fx_press(lane: int) -> void:
	_lane_flash[lane] = maxf(_lane_flash[lane], 0.55)
	_lane_flash_col[lane] = LANE_COLORS[lane]
	if lane == 0:
		_thump()
		_dj_pump = 0.3
	_vu[lane % 2] = minf(_vu[lane % 2] + 0.45, 1.0)


func _fx_judge(lane: int, kind: String) -> void:
	var col: Color = LANE_COLORS[lane]
	match kind:
		"perfect":
			_lane_flash[lane] = 1.0
			_lane_flash_col[lane] = col.lightened(0.4)
			_laser_boost = 1.0
			_screen_flash = 1.0
			_screen_flash_col = col
			_hype = minf(_hype + 0.06, 1.0)
			_burst(lane, 16, col)
			_thump()
		"good":
			_lane_flash[lane] = 0.8
			_lane_flash_col[lane] = col
			_laser_boost = maxf(_laser_boost, 0.5)
			_hype = minf(_hype + 0.03, 1.0)
			_burst(lane, 8, col)
		"miss":
			_lane_flash[lane] = 0.9
			_lane_flash_col[lane] = MISS_COLOR
			_laser_boost = 0.0
			_hype = maxf(_hype - 0.15, 0.0)


func _burst(lane: int, count: int, col: Color) -> void:
	for i in count:
		var a: float = _rng.randf_range(-PI, 0.0)
		var sp: float = _rng.randf_range(220.0, 520.0)
		_sparks.append({
			"p": Vector2(LANE_X[lane] + _rng.randf_range(-50.0, 50.0), TARGET_LINE_Y),
			"v": Vector2(cos(a), sin(a)) * sp,
			"life": _rng.randf_range(0.35, 0.6),
			"col": Color(1, 1, 1, 1) if i % 3 == 0 else col.lightened(0.2),
		})


# Les caissons « pompent » : écrasés d'un coup puis relâchés.
func _thump() -> void:
	for sp in _speakers:
		sp.scale = Vector2(Art.N * 1.04, Art.N * 0.95)


func _animate_stage(delta: float) -> void:
	_clock += delta
	_beat_acc += delta
	if _beat_acc >= BEAT:
		_beat_acc -= BEAT
		_on_beat()
	var elapsed: float = DURATION - _time_left
	# Lumières de la ville et du Cristo qui s'allument par vagues.
	for g in _lights.size():
		var w: Array = LIGHT_WAVES[g]
		var a: float = clampf((elapsed - float(w[0])) / float(w[1]), 0.0, 1.0)
		# Allumage par paliers (pas de fondu lisse) avec un léger scintillement.
		a = floorf(a * 4.0) / 4.0
		if a >= 1.0 and fmod(_clock * 7.0 + g, 11.0) < 0.15:
			a = 0.8
		_lights[g].modulate.a = a
	# Bondinho : aller-retour lent le long du câble.
	if _cabin:
		var u: float = 0.5 - 0.5 * cos(_clock * TAU / 36.0)
		var p: Vector2 = Art.CABLE_A.lerp(Art.CABLE_B, 0.12 + 0.76 * u)
		_cabin.position = (p - Vector2(16.0, 0.0)).snapped(Vector2(3, 3))
	for sp in _speakers:
		sp.scale = sp.scale.lerp(Vector2(Art.N, Art.N), minf(delta * 14.0, 1.0))
	# DJ : hoche la tête au beat, poing levé sur le kick.
	if _dj:
		_dj_pump = maxf(_dj_pump - delta, 0.0)
		var nod: float = 6.0 if _beat_acc < BEAT * 0.35 else 0.0
		_dj.position.y = _dj_base_y + nod
		_dj.region_rect = Rect2((1 if _dj_pump > 0.0 else 0) * Art.CW, 0, Art.CW, Art.CH)
	for c in _crowd:
		var spr: Sprite2D = c.spr
		c.hop = maxf(float(c.hop) - delta * 60.0, 0.0)
		spr.position.y = snappedf(float(c.base_y) - float(c.hop), 3.0)
	for i in 4:
		_lane_flash[i] = maxf(_lane_flash[i] - delta * 3.0, 0.0)
	_laser_boost = maxf(_laser_boost - delta * 2.5, 0.0)
	_screen_flash = maxf(_screen_flash - delta * 5.0, 0.0)
	for k in 2:
		_vu[k] = maxf(_vu[k] - delta * 1.6, 0.12 + 0.1 * sin(_clock * 9.0 + k))
	var alive: Array = []
	for s in _sparks:
		s.life = float(s.life) - delta
		if s.life <= 0.0:
			continue
		s.v = (s.v as Vector2) + Vector2(0, 900.0) * delta
		s.p = (s.p as Vector2) + (s.v as Vector2) * delta
		alive.append(s)
	_sparks = alive
	_hype = maxf(_hype, minf(float(_combo) / 20.0, 1.0) * 0.8)
	if _dusk:
		_dusk.queue_redraw()
	if _fx_back:
		_fx_back.queue_redraw()
	if _fx_front:
		_fx_front.queue_redraw()


func _on_beat() -> void:
	_beat_count += 1
	_thump()
	_vu[0] = maxf(_vu[0], 0.6)
	_vu[1] = maxf(_vu[1], 0.5)
	# Foule : saute en rythme ; plus le combo monte, plus les bras se lèvent.
	var arms_p: float = 0.12 + _hype * 0.7
	for c in _crowd:
		var spr: Sprite2D = c.spr
		if (_beat_count + int(c.phase)) % 2 == 0:
			c.hop = 9.0
		var col: int = 1 + (_beat_count + int(c.phase)) % 2
		if float(c.fan) < arms_p:
			col = 3 if (_beat_count + int(c.phase)) % 4 < 2 or _hype > 0.6 else 4
		spr.region_rect = Rect2(col * Art.CW, 0, Art.CW, Art.CH)


func _draw_dusk() -> void:
	var elapsed: float = DURATION - _time_left
	var a: float = floorf(clampf(elapsed / DURATION, 0.0, 1.0) * 6.0) / 6.0 * 0.32
	if a > 0.0:
		_dusk.draw_rect(Rect2(Art.ORIGIN.x, 0, Art.W * Art.N, Art.HORIZON + 174.0), Color(0.07, 0.03, 0.18, a))


# Lasers en éventail depuis le treillis et les enceintes, puis récepteurs.
func _draw_fx_back() -> void:
	var n: Node2D = _fx_back
	var power: float = 0.22 + 0.25 * _hype + 0.5 * _laser_boost
	var beat_k: float = 1.0 - _beat_acc / BEAT
	power += 0.15 * beat_k
	# [origine, angle central (deg), amplitude, vitesse]
	var emitters: Array = [
		[Vector2(458, 36), 150.0, 22.0, 0.9],
		[Vector2(1382, 36), 30.0, 22.0, 1.1],
		[Vector2(-30, 552), -120.0, 25.0, 0.7],
		[Vector2(1510, 552), -60.0, 25.0, 0.8],
	]
	var beams: int = 3 if _laser_boost < 0.4 else 5
	for e in emitters.size():
		var em: Array = emitters[e]
		var o: Vector2 = em[0]
		var col: Color = LANE_COLORS[(e + _beat_count / 4) % 4]
		for b in beams:
			var spread: float = (float(b) - float(beams - 1) * 0.5) * 9.0
			var ang: float = deg_to_rad(float(em[1]) + spread + float(em[2]) * sin(_clock * float(em[3]) + float(e)))
			var tip: Vector2 = o + Vector2(cos(ang), sin(ang)) * 1500.0
			n.draw_line(o, tip, Color(col.r, col.g, col.b, 0.16 * power), 9.0)
			n.draw_line(o, tip, Color(col.lightened(0.5).r, col.lightened(0.5).g, col.lightened(0.5).b, 0.55 * power), 3.0)
		n.draw_rect(Rect2(o - Vector2(6, 6), Vector2(12, 12)), Color(1, 1, 1, minf(power * 1.5, 1.0)))
	# Pistes : colonne de lumière par paliers quand on tape, récepteur en cadre.
	for i in 4:
		var col: Color = LANE_COLORS[i]
		var a: float = _lane_flash[i]
		var fc: Color = _lane_flash_col[i]
		var x0: float = LANE_X[i] - 63.0
		if a > 0.0:
			for k in 4:
				var y0: float = TARGET_LINE_Y - 120.0 * float(k + 1)
				n.draw_rect(Rect2(x0, y0, 126.0, 120.0), Color(fc.r, fc.g, fc.b, a * (0.5 - 0.1 * float(k))))
		var r: Rect2 = Rect2(LANE_X[i] - NOTE_W * 0.5, TARGET_LINE_Y - NOTE_H * 0.5, NOTE_W, NOTE_H)
		if a > 0.0:
			n.draw_rect(r.grow(6.0), Color(fc.r, fc.g, fc.b, a * 0.8))
		n.draw_rect(r, Color(0.04, 0.02, 0.08, 0.55))
		var edge: Color = col.lerp(Color.WHITE, a * 0.6)
		n.draw_rect(r, edge, false, 6.0)
		n.draw_rect(r.grow(-6.0), Color(edge.r, edge.g, edge.b, 0.35), false, 3.0)


func _draw_fx_front() -> void:
	var n: Node2D = _fx_front
	for s in _sparks:
		var c: Color = s.col
		c.a = clampf(float(s.life) * 2.5, 0.0, 1.0)
		var p: Vector2 = (s.p as Vector2).snapped(Vector2(3, 3))
		n.draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), c)
	# VU-mètres de la console : diodes vert → jaune → rouge.
	for k in 2:
		var bx: float = 87.0 + (24.0 if k == 0 else 300.0)
		var lit: int = int(round(_vu[k] * 6.0))
		for j in 6:
			var c2: Color = Color(0.3, 0.95, 0.4) if j < 3 else (Color(1.0, 0.85, 0.3) if j < 5 else Color(1.0, 0.3, 0.3))
			if j >= lit:
				c2 = c2.darkened(0.75)
			n.draw_rect(Rect2(bx, 864.0 - j * 9.0, 12.0, 6.0), c2)
	if _screen_flash > 0.0:
		var f: Color = _screen_flash_col.lightened(0.5)
		f.a = 0.22 * _screen_flash
		n.draw_rect(Rect2(Art.ORIGIN.x, 0, Art.W * Art.N, 1080.0), f)
