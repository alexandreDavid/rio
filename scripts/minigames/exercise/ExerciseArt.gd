extends Node2D

# Rendu du Treino (aucune règle ici) : academia de bairro peinte une fois en
# pixels natifs ×3 (mur vert délavé, azulejos, grand miroir, pôsteres de luta,
# janela sur le morro, râtelier d'haltères, sol en caoutchouc) et l'athlète
# recomposé en natif à partir du sprite CharacterSpriteFactory : chaque série
# a sa vraie pose (supino couché, agachamento, remada alta) et la barre suit
# exactement la valeur du jeu. Effort lisible : visage crispé, sueur,
# tremblement au-delà de la zone. Le miroir renvoie la scène, vue de dos.

const PX: int = 3
const BODY_PX: int = 10
const INK: Color = Color(0.13, 0.10, 0.12)
const ROOM_L: float = -1320.0
const ROOM_T: float = -540.0
const ROOM_W: int = 880
const ROOM_H: int = 360
const FLOOR_ROW: int = 230

# Toile d'une pose (natif) : sprite 21×32 posé en (OX, OY), pieds en bas.
const CW: int = 60
const CH: int = 48
const OX: int = 20
const OY: int = 16
const STEPS: int = 12

const ATHLETE_FEET: Vector2 = Vector2(-250, 398)
const MIRROR_GLASS: Rect2 = Rect2(-741, -330, 984, 456)
const REFL_FEET: Vector2 = Vector2(-205, 112)
const REFL_PX: float = 7.0
const COACH_FEET: Vector2 = Vector2(345, 372)
const CLAPPER_FEET: Vector2 = Vector2(150, 252)
const CLAPPER_REFL_FEET: Vector2 = Vector2(178, 104)
const CURLER_FEET: Vector2 = Vector2(760, 262)
const FAN_POS: Vector2 = Vector2(381, -318)
const BOARD: Rect2 = Rect2(282, -168, 186, 156)

const STEEL: Color = Color(0.72, 0.74, 0.78)
const STEEL_DK: Color = Color(0.38, 0.40, 0.46)
const IRON: Color = Color(0.17, 0.17, 0.2)
const RED_PLATE: Color = Color(0.82, 0.2, 0.18)
const BLUE_PLATE: Color = Color(0.22, 0.42, 0.8)
const YELLOW_PLATE: Color = Color(0.95, 0.78, 0.2)
const GREEN_PLATE: Color = Color(0.25, 0.62, 0.32)
const VINYL: Color = Color(0.6, 0.12, 0.14)
const CHALK: Color = Color(0.93, 0.94, 0.88)
const WHITE: Color = Color(0.98, 0.97, 0.94)

