class_name RegataGame
extends Node2D

# Regata da Glória — un dériveur dans la baie, au standard volley/surf.
# Le vent vient du nord (avec des rafales qui le font tourner). On ne remonte
# PAS face au vent : à moins de 40° du lit du vent, la voile fasseye et le
# bateau s'arrête. Pour atteindre la bouée au vent, il faut tirer des bords
# (zigzag) et virer proprement — un virement lent te laisse planté face au
# vent. Le travers (90°) est l'allure la plus rapide.
# Parcours : au vent (nord) → travers (est) → sous le vent (sud-ouest) → au
# vent encore → arrivée (sud). Deux bords de près : lire le vent deux fois.
# Bia, la meilleure de l'escolinha, court le même parcours : la battre =
# Perfeito. Finir dans le temps = qualifié.
# Contrat : match_ended(qualifies, beat_rival) ; minigame_ended("regata", {...}).

signal match_ended(qualifies: bool, beat_rival: bool)

const TIME_LIMIT: float = 120.0
const ARENA: Rect2 = Rect2(-900, -470, 1800, 900)
const MAX_SPEED: float = 110.0
const ACCEL: float = 0.9          # rapprochement de la vitesse cible (par s)
const LUFF_DRAG: float = 1.6      # décélération voile fasseyante
const TURN_RATE: float = 1.5      # rad/s
const NO_GO_DEG: float = 40.0
const ROUND_RADIUS: float = 75.0
const GUST_EVERY: Vector2 = Vector2(6.0, 9.0)
const GUST_SHIFT_DEG: float = 14.0
const CLEAN_TACK_SEC: float = 1.6
const RIVAL_SKILL: float = 0.97
const START: Vector2 = Vector2(0, 380)
# Bouées dans l'ordre ; la dernière est l'arrivée.
const MARKS: Array[Vector2] = [Vector2(0, -360), Vector2(660, -20), Vector2(-470, 260), Vector2(0, -360), Vector2(0, 380)]
const MARK_NAMES: Array[String] = ["bouée au vent", "bouée de travers", "bouée sous le vent", "bouée au vent (2e tour)", "arrivée"]
# Trajectoire de Bia : bords de près vers la bouée au vent, puis travers et largue.
const RIVAL_PATH: Array[Vector2] = [
	Vector2(-60, 380), Vector2(-330, 130), Vector2(180, -150), Vector2(-40, -360),
	Vector2(660, -20), Vector2(-470, 260),
	Vector2(-150, 150), Vector2(-420, -150), Vector2(-40, -360),
	Vector2(0, 380),
]
# Polaire simplifiée : (angle au vent en degrés, fraction de MAX_SPEED).
const POLAR: Array = [[40.0, 0.5], [60.0, 0.8], [90.0, 1.0], [120.0, 0.95], [150.0, 0.8], [180.0, 0.65]]

var _pos: Vector2 = START
var _heading: float = -PI / 2.0 + 0.9   # cap initial : bâbord amures, au près
var _speed: float = 0.0
var _wind_from: float = -PI / 2.0       # le vent VIENT du nord (−y)
var _wind_target: float = -PI / 2.0
var _gust_timer: float = 7.0
var _next_mark: int = 0
var _time: float = 0.0
var _ended: bool = false
var _turn_left: bool = false
var _turn_right: bool = false
var _rival_pos: Vector2 = RIVAL_PATH[0]
var _rival_seg: int = 0
var _rival_done_at: float = -1.0
var _finished_at: float = -1.0
var _last_side: int = 0
var _luff_time: float = 0.0
var _trail: Array[Vector2] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _hud: Label
var _status: Label

# --- Règles pures (testées sans scène) ---

# Angle entre le cap et la direction d'où vient le vent, en degrés [0, 180].
static func off_wind_deg(heading: float, wind_from: float) -> float:
	return rad_to_deg(absf(angle_difference(heading, wind_from)))

# Fraction de vitesse selon l'allure ; 0 dans la zone interdite (vent debout).
static func polar(off_deg: float) -> float:
	if off_deg < NO_GO_DEG:
		return 0.0
	for i in range(1, POLAR.size()):
		var a: Array = POLAR[i - 1]
		var b: Array = POLAR[i]
		if off_deg <= float(b[0]):
			var k: float = (off_deg - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), k)
	return float(POLAR[POLAR.size() - 1][1])

# Côté du vent (amures) : -1 bâbord, +1 tribord, 0 vent debout.
static func tack_side(heading: float, wind_from: float) -> int:
	var d: float = angle_difference(wind_from, heading)
	if absf(rad_to_deg(d)) < NO_GO_DEG:
		return 0
	return 1 if d > 0.0 else -1

# --- Scène ---

