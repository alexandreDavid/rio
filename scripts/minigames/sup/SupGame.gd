class_name SupGame
extends MinigameBase

# Mini-jeu de stand-up paddle aux Cagarras. Vue top-down. 4 îlots à contourner
# dans l'ordre. Particularité : un courant constant pousse vers l'ouest (-x), il
# faut compenser à la pagaie. Chrono limité ; finir → pourboires de Seu Pedro.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 90.0
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const SUP_RADIUS: float = 16.0
const PADDLE_SPEED: float = 240.0   # plus lent qu'un vélo, plus vite qu'un nageur
# Le courant des Cagarras tourne : il change de cap et de force toutes les
# 5-8 s (annoncé par les flèches), jusqu'à la moitié de la vitesse de pagaie.
const CURRENT_MIN: float = 50.0
const CURRENT_MAX: float = 125.0
const CURRENT_SHIFT_MIN: float = 5.0
const CURRENT_SHIFT_MAX: float = 8.0
const CHECKPOINT_RADIUS: float = 70.0
# Deux tours des 4 îlots, puis retour au départ.
const LAPS: int = 2

# 4 îlots disposés en quinconce, ordre du circuit.
const CHECKPOINTS: Array = [
	Vector2(420, 700),    # 1 — Sud-ouest (départ)
	Vector2(700, 320),    # 2 — Nord-ouest
	Vector2(1300, 280),   # 3 — Nord-est
	Vector2(1500, 700),   # 4 — Sud-est
]

# Location de SUP : petite caixinha du Pedro (max 120 R$), pas une planche à billets.
const TIP_BASE: int = 30
const TIP_BONUS_MAX: int = 90    # max si finition < 40 s
const TIP_FAST_TIME: float = 40.0
const TIP_SLOW_TIME: float = 80.0

# --- Rendu (aucune incidence sur le gameplay) ---
const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")
const PX: float = 3.0                        # un pixel natif = 3 px monde
const DEEP_SEA: Color = Color(0.17, 0.5, 0.68)
const SHORE_Y: float = 60.0                   # sable d'Ipanema au nord
const GRANITE: Color = Color(0.58, 0.53, 0.5)
const VEG: Color = Color(0.3, 0.52, 0.27)
# Les Cagarras, posées au large de chaque bouée (centre monde, taille native).
const ISLANDS: Array = [
	{"name": "Comprida", "pos": Vector2(290, 790), "size": Vector2i(70, 46), "seed": 3},
	{"name": "Palmas", "pos": Vector2(585, 225), "size": Vector2i(56, 42), "seed": 8},
	{"name": "Cagarra", "pos": Vector2(1430, 190), "size": Vector2i(78, 50), "seed": 5},
	{"name": "Redonda", "pos": Vector2(1640, 790), "size": Vector2i(54, 54), "seed": 11},
]
const STREAKS: int = 44
const WAKE_POINTS: int = 18

var _time_left: float = DURATION
var _ended: bool = false
var _sup_pos: Vector2 = CHECKPOINTS[0]
var _next_cp: int = 0  # index global : tour * 4 + îlot
var _current: Vector2 = Vector2(-60.0, 0.0)
var _current_shift_in: float = 3.0
var _completion_time: float = -1.0

var _anim_t: float = 0.0
var _sea_sprite: Sprite2D
var _sea_frames: Array[Texture2D] = []
var _foam_sprite: Sprite2D
var _foam_frames: Array[Texture2D] = []
var _island_sprites: Array[Sprite2D] = []
var _island_frames: Array = []   # [[frame0, frame1], …]
var _drift: Vector2 = Vector2.ZERO
var _fx_current: Node2D
var _fx_sup: Node2D
var _fx_paddle: Node2D
var _rider: Sprite2D
var _streaks: Array = []
var _wake: Array[Vector2] = []
var _wake_clock: float = 0.0
var _heading_angle: float = 0.0
var _paddling: bool = false
var _board_cache: Dictionary = {}

@onready var arena: Node2D = $Arena
@onready var sup_node: ColorRect = $Arena/Sup
@onready var cp_markers: Node2D = $Arena/Checkpoints
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var progress_label: Label = $UI/Progress
@onready var prompt_label: Label = $UI/Prompt

