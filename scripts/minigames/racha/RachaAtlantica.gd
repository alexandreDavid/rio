class_name RachaAtlantica
extends Node2D

# Course de rue type "racha carioca" sur l'Avenida Atlântica. Circuit rectangulaire
# fermé, 3 tours, joueur + 3 IA avec vitesses différenciées. Récompense scalée
# selon la position finale (1er → 4e). Pattern minigame identique à LagoaCircuit
# (Camera2D fixe + Arena + EventBus.minigame_started/ended).

signal match_ended(qualifies: bool, tips: int)

const MAX_DURATION: float = 180.0        # 3 min max, sinon on coupe court
const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const PLAYER_SPEED: float = 380.0
const AI_SPEEDS: Array = [365.0, 340.0, 310.0]  # IA0 (rouge) tough, IA2 (verte) facile

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

const PAYOUTS: Dictionary = {
	1: 600,
	2: 200,
	3: 60,
	4: 0,
}

# État coureurs : [{pos, vel, next_cp, lap, finished, name, color, is_player}]
var _racers: Array = []
var _ended: bool = false
var _time_elapsed: float = 0.0

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
	_init_racers()
	_render_checkpoints()
	if status_label:
		status_label.text = "Racha da Atlântica · 3 tours · clockwise"
	if prompt_label:
		prompt_label.text = "[WASD / Flèches] accélérer"

func _init_racers() -> void:
	# Spawn grille de départ : 4 cases derrière CP0, alignement horizontal.
	var grid_y: float = 280.0
	var grid_xs: Array = [1000.0, 1080.0, 1160.0, 1240.0]
	# Joueur en case 2 (deuxième en partant de la gauche, position avantageuse)
	var configs: Array = [
		{"name": "Sobrinho",    "color": Color(0.95, 0.85, 0.4, 1),  "is_player": true,  "speed": PLAYER_SPEED},
		{"name": "Faísca",      "color": Color(0.85, 0.32, 0.25, 1), "is_player": false, "speed": AI_SPEEDS[0]},
		{"name": "Capivara",    "color": Color(0.4, 0.55, 0.85, 1),  "is_player": false, "speed": AI_SPEEDS[1]},
		{"name": "Moranguinho", "color": Color(0.4, 0.85, 0.55, 1),  "is_player": false, "speed": AI_SPEEDS[2]},
	]
	for i in CARS_TOTAL:
		var cfg: Dictionary = configs[i]
		var pos: Vector2 = Vector2(grid_xs[i], grid_y)
		_racers.append({
			"pos": pos,
			"vel": Vector2.ZERO,
			"next_cp": 0,
			"lap": 0,
			"finished": false,
			"finish_time": -1.0,
			"final_position": -1,
			"name": cfg.name,
			"color": cfg.color,
			"is_player": cfg.is_player,
			"speed": cfg.speed,
			"sprite": _spawn_car_sprite(pos, cfg.color),
			"ai_jitter": Vector2.ZERO,
			"ai_jitter_timer": 0.0,
		})

func _spawn_car_sprite(pos: Vector2, color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(28, 16)
	rect.position = pos - Vector2(14, 8)
	rect.color = color
	arena.add_child(rect)
	return rect

func _render_checkpoints() -> void:
	if cp_markers == null:
		return
	for child in cp_markers.get_children():
		child.queue_free()
	for i in range(CHECKPOINTS.size()):
		var cp: Vector2 = CHECKPOINTS[i]
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(56, 56)
		dot.position = cp - Vector2(28, 28)
		dot.color = Color(0.95, 0.85, 0.4, 0.5)
		cp_markers.add_child(dot)

func _process(delta: float) -> void:
	if _ended:
		return
	_time_elapsed += delta
	if _time_elapsed >= MAX_DURATION:
		_end_race(true)
		return
	_update_racers(delta)
	_check_checkpoints()
	_update_labels()
	# Si le joueur a fini ET toutes les positions sont déterminables, on termine.
	if _all_finished() or _player_finished_and_others_settled():
		_end_race(false)

func _update_racers(delta: float) -> void:
	for r in _racers:
		if r.finished:
			continue
		if r.is_player:
			_update_player(r, delta)
		else:
			_update_ai(r, delta)
		r.pos.x = clamp(r.pos.x, CAR_RADIUS, ARENA_W - CAR_RADIUS)
		r.pos.y = clamp(r.pos.y, CAR_RADIUS, ARENA_H - CAR_RADIUS)
		var sprite: ColorRect = r.sprite
		if sprite:
			sprite.position = r.pos - Vector2(14, 8)

func _update_player(r: Dictionary, delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	r.pos += dir * r.speed * delta

func _update_ai(r: Dictionary, delta: float) -> void:
	# Vers le prochain checkpoint avec un peu de jitter (sinon trajectoires
	# parfaites = pas marrant). Le jitter change toutes les 0.6 s.
	r.ai_jitter_timer -= delta
	if r.ai_jitter_timer <= 0.0:
		r.ai_jitter_timer = 0.5 + randf() * 0.4
		r.ai_jitter = Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
	var target: Vector2 = CHECKPOINTS[r.next_cp]
	var dir: Vector2 = (target - r.pos).normalized() + r.ai_jitter
	if dir.length() > 1.0:
		dir = dir.normalized()
	r.pos += dir * r.speed * delta

func _check_checkpoints() -> void:
	for r in _racers:
		if r.finished:
			continue
		var target: Vector2 = CHECKPOINTS[r.next_cp]
		if r.pos.distance_to(target) > CHECKPOINT_RADIUS:
			continue
		# Avance d'un checkpoint. CP0 atteint en provenance de CP3 = tour bouclé.
		r.next_cp += 1
		if r.next_cp >= CHECKPOINTS.size():
			r.next_cp = 0
			r.lap += 1
			if r.lap >= LAPS_REQUIRED:
				r.finished = true
				r.finish_time = _time_elapsed
				r.final_position = _next_finish_position()

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
	var target_score: int = _progress_score(target)
	var ahead: int = 0
	for r in _racers:
		if r == target:
			continue
		if _progress_score(r) > target_score:
			ahead += 1
	return ahead + 1

func _progress_score(r: Dictionary) -> int:
	# Une lap complète = 4 cp. On y ajoute next_cp pour départager les
	# coureurs dans le même tour.
	return r.lap * CHECKPOINTS.size() + r.next_cp

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
	var tip: int = int(PAYOUTS.get(pos, 0))
	var qualifies: bool = pos <= 2  # podium = qualifié (gagne le mini-jeu)
	if status_label:
		if timeout:
			status_label.text = "Temps écoulé · Position %d · R$ %d" % [pos, tip]
		elif pos == 1:
			status_label.text = "VITORIA ! · %.1fs · R$ %d" % [player.finish_time, tip]
		else:
			status_label.text = "Course terminée · Position %d · R$ %d" % [pos, tip]
	await get_tree().create_timer(2.6).timeout
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