func _ready() -> void:
	EventBus.minigame_started.emit("regata")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	var quit_btn: CanvasLayer = get_node_or_null("MinigameQuitButton")
	if quit_btn and quit_btn.has_signal("quit_pressed"):
		quit_btn.quit_pressed.connect(_end_game)
	_hud = _label(Vector2(-900, -530), Vector2(1800, 50), 28)
	_status = _label(Vector2(-900, 470), Vector2(1800, 56), 24)
	_hold_button(Vector2(-940, 320), "◀ Bombordo", true)
	_hold_button(Vector2(660, 320), "Boreste ▶", false)
	var vent: Label = _label(Vector2(-860, -310), Vector2(160, 30), 20)
	vent.text = "VENT"
	_last_side = tack_side(_heading, _wind_from)
	_set_status("Le vent vient du nord. Tire des bords vers la bouée au vent — jamais face au vent !")

func _label(pos: Vector2, size: Vector2, font: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color(0.98, 0.97, 0.92, 1))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.18, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.z_index = 5
	add_child(l)
	return l

# Bouton à maintenir (tactile) : barre tant qu'il est enfoncé.
func _hold_button(pos: Vector2, text: String, left: bool) -> void:
	var b: Button = Button.new()
	b.position = pos
	b.size = Vector2(280, 150)
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.z_index = 5
	b.button_down.connect(func(): _set_turn(left, true))
	b.button_up.connect(func(): _set_turn(left, false))
	add_child(b)

func _set_turn(left: bool, on: bool) -> void:
	if left:
		_turn_left = on
	else:
		_turn_right = on

func _process(delta: float) -> void:
	if _ended:
		return
	_time += delta
	if _time >= TIME_LIMIT:
		_set_status("⏱ Temps écoulé — la Marina rentre les bateaux.")
		_end_game()
		return
	_update_wind(delta)
	_update_boat(delta)
	_update_rival(delta)
	_check_marks()
	_refresh_hud()
	queue_redraw()

func _update_wind(delta: float) -> void:
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)
		_wind_target = -PI / 2.0 + deg_to_rad(_rng.randf_range(-GUST_SHIFT_DEG, GUST_SHIFT_DEG))
		_set_status("🌬 Rafale — le vent tourne. Ajuste ton cap.")
	_wind_from = lerp_angle(_wind_from, _wind_target, clampf(delta * 0.6, 0.0, 1.0))

func _update_boat(delta: float) -> void:
	var turn: float = 0.0
	if _turn_left or Input.is_action_pressed("ui_left"):
		turn -= 1.0
	if _turn_right or Input.is_action_pressed("ui_right"):
		turn += 1.0
	_heading = wrapf(_heading + turn * TURN_RATE * delta, -PI, PI)
	var off: float = off_wind_deg(_heading, _wind_from)
	var target: float = MAX_SPEED * polar(off)
	if target <= 0.0:
		_speed = maxf(0.0, _speed - MAX_SPEED * LUFF_DRAG * delta * 0.5)
		_luff_time += delta
	else:
		_speed = lerpf(_speed, target, clampf(ACCEL * delta, 0.0, 1.0))
	# Virement de bord : on change d'amures en passant par le vent debout.
	var side: int = tack_side(_heading, _wind_from)
	if side != 0:
		if _last_side != 0 and side != _last_side:
			if _luff_time <= CLEAN_TACK_SEC:
				_set_status("✨ Bordo limpo ! Virement propre, le bateau repart.")
			else:
				_set_status("Virement lent — tu as perdu ton erre face au vent.")
		elif _luff_time > 2.5:
			_set_status("Vela panejando — abats, sors du lit du vent !")
		_last_side = side
		_luff_time = 0.0
	var next: Vector2 = _pos + Vector2.from_angle(_heading) * _speed * delta
	if not ARENA.has_point(next):
		next = Vector2(clampf(next.x, ARENA.position.x, ARENA.end.x), clampf(next.y, ARENA.position.y, ARENA.end.y))
		_speed *= 0.3
	_pos = next
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(_pos) > 14.0:
		_trail.append(_pos)
		if _trail.size() > 40:
			_trail.remove_at(0)

# Bia suit sa trajectoire avec la même polaire (un peu moins bien réglée).
func _update_rival(delta: float) -> void:
	if _rival_done_at >= 0.0 or _rival_seg >= RIVAL_PATH.size() - 1:
		return
	var target: Vector2 = RIVAL_PATH[_rival_seg + 1]
	var dir: Vector2 = (target - _rival_pos).normalized()
	var off: float = off_wind_deg(dir.angle(), _wind_from)
	var v: float = MAX_SPEED * RIVAL_SKILL * maxf(polar(off), 0.45)
	var step: float = v * delta
	if _rival_pos.distance_to(target) <= step:
		_rival_pos = target
		_rival_seg += 1
		if _rival_seg >= RIVAL_PATH.size() - 1:
			_rival_done_at = _time
			_set_status("🚩 Bia a franchi l'arrivée !")
	else:
		_rival_pos += dir * step

