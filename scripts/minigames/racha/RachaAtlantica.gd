class_name RachaAtlantica
extends MinigameBase

# Course de rue type "racha carioca" sur l'Avenida Atlântica. Circuit rectangulaire
# fermé, 3 tours, joueur + 3 IA avec vitesses différenciées. Récompense scalée
# selon la position finale (1er → 4e). Pattern minigame identique à LagoaCircuit
# (Camera2D fixe + Arena + EventBus.minigame_started/ended).

signal match_ended(qualifies: bool, tips: int)

const MAX_DURATION: float = 180.0        # 3 min max, sinon on coupe court
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const PLAYER_SPEED: float = 400.0
# Inertie : on accélère et on freine, la voiture glisse dans les virages.
const PLAYER_ACCEL: float = 700.0
const PLAYER_GRIP: float = 3.2          # retour de l'adhérence (1/s)
# Turbo (bouton Action / A / E) : 1,4 s à +35 %, recharge 6 s.
const TURBO_MULT: float = 1.35
const TURBO_TIME: float = 1.4
const TURBO_COOLDOWN: float = 6.0
const AI_SPEEDS: Array = [392.0, 372.0, 350.0]  # IA0 (rouge) tough, IA2 (verte) facile
# Hors bitume (canteiro central ou trottoir) tout le monde ralentit.
const TRACK_OUTER: Rect2 = Rect2(200, 240, 1520, 600)
const TRACK_INNER: Rect2 = Rect2(460, 400, 1000, 280)
const OFFROAD_MULT: float = 0.45
# Trajectoire de l'IA : les portes + les coins (évite de couper par l'herbe).
const AI_WAYPOINTS: Array = [
	Vector2(1100, 320), Vector2(1590, 330), Vector2(1600, 540), Vector2(1590, 750),
	Vector2(1100, 760), Vector2(330, 750), Vector2(320, 540), Vector2(330, 330),
]
const COUNTDOWN: float = 3.0

const CAR_RADIUS: float = 14.0
const CHECKPOINT_RADIUS: float = 70.0
const LAPS_REQUIRED: int = 3
const CARS_TOTAL: int = 4  # 1 joueur + 3 IA

# Circuit clockwise. 4 checkpoints aux coins, retour sur CP0 pour fermer le tour.
const CHECKPOINTS: Array = [
	Vector2(1100, 320),  # CP0 — top (ligne départ/arrivée)
	Vector2(1600, 540),  # CP1 — right
	Vector2(1100, 760),  # CP2 — bottom
	Vector2(320, 540),   # CP3 — left
]

# Inscription 50 R$ : la vitória rapporte, sans faire du racha une planche à billets.
# Rendu : décor peint (RachaPainter), voitures en 16 caps pré-rendus.
const Painter := preload("res://scripts/minigames/racha/RachaPainter.gd")
const GRID: Array = [Vector2(1040, 300), Vector2(1000, 350), Vector2(950, 300), Vector2(910, 350)]
const LAMPS: Array = [
	Vector2(-300, 540), Vector2(40, 540), Vector2(590, 540), Vector2(960, 540), Vector2(1330, 540),
	Vector2(1880, 540), Vector2(2220, 540), Vector2(-200, 150), Vector2(290, 150), Vector2(770, 150),
	Vector2(1250, 150), Vector2(1730, 150), Vector2(2150, 150), Vector2(60, 945), Vector2(560, 945),
	Vector2(1360, 945), Vector2(1860, 945),
]
const PALMS: Array = [
	Vector2(760, 650), Vector2(1160, 650), Vector2(-120, 650), Vector2(2080, 650),
	Vector2(-420, 985), Vector2(-40, 985), Vector2(1980, 985), Vector2(2300, 985),
]
# Sens de passage à chaque porte (horaire) : le chevron le montre.
const CP_ANGLES: Array = [0.0, PI * 0.5, PI, PI * 1.5]

const PAYOUTS: Dictionary = {
	1: 220,
	2: 100,
	3: 40,
	4: 0,
}