func _ready() -> void:
	EventBus.minigame_started.emit("cagarras_sup")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_sup_pos = CHECKPOINTS[0]
	_build_scenery()
	if sup_node:
		sup_node.color = Color(0, 0, 0, 0)
		sup_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sup_node.position = _sup_pos - Vector2(SUP_RADIUS, SUP_RADIUS)
	_render_checkpoints()
	# On considère le point 0 atteint d'office (c'est le point de mise à l'eau).
	_next_cp = 1
	if status_label:
		status_label.text = "Deux tours des 4 îlots, puis retour au départ. Le courant tourne !"
	if prompt_label:
		prompt_label.text = "Joystick : pagayer — le courant tourne, suis les flèches"

func _render_checkpoints() -> void:
	if cp_markers == null:
		return
	for child in cp_markers.get_children():
		child.queue_free()
	for i in range(CHECKPOINTS.size()):
		var label: Label = Label.new()
		label.text = str(i + 1)
		label.size = Vector2(42, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 33)
		label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.2, 1))
		cp_markers.add_child(label)
	if not cp_markers.draw.is_connected(_draw_buoys):
		cp_markers.draw.connect(_draw_buoys)

func _process(delta: float) -> void:
	_animate(delta)
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game(false)
		return
	_update_current(delta)
	_update_sup(delta)
	_check_checkpoint()
	_update_visuals()
	_update_labels()

func _update_current(delta: float) -> void:
	_current_shift_in -= delta
	if _current_shift_in > 0.0:
		return
	_current_shift_in = randf_range(CURRENT_SHIFT_MIN, CURRENT_SHIFT_MAX)
	var angle: float = randf() * TAU
	_current = Vector2.from_angle(angle) * randf_range(CURRENT_MIN, CURRENT_MAX)
	var arrow: String = _arrow_for(_current)
	var strong: bool = _current.length() > 95.0
	for n in ["Arena/CurrentArrow1", "Arena/CurrentArrow2"]:
		var l: Label = get_node_or_null(n) as Label
		if l:
			l.text = "  ".join([arrow, arrow, arrow]) if strong else "%s  %s" % [arrow, arrow]
	if status_label:
		status_label.text = "O mar virou — courant %s %s" % [arrow, "fort !" if strong else "léger"]
	sfx("splash", 0.7)
	pulse(0.25, 0.1)

static func _arrow_for(v: Vector2) -> String:
	var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var idx: int = int(round(fposmod(v.angle(), TAU) / (TAU / 8.0))) % 8
	return arrows[idx]

func _update_sup(delta: float) -> void:
	var input_dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	_paddling = input_dir.length() > 0.15
	if _paddling:
		_heading_angle = rotate_toward(_heading_angle, input_dir.angle(), 7.0 * delta)
	var velocity: Vector2 = input_dir * PADDLE_SPEED + _current
	_sup_pos += velocity * delta
	_sup_pos.x = clamp(_sup_pos.x, SUP_RADIUS, ARENA_W - SUP_RADIUS)
	_sup_pos.y = clamp(_sup_pos.y, SUP_RADIUS, ARENA_H - SUP_RADIUS)
	if sup_node:
		sup_node.position = _sup_pos - Vector2(SUP_RADIUS, SUP_RADIUS)

func _check_checkpoint() -> void:
	var total: int = CHECKPOINTS.size() * LAPS
	if _next_cp >= total:
		# Tous les îlots faits → on rentre vers le point de départ.
		if _sup_pos.distance_to(CHECKPOINTS[0]) <= CHECKPOINT_RADIUS:
			_completion_time = DURATION - _time_left
			sfx("mg_perfect")
			_end_game(true)
		return
	var target: Vector2 = CHECKPOINTS[_next_cp % CHECKPOINTS.size()]
	if _sup_pos.distance_to(target) <= CHECKPOINT_RADIUS:
		_next_cp += 1
		sfx("checkpoint")
		pulse(0.25, 0.05)
		if status_label:
			if _next_cp < total:
				status_label.text = "Îlot %d/%d ✓ — vise le suivant" % [_next_cp, total]
			else:
				status_label.text = "Volta completa ! Reviens au départ."

func _update_visuals() -> void:
	if cp_markers:
		cp_markers.queue_redraw()

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if progress_label:
		var total: int = CHECKPOINTS.size() * LAPS
		progress_label.text = "Îlots %d / %d" % [clampi(_next_cp, 0, total), total]

