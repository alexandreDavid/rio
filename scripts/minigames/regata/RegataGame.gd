class_name RegataGame
extends MinigameBase

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

# Habillage (rendu seul, aucune incidence sur la course).
const Art := preload("res://scripts/minigames/regata/RegataArt.gd")
const SEA_BAY: Color = Color(0.2, 0.55, 0.68)
const RIPPLE_COUNT: int = 90
const RIPPLE_RECT: Rect2 = Rect2(-930, -720, 2700, 1155)
const RIPPLE_SPEED: float = 46.0
const WAKE_LIFE: float = 1.7
const SAIL_HEIGHT: float = 51.0
const SAIL_FOOT: float = 63.0
const WIND_GAUGE: Vector2 = Vector2(-780, -380)
const PONTOONS_X: Array[float] = [-470.0, 470.0, 1080.0]
const PALMS: Array[Vector2] = [Vector2(-1130, 560), Vector2(-1020, 575), Vector2(-300, 572), Vector2(330, 568), Vector2(1010, 566), Vector2(1135, 578),
	Vector2(-1090, -330), Vector2(-1150, -90), Vector2(-1080, 170), Vector2(-1140, 390)]
const WATCHERS: Array[Vector2] = [Vector2(-150, 492), Vector2(-112, 494), Vector2(205, 493), Vector2(-1000, 495)]
const URCA_BASE: Vector2 = Vector2(505, -394)
const PAO_BASE: Vector2 = Vector2(700, -394)

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

var _anim_t: float = 0.0
var _gust_flash: float = 0.0
var _ripples: Array[Vector2] = []
var _wake_p: Array = []   # [position, instant, travers, vitesse relative]
var _wake_r: Array = []
var _fx: Node2D
var _peaks: Node2D
var _boat_p: Dictionary = {}
var _boat_r: Dictionary = {}
var _rival_heading: float = -PI / 2.0

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
	_hud = _label(Vector2(-900, -530), Vector2(1800, 50), 28)
	_status = _label(Vector2(-900, 470), Vector2(1800, 56), 24)
	_hold_button(Vector2(-940, 320), "◀ Bombordo", true)
	_hold_button(Vector2(660, 320), "Boreste ▶", false)
	var vent: Label = _label(Vector2(-860, -320), Vector2(160, 34), 24)
	vent.text = "VENT"
	_last_side = tack_side(_heading, _wind_from)
	_build_scene_art()
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
	_step_fx(delta)
	if _ended:
		queue_redraw()
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
	_sync_boats(delta)
	queue_redraw()

func _update_wind(delta: float) -> void:
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)
		_wind_target = -PI / 2.0 + deg_to_rad(_rng.randf_range(-GUST_SHIFT_DEG, GUST_SHIFT_DEG))
		_gust_flash = 2.5
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
				sfx("mg_good")
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
		sfx("checkpoint")
		pulse(0.3, 0.06)
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

# --- Rendu (habillage pixel ; la logique ci-dessus reste seule maîtresse) ---

func _build_scene_art() -> void:
	for n in ["PaoDeAcucar", "AterroShore"]:
		var r: CanvasItem = get_node_or_null(n)
		if r:
			r.visible = false
	var bay: ColorRect = get_node_or_null("Bay")
	if bay:
		bay.color = SEA_BAY
	# Mer peinte de la baie (défile et scintille comme à Copa).
	var sea_origin: Vector2 = Vector2(-1800, -720)
	var sea: Sprite2D = DistrictDresser.painted_sprite(GroundPainter.sea(SEA_BAY, 11), Vector2(3600, 1440), DistrictDresser.sea_anim(sea_origin))
	sea.name = "SeaPainted"
	sea.position = sea_origin
	sea.z_index = -10
	add_child(sea)
	# Risées, sillages, ressac : couche animée au ras de l'eau.
	_fx = Node2D.new()
	_fx.name = "SeaFx"
	_fx.z_index = -8
	_fx.draw.connect(_draw_sea_fx)
	add_child(_fx)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for i in RIPPLE_COUNT:
		_ripples.append(Vector2(rng.randf_range(RIPPLE_RECT.position.x, RIPPLE_RECT.end.x), rng.randf_range(RIPPLE_RECT.position.y, RIPPLE_RECT.end.y)))
	_build_marina()
	_build_peaks()
	_boat_r = _make_boat(Color(0.86, 0.22, 0.2), Color(0.98, 0.95, 0.88), Color(0.98, 0.94, 0.86), Color(0.86, 0.2, 0.18), CharacterSpriteFactory.random_config(1307))
	_boat_p = _make_boat(Color(0.97, 0.97, 0.94), Color(0.2, 0.45, 0.85), Color(0.99, 0.99, 0.96), Color(0.2, 0.45, 0.85), {})
	_rival_heading = (RIVAL_PATH[1] - RIVAL_PATH[0]).angle()
	_sync_boats(0.0)