# État coureurs : [{pos, vel, next_cp, lap, finished, name, color, is_player}]
var _racers: Array = []
var _ended: bool = false
var _time_elapsed: float = 0.0
var _countdown: float = COUNTDOWN
var _turbo_left: float = 0.0
var _turbo_cd: float = 0.0
var _last_beat: int = 4
var _anim_t: float = 0.0
var _fans: Array[Sprite2D] = []
var _fan_t: float = 0.0
var _sea: Sprite2D = null
var _sea_frames: Array = []
var _glints: Array[ColorRect] = []
var _marker: Sprite2D = null
var _flag: Sprite2D = null

@onready var arena: Node2D = $Arena
@onready var cp_markers: Node2D = $Arena/Checkpoints
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var lap_label: Label = $UI/Lap
@onready var position_label: Label = $UI/Position
@onready var prompt_label: Label = $UI/Prompt

func _ready() -> void:
	EventBus.minigame_started.emit("racha_atlantica")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_build_scenery()
	_init_racers()
	_render_checkpoints()
	if status_label:
		status_label.text = "Racha da Atlântica · 3 tours · reste sur le bitume"
	if prompt_label:
		prompt_label.text = "Joystick : piloter · Turbo : coup de boost"

func _init_racers() -> void:
	# Grille derrière la ligne (CP0, x=1100), en quinconce sur 2 files ; on
	# vise d'abord CP1 : la ligne n'est franchie qu'à la fin de chaque tour.
	var grid: Array = GRID
	# Joueur en tête de grille : il doit défendre, pas remonter tout le peloton.
	var configs: Array = [
		{"name": "Sobrinho",    "color": Color(0.95, 0.85, 0.4, 1),  "is_player": true,  "speed": PLAYER_SPEED},
		{"name": "Faísca",      "color": Color(0.85, 0.32, 0.25, 1), "is_player": false, "speed": AI_SPEEDS[0]},
		{"name": "Capivara",    "color": Color(0.4, 0.55, 0.85, 1),  "is_player": false, "speed": AI_SPEEDS[1]},
		{"name": "Moranguinho", "color": Color(0.4, 0.85, 0.55, 1),  "is_player": false, "speed": AI_SPEEDS[2]},
	]
	for i in CARS_TOTAL:
		var cfg: Dictionary = configs[i]
		var pos: Vector2 = grid[i]
		_racers.append({
			"pos": pos,
			"vel": Vector2.ZERO,
			"next_cp": 1,
			"wp": 1,
			"lap": 0,
			"finished": false,
			"finish_time": -1.0,
			"final_position": -1,
			"name": cfg.name,
			"color": cfg.color,
			"is_player": cfg.is_player,
			"speed": cfg.speed,
			"sprite": _spawn_car_sprite(pos, cfg.color),
			"heading": 0.0,
			"fx_t": 0.0,
			"ai_jitter": Vector2.ZERO,
			"ai_jitter_timer": 0.0,
		})

# Voiture pixel-art : carrosserie de la couleur du coureur, bande contrastée.
func _spawn_car_sprite(pos: Vector2, color: Color) -> Sprite2D:
	var stripe: Color = Color(0.12, 0.11, 0.14) if color.get_luminance() > 0.6 else Color(0.96, 0.94, 0.88)
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = Painter.car_strip(color, stripe)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, Painter.CAR_F, Painter.CAR_F)
	spr.scale = Vector2(Painter.N, Painter.N)
	spr.z_index = 5
	spr.position = _snap(pos)
	arena.add_child(spr)
	return spr

# Le monde est peint à 3 px par pixel natif : les sprites restent sur la grille.
func _snap(p: Vector2) -> Vector2:
	return (p / float(Painter.N)).round() * float(Painter.N)