func _compute_tip(qualifies: bool) -> int:
	if not qualifies:
		# Circuit incomplet → tip réduit selon îlots atteints.
		return 0 if forfeited else int(round(TIP_BASE * float(min(_next_cp, CHECKPOINTS.size() * LAPS)) / float(CHECKPOINTS.size() * LAPS) * 0.5))
	var t: float = _completion_time
	var ratio: float = clamp((TIP_SLOW_TIME - t) / (TIP_SLOW_TIME - TIP_FAST_TIME), 0.0, 1.0)
	return TIP_BASE + int(round(TIP_BONUS_MAX * ratio))

func quit_game() -> void:
	_end_game(false)

func _end_game(qualifies: bool) -> void:
	if _ended:
		return
	_ended = true
	qualifies = final_qualifies(qualifies)
	var tip: int = _compute_tip(qualifies)
	if status_label:
		if qualifies:
			status_label.text = "Volta complète en %.1fs · R$ %d" % [_completion_time, tip]
		else:
			status_label.text = "Marée tournée · R$ %d" % tip
	await get_tree().create_timer(bilan_delay(2.4)).timeout
	EventBus.minigame_ended.emit("cagarras_sup", {"tip": tip, "time": _completion_time, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)

# ======================================================================
# Rendu pixel : mer peinte, côte d'Ipanema, Cagarras, bouées, courant,
# planche + pagaie + sillage. Tout est purement visuel.
# ======================================================================

func _build_scenery() -> void:
	# Mer : 2 frames de la tuile peinte, répétées, défilant avec le courant.
	var sea_tex: ImageTexture = GroundPainter.sea(DEEP_SEA, 4)
	_sea_frames = _split_frames(sea_tex, GroundPainter.SEA_FRAMES)
	_sea_sprite = _tiled_sprite(_sea_frames[0], Rect2(-900, -400, 3720, 1900))
	_add_at(_sea_sprite, 1)
	# Sable d'Ipanema au nord, écume à la couture.
	var sand: Sprite2D = _tiled_sprite(GroundPainter.sand(Cfg.SAND_COLOR, 7), Rect2(-900, -420, 3720, SHORE_Y + 420))
	_add_at(sand, 2)
	_foam_frames = _split_frames(GroundPainter.foam(DEEP_SEA, 2), GroundPainter.FOAM_FRAMES)
	_foam_sprite = _tiled_sprite(_foam_frames[0], Rect2(-900, SHORE_Y - GroundPainter.FOAM_H * 0.5 * PX, 3720, GroundPainter.FOAM_H * PX))
	_add_at(_foam_sprite, 3)
	var idx: int = 4
	for u in [[Cfg.UMBRELLA_RED_REGION, Vector2(-120, 50)], [Cfg.UMBRELLA_YELLOW_REGION, Vector2(470, 46)],
			[Cfg.UMBRELLA_YELLOW_REGION, Vector2(1560, 48)], [Cfg.UMBRELLA_RED_REGION, Vector2(2060, 46)]]:
		var spr: Sprite2D = PropSprites.spawn(arena, u[0], u[1], 60.0)
		arena.move_child(spr, idx)
		idx += 1
	# Traînées de courant (sous les îles).
	_fx_current = Node2D.new()
	_fx_current.name = "CurrentFx"
	_add_at(_fx_current, idx)
	idx += 1
	_fx_current.draw.connect(_draw_current)
	for i in STREAKS:
		_streaks.append(_new_streak(true))
	# Îles : granit + mata + écume (2 frames).
	for isl in ISLANDS:
		var frames: Array = _island_textures(isl.size, isl.seed)
		_island_frames.append(frames)
		var s: Sprite2D = Sprite2D.new()
		s.texture = frames[0]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(PX, PX)
		s.position = _snap(isl.pos)
		_add_at(s, idx)
		idx += 1
		_island_sprites.append(s)
		var tag: Label = _world_label(isl.name, 22, Color(1, 1, 1, 0.9))
		tag.size = Vector2(200, 30)
		tag.position = isl.pos + Vector2(-100, float(isl.size.y) * PX * 0.5 + 10.0)
		_add_at(tag, idx)
		idx += 1
	# Planche + sillage, puis le personnage, puis la pagaie (devant lui).
	_fx_sup = Node2D.new()
	_fx_sup.name = "SupFx"
	_fx_sup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.add_child(_fx_sup)
	_fx_sup.draw.connect(_draw_sup)
	_rider = char_sprite(96.0)
	_fx_sup.add_child(_rider)
	_fx_paddle = Node2D.new()
	_fx_paddle.name = "PaddleFx"
	arena.add_child(_fx_paddle)
	_fx_paddle.draw.connect(_draw_paddle)
	# Les textes du monde restent au-dessus de tout.
	for n in ["CurrentArrow1", "CurrentArrow2", "Sign"]:
		var l: Node = arena.get_node_or_null(n)
		if l:
			arena.move_child(l, -1)

func _add_at(n: Node, idx: int) -> void:
	arena.add_child(n)
	arena.move_child(n, mini(idx, arena.get_child_count() - 1))

func _world_label(txt: String, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.2, 0.3, 1))
	l.add_theme_constant_override("outline_size", 6)
	return l