const GLYPHS: Dictionary = {
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "C": ["###", "#..", "#..", "#..", "###"],
	"D": ["##.", "#.#", "#.#", "#.#", "##."], "E": ["###", "#..", "##.", "#..", "###"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "M": ["#.#", "###", "###", "#.#", "#.#"],
	"O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["###", "#.#", "###", "#..", "#.."],
	"J": ["..#", "..#", "..#", "#.#", "###"], "U": ["#.#", "#.#", "#.#", "#.#", "###"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."], "S": ["###", "#..", "###", "..#", "###"],
	"V": ["#.#", "#.#", "#.#", "#.#", ".#."], "L": ["#..", "#..", "#..", "#..", "###"],
	"G": ["###", "#..", "#.#", "#.#", "###"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"F": ["###", "#..", "##.", "#..", "#.."], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"-": ["...", "...", "###", "...", "..."], "!": [".#.", ".#.", ".#.", "...", ".#."],
	"H": ["#.#", "#.#", "###", "#.#", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"0": ["###", "#.#", "#.#", "#.#", "###"], "2": ["###", "..#", "###", "#..", "###"],
}

var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _base: Array[Image] = []
var _skin: Color
var _skin_sh: Color
var _shirt: Color
var _shirt_sh: Color
var _pants: Color
var _pants_sh: Color
var _long_pants: bool = false
var _pose_cache: Dictionary = {}

var _athlete: Sprite2D = null
var _refl: Sprite2D = null
var _coach: Sprite2D = null
var _coach_tex: Array[Texture2D] = []
var _coach_mood: int = 0
var _coach_t: float = 0.0
var _clapper: Sprite2D = null
var _clapper_refl: Sprite2D = null
var _hop_t: float = 9.0
var _curler: Sprite2D = null
var _curl_tex: Array[Texture2D] = []
var _fan: Node2D = null
var _fx: Node2D = null
var _board: Node2D = null
var _board_label: Label = null
var _gauge: Control = null

var _state: Dictionary = {}
var _set: int = -1
var _bar_world: Vector2 = Vector2.ZERO
var _head_world: Vector2 = Vector2.ZERO
var _sweat: Array = []
var _sparks: Array = []
var _dust: Array = []
var _sweat_acc: float = 0.0
var _shake: float = 0.0
var _finished: bool = false


func build(game: Node) -> void:
	_rng.seed = 4242
	var room: Sprite2D = _sprite(ImageTexture.create_from_image(_paint_room()), Vector2(ROOM_L, ROOM_T), PX)
	room.z_index = -9
	add_child(room)
	_build_athlete()
	_build_extras()
	_fan = Node2D.new()
	_fan.position = FAN_POS
	_fan.z_index = -7
	_fan.draw.connect(_draw_fan)
	add_child(_fan)
	_board = Node2D.new()
	_board.z_index = -7
	_board.draw.connect(_draw_board)
	add_child(_board)
	_board_label = Label.new()
	_board_label.position = BOARD.position + Vector2(8, 10)
	_board_label.size = Vector2(BOARD.size.x - 16, 30)
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_label.z_index = -6
	PixelFont.apply(_board_label, 2, false)
	_board_label.add_theme_color_override("font_color", CHALK)
	add_child(_board_label)
	_fx = Node2D.new()
	_fx.z_index = 5
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var bar: ProgressBar = game.get_node_or_null("UI/Bar") as ProgressBar
	if bar:
		_setup_gauge(bar)


# --- Boucle ---

# s : set, value, holding, lo, hi, resting, gas, ended, rep, score
func tick(delta: float, s: Dictionary) -> void:
	_t += delta
	_state = s
	var ex: int = int(s.get("set", 0))
	var value: float = float(s.get("value", 0.0))
	var holding: bool = bool(s.get("holding", false))
	var hi: float = float(s.get("hi", 100.0))
	var v: float = clampf(value / 100.0, 0.0, 1.0)
	var step: int = roundi(v * STEPS)
	var danger: float = 0.0
	if holding and value > hi:
		danger = clampf((value - hi) / maxf(100.0 - hi, 1.0), 0.0, 1.0)
	var strain: int = 0
	if holding:
		strain = 2 if danger > 0.0 else 1
	_athlete.texture = _pose(ex, step, strain, false)
	_refl.texture = _pose(ex, step, strain, true)
	# Tremblement : léger sous l'effort, franc quand la forme va casser.
	var jit: Vector2 = Vector2.ZERO
	if holding:
		var amp: float = 1.5 + danger * 7.0
		jit = Vector2(roundf(sin(_t * 47.0) * amp), roundf(cos(_t * 39.0) * amp * 0.4))
	_athlete.position = ATHLETE_FEET + jit
	_refl.position = REFL_FEET - MIRROR_GLASS.position + jit * 0.7
	var geo: Dictionary = _geometry(ex, float(step) / float(STEPS))
	_bar_world = ATHLETE_FEET + (geo.bar as Vector2) * BODY_PX
	_head_world = ATHLETE_FEET + (geo.head as Vector2) * BODY_PX
	if ex != _set:
		_set = ex
		_board_label.text = String(s.get("name", "")).to_upper()
	_tick_sweat(delta, holding, float(s.get("gas", 100.0)))
	_tick_people(delta)
	_tick_particles(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var k: float = _shake / 0.3 * 9.0
		position = Vector2(roundf(_rng.randf_range(-k, k)), roundf(_rng.randf_range(-k, k)))
	else:
		position = Vector2.ZERO
	_fan.queue_redraw()
	_board.queue_redraw()
	_fx.queue_redraw()
	if _gauge:
		_gauge.queue_redraw()


# kind : perfeito / boa / falha / esmagado
func feedback(kind: String) -> void:
	match kind:
		"perfeito":
			_float_text("PERFEITO!", Color(1.0, 0.86, 0.3))
			_burst(_bar_world, 22, [Color(1.0, 0.9, 0.4), WHITE, Color(1.0, 0.7, 0.25)])
			_coach_react(1)
			_hop_t = 0.0
		"boa":
			_float_text("BOA!", Color(0.6, 1.0, 0.6))
			_burst(_bar_world, 10, [WHITE, Color(0.7, 1.0, 0.7)])
			_coach_react(1)
		_:
			_float_text("FALHA" if kind == "falha" else "PESADO!", Color(1.0, 0.42, 0.36))
			_shake = 0.3
			_puff(ATHLETE_FEET + Vector2(-40, 0))
			_coach_react(2)


func finish(qualifies: bool) -> void:
	_finished = true
	if qualifies:
		_coach_react(1)
		_hop_t = 0.0
		_burst(_head_world + Vector2(0, -60), 30, [Color(1.0, 0.9, 0.4), WHITE, GREEN_PLATE])


func _coach_react(mood: int) -> void:
	_coach_mood = mood
	_coach_t = 1.1


func _tick_people(delta: float) -> void:
	_coach_t = maxf(0.0, _coach_t - delta)
	if _finished and _coach_mood == 1:
		_coach_t = 1.0
	var mood: int = _coach_mood if _coach_t > 0.0 else 0
	_coach.texture = _coach_tex[mood]
	var bob: float = 0.0
	if mood == 1:
		bob = -absf(sin(_t * 10.0)) * 18.0
	_coach.position = COACH_FEET + Vector2(0, roundf(bob / 3.0) * 3.0)
	# Le figurant saute de joie au Perfeito (et son reflet avec lui).
	_hop_t += delta
	var hop: float = 0.0
	if _hop_t < 0.6 or _finished:
		hop = -absf(sin(_hop_t * 10.0)) * 24.0
	_clapper.position = CLAPPER_FEET + Vector2(0, roundf(hop / 3.0) * 3.0)
	_clapper_refl.position = CLAPPER_REFL_FEET - MIRROR_GLASS.position + Vector2(0, roundf(hop * 0.7 / 3.0) * 3.0)
	# Le parceiro du fond enchaîne ses roscas, à son rythme.
	var ph: float = fposmod(_t / 2.4, 1.0)
	var k: float = ph * 2.0 if ph < 0.5 else 2.0 - ph * 2.0
	_curler.texture = _curl_tex[clampi(roundi(k * float(_curl_tex.size() - 1)), 0, _curl_tex.size() - 1)]


func _tick_sweat(delta: float, holding: bool, gas: float) -> void:
	var rate: float = 0.0
	if holding:
		rate = 2.5 + (1.0 - gas / 100.0) * 6.0
	elif gas < 40.0:
		rate = 1.2
	_sweat_acc += delta * rate
	while _sweat_acc >= 1.0:
		_sweat_acc -= 1.0
		_sweat.append({
			"p": _head_world + Vector2(_rng.randf_range(-36, 36), _rng.randf_range(-10, 20)),
			"v": Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-140, -60)),
			"life": 0.7,
		})


func _tick_particles(delta: float) -> void:
	var lists: Array = [_sweat, _sparks, _dust]
	for li in lists.size():
		var list: Array = lists[li]
		for i in range(list.size() - 1, -1, -1):
			var p: Dictionary = list[i]
			p.life = float(p.life) - delta
			if float(p.life) <= 0.0:
				list.remove_at(i)
				continue
			var vel: Vector2 = p.v
			if li == 0:
				vel.y += 700.0 * delta
			else:
				vel *= pow(0.04, delta)
			p.v = vel
			p.p = (p.p as Vector2) + vel * delta


func _burst(at: Vector2, n: int, cols: Array) -> void:
	for i in n:
		var a: float = _rng.randf() * TAU
		var sp: float = _rng.randf_range(220.0, 520.0)
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp,
			"life": _rng.randf_range(0.4, 0.75), "c": cols[i % cols.size()]})


func _puff(at: Vector2) -> void:
	for i in 14:
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		_dust.append({"p": at + Vector2(_rng.randf_range(-60, 60), 0),
			"v": Vector2(dir * _rng.randf_range(120, 320), _rng.randf_range(-90, -20)),
			"life": _rng.randf_range(0.35, 0.6)})


func _float_text(text: String, col: Color) -> void:
	var l: Label = Label.new()
	l.text = text
	l.size = Vector2(300, 40)
	l.scale = Vector2(2, 2)
	l.position = Vector2(ATHLETE_FEET.x - 300, minf(_bar_world.y, _head_world.y) - 170)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 6
	PixelFont.apply(l, 3, true)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 75.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# --- Dessin dynamique (cellules natives) ---

func _cell(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(p.snapped(Vector2(3, 3)), Vector2(s, s)), col)


func _draw_fx() -> void:
	for p: Dictionary in _sweat:
		var at: Vector2 = (p.p as Vector2).snapped(Vector2(3, 3))
		_fx.draw_rect(Rect2(at + Vector2(-1, -1), Vector2(11, 14)), Color(0.1, 0.25, 0.4, 0.6))
		_fx.draw_rect(Rect2(at, Vector2(9, 12)), Color(0.62, 0.86, 1.0))
		_fx.draw_rect(Rect2(at, Vector2(3, 3)), WHITE)
	for p: Dictionary in _sparks:
		var at: Vector2 = p.p
		var c: Color = p.c
		var s: float = 12.0 if float(p.life) > 0.3 else 9.0
		_cell(_fx, at, s, c)
		_cell(_fx, at + Vector2(-s, 0), s, c.darkened(0.15))
		_cell(_fx, at + Vector2(s, 0), s, c.darkened(0.15))
		_cell(_fx, at + Vector2(0, -s), s, c.darkened(0.15))
		_cell(_fx, at + Vector2(0, s), s, c.darkened(0.15))
	for p: Dictionary in _dust:
		var a: float = clampf(float(p.life) / 0.6, 0.0, 1.0)
		_cell(_fx, p.p, 15.0, Color(0.75, 0.72, 0.66, 0.75 * a))


# Ventilador de parede : grade qui oscille (largeur), pales qui tournent.
func _draw_fan() -> void:
	var c: CanvasItem = _fan
	var osc: float = sin(_t * 0.9)
	var k: float = 0.62 + 0.38 * cos(_t * 0.9 * 0.5) * cos(_t * 0.9 * 0.5)
	var cx: float = osc * 6.0
	# Bras mural.
	c.draw_rect(Rect2(-6, -42, 12, 9), INK)
	c.draw_rect(Rect2(-3, -39, 6, 3), STEEL_DK)
	c.draw_rect(Rect2(-3, -36, 6, 33), STEEL_DK)
	c.draw_rect(Rect2(-3, -36, 3, 33), STEEL)
	var theta: float = floorf(_t * 24.0) * 0.83
	for gy in range(-15, 16):
		for gx in range(-15, 16):
			var fx: float = float(gx) / k
			var r: float = sqrt(fx * fx + float(gy * gy))
			if r > 14.5:
				continue
			var at: Vector2 = Vector2(cx + float(gx), float(gy)) * PX + Vector2(0, 30)
			var col: Color = Color(0, 0, 0, 0)
			if r > 13.0:
				col = Color(0.9, 0.92, 0.95)
			elif r > 12.0:
				col = INK
			elif r < 2.5:
				col = Color(0.25, 0.48, 0.72) if r < 1.5 else INK
			else:
				var phi: float = atan2(float(gy), fx) - theta
				var m: float = fposmod(phi, TAU / 3.0)
				if m < 0.62:
					col = Color(0.42, 0.7, 0.95, 0.85) if m > 0.12 else Color(0.25, 0.48, 0.72)
				elif (gx + gy) % 4 == 0 or gx == 0 or gy == 0:
					col = Color(0.85, 0.88, 0.92, 0.55)
			if col.a > 0.0:
				c.draw_rect(Rect2(at, Vector2(PX, PX)), col)


# Lousa du professor : la série en cours, les reps cochées à la craie.
func _draw_board() -> void:
	var c: CanvasItem = _board
	var rep: int = int(_state.get("rep", 0))
	var ex: int = int(_state.get("set", 0))
	var base: Vector2 = BOARD.position + Vector2(24, 60)
	for i in 5:
		var x: float = base.x + float(i) * 21.0
		if i < rep:
			for j in 8:
				c.draw_rect(Rect2(Vector2(x + float(j % 2) * 3.0, base.y + float(j) * 4.5).snapped(Vector2(3, 3)), Vector2(6, 6)), CHALK)
		else:
			c.draw_rect(Rect2(x, base.y + 30, 9, 3), Color(CHALK, 0.35))
	if rep >= 5:
		for j in 12:
			c.draw_rect(Rect2(Vector2(base.x - 6 + float(j) * 9.0, base.y + 30 - float(j) * 2.5).snapped(Vector2(3, 3)), Vector2(6, 6)), CHALK)
	# Les trois séries : ronds pleins = faites.
	for i in 3:
		var p: Vector2 = BOARD.position + Vector2(48 + i * 42, 120)
		var done: bool = i < ex or (i == ex and _finished and float(_state.get("gas", 0.0)) > 0.0)
		var col: Color = Color(1.0, 0.85, 0.4) if i == ex and not _finished else CHALK
		for y in range(-2, 3):
			for x in range(-2, 3):
				if x * x + y * y > 5:
					continue
				var ring: bool = x * x + y * y >= 3
				if done or ring:
					c.draw_rect(Rect2(p + Vector2(x, y) * PX, Vector2(PX, PX)), col)


# --- Jauge (habille la ProgressBar du jeu) ---

func _setup_gauge(bar: ProgressBar) -> void:
	bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("background", UITheme.frame_box(UITheme.GOLD, Color(0.07, 0.08, 0.11, 0.94)))
	bar.show_percentage = false
	_gauge = Control.new()
	_gauge.name = "GaugeArt"
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.draw.connect(_draw_gauge)
	bar.add_child(_gauge)


func _draw_gauge() -> void:
	var c: Control = _gauge
	var m: float = 12.0
	var w: float = c.size.x - m * 2.0
	var h: float = c.size.y - m * 2.0
	var lo: float = float(_state.get("lo", 60.0))
	var hi: float = float(_state.get("hi", 80.0))
	var value: float = float(_state.get("value", 0.0))
	var resting: bool = bool(_state.get("resting", false))
	var yv: Callable = func(v: float) -> float:
		return roundf((m + h * (1.0 - v / 100.0)) / 3.0) * 3.0
	# Zone rouge (au-delà de la forme) hachurée.
	var y_top: float = yv.call(100.0)
	var y_hi: float = yv.call(hi)
	c.draw_rect(Rect2(m, y_top, w, y_hi - y_top), Color(0.58, 0.14, 0.14))
	var yy: float = y_top
	while yy < y_hi:
		c.draw_rect(Rect2(m, yy, w, 3), Color(0.78, 0.24, 0.2))
		yy += 12.0
	# Zone verte + cœur Perfeito.
	var y_lo: float = yv.call(lo)
	var center: float = (lo + hi) * 0.5
	var half_p: float = (hi - lo) * 0.2
	if not resting:
		c.draw_rect(Rect2(m, y_hi, w, y_lo - y_hi), Color(0.2, 0.62, 0.3))
		var py0: float = yv.call(center + half_p)
		var py1: float = yv.call(center - half_p)
		c.draw_rect(Rect2(m, py0, w, maxf(3.0, py1 - py0)), Color(0.55, 0.95, 0.5))
		c.draw_rect(Rect2(m, y_hi, w, 3), Color(0.75, 1.0, 0.7))
		c.draw_rect(Rect2(m, y_lo - 3.0, w, 3), Color(0.1, 0.38, 0.18))
	# Graduations.
	for i in range(1, 10):
		var ty: float = yv.call(float(i) * 10.0)
		c.draw_rect(Rect2(m, ty, 9 if i % 5 else 15, 3), Color(1, 1, 1, 0.35))
	# Colonne de levée + aiguille.
	var y_v: float = yv.call(clampf(value, 0.0, 100.0))
	c.draw_rect(Rect2(m + w * 0.35, y_v, w * 0.3, m + h - y_v), Color(0.96, 0.92, 0.82, 0.3))
	var nc: Color = WHITE
	if value > hi:
		nc = Color(1.0, 0.45, 0.4)
	elif value >= lo:
		nc = Color(0.7, 1.0, 0.6)
	c.draw_rect(Rect2(-6, y_v - 6, c.size.x + 12, 12), INK)
	c.draw_rect(Rect2(-3, y_v - 3, c.size.x + 6, 6), nc)
	for i in 4:
		var s: float = float(4 - i) * 6.0
		c.draw_rect(Rect2(-30 + float(i) * 6.0, y_v - s * 0.5 - 3.0, 6, s + 6.0), INK)
		c.draw_rect(Rect2(-27 + float(i) * 6.0, y_v - s * 0.5, 6, s), nc)


# --- Personnages ---

func _build_athlete() -> void:
	var cfg: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var sheet: Image = CharacterSpriteFactory.build_sheet(cfg).get_image()
	for dir in 3:
		_base.append(_native(sheet, dir, 0))
	_skin = cfg.get("skin", Color(0.92, 0.78, 0.62))
	_skin_sh = _skin.darkened(0.22)
	_shirt = cfg.get("shirt_color", Color(0.85, 0.55, 0.4))
	_shirt_sh = _shirt.darkened(0.24)
	_pants = cfg.get("pants_color", Color(0.3, 0.25, 0.2))
	_pants_sh = _pants.darkened(0.26)
	_long_pants = _pants.v < 0.4
	_athlete = _sprite(_pose(0, 0, 0, false), ATHLETE_FEET, BODY_PX)
	_athlete.offset = Vector2(-CW / 2, -CH)
	add_child(_athlete)
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.position = MIRROR_GLASS.position
	clip.size = MIRROR_GLASS.size
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.z_index = -8
	add_child(clip)
	_refl = _sprite(_pose(0, 0, 0, true), REFL_FEET - MIRROR_GLASS.position, int(REFL_PX))
	_refl.offset = Vector2(-CW / 2, -CH)
	_refl.modulate = Color(0.8, 0.9, 0.98, 0.72)
	clip.add_child(_refl)
	# Figurant devant le miroir (et son reflet de dos).
	var fan_cfg: Dictionary = CharacterSpriteFactory.random_config(7310)
	fan_cfg["shirt_color"] = Color(0.85, 0.32, 0.32)
	var fan_sheet: Texture2D = CharacterSpriteFactory.build_sheet(fan_cfg)
	_clapper = _sheet_sprite(fan_sheet, CharacterSpriteFactory.DIR_DOWN, 7.0 / 3.0)
	_clapper.position = CLAPPER_FEET
	_clapper.z_index = -5
	add_child(_clapper)
	_clapper_refl = _sheet_sprite(fan_sheet, CharacterSpriteFactory.DIR_UP, 5.0 / 3.0)
	_clapper_refl.modulate = Color(0.8, 0.9, 0.98, 0.72)
	_clapper_refl.position = CLAPPER_REFL_FEET - MIRROR_GLASS.position
	clip.add_child(_clapper_refl)
	clip.move_child(_clapper_refl, 0)


func _build_extras() -> void:
	# Le professor : regata jaune, bermuda verde — il suit chaque rep.
	var cc: Dictionary = CharacterSpriteFactory.random_config(5021)
	cc["shirt_color"] = Color(0.98, 0.82, 0.2)
	cc["pants_color"] = Color(0.18, 0.6, 0.34)
	cc["hat_style"] = "cap"
	cc["hat_color"] = Color(0.18, 0.18, 0.22)
	cc["shirt_pattern"] = "solid"
	var cs: Image = CharacterSpriteFactory.build_sheet(cc).get_image()
	var side: Image = _native(cs, CharacterSpriteFactory.DIR_RIGHT, 0)
	for mood in 3:
		_coach_tex.append(ImageTexture.create_from_image(_coach_pose(side, mood, cc)))
	_coach = _sprite(_coach_tex[0], COACH_FEET, 9)
	_coach.offset = Vector2(-10, -36)
	_coach.flip_h = true
	_coach.z_index = -4
	add_child(_coach)
	# Au fond, devant la janela : un habitué et ses roscas.
	var rc: Dictionary = CharacterSpriteFactory.random_config(1187)
	rc["shirt_color"] = Color(0.22, 0.22, 0.28)
	var rs: Image = CharacterSpriteFactory.build_sheet(rc).get_image()
	var rside: Image = _native(rs, CharacterSpriteFactory.DIR_RIGHT, 0)
	for i in 6:
		_curl_tex.append(ImageTexture.create_from_image(_curl_pose(rside, float(i) / 5.0, rc)))
	_curler = _sprite(_curl_tex[0], CURLER_FEET, 6)
	_curler.offset = Vector2(-10, -36)
	_curler.flip_h = true
	_curler.z_index = -6
	add_child(_curler)


func _sheet_sprite(tex: Texture2D, dir: int, k: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(0, dir * CharacterSpriteFactory.CELL_H, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = Vector2(-31, -96)
	s.scale = Vector2(k, k)
	return s


func _sprite(tex: Texture2D, pos: Vector2, k: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(k, k)
	s.position = pos
	return s


# Cellule 21×32 de la planche, contour retiré (il est recalculé après pose).
func _native(sheet: Image, dir: int, frame: int) -> Image:
	var img: Image = Image.create(21, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 21:
			var c: Color = sheet.get_pixel(frame * CharacterSpriteFactory.CELL_W + x * 3 + 1,
					dir * CharacterSpriteFactory.CELL_H + y * 3 + 1)
			if c.a > 0.01 and not _is_ink(c):
				img.set_pixel(x, y, c)
	return img


func _is_ink(c: Color) -> bool:
	var l: Color = CharacterSpriteFactory.LINE_COLOR
	return absf(c.r - l.r) < 0.012 and absf(c.g - l.g) < 0.012 and absf(c.b - l.b) < 0.012


# Professor : 0 = attentif, 1 = poing levé, 2 = bras tendu (il corrige).
func _coach_pose(side: Image, mood: int, cfg: Dictionary) -> Image:
	var img: Image = Image.create(21, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = cfg.get("skin", Color(0.8, 0.6, 0.45))
	var shirt: Color = cfg.get("shirt_color", Color.YELLOW)
	_blit(img, side, 0, 0, 21, 32, 0, 4)
	if mood > 0:
		for y in range(18, 22):
			if img.get_pixel(13, y + 4).a > 0.0:
				img.set_pixel(13, y + 4, shirt)
		_put(img, 14, 19, shirt)
		_put(img, 14, 20, shirt.darkened(0.2))
		if mood == 1:
			_line(img, Vector2i(15, 19), Vector2i(17, 9), skin.darkened(0.2), 2)
			_line(img, Vector2i(15, 19), Vector2i(17, 9), skin, 1)
			_fill(img, 16, 6, 3, 3, skin.darkened(0.1))
		else:
			for x in range(15, 19):
				_put(img, x, 20, skin)
				_put(img, x, 21, skin.darkened(0.2))
			_put(img, 19, 20, skin)
	# Apito au cou.
	_put(img, 11, 22, Color(0.85, 0.85, 0.9))
	_put(img, 10, 21, Color(0.85, 0.2, 0.2))
	_outline(img)
	return img


# Rosca direta de profil : l'avant-bras tourne autour du coude, k 0 → 1.
func _curl_pose(side: Image, k: float, cfg: Dictionary) -> Image:
	var img: Image = Image.create(21, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = cfg.get("skin", Color(0.8, 0.6, 0.45))
	var shirt: Color = cfg.get("shirt_color", Color.GRAY)
	_blit(img, side, 0, 0, 21, 32, 0, 4)
	for y in range(18, 22):
		if img.get_pixel(13, y + 4).a > 0.0:
			img.set_pixel(13, y + 4, shirt)
	for y in range(19, 23):
		_put(img, 13, y, skin.darkened(0.15))
	var a: float = lerpf(0.0, 2.5, k)
	var elbow: Vector2 = Vector2(13, 23)
	var hand: Vector2i = Vector2i(roundi(elbow.x + sin(a) * 4.0), roundi(elbow.y + cos(a) * 4.0))
	_line(img, Vector2i(elbow), hand, skin, 1)
	_fill(img, hand.x - 1, hand.y - 1, 3, 3, IRON)
	_put(img, hand.x, hand.y, STEEL)
	_outline(img)
	return img


# --- Poses de l'athlète ---

# Repères natifs (relatifs aux pieds) : barre et front, pour les effets.
func _geometry(ex: int, v: float) -> Dictionary:
	var feet: Vector2 = Vector2(CW / 2, CH)
	if ex == 0:
		var bc: float = roundf(lerpf(28.0, 21.0, v))
		return {"bar": Vector2(25.5, bc) - feet, "head": Vector2(11, 31) - feet}
	var d: float = roundf(lerpf(4.0, 0.0, v)) if ex == 1 else 0.0
	var bar_row: float = float(OY) + 14.0 + d if ex == 1 else roundf(lerpf(float(OY) + 21.0, float(OY) + 12.0, v))
	return {"bar": Vector2(30, bar_row) - feet, "head": Vector2(30, float(OY) + 6.0 + d) - feet}


func _pose(ex: int, step: int, strain: int, back: bool) -> Texture2D:
	var key: String = "%d_%d_%d_%d" % [ex, step, strain, int(back)]
	if _pose_cache.has(key):
		return _pose_cache[key]
	var v: float = float(step) / float(STEPS)
	var img: Image = _pose_bench(v, strain) if ex == 0 else _pose_front(ex, v, strain, back)
	_outline(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_pose_cache[key] = tex
	return tex


func _canvas() -> Image:
	var img: Image = Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


# Supino : couché sur le banc (profil tourné d'un quart), barre vue de bout.
func _pose_bench(v: float, strain: int) -> Image:
	var img: Image = _canvas()
	# Montants du rack, derrière la tête.
	_fill(img, 7, 14, 2, 33, STEEL_DK)
	_fill(img, 7, 14, 1, 33, STEEL)
	_fill(img, 9, 20, 2, 1, STEEL_DK)
	_fill(img, 5, 46, 6, 1, STEEL_DK)
	# Banco : estofado vinyle, châssis, pieds.
	_fill(img, 8, 40, 23, 2, VINYL)
	_fill(img, 8, 40, 23, 1, VINYL.lightened(0.3))
	_fill(img, 10, 42, 19, 1, STEEL_DK)
	for lx: int in [11, 26]:
		_fill(img, lx, 43, 2, 3, STEEL_DK)
		_fill(img, lx, 43, 1, 3, STEEL)
		_fill(img, lx - 1, 46, 4, 1, IRON)
	var side: Image = _base[CharacterSpriteFactory.DIR_RIGHT].duplicate()
	for y in range(18, 22):
		if side.get_pixel(13, y).a > 0.0:
			side.set_pixel(13, y, _shirt)
	for y in range(27, 32):
		for x in 21:
			side.set_pixel(x, y, Color(0, 0, 0, 0))
	if strain > 0:
		_fill(side, 12, 9, 2, 2, _skin)
		_put(side, 12, 10, INK)
		_put(side, 13, 10, INK)
		if strain > 1:
			_flush(side, 5, 15)
	# Quart de tour : la tête à gauche, le visage vers le haut.
	for y in 32:
		for x in 21:
			var c: Color = side.get_pixel(x, y)
			if c.a > 0.01:
				_put(img, 6 + y, 46 - x, c)
	# Jambes : cuisses sur le banc, tibias vers le sol, pieds à plat.
	var shin: Color = _pants if _long_pants else _skin
	var shin_sh: Color = _pants_sh if _long_pants else _skin_sh
	_fill(img, 32, 34, 2, 5, _pants)
	_fill(img, 32, 39, 3, 6, shin)
	_fill(img, 32, 39, 1, 6, shin_sh)
	_fill(img, 32, 45, 5, 2, Color(0.28, 0.2, 0.14))
	# Bras proche : épaule → coude → main sous le disque.
	var bc: int = roundi(lerpf(28.0, 21.0, v))
	var sh: Vector2 = Vector2(22, 33)
	var hand: Vector2 = Vector2(25, bc + 1)
	var elbow: Vector2 = Vector2(19, 37).lerp((sh + hand) * 0.5 + Vector2(-1, 0), v)
	_limb(img, Vector2i(sh), Vector2i(elbow.round()), Vector2i(hand), _shirt)
	# Barre vue de bout : anilha rouge, moyeu acier.
	_disc(img, 25, bc, 4, RED_PLATE)
	return img


# Agachamento (barre sur la nuque) et remada alta (barre des hanches au menton).
func _pose_front(ex: int, v: float, strain: int, back: bool) -> Image:
	var img: Image = _canvas()
	var base: Image = _base[CharacterSpriteFactory.DIR_UP if back else CharacterSpriteFactory.DIR_DOWN]
	var squat: bool = ex == 1
	var d: int = roundi(lerpf(4.0, 0.0, v)) if squat else 0
	var bar_row: int = OY + 14 + d if squat else roundi(lerpf(float(OY) + 21.0, float(OY) + 12.0, v))
	# De face, la barre du squat passe derrière la nuque ; de dos, devant.
	var bar_behind: bool = squat != back
	if bar_behind:
		_barbell(img, bar_row, squat)
	if squat:
		_squat_legs(img, d)
	else:
		_blit(img, base, 0, 23, 21, 9, OX, OY + 23)
	_blit(img, base, 0, 0, 21, 14, OX, OY + d)
	_blit(img, base, 6, 14, 9, 9, OX + 6, OY + 14 + d)
	if not back and strain > 0:
		_strain_front(img, OX, OY + d, strain)
	if not bar_behind:
		_barbell(img, bar_row, squat)
	for s in 2:
		var mx: Callable = func(p: Vector2i) -> Vector2i:
			return p if s == 0 else Vector2i(2 * OX + 20 - p.x, p.y)
		var sh: Vector2i = Vector2i(OX + 5, OY + 15 + d)
		var elbow: Vector2i
		var hand: Vector2i
		if squat:
			elbow = Vector2i(OX + 2, OY + 18 + d)
			hand = Vector2i(OX + 3, bar_row)
		else:
			var e: Vector2 = Vector2(OX + 4, OY + 19).lerp(Vector2(OX + 2, OY + 12), v)
			elbow = Vector2i(e.round())
			hand = Vector2i(OX + 7, bar_row)
		_limb(img, mx.call(sh), mx.call(elbow), mx.call(hand), _shirt)
	return img


func _squat_legs(img: Image, d: int) -> void:
	var hr: int = OY + 23 + d
	var thigh_w: int = 3
	_fill(img, OX + 6, hr - 1, 9, 2, _pants)
	_fill(img, OX + 6, hr, 9, 1, _pants_sh)
	var shin: Color = _pants if _long_pants else _skin
	for s in 2:
		var sg: int = -1 if s == 0 else 1
		var hip: Vector2i = Vector2i(OX + 10 + sg * 2, hr)
		var knee: Vector2i = Vector2i(OX + 10 + sg * (6 + d / 2), OY + 25)
		var ankle: Vector2i = Vector2i(OX + 10 + sg * 4, OY + 28)
		_line(img, hip, knee, _pants, thigh_w)
		_line(img, knee, ankle, shin, 2)
		_fill(img, ankle.x - 2 + (1 if s == 1 else 0), OY + 29, 4, 2, Color(0.28, 0.2, 0.14))


func _strain_front(img: Image, x0: int, y0: int, strain: int) -> void:
	for e: int in [7, 12]:
		_fill(img, x0 + e, y0 + 9, 2, 2, _skin)
		_fill(img, x0 + e, y0 + 10, 2, 1, INK)
	_put(img, x0 + 7, y0 + 8, INK)
	_put(img, x0 + 13, y0 + 8, INK)
	_fill(img, x0 + 9, y0 + 12, 3, 1, WHITE)
	_put(img, x0 + 8, y0 + 12, INK)
	_put(img, x0 + 12, y0 + 12, INK)
	if strain > 1:
		for y in range(y0 + 5, y0 + 14):
			for x in range(x0 + 4, x0 + 17):
				var c: Color = img.get_pixel(x, y)
				if c.is_equal_approx(_skin) or c.is_equal_approx(_skin_sh):
					img.set_pixel(x, y, c.lerp(Color(0.92, 0.3, 0.26), 0.3))


# Rougeur de l'effort sur la peau du profil (lignes y0..y1).
func _flush(img: Image, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		for x in 21:
			var c: Color = img.get_pixel(x, y)
			if c.is_equal_approx(_skin) or c.is_equal_approx(_skin_sh):
				img.set_pixel(x, y, c.lerp(Color(0.92, 0.3, 0.26), 0.3))


# Barre de face : acier, colliers, anilhas de chant (squat = plus chargé).
func _barbell(img: Image, row: int, heavy: bool) -> void:
	_fill(img, 1, row, CW - 2, 1, STEEL)
	for side in 2:
		var mx: Callable = func(x: int, w: int) -> int:
			return x if side == 0 else CW - x - w
		_fill(img, mx.call(11, 1), row - 1, 1, 3, STEEL_DK)
		if heavy:
			_plate_edge(img, mx.call(4, 3), row, 7, RED_PLATE)
			_plate_edge(img, mx.call(7, 2), row, 5, BLUE_PLATE)
			_plate_edge(img, mx.call(9, 2), row, 4, YELLOW_PLATE)
		else:
			_plate_edge(img, mx.call(6, 2), row, 5, BLUE_PLATE)
			_plate_edge(img, mx.call(8, 2), row, 3, GREEN_PLATE)


func _plate_edge(img: Image, x: int, row: int, r: int, c: Color) -> void:
	var w: int = 3 if c == RED_PLATE else 2
	_fill(img, x, row - r, w, r * 2 + 1, c)
	_fill(img, x, row - r, 1, r * 2 + 1, c.lightened(0.25))
	_fill(img, x + w - 1, row - r + 1, 1, r * 2 - 1, c.darkened(0.25))
	_put(img, x, row - r, c.darkened(0.2))
	_put(img, x + w - 1, row + r, c.darkened(0.35))


func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var dd: int = x * x + y * y
			if dd > r * r + r:
				continue
			var col: Color = c
			if dd >= r * r - r:
				col = c.darkened(0.3)
			elif x + y < -r / 2:
				col = c.lightened(0.2)
			if dd <= 2:
				col = STEEL if dd == 0 else STEEL_DK
			_put(img, cx + x, cy + y, col)


# Bras de 2 px : manche, puis peau, main fermée en bout.
func _limb(img: Image, sh: Vector2i, elbow: Vector2i, hand: Vector2i, sleeve: Color) -> void:
	_line(img, sh, elbow, _skin_sh, 2)
	_line(img, elbow, hand, _skin_sh, 2)
	_line(img, sh, elbow, _skin, 1)
	_line(img, elbow, hand, _skin, 1)
	_fill(img, sh.x - 1, sh.y - 1, 2, 2, sleeve)
	_fill(img, hand.x - 1, hand.y, 2, 2, _skin_sh)


# --- Primitives Image ---

func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0: int = maxi(x, 0)
	var y0: int = maxi(y, 0)
	var x1: int = mini(x + w, img.get_width())
	var y1: int = mini(y + h, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _blit(dst: Image, src: Image, sx: int, sy: int, w: int, h: int, dx: int, dy: int) -> void:
	for y in h:
		for x in w:
			var c: Color = src.get_pixel(sx + x, sy + y)
			if c.a > 0.01:
				_put(dst, dx + x, dy + y, c)


func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, w: int) -> void:
	var n: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t: float = float(i) / float(maxi(n, 1))
		var p: Vector2i = Vector2i(Vector2(a).lerp(Vector2(b), t).round())
		_fill(img, p.x - (w - 1) / 2, p.y - (w - 1) / 2, w, w, c)


func _outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.01:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px: int = x + o.x
				var py: int = y + o.y
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				var n: Color = src.get_pixel(px, py)
				if n.a > 0.01 and not n.is_equal_approx(INK):
					img.set_pixel(x, y, INK)
					break


func _text(img: Image, x: int, y: int, s: String, c: Color, k: int = 1) -> void:
	var cx: int = x
	for ch in s:
		var g: Array = GLYPHS.get(ch, [])
		for r in g.size():
			var row: String = g[r]
			for col in 3:
				if row[col] == "#":
					_fill(img, cx + col * k, y + r * k, k, k, c)
		cx += 4 * k


func _ellipse_shade(img: Image, cx: int, cy: int, rx: int, ry: int, a: float) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var q: float = float(x * x) / float(rx * rx) + float(y * y) / float(ry * ry)
			if q <= 1.0:
				_blend(img, cx + x, cy + y, Color(0.02, 0.03, 0.05, a * (1.0 if q < 0.55 else 0.6)))


func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + r:
				_put(img, cx + x, cy + y, c)


# --- La salle (peinte une fois) ---

func _paint_room() -> Image:
	var img: Image = Image.create(ROOM_W, ROOM_H, false, Image.FORMAT_RGBA8)
	_paint_wall(img)
	_paint_floor(img)
	_paint_lights(img)
	_paint_mirror(img)
	_paint_sign(img)
	_paint_posters(img)
	_paint_board(img)
	_paint_window(img)
	_paint_bag(img)
	_paint_cooler(img)
	# Ombres au sol, puis le mobilier qui s'y pose.
	_ellipse_shade(img, 343, 313, 34, 4, 0.4)
	_ellipse_shade(img, 555, 305, 13, 3, 0.4)
	_ellipse_shade(img, 490, 264, 9, 2, 0.35)
	_ellipse_shade(img, 693, 268, 8, 2, 0.35)
	_ellipse_shade(img, 184, 301, 58, 4, 0.4)
	_ellipse_shade(img, 656, 293, 22, 3, 0.4)
	_paint_rack(img)
	_paint_plate_tree(img)
	_paint_floor_props(img)
	return img


func _paint_wall(img: Image) -> void:
	var wall: Color = Color(0.5, 0.7, 0.58)
	_fill(img, 0, 0, ROOM_W, FLOOR_ROW, wall)
	# Plafond et ombre du haut, en dégradé tramé.
	for y in 26:
		var k: float = 1.0 - float(y) / 26.0
		for x in ROOM_W:
			if y < 6 or float((x * 7 + y * 13) % 10) / 10.0 < k * k:
				img.set_pixel(x, y, wall.darkened(0.12 + 0.2 * k))
	# Peinture qui s'écaille : plaques de reboco.
	for i in 22:
		var cx: int = _rng.randi_range(10, ROOM_W - 10)
		var cy: int = _rng.randi_range(30, 170)
		var rx: int = _rng.randi_range(3, 9)
		var ry: int = _rng.randi_range(2, 5)
		for y in range(-ry, ry + 1):
			for x in range(-rx, rx + 1):
				var q: float = float(x * x) / float(rx * rx) + float(y * y) / float(ry * ry)
				if q <= 1.0 and _rng.randf() < 0.9:
					_put(img, cx + x, cy + y, Color(0.84, 0.82, 0.74) if q < 0.7 else wall.darkened(0.18))
	for i in 260:
		var x: int = _rng.randi_range(0, ROOM_W - 1)
		var y: int = _rng.randi_range(26, 180)
		_put(img, x, y, wall.lightened(0.08) if i % 2 else wall.darkened(0.06))
	# Faixa amarela, puis azulejos jusqu'au rodapé.
	_fill(img, 0, 181, ROOM_W, 3, Color(0.95, 0.8, 0.25))
	_fill(img, 0, 184, ROOM_W, 1, Color(0.2, 0.38, 0.28))
	var tile: Color = Color(0.82, 0.9, 0.9)
	var grout: Color = Color(0.6, 0.68, 0.7)
	for y in range(185, 226):
		for x in ROOM_W:
			var tx: int = x % 9
			var ty: int = (y - 185) % 9
			var c: Color = grout if tx == 0 or ty == 0 else tile
			if tx >= 3 and tx <= 5 and ty >= 3 and ty <= 5 and ((x / 9 + (y - 185) / 9) % 2 == 0):
				c = Color(0.28, 0.5, 0.78) if (tx == 4 or ty == 4) else tile
			if tx == 1 and ty > 0:
				c = c.lightened(0.1)
			# Encrassé près du sol.
			if y > 214 and (x * 3 + y) % 5 < y - 214:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	_fill(img, 0, 226, ROOM_W, 4, Color(0.2, 0.23, 0.26))
	_fill(img, 0, 226, ROOM_W, 1, Color(0.36, 0.4, 0.44))


func _paint_floor(img: Image) -> void:
	var rubber: Color = Color(0.17, 0.17, 0.2)
	var vx: float = 440.0
	var vy: float = -160.0
	for y in range(FLOOR_ROW, ROOM_H):
		for x in ROOM_W:
			var c: Color = rubber
			if y < FLOOR_ROW + 5:
				c = rubber.darkened(0.3 - float(y - FLOOR_ROW) * 0.05)
			img.set_pixel(x, y, c)
	# Joints des dalles : lignes de fuite + rangées qui s'espacent.
	var seam: Color = Color(0.1, 0.1, 0.12)
	for row: int in [238, 249, 263, 281, 304, 333]:
		_fill(img, 0, row, ROOM_W, 1, seam)
		_fill(img, 0, row + 1, ROOM_W, 1, rubber.lightened(0.06))
	for i in range(-14, 30):
		var xb: float = -400.0 + float(i) * 66.0
		for y in range(FLOOR_ROW, ROOM_H):
			var x: int = roundi(vx + (xb - vx) * (float(y) - vy) / (float(ROOM_H) - vy))
			_put(img, x, y, seam)
	# Paillettes EPDM.
	var flecks: Array[Color] = [Color(0.3, 0.45, 0.75), Color(0.75, 0.3, 0.28), Color(0.85, 0.75, 0.3), Color(0.5, 0.5, 0.55)]
	for i in 1800:
		var x: int = _rng.randi_range(0, ROOM_W - 1)
		var y: int = _rng.randi_range(FLOOR_ROW + 2, ROOM_H - 1)
		_put(img, x, y, flecks[i % flecks.size()].darkened(0.25))
	# Zone usée devant le banc.
	for i in 500:
		var x: int = 343 + roundi(_rng.randfn(0.0, 22.0))
		var y: int = 320 + roundi(_rng.randfn(0.0, 10.0))
		if y >= FLOOR_ROW + 4:
			_blend(img, x, y, Color(1, 1, 1, 0.05))


func _paint_lights(img: Image) -> void:
	for x0: int in [90, 330, 560, 790]:
		_fill(img, x0 + 10, 0, 1, 4, STEEL_DK)
		_fill(img, x0 + 60, 0, 1, 4, STEEL_DK)
		_fill(img, x0, 4, 71, 2, Color(0.78, 0.8, 0.78))
		_fill(img, x0 + 2, 6, 67, 2, Color(1.0, 1.0, 0.93))
		_fill(img, x0, 8, 71, 1, INK)
		for y in range(9, 34):
			var spread: int = (y - 9) / 2
			for x in range(x0 - spread, x0 + 71 + spread):
				if (x + y) % 2 == 0:
					_blend(img, x, y, Color(1, 1, 0.9, 0.09 * (1.0 - float(y - 9) / 25.0)))


func _paint_mirror(img: Image) -> void:
	var x0: int = 193
	var x1: int = 521
	var y0: int = 70
	var y1: int = 222
	_fill(img, x0 - 4, y0 - 4, x1 - x0 + 8, y1 - y0 + 8, INK)
	_fill(img, x0 - 3, y0 - 3, x1 - x0 + 6, y1 - y0 + 6, Color(0.78, 0.8, 0.82))
	_fill(img, x0 - 3, y0 - 3, x1 - x0 + 6, 1, Color(0.95, 0.96, 0.97))
	_fill(img, x0 - 1, y0 - 1, x1 - x0 + 2, y1 - y0 + 2, Color(0.45, 0.48, 0.52))
	# Ce que le miroir renvoie : le mur d'en face, son sol, ses néons.
	for y in range(y0, y1):
		var k: float = float(y - y0) / float(y1 - y0)
		var c: Color = Color(0.64, 0.78, 0.76).lerp(Color(0.54, 0.68, 0.68), k)
		if y > 196:
			c = Color(0.26, 0.29, 0.32)
		elif y > 186:
			c = Color(0.7, 0.8, 0.82)
		elif y > 183:
			c = Color(0.86, 0.78, 0.38)
		_fill(img, x0, y, x1 - x0, 1, c)
	for x in range(x0, x1):
		if x % 6 == 0:
			_fill(img, x, 187, 1, 10, Color(0.58, 0.68, 0.72))
	_fill(img, x0, 196, x1 - x0, 1, Color(0.2, 0.22, 0.25))
	for x0l: int in [230, 380]:
		_fill(img, x0l, y0 + 4, 50, 1, Color(0.95, 0.97, 0.92))
		_fill(img, x0l, y0 + 5, 50, 1, Color(0.8, 0.88, 0.86))
	# Reflets en biais.
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dgl: int = (x - x0) + (y - y0)
			if (dgl > 120 and dgl < 128) or (dgl > 134 and dgl < 137) or (dgl > 330 and dgl < 335):
				_blend(img, x, y, Color(1, 1, 1, 0.22))
	# Tablette basse du miroir.
	_fill(img, x0 - 4, y1 + 3, x1 - x0 + 8, 2, Color(0.6, 0.62, 0.66))


func _paint_sign(img: Image) -> void:
	var x0: int = 290
	var y0: int = 33
	var w: int = 134
	var h: int = 26
	_fill(img, x0 - 1, y0 - 1, w + 2, h + 2, INK)
	_fill(img, x0, y0, w, h, Color(0.97, 0.83, 0.22))
	_fill(img, x0, y0, w, 1, Color(1.0, 0.95, 0.6))
	_fill(img, x0, y0 + h - 2, w, 2, Color(0.82, 0.62, 0.15))
	for p: Vector2i in [Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 4), Vector2i(w - 3, h - 4)]:
		_put(img, x0 + p.x, y0 + p.y, STEEL_DK)
	var text: String = "ACADEMIA COPA"
	var tw: int = text.length() * 8 - 2
	var tx: int = x0 + (w - tw) / 2
	_text(img, tx + 1, y0 + 9, text, Color(0.72, 0.18, 0.15), 2)
	_text(img, tx, y0 + 8, text, Color(0.08, 0.38, 0.22), 2)
	# Bandeirinha do Brasil collée à côté.
	var bx: int = 440
	var by: int = 38
	_fill(img, bx - 1, by - 1, 17, 12, INK)
	_fill(img, bx, by, 15, 10, Color(0.1, 0.6, 0.3))
	for y in 8:
		var half: int = 6 - absi(y - 4) * 3 / 2
		_fill(img, bx + 7 - half, by + 1 + y, half * 2 + 1, 1, Color(0.98, 0.85, 0.15))
	_fill(img, bx + 5, by + 3, 5, 4, Color(0.15, 0.25, 0.65))
	_fill(img, bx + 6, by + 2, 3, 6, Color(0.15, 0.25, 0.65))
	_fill(img, bx + 5, by + 5, 5, 1, WHITE)


func _paint_posters(img: Image) -> void:
	# Jiu-jitsu : un faixa-preta en garde, kimono branco.
	var x0: int = 128
	var y0: int = 62
	_fill(img, x0 - 1, y0 - 1, 52, 76, INK)
	for y in 74:
		_fill(img, x0, y0 + y, 50, 1, Color(0.18, 0.36, 0.72).lerp(Color(0.1, 0.2, 0.45), float(y) / 74.0))
	_text(img, x0 + 8, y0 + 4, "JIU-JITSU", Color(0.98, 0.85, 0.2))
	var cx: int = x0 + 25
	var gi: Color = Color(0.95, 0.95, 0.92)
	var skin: Color = Color(0.7, 0.5, 0.36)
	_fill(img, cx - 3, y0 + 14, 7, 7, skin)
	_fill(img, cx - 3, y0 + 13, 7, 3, Color(0.12, 0.1, 0.1))
	_fill(img, cx - 1, y0 + 21, 3, 1, skin.darkened(0.2))
	_fill(img, cx - 7, y0 + 22, 15, 15, gi)
	for i in 6:
		_put(img, cx - 3 + i / 2, y0 + 22 + i, Color(0.7, 0.72, 0.75))
		_put(img, cx + 3 - i / 2, y0 + 22 + i, Color(0.7, 0.72, 0.75))
	_fill(img, cx - 7, y0 + 34, 15, 2, Color(0.08, 0.08, 0.1))
	_fill(img, cx + 3, y0 + 36, 2, 4, Color(0.08, 0.08, 0.1))
	_fill(img, cx - 6, y0 + 37, 6, 17, gi)
	_fill(img, cx + 1, y0 + 37, 6, 17, gi)
	_fill(img, cx, y0 + 37, 1, 17, Color(0.7, 0.72, 0.75))
	_fill(img, cx - 7, y0 + 54, 7, 2, skin)
	_fill(img, cx + 1, y0 + 54, 7, 2, skin)
	for s in 2:
		var sg: int = -1 if s == 0 else 1
		_line(img, Vector2i(cx + sg * 7, y0 + 23), Vector2i(cx + sg * 12, y0 + 18), gi, 3)
		_fill(img, cx + sg * 12 - 1, y0 + 15, 3, 3, skin)
	_text(img, x0 + 18, y0 + 63, "OSS", Color(0.98, 0.85, 0.2))
	_paint_tape(img, x0, y0, 50, 74)
	# Vale tudo : l'affiche du combat du samedi.
	x0 = 58
	y0 = 66
	_fill(img, x0 - 1, y0 - 1, 54, 72, INK)
	_fill(img, x0, y0, 52, 70, Color(0.96, 0.8, 0.2))
	_fill(img, x0, y0, 52, 14, Color(0.8, 0.16, 0.14))
	_text(img, x0 + 8, y0 + 5, "VALE TUDO", WHITE)
	for s in 2:
		var fx: int = x0 + 14 + s * 22
		var sk: Color = Color(0.86, 0.66, 0.5) if s == 0 else Color(0.45, 0.3, 0.2)
		var shorts: Color = Color(0.8, 0.16, 0.14) if s == 0 else Color(0.18, 0.3, 0.7)
		_fill(img, fx - 2, y0 + 20, 6, 6, sk)
		_fill(img, fx - 4, y0 + 27, 10, 12, sk)
		_fill(img, fx - 4, y0 + 39, 10, 6, shorts)
		_fill(img, fx - 4, y0 + 45, 4, 12, sk)
		_fill(img, fx + 2, y0 + 45, 4, 12, sk)
		var dir: int = 1 if s == 0 else -1
		_fill(img, fx + 1 + dir * 7, y0 + 26, 4, 4, Color(0.12, 0.12, 0.14))
		_line(img, Vector2i(fx + 1, y0 + 29), Vector2i(fx + 1 + dir * 6, y0 + 28), sk, 2)
	_text(img, x0 + 18, y0 + 60, "X", Color(0.8, 0.16, 0.14), 1)
	_paint_tape(img, x0, y0, 52, 70)


func _paint_tape(img: Image, x0: int, y0: int, w: int, h: int) -> void:
	var tape: Color = Color(0.92, 0.9, 0.78, 0.9)
	for p: Vector2i in [Vector2i(-2, -2), Vector2i(w - 4, -2), Vector2i(-2, h - 4), Vector2i(w - 4, h - 4)]:
		for y in 5:
			for x in 6:
				_blend(img, x0 + p.x + x, y0 + p.y + y, tape)


func _paint_board(img: Image) -> void:
	var x0: int = 534
	var y0: int = 124
	var w: int = 62
	var h: int = 52
	_fill(img, x0 - 1, y0 - 1, w + 2, h + 2, INK)
	_fill(img, x0, y0, w, h, Color(0.55, 0.36, 0.2))
	_fill(img, x0, y0, w, 1, Color(0.72, 0.52, 0.3))
	_fill(img, x0 + 2, y0 + 2, w - 4, h - 4, Color(0.15, 0.25, 0.2))
	for i in 140:
		_blend(img, _rng.randi_range(x0 + 3, x0 + w - 4), _rng.randi_range(y0 + 3, y0 + h - 4), Color(1, 1, 1, 0.08))
	_fill(img, x0 + 6, y0 + h, w - 12, 2, Color(0.55, 0.36, 0.2))
	_fill(img, x0 + 10, y0 + h - 1, 4, 1, CHALK)


func _paint_window(img: Image) -> void:
	var x0: int = 620
	var y0: int = 44
	var x1: int = 740
	var y1: int = 164
	_fill(img, x0 - 5, y0 - 5, x1 - x0 + 10, y1 - y0 + 10, INK)
	_fill(img, x0 - 4, y0 - 4, x1 - x0 + 8, y1 - y0 + 8, Color(0.3, 0.52, 0.78))
	_fill(img, x0 - 4, y0 - 4, x1 - x0 + 8, 1, Color(0.5, 0.7, 0.9))
	# Céu.
	for y in range(y0, y1):
		var k: float = float(y - y0) / float(y1 - y0)
		_fill(img, x0, y, x1 - x0, 1, Color(0.42, 0.72, 0.95).lerp(Color(0.82, 0.93, 0.98), k))
	for c: Vector3i in [Vector3i(640, 56, 9), Vector3i(704, 50, 7)]:
		_fill(img, c.x - c.z, c.y, c.z * 2, 3, WHITE)
		_fill(img, c.x - c.z / 2, c.y - 2, c.z, 2, WHITE)
	# Le morro : mata, puis la favela qui grimpe.
	var top: PackedInt32Array = PackedInt32Array()
	for x in range(x0, x1):
		var fx: float = float(x - x0)
		top.append(roundi(84.0 - 26.0 * sin(fx / 120.0 * PI * 0.9 + 0.3) + 3.0 * sin(fx * 0.31)))
	for x in range(x0, x1):
		for y in range(top[x - x0], y1):
			var c: Color = Color(0.24, 0.52, 0.3)
			if (x * 5 + y * 3) % 7 == 0 or y == top[x - x0]:
				c = Color(0.32, 0.62, 0.34) if y == top[x - x0] else Color(0.17, 0.42, 0.24)
			img.set_pixel(x, y, c)
	var house_cols: Array[Color] = [Color(0.85, 0.45, 0.3), Color(0.96, 0.74, 0.55), Color(0.94, 0.86, 0.45),
		Color(0.55, 0.76, 0.92), Color(0.93, 0.91, 0.86), Color(0.86, 0.55, 0.66), Color(0.72, 0.4, 0.28)]
	var hy: int = 100
	while hy < y1 + 4:
		var hx: int = x0 - 4 + _rng.randi_range(0, 6)
		while hx < x1:
			var hw: int = _rng.randi_range(6, 11)
			var hh: int = _rng.randi_range(5, 8)
			var mid: int = clampi(hx + hw / 2 - x0, 0, top.size() - 1)
			if hy - hh > top[mid] + 10 and _rng.randf() < 0.7 - float(hx - x0) / 400.0:
				var c: Color = house_cols[_rng.randi_range(0, house_cols.size() - 1)]
				_fill(img, hx, hy - hh, hw, hh, c)
				_fill(img, hx, hy - hh, hw, 1, c.darkened(0.3))
				_fill(img, hx + hw - 1, hy - hh, 1, hh, c.darkened(0.18))
				for wx in range(hx + 2, hx + hw - 2, 3):
					_put(img, wx, hy - hh + 3, Color(0.15, 0.15, 0.2))
				if _rng.randf() < 0.35:
					_fill(img, hx + 1, hy - hh - 2, 3, 2, Color(0.25, 0.45, 0.8))
			hx += hw + _rng.randi_range(1, 4)
		hy += 7
	# Grade de fer.
	for x in range(x0 + 10, x1, 13):
		_fill(img, x, y0, 2, y1 - y0, Color(0.16, 0.17, 0.2))
		_fill(img, x, y0, 1, y1 - y0, Color(0.32, 0.34, 0.38))
	for y: int in [y0 + 40, y0 + 80]:
		_fill(img, x0, y, x1 - x0, 2, Color(0.16, 0.17, 0.2))
	_fill(img, x0 + 58, y0, 3, y1 - y0, Color(0.3, 0.52, 0.78))
	_fill(img, x0 - 7, y1 + 4, x1 - x0 + 14, 3, Color(0.86, 0.85, 0.8))
	_fill(img, x0 - 7, y1 + 7, x1 - x0 + 14, 1, INK)


func _paint_bag(img: Image) -> void:
	var bx: int = 18
	for y in range(0, 108, 2):
		_put(img, bx + 10, y, STEEL_DK)
		_put(img, bx + 10, y + 1, STEEL)
	var leather: Color = Color(0.7, 0.14, 0.12)
	_fill(img, bx, 108, 21, 86, INK)
	_fill(img, bx + 1, 109, 19, 84, leather)
	_fill(img, bx + 3, 110, 3, 82, leather.lightened(0.25))
	_fill(img, bx + 16, 110, 3, 82, leather.darkened(0.3))
	for y: int in [118, 182]:
		_fill(img, bx + 1, y, 19, 3, Color(0.12, 0.12, 0.14))


func _paint_cooler(img: Image) -> void:
	# Bebedouro + galão azul, pour la pausa água.
	var x0: int = 770
	_fill(img, x0 - 1, 195, 22, 34, INK)
	_fill(img, x0, 196, 20, 32, Color(0.9, 0.9, 0.88))
	_fill(img, x0 + 16, 196, 4, 32, Color(0.72, 0.72, 0.7))
	_fill(img, x0 + 4, 204, 4, 2, Color(0.2, 0.45, 0.8))
	_fill(img, x0 + 11, 204, 4, 2, Color(0.8, 0.2, 0.2))
	_fill(img, x0 + 1, 172, 18, 24, INK)
	_fill(img, x0 + 2, 173, 16, 22, Color(0.35, 0.62, 0.9, 1))
	_fill(img, x0 + 4, 175, 3, 18, Color(0.6, 0.82, 1.0))
	_fill(img, x0 + 6, 170, 8, 3, Color(0.2, 0.45, 0.8))


func _paint_rack(img: Image) -> void:
	var x0: int = 128
	var x1: int = 240
	for lx: int in [x0, x1 - 4]:
		_fill(img, lx, 250, 4, 51, INK)
		_fill(img, lx + 1, 251, 2, 49, STEEL_DK)
		_fill(img, lx + 1, 251, 1, 49, Color(0.5, 0.52, 0.58))
		_fill(img, lx - 3, 298, 10, 3, INK)
	for ry: int in [264, 284]:
		_fill(img, x0, ry, x1 - x0, 3, INK)
		_fill(img, x0 + 1, ry + 1, x1 - x0 - 2, 1, Color(0.5, 0.52, 0.58))
	var neo: Array[Color] = [Color(0.92, 0.45, 0.62), Color(0.3, 0.75, 0.75), Color(0.95, 0.8, 0.3)]
	for i in 6:
		_dumbbell(img, 134 + i * 17, 263, 3 + i / 2, IRON)
	for i in 6:
		var big: int = 5 + i / 2
		_dumbbell(img, 134 + i * 17, 283, big if i > 2 else 3, IRON if i > 2 else neo[i])


func _dumbbell(img: Image, x: int, base: int, hh: int, c: Color) -> void:
	for hx: int in [x, x + 9]:
		_fill(img, hx - 1, base - hh * 2 - 1, 5, hh * 2 + 1, INK)
		_fill(img, hx, base - hh * 2, 3, hh * 2, c)
		_fill(img, hx, base - hh * 2, 3, 1, c.lightened(0.35))
		_fill(img, hx + 2, base - hh * 2 + 1, 1, hh * 2 - 1, c.darkened(0.3))
	_fill(img, x + 3, base - hh - 1, 6, 3, INK)
	_fill(img, x + 3, base - hh, 6, 1, STEEL)


func _paint_plate_tree(img: Image) -> void:
	var cx: int = 656
	_fill(img, cx - 20, 290, 41, 3, INK)
	_fill(img, cx - 19, 291, 39, 1, STEEL_DK)
	_fill(img, cx - 2, 232, 4, 59, INK)
	_fill(img, cx - 1, 233, 2, 57, STEEL_DK)
	for p: Vector4 in [Vector4(cx - 9, 248, 10, 0), Vector4(cx + 9, 258, 9, 1), Vector4(cx - 8, 272, 8, 2), Vector4(cx + 9, 278, 7, 3)]:
		var col: Color = [RED_PLATE, BLUE_PLATE, YELLOW_PLATE, GREEN_PLATE][int(p.w)]
		var r: int = int(p.z)
		_circle(img, int(p.x), int(p.y), r + 1, INK)
		_circle(img, int(p.x), int(p.y), r, col.darkened(0.25))
		_circle(img, int(p.x), int(p.y), r - 2, col)
		_circle(img, int(p.x), int(p.y), 2, INK)
		_put(img, int(p.x) - r / 2, int(p.y) - r / 2 - 1, col.lightened(0.4))
		_put(img, int(p.x) - r / 2 + 1, int(p.y) - r / 2 - 1, col.lightened(0.4))


func _paint_floor_props(img: Image) -> void:
	# Serviette et garrafa d'água près du banc.
	_fill(img, 410, 303, 5, 12, INK)
	_fill(img, 411, 305, 3, 9, Color(0.5, 0.8, 0.95))
	_fill(img, 411, 302, 3, 3, Color(0.2, 0.45, 0.8))
	_fill(img, 412, 306, 1, 6, WHITE)
	_fill(img, 280, 320, 22, 6, INK)
	_fill(img, 281, 321, 20, 4, WHITE)
	for x in range(282, 300, 4):
		_fill(img, x, 321, 2, 4, Color(0.95, 0.55, 0.2))