# Avenue au coucher du soleil, mer animée, palmiers, public derrière les grades.
func _build_scenery() -> void:
	var bg: Sprite2D = Sprite2D.new()
	bg.name = "Backdrop"
	bg.texture = Painter.backdrop(TRACK_OUTER, TRACK_INNER, CHECKPOINTS[0].x, GRID, LAMPS)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.centered = false
	bg.position = Painter.ORIGIN
	bg.scale = Vector2(Painter.N, Painter.N)
	bg.z_index = -10
	arena.add_child(bg)
	_sea_frames = Painter.sea_frames()
	_sea = Sprite2D.new()
	_sea.texture = _sea_frames[0]
	_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sea.centered = false
	_sea.region_enabled = true
	_sea.region_rect = Rect2(0, 0, Painter.W, 110)
	_sea.position = Vector2(Painter.ORIGIN.x, Painter.SEA_Y)
	_sea.scale = Vector2(Painter.N, Painter.N)
	_sea.z_index = -10
	arena.add_child(_sea)
	# Reflet du couchant sur l'eau, sous le soleil.
	for i in 9:
		var g: ColorRect = ColorRect.new()
		g.size = Vector2(3 * (2 + i % 4), 3)
		g.position = _snap(Vector2(-110.0 + randf_range(-60.0, 60.0) - g.size.x * 0.5, Painter.SEA_Y + 9.0 + i * 9.0))
		g.color = Color(1.0, 0.80, 0.52) if i % 3 else Color(1.0, 0.94, 0.75)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.z_index = -9
		arena.add_child(g)
		_glints.append(g)
	for p in PALMS:
		var pos: Vector2 = p
		var palm: Sprite2D = PropSprites.spawn(arena, PropSprites.palm_region_at(pos), pos, PropSprites.palm_height_at(pos))
		palm.z_index = -2
	_spawn_fans()
	_marker = Sprite2D.new()
	_marker.texture = Painter.marker()
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker.scale = Vector2(Painter.N, Painter.N)
	_marker.z_index = 7
	arena.add_child(_marker)
	var title: Label = get_node_or_null("Arena/Title")
	if title:
		title.z_index = 10

func _spawn_fans() -> void:
	# Nord : face à la piste (rangée DIR_DOWN), au pied des immeubles.
	var xs: Array = [230, 340, 470, 590, 720, 830, 1000, 1210, 1330, 1460, 1580, 1700]
	for i in xs.size():
		_add_fan(Vector2(float(xs[i]) + randf_range(-12.0, 12.0), 162.0), CharacterSpriteFactory.DIR_DOWN, 300 + i)
	# Côté plage : de dos, sur le calçadão.
	for i in 6:
		_add_fan(Vector2(300.0 + i * 260.0 + randf_range(-20.0, 20.0), 1000.0), CharacterSpriteFactory.DIR_UP, 400 + i)
	# Le bandeirinha, au droit de la ligne.
	var starter: Sprite2D = _add_fan(Vector2(CHECKPOINTS[0].x, 162.0), CharacterSpriteFactory.DIR_DOWN, 77)
	_flag = Sprite2D.new()
	_flag.texture = Painter.flag()
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.region_enabled = true
	_flag.region_rect = Rect2(0, 0, 12, 16)
	_flag.centered = false
	_flag.position = Vector2(12, -84)
	_flag.scale = Vector2(Painter.N, Painter.N)
	starter.add_child(_flag)

func _add_fan(feet: Vector2, row: int, seed_value: int) -> Sprite2D:
	var fan: Sprite2D = char_sprite(96.0, CharacterSpriteFactory.random_config(seed_value))
	fan.region_rect.position.y = row * CharacterSpriteFactory.CELL_H
	fan.position = _snap(feet)
	fan.z_index = -1
	fan.set_meta("feet_y", fan.position.y)
	arena.add_child(fan)
	_fans.append(fan)
	return fan

func _render_checkpoints() -> void:
	if cp_markers == null:
		return
	for child in cp_markers.get_children():
		child.queue_free()
	cp_markers.z_index = 1
	for i in range(CHECKPOINTS.size()):
		var cp: Vector2 = CHECKPOINTS[i]
		var chev: Sprite2D = Sprite2D.new()
		chev.texture = Painter.chevron()
		chev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chev.scale = Vector2(Painter.N, Painter.N)
		chev.rotation = CP_ANGLES[i]
		chev.position = _snap(cp)
		cp_markers.add_child(chev)