static func _split_frames(tex: Texture2D, count: int) -> Array[Texture2D]:
	var img: Image = tex.get_image()
	var w: int = img.get_width() / count
	var out: Array[Texture2D] = []
	for f in count:
		out.append(ImageTexture.create_from_image(img.get_region(Rect2i(f * w, 0, w, img.get_height()))))
	return out

# Sprite répété couvrant `rect` (monde), texels de PX px, calé sur la grille.
func _tiled_sprite(tex: Texture2D, rect: Rect2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, (rect.size / PX).ceil())
	s.position = _snap(rect.position)
	s.scale = Vector2(PX, PX)
	return s

static func _snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX

# Île vue de dessus : affleurement de granit, calotte de mata, fientes
# d'oiseaux sur la roche, puis 2 frames d'écume qui battent autour.
static func _island_textures(size: Vector2i, seed: int) -> Array:
	const M: int = 5
	var rock: Image = GroundPainter.outcrop(size.x, size.y, GRANITE, seed).get_image()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed * 31
	var veg_l: Color = VEG.lightened(0.16)
	var veg_s: Color = VEG.darkened(0.22)
	var veg_d: Color = VEG.darkened(0.48)
	var ph: float = rng.randf() * TAU
	var veg_mask: Array = []
	for y in size.y:
		for x in size.x:
			var u: float = (float(x) + 0.5) / float(size.x) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(size.y) * 2.0 - 1.0
			var a: float = atan2(v, u)
			var lim: float = 0.6 + 0.06 * sin(a * 3.0 + ph) + 0.04 * sin(a * 5.0 + ph * 2.0) + 0.03 * sin(a * 11.0 + ph * 3.0)
			var inside: bool = rock.get_pixel(x, y).a > 0.0 and sqrt(u * u + v * v) < lim
			veg_mask.append(inside)
	for y in size.y:
		for x in size.x:
			if not veg_mask[y * size.x + x]:
				continue
			var edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			if not edge:
				edge = not veg_mask[y * size.x + x - 1] or not veg_mask[y * size.x + x + 1] \
					or not veg_mask[(y - 1) * size.x + x] or not veg_mask[(y + 1) * size.x + x]
			var u2: float = (float(x) + 0.5) / float(size.x) * 2.0 - 1.0
			var v2: float = (float(y) + 0.5) / float(size.y) * 2.0 - 1.0
			var c: Color = VEG
			if u2 + v2 < -0.5:
				c = veg_l
			elif u2 + v2 > 0.45:
				c = veg_s
			var roll: float = rng.randf()
			if roll < 0.1:
				c = veg_d
			elif roll < 0.2:
				c = veg_l
			if edge:
				c = veg_d
			rock.set_pixel(x, y, c)
	# Touffes : petits bouquets clairs ombrés en bas à droite.
	for i in (size.x * size.y) / 90:
		var tx: int = rng.randi_range(2, size.x - 4)
		var ty: int = rng.randi_range(2, size.y - 4)
		if not veg_mask[ty * size.x + tx]:
			continue
		rock.set_pixel(tx, ty, veg_l)
		rock.set_pixel(tx + 1, ty, veg_l)
		rock.set_pixel(tx + 1, ty + 1, veg_s)
		rock.set_pixel(tx + 2, ty + 1, veg_d)
	# Fientes des fragatas sur le granit nu.
	for i in (size.x + size.y) / 4:
		var gx: int = rng.randi_range(1, size.x - 2)
		var gy: int = rng.randi_range(1, size.y - 2)
		if rock.get_pixel(gx, gy).a > 0.0 and not veg_mask[gy * size.x + gx] and rock.get_pixel(gx, gy).g < 0.7:
			rock.set_pixel(gx, gy, Color(0.93, 0.92, 0.86))
	# Distance à la roche (dilatation 4-voisins) pour l'anneau d'écume.
	var W: int = size.x + M * 2
	var H: int = size.y + M * 2
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(W * H)
	dist.fill(99)
	for y in size.y:
		for x in size.x:
			if rock.get_pixel(x, y).a > 0.0:
				dist[(y + M) * W + x + M] = 0
	for d in range(1, M + 1):
		for y in H:
			for x in W:
				if dist[y * W + x] != 99:
					continue
				for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx >= 0 and ny >= 0 and nx < W and ny < H and dist[ny * W + nx] == d - 1:
						dist[y * W + x] = d
						break
	var ramp: Dictionary = GroundPainter.sea_ramp(DEEP_SEA)
	var white: Color = GroundPainter.FOAM_WHITE
	var out: Array = []
	for f in 2:
		var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var frng: RandomNumberGenerator = RandomNumberGenerator.new()
		frng.seed = seed * 7 + f * 101
		for y in H:
			for x in W:
				var d2: int = dist[y * W + x]
				var c: Color = Color(0, 0, 0, 0)
				var r: float = frng.randf()
				# L'anneau respire : la frame 1 pousse l'écume d'un pixel plus loin.
				var reach: int = d2 - f
				if d2 == 1:
					c = white if r < 0.85 else ramp.lighter
				elif reach <= 1 and d2 == 2:
					c = white if r < 0.6 else ramp.lighter
				elif d2 <= 3:
					c = ramp.lighter if r < 0.45 else Color(ramp.light.r, ramp.light.g, ramp.light.b, 0.0 if r > 0.8 else 1.0)
				elif d2 <= M and r < 0.12 + 0.08 * f:
					c = ramp.lighter
				if c.a > 0.0:
					img.set_pixel(x, y, c)
		img.blend_rect(rock, Rect2i(0, 0, size.x, size.y), Vector2i(M, M))
		out.append(ImageTexture.create_from_image(img))
	return out