# Marina da Glória : quai et gazon de l'Aterro au sud et à l'ouest, pontons
# et voiliers au mouillage, palmiers.
func _build_marina() -> void:
	var land: Node2D = Node2D.new()
	land.name = "Aterro"
	land.z_index = -6
	add_child(land)
	var moored: Node2D = Node2D.new()
	moored.name = "Mouillage"
	moored.z_index = -7
	add_child(moored)
	var rect: Rect2 = Rect2(-1701, -720, 3402, 1440)
	# Deux nappes (sud, ouest) plutôt qu'une image pleine d'eau transparente.
	for r in [Rect2(rect.position.x, Art.SHORE_Y, rect.size.x, rect.end.y - Art.SHORE_Y),
			Rect2(rect.position.x, rect.position.y, Art.WEST_X - rect.position.x, Art.SHORE_Y - rect.position.y)]:
		var s: Sprite2D = Art.sprite(Art.shore_texture(r))
		s.centered = false
		s.position = r.position
		land.add_child(s)
	var pont: ImageTexture = Art.pontoon_texture(7, 16)
	var moor_hues: Array[Color] = [Color(0.97, 0.97, 0.94), Color(0.2, 0.4, 0.7), Color(0.95, 0.85, 0.3), Color(0.97, 0.97, 0.94), Color(0.25, 0.6, 0.45)]
	var k: int = 0
	for px in PONTOONS_X:
		var p: Sprite2D = Art.sprite(pont)
		p.centered = false
		p.position = Vector2(px - 10.5, Art.SHORE_Y - 48.0)
		moored.add_child(p)
		for side in [-1.0, 1.0]:
			var hue: Color = moor_hues[k % moor_hues.size()]
			k += 1
			var b: Sprite2D = Art.sprite(Art.hull_texture(30, 12, hue, Color(0.2, 0.3, 0.55) if hue.v > 0.8 else Color(0.95, 0.95, 0.9), true))
			b.rotation = -PI / 2.0
			b.position = Vector2(px + side * 33.0, Art.SHORE_Y - 42.0)
			moored.add_child(b)
	# Pontons de l'ouest (visibles sur les écrans larges).
	for py in [-260.0, -60.0, 140.0]:
		var p2: Sprite2D = Art.sprite(pont)
		p2.rotation = PI / 2.0
		p2.position = Vector2(Art.WEST_X + 24.0, py)
		moored.add_child(p2)
		var b2: Sprite2D = Art.sprite(Art.hull_texture(30, 12, moor_hues[k % moor_hues.size()], Color(0.95, 0.95, 0.9), true))
		k += 1
		b2.position = Vector2(Art.WEST_X + 42.0, py + 33.0)
		moored.add_child(b2)
	for pos in PALMS:
		PropSprites.spawn(land, PropSprites.palm_region_at(pos), pos, PropSprites.palm_height_at(pos))
	# Promeneurs du calçadão (immobiles : on regarde la régate).
	for i in WATCHERS.size():
		var w: Sprite2D = char_sprite(64.0, CharacterSpriteFactory.random_config(90 + i * 7))
		w.region_rect = Rect2(0, CharacterSpriteFactory.DIR_UP * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
		w.position = WATCHERS[i]
		land.add_child(w)

# Pão de Açúcar et Morro da Urca dans le coin nord-est, sur leurs hauts-fonds,
# avec le bondinho qui va et vient.
func _build_peaks() -> void:
	_peaks = Node2D.new()
	_peaks.name = "PaoDeAcucarArt"
	_peaks.z_index = -5
	add_child(_peaks)
	var rock: Color = Color(0.56, 0.52, 0.5)
	for spec in [[URCA_BASE, Vector2i(54, 30), 3], [PAO_BASE, Vector2i(92, 50), 5]]:
		var base: Vector2 = spec[0]
		var sz: Vector2i = spec[1]
		var shoal: Sprite2D = Art.sprite(GroundPainter.outcrop(sz.x + 14, 9, rock.darkened(0.1), spec[2]))
		shoal.position = base + Vector2(0, 2)
		_peaks.add_child(shoal)
		var dome: Sprite2D = Art.sprite(GroundPainter.dome(sz.x, sz.y, rock, GroundPainter.FOREST_COLOR, spec[2]))
		dome.centered = false
		dome.position = base - Vector2(sz.x * 1.5, sz.y * 3.0 - 6.0)
		_peaks.add_child(dome)
	_peaks.draw.connect(_draw_peaks)

func _draw_peaks() -> void:
	# Câble du bondinho entre les deux sommets, légère flèche.
	var a: Vector2 = URCA_BASE + Vector2(0, -84)
	var b: Vector2 = PAO_BASE + Vector2(0, -144)
	for i in 41:
		var t: float = float(i) / 40.0
		var p: Vector2 = a.lerp(b, t) + Vector2(0, sin(t * PI) * 16.0)
		Art.cell(_peaks, p, Color(0.15, 0.15, 0.2, 0.9))
	var u: float = 0.5 - 0.5 * cos(_anim_t * 0.35)
	var car: Vector2 = a.lerp(b, u) + Vector2(0, sin(u * PI) * 16.0 + 3.0)
	var o: Vector2 = (car / Art.D).floor() * Art.D
	_peaks.draw_rect(Rect2(o + Vector2(-6, 0), Vector2(15, 12)), Art.OUTLINE)
	_peaks.draw_rect(Rect2(o + Vector2(-3, 3), Vector2(9, 6)), Color(0.95, 0.8, 0.25))
	_peaks.draw_rect(Rect2(o + Vector2(-3, 3), Vector2(9, 3)), Color(0.7, 0.88, 0.95))

# Un voilier = ombre + coque (tournées au cap), gréement dessiné, équipier.
func _make_boat(hull: Color, stripe: Color, sail: Color, band: Color, crew_cfg: Dictionary) -> Dictionary:
	var root: Node2D = Node2D.new()
	root.z_index = 2
	add_child(root)
	var tex: ImageTexture = Art.hull_texture(36, 14, hull, stripe)
	var shadow: Sprite2D = Art.sprite(tex)
	shadow.modulate = Color(0.02, 0.1, 0.18, 0.35)
	shadow.position = Vector2(6, 9)
	root.add_child(shadow)
	var body: Sprite2D = Art.sprite(tex)
	root.add_child(body)
	var rig: Node2D = Node2D.new()
	root.add_child(rig)
	var crew: Sprite2D = char_sprite(64.0, crew_cfg)
	# Buste seulement : l'équipier est assis au rappel, à la barre.
	crew.offset = Vector2.ZERO
	root.add_child(crew)
	var boat: Dictionary = {"root": root, "shadow": shadow, "hull": body, "rig": rig, "crew": crew,
		"sail": sail, "band": band, "heading": 0.0, "speed": 0.0, "pos": Vector2.ZERO}
	rig.draw.connect(_draw_rig.bind(boat))
	return boat

func _sync_boats(delta: float) -> void:
	if _boat_p.is_empty():
		return
	var rival_dir: Vector2 = RIVAL_PATH[mini(_rival_seg + 1, RIVAL_PATH.size() - 1)] - _rival_pos
	if rival_dir.length() > 1.0 and _rival_done_at < 0.0:
		_rival_heading = lerp_angle(_rival_heading, rival_dir.angle(), clampf(delta * 4.0, 0.0, 1.0))
	var rival_speed: float = 0.0 if _rival_done_at >= 0.0 else MAX_SPEED * RIVAL_SKILL * maxf(polar(off_wind_deg(_rival_heading, _wind_from)), 0.45)
	_place_boat(_boat_p, _pos, _heading, _speed, _wake_p)
	_place_boat(_boat_r, _rival_pos, _rival_heading, rival_speed, _wake_r)

func _place_boat(boat: Dictionary, at: Vector2, heading: float, speed: float, wake: Array) -> void:
	boat.pos = at
	boat.heading = heading
	boat.speed = speed
	var root: Node2D = boat.root
	root.position = at.round()
	(boat.hull as Sprite2D).rotation = heading
	(boat.shadow as Sprite2D).rotation = heading
	var fwd: Vector2 = Vector2.from_angle(heading)
	# Équipier au vent, à l'arrière du cockpit, tourné vers l'étrave.
	var blow: Vector2 = -Vector2.from_angle(_wind_from)
	var windward: Vector2 = fwd.orthogonal()
	if windward.dot(blow) > 0.0:
		windward = -windward
	var crew: Sprite2D = boat.crew
	crew.position = (-fwd * 30.0 + windward * 10.0 + Vector2(0, -12)).round()
	var dir: int = CharacterSpriteFactory.DIR_RIGHT
	if absf(fwd.y) > absf(fwd.x) * 1.2:
		dir = CharacterSpriteFactory.DIR_UP if fwd.y < 0.0 else CharacterSpriteFactory.DIR_DOWN
	crew.flip_h = dir == CharacterSpriteFactory.DIR_RIGHT and fwd.x < 0.0
	crew.region_rect = Rect2(0, dir * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, 63)
	(boat.rig as Node2D).queue_redraw()
	# Sillage : un point tous les 10 px parcourus.
	if speed > 8.0 and (wake.is_empty() or (wake[wake.size() - 1][0] as Vector2).distance_to(at) > 10.0):
		wake.append([at - fwd * 50.0, _anim_t, fwd.orthogonal(), speed / MAX_SPEED])
	while not wake.is_empty() and _anim_t - float(wake[0][1]) > WAKE_LIFE:
		wake.remove_at(0)

# Gréement en légère vue 3/4 (le mât monte vers le haut de l'écran) : la voile
# est un triangle mât–tête–point d'écoute, bôme orientée selon l'allure, chute
# creusée sous le vent quand elle porte, qui ondule et bat quand elle fasseye.
func _draw_rig(boat: Dictionary) -> void:
	var rig: Node2D = boat.rig
	var heading: float = boat.heading
	var fwd: Vector2 = Vector2.from_angle(heading)
	var off: float = off_wind_deg(heading, _wind_from)
	var lee: float = -1.0 if angle_difference(_wind_from, heading) > 0.0 else 1.0
	var open: float = deg_to_rad(clampf((off - 30.0) * 0.5, 5.0, 80.0))
	var boom: Vector2 = (-fwd).rotated(lee * open)
	var blow: Vector2 = -Vector2.from_angle(_wind_from)
	var perp: Vector2 = boom.orthogonal()
	if perp.dot(blow) < 0.0:
		perp = -perp
	var luff: bool = off < NO_GO_DEG
	var speed_k: float = clampf(float(boat.speed) / MAX_SPEED, 0.0, 1.0)
	var mast: Vector2 = fwd * 21.0
	var clew: Vector2 = mast + boom * SAIL_FOOT
	# Gîte : la tête de mât penche sous le vent quand ça porte.
	var heel: Vector2 = Vector2(perp.x, perp.y * 0.5) * (4.0 + 8.0 * speed_k) * (0.0 if luff else 1.0)
	var head: Vector2 = mast + Vector2(0, -SAIL_HEIGHT) + heel
	# Chute (tête → écoute) : creux bombé vers l'extérieur du triangle, ou onde
	# de faseyement. Mesuré à la corde : la voile garde une largeur lisible
	# même quand la bôme pointe vers le bas de l'écran.
	var chord: Vector2 = clew - head
	var bulge: Vector2 = chord.orthogonal().normalized()
	if bulge.dot(head.lerp(clew, 0.5) - mast) < 0.0:
		bulge = -bulge
	var poly: PackedVector2Array = [mast, head]
	for i in range(1, 10):
		var t: float = float(i) / 10.0
		var p: Vector2 = head.lerp(clew, t)
		var b: float
		if luff:
			b = 9.0 * sin(t * TAU * 1.5 - _anim_t * 16.0) * sin(t * PI)
		else:
			b = (16.0 + 10.0 * speed_k) * sin(t * PI) * (1.0 - 0.25 * t)
		poly.append(p + bulge * b)
	poly.append(clew)
	var origin: Vector2 = (boat.pos as Vector2).round()
	# Ombre portée sur l'eau (lumière du nord-ouest).
	var sh: PackedVector2Array = PackedVector2Array()
	for p in poly:
		var lift: float = mast.y - p.y
		sh.append(Vector2(p.x, mast.y) + Vector2(0.55, 0.35) * lift + Vector2(6, 10))
	_raster(rig, origin, sh, func(_u: float, _v: float, _edge: bool) -> Color: return Color(0.02, 0.1, 0.18, 0.22))
	# Voile : bandes de ton du guindant à la chute, bande de couleur du club.
	var sail: Color = boat.sail
	var band: Color = boat.band
	var flap: int = int(_anim_t * 10.0)
	var tone: Callable = func(u: float, v: float, edge: bool) -> Color:
		if edge:
			return sail.darkened(0.55)
		var c: Color = sail.lightened(0.12) if u < 0.3 else (sail if u < 0.7 else sail.darkened(0.14))
		if v > 0.18 and v < 0.27:
			c = band
		if luff and (int(u * 9.0) + flap) % 3 == 0:
			c = c.darkened(0.22)
		return c
	_raster(rig, origin, poly, tone, mast, head, clew)
	# Mât et bôme.
	var spar: Color = Color(0.28, 0.24, 0.22)
	for k in int(SAIL_HEIGHT / Art.D) + 1:
		var t2: float = float(k) / (SAIL_HEIGHT / Art.D)
		_cell_local(rig, origin, mast.lerp(head, t2), spar)
	var n: int = int(SAIL_FOOT / Art.D)
	for k in n + 1:
		_cell_local(rig, origin, mast.lerp(clew, float(k) / float(n)), spar)
	# Penon en tête de mât : il file sous le vent.
	var tell: Vector2 = head + blow * (12.0 + sin(_anim_t * 14.0) * 3.0)
	for k in 4:
		_cell_local(rig, origin, head.lerp(tell, float(k) / 3.0), Color(0.95, 0.3, 0.2))
	# Moustaches d'étrave quand ça file.
	if speed_k > 0.45 and not luff:
		var side: Vector2 = fwd.orthogonal()
		var fl: float = 1.0 if int(_anim_t * 12.0) % 2 == 0 else 0.0
		for sgn in [-1.0, 1.0]:
			_cell_local(rig, origin, fwd * 54.0 + side * sgn * (12.0 + fl * 3.0), Color(1, 1, 1, 0.85))
			_cell_local(rig, origin, fwd * 47.0 + side * sgn * (18.0 + fl * 3.0), Color(1, 1, 1, 0.6))

# Cellule calée sur la grille monde, dessinée dans un nœud placé en `origin`.
func _cell_local(ci: CanvasItem, origin: Vector2, lp: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(((origin + lp) / Art.D).floor() * Art.D - origin, Vector2(Art.D, Art.D)), col)

# Remplit `poly` (local au bateau) de cellules calées sur la grille monde ;
# `shade(u, v, edge)` : u = 0 au guindant → 1 à la chute, v = 0 en pied → 1 en tête.
func _raster(ci: CanvasItem, origin: Vector2, poly: PackedVector2Array, shade: Callable, mast: Vector2 = Vector2.ZERO, head: Vector2 = Vector2.ZERO, clew: Vector2 = Vector2.ZERO) -> void:
	var box: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var d: float = Art.D
	var x0: float = floor((origin.x + box.position.x) / d) * d
	var y0: float = floor((origin.y + box.position.y) / d) * d
	var inside: Dictionary = {}
	var y: float = y0
	while y <= origin.y + box.end.y:
		var x: float = x0
		while x <= origin.x + box.end.x:
			var lp: Vector2 = Vector2(x + d * 0.5, y + d * 0.5) - origin
			if Geometry2D.is_point_in_polygon(lp, poly):
				inside[Vector2i(int(x / d), int(y / d))] = lp
			x += d
		y += d
	var up: Vector2 = head - mast
	var foot: Vector2 = clew - mast
	for key in inside:
		var c: Vector2i = key
		var edge: bool = not (inside.has(c + Vector2i(1, 0)) and inside.has(c - Vector2i(1, 0)) and inside.has(c + Vector2i(0, 1)) and inside.has(c - Vector2i(0, 1)))
		var lp2: Vector2 = inside[key]
		var u: float = 0.0
		var v: float = 0.0
		if up.length_squared() > 0.0:
			v = clampf((lp2 - mast).dot(up) / up.length_squared(), 0.0, 1.0)
			u = clampf((lp2 - mast).dot(foot) / maxf(foot.length_squared(), 1.0) + v * 0.6, 0.0, 1.0)
		var col: Color = shade.call(u, v, edge)
		ci.draw_rect(Rect2(Vector2(c) * d - origin, Vector2(d, d)), col)

# Couche de l'eau : risées qui filent avec le vent, ressac au pied du quai,
# remous autour des bouées, sillages en V.
func _draw_sea_fx() -> void:
	var blow: Vector2 = -Vector2.from_angle(_wind_from)
	var crest: Vector2 = blow.orthogonal()
	var gust: float = clampf(_gust_flash / 2.5, 0.0, 1.0)
	var light: Color = SEA_BAY.lightened(0.42)
	var dark: Color = SEA_BAY.darkened(0.2)
	for i in _ripples.size():
		var p: Vector2 = _ripples[i]
		var n: int = 3 + i % 3 + (1 if gust > 0.0 else 0)
		var a: float = 0.45 + 0.35 * gust
		for k in n:
			var q: Vector2 = p + crest * float(k) * Art.D
			Art.cell(_fx, q, Color(light, a))
			if k > 0 and k < n - 1:
				Art.cell(_fx, q + blow * Art.D, Color(dark, a * 0.7))
	# Ressac le long du quai sud et ouest.
	var tick: int = int(_anim_t * 3.0)
	var x: float = Art.WEST_X
	while x < 1700.0:
		var h: int = absi(int(x / 3.0) * 7919 + tick * 31) % 7
		if h < 3:
			Art.cell(_fx, Vector2(x, Art.SHORE_Y - 6.0 - float(h % 2) * 3.0), Color(1, 1, 1, 0.75))
		x += 6.0
	var y: float = -720.0
	while y < Art.SHORE_Y:
		var h2: int = absi(int(y / 3.0) * 6151 + tick * 17) % 7
		if h2 < 3:
			Art.cell(_fx, Vector2(Art.WEST_X + 3.0 + float(h2 % 2) * 3.0, y), Color(1, 1, 1, 0.75))
		y += 6.0
	# Remous autour des bouées.
	for m in _unique_marks():
		var r: float = 24.0 + fmod(_anim_t * 10.0 + m.x * 0.01, 12.0)
		var fade: float = 1.0 - (r - 24.0) / 12.0
		for k in 16:
			var ang: float = float(k) / 16.0 * TAU
			Art.cell(_fx, m + Vector2.from_angle(ang) * r, Color(1, 1, 1, 0.35 * fade))
	# Sillages.
	for wake in [_wake_p, _wake_r]:
		for wi in wake.size():
			var e: Array = wake[wi]
			if wi % 2 == 1 and _anim_t - float(e[1]) > 0.5:
				continue
			var age: float = _anim_t - float(e[1])
			var f: float = 1.0 - age / WAKE_LIFE
			var at: Vector2 = e[0]
			var side: Vector2 = e[2]
			var spread: float = 6.0 + age * 12.0 * float(e[3])
			Art.cell(_fx, at + side * spread, Color(1, 1, 1, 0.6 * f))
			Art.cell(_fx, at - side * spread, Color(1, 1, 1, 0.6 * f))
			if age < 0.7:
				Art.cell(_fx, at, Color(0.85, 0.95, 1.0, 0.5 * f), 2.0)

func _step_fx(delta: float) -> void:
	_anim_t += delta
	_gust_flash = maxf(0.0, _gust_flash - delta)
	var blow: Vector2 = -Vector2.from_angle(_wind_from)
	var v: float = RIPPLE_SPEED * (1.0 + 0.8 * clampf(_gust_flash / 2.5, 0.0, 1.0))
	var r: Rect2 = RIPPLE_RECT
	for i in _ripples.size():
		var p: Vector2 = _ripples[i] + blow * v * delta * (0.8 + 0.4 * float(i % 3) / 2.0)
		p.x = wrapf(p.x, r.position.x, r.end.x)
		p.y = wrapf(p.y, r.position.y, r.end.y)
		_ripples[i] = p
	if _fx:
		_fx.queue_redraw()
	if _peaks:
		_peaks.queue_redraw()

func _unique_marks() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for m in MARKS:
		if not out.has(m):
			out.append(m)
	return out

func _draw() -> void:
	var blow: Vector2 = -Vector2.from_angle(_wind_from)
	var finish: Vector2 = MARKS[MARKS.size() - 1]
	# Ligne d'arrivée : pointillés entre deux piquets à damier.
	var x: float = -110.0
	while x <= 110.0:
		if int((x + 110.0) / 12.0) % 2 == 0:
			Art.cell(self, finish + Vector2(x, 0), Color(1, 1, 1, 0.7), 2.0)
		x += 6.0
	for sx in [-110.0, 110.0]:
		_draw_buoy(finish + Vector2(sx, 0), Color(0.96, 0.96, 0.94), false, 1.0, blow, true)
	# Bouées de parcours.
	for m in _unique_marks():
		var idx: Array[int] = []
		for i in MARKS.size():
			if MARKS[i] == m:
				idx.append(i)
		var is_next: bool = idx.has(_next_mark)
		var passed: bool = idx.all(func(i: int) -> bool: return i < _next_mark)
		var is_finish: bool = idx.has(MARKS.size() - 1)
		var col: Color = Color(1.0, 0.52, 0.1) if not is_finish else Color(0.96, 0.96, 0.94)
		_draw_buoy(m, col, is_next, 0.4 if passed else 1.0, blow, is_finish)
		if is_next:
			_draw_target_ring(m)
	# Repère de cap vers la prochaine bouée, devant ton étrave.
	if _next_mark < MARKS.size() and not _ended:
		var to: Vector2 = MARKS[_next_mark] - _pos
		if to.length() > 220.0:
			_draw_chevron(_pos + to.normalized() * 96.0, to.angle(), Color(1.0, 0.9, 0.35, 0.9))
	_draw_wind_gauge(blow)

# Bouée de régate vue de haut : boudin orange, bande blanche, ombre, fanion
# qui claque dans le vent (damier pour l'arrivée).
func _draw_buoy(at: Vector2, col: Color, hot: bool, alpha: float, blow: Vector2, checkered: bool) -> void:
	var bob: float = round(sin(_anim_t * 2.4 + at.x * 0.02))
	var c: Vector2 = at + Vector2(0, bob * Art.D * 0.5)
	Art.disc(self, c + Vector2(6, 6), 5, Color(0.02, 0.1, 0.18), 0.3 * alpha)
	Art.disc(self, c, 5, col, alpha)
	var o: Vector2 = (c / Art.D).floor() * Art.D
	for i in range(-3, 4):
		draw_rect(Rect2(o + Vector2(i, 0) * Art.D, Vector2(Art.D, Art.D)), Color(1, 1, 1, 0.9 * alpha))
	# Hampe et fanion.
	for j in 9:
		draw_rect(Rect2(o + Vector2(0, -1 - j) * Art.D, Vector2(Art.D, Art.D)), Color(Art.OUTLINE, alpha))
	var sgn: float = 1.0 if blow.x >= -0.05 else -1.0
	var flag: Color = Color(1.0, 0.85, 0.2) if hot else Color(0.9, 0.2, 0.18)
	for i in 5:
		var wave: int = int(round(sin(_anim_t * 9.0 - float(i) * 1.1) * 0.8))
		var hgt: int = 3 - i / 2
		for j in hgt:
			var cc: Color = flag
			if checkered:
				cc = Color(0.1, 0.1, 0.12) if (i + j) % 2 == 0 else Color(0.97, 0.97, 0.95)
			cc.a *= alpha
			draw_rect(Rect2(o + Vector2(sgn * float(1 + i), -10 + j + wave) * Art.D, Vector2(Art.D, Art.D)), cc)

# Cercle d'approche de la bouée à rejoindre : pointillés qui tournent et un
# chevron qui sautille au-dessus.
func _draw_target_ring(at: Vector2) -> void:
	var n: int = 44
	for k in n:
		if k % 2 == 1:
			continue
		var ang: float = float(k) / float(n) * TAU + _anim_t * 0.6
		Art.cell(self, at + Vector2.from_angle(ang) * ROUND_RADIUS, Color(1.0, 0.92, 0.4, 0.85), 2.0)
	var top: Vector2 = at + Vector2(0, -58.0 + round(sin(_anim_t * 5.0) * 2.0) * Art.D)
	_draw_chevron(top, PI / 2.0, Color(1.0, 0.92, 0.4, 1.0))

func _draw_chevron(at: Vector2, angle: float, col: Color) -> void:
	# Pointe de flèche pleine, liseré sombre, pointe en `at`.
	draw_set_transform_matrix(Transform2D(Vector2.from_angle(angle), Vector2.from_angle(angle).orthogonal(), at))
	var line: Color = Color(Art.OUTLINE, col.a)
	for k in 6:
		var hw: int = k / 2 + 1
		for m in range(-hw, hw + 1):
			var edge: bool = absi(m) == hw or k == 0 or k == 5
			draw_rect(Rect2(-float(k + 1) * Art.D, (float(m) - 0.5) * Art.D, Art.D, Art.D), line if edge else col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# Girouette : cadran pixel, repère jaune d'où VIENT le vent, manche à air
# rayée qui file là où il souffle (et claque plus fort en rafale).
func _draw_wind_gauge(blow: Vector2) -> void:
	var o: Vector2 = WIND_GAUGE
	var r: int = 17
	var oo: Vector2 = (o / Art.D).floor() * Art.D
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var d2: int = i * i + j * j
			if d2 > r * r:
				continue
			var col: Color = Color(0.04, 0.15, 0.27, 0.62)
			if d2 > (r - 1) * (r - 1):
				col = Color(0.85, 0.93, 1.0, 0.9)
			elif d2 > (r - 2) * (r - 2):
				col = Color(0.02, 0.08, 0.15, 0.8)
			draw_rect(Rect2(oo + Vector2(i, j) * Art.D, Vector2(Art.D, Art.D)), col)
	# Graduations N/E/S/O.
	for q in 4:
		var t: Vector2 = Vector2.from_angle(float(q) * PI / 2.0)
		Art.cell(self, o + t * 40.0, Color(0.85, 0.93, 1.0, 0.9), 2.0)
	# Repère « vent du… ».
	var from_dir: Vector2 = Vector2.from_angle(_wind_from)
	for k in 3:
		Art.cell(self, o + from_dir * (44.0 - float(k) * 4.0), Color(1.0, 0.85, 0.2), 2.0 - float(k) * 0.5)
	# Mât et manche à air.
	var gust: float = clampf(_gust_flash / 2.5, 0.0, 1.0)
	var side: Vector2 = blow.orthogonal()
	draw_set_transform_matrix(Transform2D(blow, side, o))
	for u in 14:
		var seg: int = u / 3
		var half_w: float = 2.4 - float(u) / 7.0
		var flap: float = sin(_anim_t * (7.0 + 6.0 * gust) - float(u) * 0.6) * float(u) * (0.05 + 0.06 * gust)
		var col2: Color = Color(0.93, 0.27, 0.18) if seg % 2 == 0 else Color(0.97, 0.96, 0.92)
		var hw: int = int(round(half_w))
		for v in range(-hw, hw + 1):
			draw_rect(Rect2(float(u) * Art.D, (float(v) + flap) * Art.D - Art.D * 0.5, Art.D, Art.D), col2)
		draw_rect(Rect2(float(u) * Art.D, (float(hw) + flap) * Art.D + Art.D * 0.5, Art.D, Art.D * 0.6), Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(oo - Vector2(Art.D, Art.D), Vector2(Art.D * 2.0, Art.D * 2.0) + Vector2(Art.D, Art.D)), Art.OUTLINE)
	draw_rect(Rect2(oo, Vector2(Art.D, Art.D)), Color(0.85, 0.85, 0.82))

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
	var qualifies: bool = final_qualifies(_finished_at >= 0.0)
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