# Décor vivant : public qui saute, mer, reflets, flèche du joueur, porte visée.
func _animate(delta: float) -> void:
	_anim_t += delta
	_fan_t -= delta
	if _fan_t <= 0.0:
		_fan_t = 0.16
		for k in 3:
			var fan: Sprite2D = _fans[randi() % _fans.size()]
			var col: int = randi() % 3
			fan.region_rect.position.x = col * CharacterSpriteFactory.CELL_W
			fan.position.y = float(fan.get_meta("feet_y")) - (6.0 if col > 0 and randf() < 0.5 else 0.0)
	if _sea and _sea_frames.size() > 1:
		_sea.texture = _sea_frames[int(_anim_t * 2.0) % _sea_frames.size()]
		_sea.region_rect.position.x = float(int(_anim_t * 4.0) % 64)
	for i in _glints.size():
		_glints[i].visible = int(_anim_t * 3.0 + i * 1.7) % 3 != 0
	if _flag:
		var waving: bool = _countdown > 0.0 or _ended
		_flag.region_rect.position.x = 12.0 * float(int(_anim_t * (8.0 if waving else 3.0)) % 2)
	# Le « VAI ! » s'efface : le centre de l'écran reste à la course.
	if not _ended and _countdown <= 0.0 and _time_elapsed > 1.2 and status_label and status_label.text == "VAI !":
		status_label.text = ""
	if _racers.is_empty():
		return
	var player: Dictionary = _racers[0]
	if _marker:
		var sprite: Sprite2D = player.sprite
		_marker.position = sprite.position + Vector2(0, -48.0 - (3.0 if int(_anim_t * 4.0) % 2 == 0 else 0.0))
	if cp_markers:
		var markers: Array = cp_markers.get_children()
		for i in markers.size():
			var chev: Sprite2D = markers[i]
			if i == int(player.next_cp) and not player.finished:
				var on: bool = int(_anim_t * 4.0) % 2 == 0
				chev.modulate = Color(1.0, 0.86, 0.3, 1.0 if on else 0.7)
			else:
				chev.modulate = Color(1, 1, 1, 0.22)

# Petite bouffée de pixels (turbo, poussière hors bitume), qui s'éteint seule.
func _puff(pos: Vector2, color: Color) -> void:
	var r: ColorRect = ColorRect.new()
	r.size = Vector2(6, 6)
	r.position = _snap(pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)))
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 4
	arena.add_child(r)
	var tw: Tween = r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.4)
	tw.tween_callback(r.queue_free)

func _car_fx(r: Dictionary, moved: Vector2, delta: float) -> void:
	var speed: float = moved.length() / maxf(delta, 0.0001)
	if speed > 20.0:
		r.heading = lerp_angle(float(r.heading), moved.angle(), clampf(14.0 * delta, 0.0, 1.0))
	var frame: int = posmod(int(roundf(float(r.heading) / (TAU / Painter.CAR_DIRS))), Painter.CAR_DIRS)
	var sprite: Sprite2D = r.sprite
	sprite.region_rect = Rect2(frame * Painter.CAR_F, 0, Painter.CAR_F, Painter.CAR_F)
	r.fx_t = float(r.fx_t) - delta
	if r.fx_t > 0.0 or speed < 60.0:
		return
	var back: Vector2 = r.pos - Vector2.from_angle(float(r.heading)) * 34.0
	if r.is_player and _turbo_left > 0.0:
		r.fx_t = 0.035
		_puff(back, Color(1.0, 0.62, 0.18) if randf() < 0.5 else Color(1.0, 0.92, 0.5))
	elif not _on_track(r.pos):
		r.fx_t = 0.08
		_puff(back, Color(0.86, 0.78, 0.66, 0.8))

func _process(delta: float) -> void:
	_animate(delta)
	if _ended:
		return
	if _countdown > 0.0:
		_tick_countdown(delta)
		return
	_time_elapsed += delta
	_turbo_left = maxf(_turbo_left - delta, 0.0)
	_turbo_cd = maxf(_turbo_cd - delta, 0.0)
	if Input.is_action_just_pressed("interact") and _turbo_cd <= 0.0:
		_turbo_left = TURBO_TIME
		_turbo_cd = TURBO_COOLDOWN
		sfx("whistle", 1.4)
		pulse(0.5, 0.2)
	if _time_elapsed >= MAX_DURATION:
		_end_race(true)
		return
	_update_racers(delta)
	_check_checkpoints()
	_update_labels()
	# Si le joueur a fini ET toutes les positions sont déterminables, on termine.
	if _all_finished() or _player_finished_and_others_settled():
		_end_race(false)