func _new_streak(anywhere: bool) -> Dictionary:
	var life: float = randf_range(1.4, 2.6)
	return {
		"p": Vector2(randf_range(-400.0, 2320.0), randf_range(SHORE_Y + 30.0, 1080.0)),
		"age": randf() * life if anywhere else 0.0,
		"life": life,
	}

func _animate(delta: float) -> void:
	_anim_t += delta
	if _sea_sprite:
		_sea_sprite.texture = _sea_frames[int(_anim_t / 0.6) % _sea_frames.size()]
		# La surface dérive avec le courant, d'un texel entier à la fois.
		_drift += _current * 0.4 * delta
		_sea_sprite.region_rect.position = -(_drift / PX).floor()
	if _foam_sprite:
		_foam_sprite.texture = _foam_frames[[0, 1, 2, 3, 2, 1][int(_anim_t / 0.22) % 6]]
	for i in _island_sprites.size():
		_island_sprites[i].texture = _island_frames[i][int(_anim_t / 0.5 + i) % 2]
	for s in _streaks:
		s.age += delta
		s.p += _current * 1.15 * delta
		if s.age >= s.life:
			var fresh: Dictionary = _new_streak(false)
			s.p = fresh.p
			s.age = 0.0
			s.life = fresh.life
	_wake_clock += delta
	if _wake_clock >= 0.05:
		_wake_clock = 0.0
		if _wake.is_empty() or _wake[0].distance_to(_sup_pos) > 4.0:
			_wake.push_front(_sup_pos)
		elif _wake.size() > 1:
			_wake.pop_back()
		if _wake.size() > WAKE_POINTS:
			_wake.pop_back()
	if _rider:
		_update_rider()
	for n in [_fx_current, _fx_sup, _fx_paddle, cp_markers]:
		if n:
			n.queue_redraw()