func _check_marks() -> void:
	if _next_mark >= MARKS.size():
		return
	if _pos.distance_to(MARKS[_next_mark]) <= ROUND_RADIUS:
		_next_mark += 1
		if _next_mark >= MARKS.size():
			_finished_at = _time
			_end_game()
		else:
			_set_status("✔ %s passée — cap sur la %s." % [MARK_NAMES[_next_mark - 1].capitalize(), MARK_NAMES[_next_mark]])

func _refresh_hud() -> void:
	var knots: float = _speed / MAX_SPEED * 7.0
	var off: int = int(off_wind_deg(_heading, _wind_from))
	var allure: String = "vent debout" if off < NO_GO_DEG else ("près" if off < 70 else ("travers" if off < 115 else ("largue" if off < 160 else "vent arrière")))
	if _hud:
		_hud.text = "⛵ Regata da Glória · %ds · %.1f nœuds · %s · prochaine : %s" \
				% [int(TIME_LIMIT - _time), knots, allure, MARK_NAMES[mini(_next_mark, MARKS.size() - 1)]]

func _draw() -> void:
	# Sillage.
	for i in range(1, _trail.size()):
		draw_line(_trail[i - 1], _trail[i], Color(1, 1, 1, 0.12 + 0.02 * i), 3.0)
	# Bouées (la prochaine est cerclée).
	for i in MARKS.size():
		var col: Color = Color(1.0, 0.55, 0.1, 1) if i < MARKS.size() - 1 else Color(0.95, 0.95, 0.95, 1)
		if i < _next_mark:
			col.a = 0.35
		draw_circle(MARKS[i], 16.0, col)
		if i == _next_mark:
			draw_arc(MARKS[i], ROUND_RADIUS, 0.0, TAU, 48, Color(1, 1, 0.6, 0.6), 3.0)
	draw_line(MARKS[MARKS.size() - 1] + Vector2(-110, 0), MARKS[MARKS.size() - 1] + Vector2(110, 0), Color(1, 1, 1, 0.5), 3.0)
	# Bia.
	_draw_boat(_rival_pos, (RIVAL_PATH[mini(_rival_seg + 1, RIVAL_PATH.size() - 1)] - _rival_pos).angle(), Color(0.85, 0.25, 0.25, 1))
	# Toi.
	_draw_boat(_pos, _heading, Color(0.98, 0.98, 0.95, 1))
	# Girouette : d'où vient le vent.
	var origin: Vector2 = Vector2(-780, -380)
	var wind_dir: Vector2 = -Vector2.from_angle(_wind_from)  # sens où il souffle
	draw_circle(origin, 54.0, Color(0, 0.15, 0.3, 0.45))
	draw_line(origin - wind_dir * 40.0, origin + wind_dir * 40.0, Color(0.7, 0.9, 1.0, 1), 5.0)
	draw_line(origin + wind_dir * 40.0, origin + wind_dir * 22.0 + wind_dir.orthogonal() * 12.0, Color(0.7, 0.9, 1.0, 1), 5.0)
	draw_line(origin + wind_dir * 40.0, origin + wind_dir * 22.0 - wind_dir.orthogonal() * 12.0, Color(0.7, 0.9, 1.0, 1), 5.0)

func _draw_boat(at: Vector2, heading: float, hull: Color) -> void:
	var fwd: Vector2 = Vector2.from_angle(heading)
	var side: Vector2 = fwd.orthogonal()
	var pts: PackedVector2Array = [at + fwd * 54.0, at - fwd * 36.0 + side * 22.0, at - fwd * 36.0 - side * 22.0]
	draw_colored_polygon(pts, hull)
	# Bôme : sous le vent, plus ouverte quand on abat.
	var off: float = off_wind_deg(heading, _wind_from)
	var lee: float = -1.0 if angle_difference(_wind_from, heading) > 0.0 else 1.0
	var open: float = deg_to_rad(clampf((off - 30.0) * 0.5, 5.0, 80.0))
	var boom: Vector2 = (-fwd).rotated(lee * open)
	draw_line(at + fwd * 10.0, at + fwd * 10.0 + boom * 60.0, Color(0.95, 0.85, 0.3, 1), 7.0)

func _set_status(text: String) -> void:
	if _status:
		_status.text = text

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_end_game()
		get_viewport().set_input_as_handled()

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	_turn_left = false
	_turn_right = false
	var qualifies: bool = _finished_at >= 0.0
	var beat_rival: bool = qualifies and (_rival_done_at < 0.0 or _finished_at < _rival_done_at)
	if beat_rival:
		_set_status("🏆 PERFEITO — arrivée en %ds, devant Bia ! A Glória é sua." % int(_finished_at))
	elif qualifies:
		_set_status("✔ Arrivée en %ds — Bia était devant, mas você leu o vento." % int(_finished_at))
	elif _time < TIME_LIMIT:
		_set_status("Abandon — le vent sera encore là demain.")
	await get_tree().create_timer(2.0).timeout
	EventBus.minigame_ended.emit("regata",
		{"qualifies": qualifies, "won": beat_rival, "time": _finished_at, "marks": _next_mark})
	match_ended.emit(qualifies, beat_rival)