# 3, 2, 1… VAI ! — personne ne bouge avant le coup de sifflet.
func _tick_countdown(delta: float) -> void:
	_countdown -= delta
	var beat: int = int(ceil(_countdown))
	if beat != _last_beat:
		_last_beat = beat
		if beat > 0:
			sfx("mg_good", 0.8)
			if status_label:
				status_label.text = str(beat)
		else:
			sfx("whistle")
			pulse(0.4, 0.1)
			if status_label:
				status_label.text = "VAI !"

func _on_track(p: Vector2) -> bool:
	return TRACK_OUTER.has_point(p) and not TRACK_INNER.has_point(p)

func _update_racers(delta: float) -> void:
	for r in _racers:
		if r.finished:
			continue
		var before: Vector2 = r.pos
		if r.is_player:
			_update_player(r, delta)
		else:
			_update_ai(r, delta)
		r.pos.x = clamp(r.pos.x, CAR_RADIUS, ARENA_W - CAR_RADIUS)
		r.pos.y = clamp(r.pos.y, CAR_RADIUS, ARENA_H - CAR_RADIUS)
		var sprite: Sprite2D = r.sprite
		if sprite:
			sprite.position = _snap(r.pos)
			_car_fx(r, r.pos - before, delta)

func _update_player(r: Dictionary, delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var top: float = float(r.speed) * (TURBO_MULT if _turbo_left > 0.0 else 1.0)
	if not _on_track(r.pos):
		top *= OFFROAD_MULT
	# Accélère vers la direction voulue ; l'adhérence ramène la vitesse dans
	# l'axe (dérapage court dans les virages serrés).
	var want: Vector2 = dir * top
	var vel: Vector2 = r.vel
	vel = vel.move_toward(want, PLAYER_ACCEL * delta)
	vel = vel.lerp(want.normalized() * vel.length() if want.length() > 1.0 else vel, clampf(PLAYER_GRIP * delta, 0.0, 1.0))
	r.vel = vel
	r.pos += vel * delta
	# Mureta : on rebondit sur le bord extérieur (petite perte de vitesse).
	var wall: Rect2 = TRACK_OUTER.grow(60.0)
	if not wall.has_point(r.pos):
		r.pos = r.pos.clamp(wall.position, wall.end)
		r.vel = -r.vel * 0.3
		sfx("mg_drop")
		pulse(0.5, 0.12)

func _update_ai(r: Dictionary, delta: float) -> void:
	# Vers le prochain checkpoint avec un peu de jitter (sinon trajectoires
	# parfaites = pas marrant). Le jitter change toutes les 0.6 s.
	r.ai_jitter_timer -= delta
	if r.ai_jitter_timer <= 0.0:
		r.ai_jitter_timer = 0.5 + randf() * 0.4
		r.ai_jitter = Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
	var target: Vector2 = AI_WAYPOINTS[r.wp]
	if r.pos.distance_to(target) < 90.0:
		r.wp = (int(r.wp) + 1) % AI_WAYPOINTS.size()
		target = AI_WAYPOINTS[r.wp]
	var dir: Vector2 = (target - r.pos).normalized() + r.ai_jitter
	if dir.length() > 1.0:
		dir = dir.normalized()
	# Élastique : derrière le joueur on pousse un peu, loin devant on lève le pied.
	var gap: int = _progress_score(r) - _progress_score(_racers[0])
	var rubber: float = 1.08 if gap < 0 else (0.94 if gap > 1 else 1.0)
	var speed: float = float(r.speed) * rubber
	if not _on_track(r.pos):
		speed *= OFFROAD_MULT
	r.pos += dir * speed * delta

func _check_checkpoints() -> void:
	for r in _racers:
		if r.finished:
			continue
		var target: Vector2 = CHECKPOINTS[r.next_cp]
		if r.pos.distance_to(target) > CHECKPOINT_RADIUS:
			continue
		# Tour bouclé quand on repasse la ligne (CP0) après CP3.
		if r.next_cp == 0:
			r.lap += 1
			r.next_cp = 1
			if r.is_player:
				sfx("mg_good")
			if r.lap >= LAPS_REQUIRED:
				r.finished = true
				r.finish_time = _time_elapsed
				r.final_position = _next_finish_position()
		else:
			r.next_cp = (int(r.next_cp) + 1) % CHECKPOINTS.size()
			if r.is_player:
				sfx("checkpoint")

func _next_finish_position() -> int:
	var count: int = 0
	for r in _racers:
		if r.finished:
			count += 1
	return count

func _all_finished() -> bool:
	for r in _racers:
		if not r.finished:
			return false
	return true

# Si le joueur a fini, on n'a plus besoin d'attendre les retardataires : on
# place tout le monde par progression actuelle.
func _player_finished_and_others_settled() -> bool:
	var player_done: bool = false
	for r in _racers:
		if r.is_player and r.finished:
			player_done = true
			break
	if not player_done:
		return false
	# On laisse 5 s aux IA après la finition joueur pour finir naturellement,
	# sinon on classe par progression.
	for r in _racers:
		if not r.finished and r.is_player == false:
			if _time_elapsed - _player_finish_time() < 5.0:
				return false
	return true

func _player_finish_time() -> float:
	for r in _racers:
		if r.is_player:
			return r.finish_time if r.finished else _time_elapsed
	return _time_elapsed

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % _time_elapsed
	var player: Dictionary = _racers[0]
	if lap_label:
		lap_label.text = "Tour %d / %d" % [clamp(player.lap + 1, 1, LAPS_REQUIRED), LAPS_REQUIRED]
	if position_label:
		position_label.text = "Position : %d/%d" % [_compute_live_position(player), CARS_TOTAL]

# Position en course basée sur la progression (lap * 4 + next_cp), à comparer
# avec les autres. Plus haut = meilleure position.
func _compute_live_position(target: Dictionary) -> int:
	var target_value: float = _progress_value(target)
	var ahead: int = 0
	for r in _racers:
		if r == target:
			continue
		if _progress_value(r) > target_value:
			ahead += 1
	return ahead + 1

# Progression fine : rang de porte, puis proximité de la porte visée.
func _progress_value(r: Dictionary) -> float:
	var gate_pos: Vector2 = CHECKPOINTS[int(r.next_cp)]
	return float(_progress_score(r)) * 10000.0 - (r.pos as Vector2).distance_to(gate_pos)

func _progress_score(r: Dictionary) -> int:
	# Une lap complète = 4 portes (next_cp 1,2,3 puis 0 = ligne). On y ajoute
	# la distance à la porte visée pour départager deux voitures au même rang.
	var gate: int = int(r.next_cp) if int(r.next_cp) > 0 else CHECKPOINTS.size()
	return int(r.lap) * CHECKPOINTS.size() + gate

func quit_game() -> void:
	_end_race(true)

func _end_race(timeout: bool) -> void:
	if _ended:
		return
	_ended = true
	# Donne une position finale à ceux qui n'ont pas fini.
	for r in _racers:
		if r.finished:
			continue
		r.final_position = _compute_live_position(r) + _count_finished()
		r.finish_time = _time_elapsed
	var player: Dictionary = _racers[0]
	var pos: int = player.final_position
	if pos < 1:
		pos = _compute_live_position(player)
	# Abandon = aucune prime, même en tête au moment de partir.
	var tip: int = 0 if forfeited else int(PAYOUTS.get(pos, 0))
	var qualifies: bool = final_qualifies(pos <= 2)  # podium = qualifié (gagne le mini-jeu)
	if status_label:
		if forfeited:
			status_label.text = "Abandon · R$ 0"
		elif timeout:
			status_label.text = "Temps écoulé · Position %d · R$ %d" % [pos, tip]
		elif pos == 1:
			status_label.text = "VITORIA ! · %.1fs · R$ %d" % [player.finish_time, tip]
		else:
			status_label.text = "Course terminée · Position %d · R$ %d" % [pos, tip]
	await get_tree().create_timer(bilan_delay(2.6)).timeout
	EventBus.minigame_ended.emit("racha_atlantica", {
		"tip": tip,
		"position": pos,
		"time": player.finish_time,
		"qualifies": qualifies,
		"won": pos == 1,
	})
	match_ended.emit(qualifies, tip)

func _count_finished() -> int:
	var n: int = 0
	for r in _racers:
		if r.finished:
			n += 1
	return n