func _update_rider() -> void:
	var fwd: Vector2 = Vector2.from_angle(_heading_angle)
	var row: int = CharacterSpriteFactory.DIR_RIGHT
	if absf(fwd.x) < 0.6:
		row = CharacterSpriteFactory.DIR_UP if fwd.y < 0.0 else CharacterSpriteFactory.DIR_DOWN
	_rider.flip_h = row == CharacterSpriteFactory.DIR_RIGHT and fwd.x < 0.0
	var col: int = 0
	if _paddling:
		col = 1 + int(_anim_t * 2.5) % 2
	_rider.region_rect = Rect2(col * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	var bob: float = PX if fmod(_anim_t, 1.2) > 0.6 else 0.0
	_rider.position = _snap(_sup_pos + Vector2(0, 10.0 + bob))

func _cell(ci: CanvasItem, p: Vector2, c: Color, n: float = 1.0) -> void:
	ci.draw_rect(Rect2(_snap(p), Vector2(PX * n, PX * n)), c)

# Traînées d'écume qui filent dans le sens du courant.
func _draw_current() -> void:
	var strength: float = _current.length()
	if strength < 1.0:
		return
	var dir: Vector2 = _current / strength
	var cells: int = 5 + int(strength / 22.0)
	for s in _streaks:
		var k: float = s.age / s.life
		var fade: float = minf(1.0, minf(k * 4.0, (1.0 - k) * 4.0))
		for j in cells:
			var a: float = fade * (1.0 - float(j) / float(cells)) * 0.85
			var c: Color = Color(0.86, 0.96, 1.0, a) if j > 1 else Color(1, 1, 1, fade * 0.95)
			var q: Vector2 = s.p - dir * float(j) * PX * 1.5
			_cell(_fx_current, q, c)
			if j < cells / 2:
				_cell(_fx_current, q + dir.orthogonal() * PX, Color(c.r, c.g, c.b, c.a * 0.6))

func _draw_buoys() -> void:
	var total: int = CHECKPOINTS.size() * LAPS
	var target: int = _next_cp % CHECKPOINTS.size() if _next_cp < total else 0
	var labels: Array = cp_markers.get_children()
	for i in range(CHECKPOINTS.size()):
		var cp: Vector2 = CHECKPOINTS[i]
		var done: bool = i < target
		var is_target: bool = i == target and not _ended
		# Zone de passage : pointillé qui tourne (cible) ou discret (à venir).
		if is_target or not done:
			var dots: int = 28 if is_target else 16
			var spin: float = _anim_t * (0.6 if is_target else 0.0)
			var glow: float = 0.85 + 0.15 * sin(_anim_t * 6.0)
			var col: Color = Color(1.0, 0.9, 0.2, glow) if is_target else Color(1, 1, 1, 0.35)
			for d in dots:
				var ang: float = TAU * float(d) / float(dots) + spin
				var dp: Vector2 = cp + Vector2.from_angle(ang) * CHECKPOINT_RADIUS - Vector2(PX, PX) * 0.5
				if is_target:
					_cell(cp_markers, dp + Vector2(PX, PX), Color(0.05, 0.2, 0.3, 0.6), 2.0)
				_cell(cp_markers, dp, col, 2.0 if is_target else 1.0)
		var bob: float = PX if sin(_anim_t * 2.4 + float(i)) > 0.0 else 0.0
		var base: Vector2 = _snap(cp + Vector2(0, bob))
		var body: Color = Color(0.36, 0.72, 0.36) if done else Color(0.98, 0.42, 0.16)
		var body_s: Color = body.darkened(0.3)
		var body_l: Color = body.lightened(0.3)
		var outline: Color = Color(0.1, 0.12, 0.18)
		# Ondes autour du flotteur.
		var ring: Color = Color(1, 1, 1, 0.55)
		for x in range(-10, 11):
			if absi(x) > 6 or int(_anim_t * 3.0 + float(x)) % 3 == 0:
				_cell(cp_markers, base + Vector2(x * PX, 6 * PX), ring)
		# Flotteur : disque pixel, bande blanche, ombre en bas à droite.
		var r: int = 7
		for y in range(-r, r + 1):
			var hw: int = int(sqrt(float(r * r - y * y)) + 0.3)
			for x in range(-hw, hw + 1):
				var c: Color = body
				if absi(x) == hw or absi(y) == r:
					c = outline
				elif y == 0 or y == 1:
					c = Color(0.97, 0.97, 0.94)
				elif x + y < -3:
					c = body_l
				elif x + y > 3:
					c = body_s
				_cell(cp_markers, base + Vector2(x * PX, y * PX), c)
		# Mât et fanion.
		for y in range(1, 14):
			_cell(cp_markers, base + Vector2(0, -(r + y) * PX), outline)
		var flag: Color = Color(1.0, 0.86, 0.2) if not done else Color(0.95, 0.97, 0.95)
		var wave: int = int(_anim_t * 4.0 + float(i)) % 2
		for fy in 5:
			var fw: int = 7 - absi(fy - 2) * 2
			for fx in range(1, fw + 1):
				var fyy: int = fy + (wave if fx > 4 else 0)
				_cell(cp_markers, base + Vector2(fx * PX, -(r + 13 - fyy) * PX), flag if fx < fw else flag.darkened(0.25))
		# Plaque du numéro au-dessus du mât.
		var plate: Rect2 = Rect2(base + Vector2(-24, -(r + 13) * PX - 60), Vector2(48, 48))
		cp_markers.draw_rect(plate.grow(3), outline)
		cp_markers.draw_rect(plate, Color(1.0, 0.96, 0.82) if not is_target else Color(1.0, 0.88, 0.3))
		cp_markers.draw_rect(Rect2(plate.position + Vector2(0, plate.size.y - PX), Vector2(plate.size.x, PX)), Color(0.8, 0.7, 0.5))
		if i < labels.size():
			var lab: Label = labels[i] as Label
			if lab:
				lab.position = plate.position + Vector2(0, 2)
				lab.add_theme_color_override("font_color", Color(0.25, 0.45, 0.25) if done else Color(0.12, 0.14, 0.2))

# Sillage, ombre et planche (le personnage est l'enfant de ce nœud).
func _draw_sup() -> void:
	# Sillage : deux lignes d'écume qui s'écartent derrière la planche.
	for j in range(1, _wake.size()):
		var a: float = 1.0 - float(j) / float(WAKE_POINTS)
		var p: Vector2 = _wake[j]
		var seg: Vector2 = _wake[j - 1] - p
		if seg.length() < 0.5:
			continue
		var side: Vector2 = seg.normalized().orthogonal()
		var spread: float = 13.0 + float(j) * 3.0
		var c: Color = Color(1, 1, 1, a * 0.85)
		_cell(_fx_sup, p + side * spread, c)
		_cell(_fx_sup, p - side * spread, c)
		if j % 3 == 0:
			_cell(_fx_sup, p, Color(0.86, 0.96, 1.0, a * 0.5))
	_draw_board(Vector2(3, 9), true)
	_draw_board(Vector2.ZERO, false)
	_draw_guide()

# Chevron jaune autour du paddleur, pointé vers la prochaine bouée.
func _draw_guide() -> void:
	if _ended:
		return
	var total: int = CHECKPOINTS.size() * LAPS
	var target: Vector2 = CHECKPOINTS[_next_cp % CHECKPOINTS.size()] if _next_cp < total else CHECKPOINTS[0]
	var to: Vector2 = target - _sup_pos
	if to.length() < CHECKPOINT_RADIUS + 90.0:
		return
	var d: Vector2 = to.normalized()
	var tip: Vector2 = _sup_pos + Vector2(0, -20) + d * (92.0 + PX * float(int(_anim_t * 4.0) % 2))
	var back: Vector2 = -d * PX
	var side: Vector2 = d.orthogonal() * PX
	var col: Color = Color(1.0, 0.9, 0.2, 0.95)
	var edge: Color = Color(0.1, 0.12, 0.18, 0.85)
	# Chevron épais, cerné de sombre (6 rangées).
	for pass_i in 2:
		for k in 6:
			for w in [-k, -k + 1, k - 1, k]:
				if absi(w) > k:
					continue
				var p: Vector2 = tip + back * float(k) + side * float(w)
				if pass_i == 0:
					_cell(_fx_sup, p - Vector2(PX, PX), edge, 3.0)
				else:
					_cell(_fx_sup, p, col)

func _draw_board(offset: Vector2, shadow: bool) -> void:
	# Cap quantifié sur 64 directions : une texture native par cap, en cache.
	var idx: int = posmod(int(round(_heading_angle / TAU * 64.0)), 64)
	var key: int = idx * 2 + (1 if shadow else 0)
	if not _board_cache.has(key):
		_board_cache[key] = _board_texture(TAU * float(idx) / 64.0, shadow)
	var tex: Texture2D = _board_cache[key]
	var half: Vector2 = Vector2(tex.get_width(), tex.get_height()) * PX * 0.5
	var at: Vector2 = _snap(_sup_pos + Vector2(0, 9) + offset - half)
	_fx_sup.draw_texture_rect(tex, Rect2(at, half * 2.0), false)

# Planche vue de dessus, un pixel natif par cellule de PX.
static func _board_texture(ang: float, shadow: bool) -> ImageTexture:
	const L: float = 54.0
	const W: float = 16.0
	var n: int = int(L / PX) + 2
	var size: int = n * 2 + 1
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shade: Color = Color(0.05, 0.22, 0.32, 0.45)
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var loc: Vector2 = (Vector2(gx, gy) * PX).rotated(-ang)
			# Nez effilé devant (lx > 0), arrière plus carré.
			var wl: float = W * (1.0 - pow(maxf(loc.x / L, 0.0), 3.0) * 0.55)
			var v: float = pow(absf(loc.x) / L, 2.6) + pow(absf(loc.y) / wl, 2.0)
			if v > 1.0:
				continue
			var c: Color
			if shadow:
				c = shade
			elif v > 0.6:
				c = Color(0.1, 0.16, 0.24)
			elif absf(loc.x + 6.0) < 15.0 and absf(loc.y) < wl - 5.0:
				c = Color(0.24, 0.27, 0.32) if (gx + gy) % 2 == 0 else Color(0.3, 0.33, 0.38)
			elif absf(loc.y) < 3.2:
				c = Color(0.99, 0.55, 0.15)
			elif loc.y < 0.0:
				c = Color(1.0, 0.98, 0.9)
			else:
				c = Color(0.86, 0.88, 0.85)
			img.set_pixel(gx + n, gy + n, c)
	return ImageTexture.create_from_image(img)

# Pagaie : coup alterné gauche/droite, éclaboussure à l'entrée de la pale.
func _draw_paddle() -> void:
	var fwd: Vector2 = Vector2.from_angle(_heading_angle)
	var perp: Vector2 = fwd.orthogonal()
	var side: float = 1.0
	var phase: float = 0.5
	if not _paddling:
		# Au repos : pagaie debout à côté du paddleur, pale posée sur la planche.
		var rest_x: float = 21.0 * (-1.0 if _rider and _rider.flip_h else 1.0)
		var top: Vector2 = _sup_pos + Vector2(rest_x, -54)
		var foot: Vector2 = _sup_pos + Vector2(rest_x, 9)
		var st: int = int(top.distance_to(foot) / PX)
		for k in st + 1:
			_cell(_fx_paddle, top.lerp(foot, float(k) / float(st)), Color(0.2, 0.2, 0.26))
		for bx in range(-1, 2):
			_cell(_fx_paddle, top + Vector2(bx * PX, 0), Color(0.2, 0.2, 0.26))
		for by in range(0, 4):
			_cell(_fx_paddle, foot + Vector2(-PX, by * PX - 9.0), Color(0.99, 0.55, 0.15))
			_cell(_fx_paddle, foot + Vector2(PX, by * PX - 9.0), Color(0.99, 0.55, 0.15).darkened(0.2))
		return
	if _paddling:
		side = 1.0 if fmod(_anim_t, 0.8) < 0.4 else -1.0
		phase = fmod(_anim_t, 0.4) / 0.4
	var hand: Vector2 = _sup_pos + Vector2(signf(perp.x * side + 0.01) * 18.0, -32.0)
	var blade: Vector2 = _sup_pos + Vector2(0, 9) + perp * side * 36.0 + fwd * (20.0 - 42.0 * phase)
	var grip: Vector2 = hand + (hand - blade).normalized() * 20.0
	var wood: Color = Color(0.2, 0.2, 0.26)
	var steps: int = int(grip.distance_to(blade) / PX) + 1
	for k in steps + 1:
		_cell(_fx_paddle, grip.lerp(blade, float(k) / float(steps)), wood)
	_cell(_fx_paddle, grip - Vector2(PX, 0), wood)
	_cell(_fx_paddle, grip + Vector2(PX, 0), wood)
	var pale: Color = Color(0.99, 0.55, 0.15)
	for bx in range(-2, 3):
		for by in range(-1, 2):
			_cell(_fx_paddle, blade + Vector2(bx, by) * PX, pale if (bx + by) % 2 == 0 or bx == 0 else pale.darkened(0.2))
	if _paddling and phase < 0.45:
		var spl: Color = Color(1, 1, 1, 0.9 - phase)
		for s in 6:
			var sp: Vector2 = Vector2.from_angle(float(s) * TAU / 6.0 + _anim_t * 3.0) * (9.0 + phase * 18.0)
			_cell(_fx_paddle, blade + sp, spl)
