class_name VolleyMatch
extends MinigameBase

# Beach-volley arcade vu de côté (genre « volley de blobs », avec de vrais personnages) : un joueur par camp, la balle rebondit
# sur le corps (pas de bouton frapper) et l'angle dépend du point d'impact.
# Trois touches max par camp, service alterné, point au camp où la balle
# touche le sable. Simulation codée à la main, à pas fixe : déterministe et
# lisible, là où un RigidBody2D rendait les renvois imprévisibles.

signal match_ended(won: bool, score_player: int, score_opponent: int)

enum Phase { SERVE, RALLY, POINT, OVER }

const Cfg := preload("res://scripts/world/CopacabanaConfig.gd")

const COURT_HALF: float = 440.0
const NET_HALF_W: float = 4.0
const NET_TOP: float = -110.0
const CEILING: float = -680.0
# Vitesse fixe donnée à la balle à chaque contact (la direction = la normale).
const HIT_SPEED: float = 540.0
# Part de la vitesse du blob (vers la balle) ajoutée au renvoi : sauter dedans tape plus fort.
const PUSH_TRANSFER: float = 0.35
const SMASH_BOOST: float = 1.3
# Aide au renvoi : la normale pure renvoie la balle à la verticale quand on est
# pile dessous (elle retombe chez soi). On la penche vers le camp adverse et on
# garantit une montée minimale. Le joueur est plus aidé que le rival.
# Assez léger pour que le point d'impact décide (passe à soi, lob, frappe à
# plat) — juste de quoi ne plus renvoyer chez soi en sautant pile dessous.
const FORWARD_ASSIST_PLAYER: float = 0.3
const FORWARD_ASSIST_AI: float = 0.3
const MIN_LIFT: float = 0.45
const BALL_MAX_SPEED: float = 950.0
const MAX_TOUCHES: int = 3
const TOUCH_COOLDOWN: float = 0.2
const HOME_X: float = 240.0
const SERVE_X: float = 210.0
const SERVE_Y: float = -150.0
const SUBSTEPS: int = 2
const POINT_PAUSE: float = 1.4
const MOUSE_POINTER: int = 1000
const BTN_JUMP: int = 0

@export var target_score: int = 5
@export var bet_amount: int = 0
@export var ball: VolleyBall
@export var score_label: Label
@export var status_label: Label

var _score_player: int = 0
var _score_opponent: int = 0
var _ended: bool = false
var _phase: Phase = Phase.SERVE
var _phase_timer: float = 0.0
# Serveur du point en cours : -1 = joueur, 1 = rival (alterné à chaque point).
var _server: int = -1
var _ball_side: int = -1
var _touch_side: int = 0
var _touches: int = 0
var _player: VolleyPlayer = null
var _ai: VolleyAI = null
var _cam: Camera2D = null
var _ball_shadow: Sprite2D = null
var _arrow: Polygon2D = null
var _pips: Array[ColorRect] = []
var _buttons: Array[Button] = []
var _held: Array[bool] = [false]
var _pointers: Dictionary = {}
var _shake_time: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	EventBus.minigame_started.emit("beach_volley")
	if ball == null:
		ball = get_node_or_null("Ball") as VolleyBall
	if score_label == null:
		score_label = get_node_or_null("UI/Score") as Label
	if status_label == null:
		status_label = get_node_or_null("UI/Status") as Label
	_player = get_node_or_null("Player") as VolleyPlayer
	_ai = get_node_or_null("AI") as VolleyAI
	_player.side_sign = -1
	_player.min_x = -COURT_HALF + VolleyPlayer.RADIUS
	_player.max_x = -NET_HALF_W - VolleyPlayer.RADIUS
	_ai.side_sign = 1
	_ai.min_x = NET_HALF_W + VolleyPlayer.RADIUS
	_ai.max_x = COURT_HALF - VolleyPlayer.RADIUS
	_ai.court_half = COURT_HALF
	_ai.net_half_w = NET_HALF_W
	_ai.net_top = NET_TOP
	_cam = get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_cam.make_current()
	_build_court()
	_wire_buttons()
	_update_score()
	_start_serve()

# --- Boucle de jeu ---

func _physics_process(delta: float) -> void:
	if _phase == Phase.OVER:
		_player.input_axis = 0.0
		_player.input_jump = false
		_ai.input_axis = 0.0
		_ai.input_jump = false
	else:
		_read_player_input()
		_ai.think(delta, ball, _phase == Phase.SERVE and _server == 1)
	var h: float = delta / float(SUBSTEPS)
	for i in SUBSTEPS:
		_player.step(h)
		_ai.step(h)
		if _phase == Phase.SERVE or _phase == Phase.RALLY:
			_step_ball(h)
		else:
			_step_dead_ball(h)
	if _phase == Phase.POINT:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			if _score_player >= target_score or _score_opponent >= target_score:
				_end_match()
			else:
				_start_serve()

func _step_ball(h: float) -> void:
	if not ball.frozen:
		ball.vel.y += VolleyBall.GRAVITY * h
		ball.position += ball.vel * h
		_collide_walls()
		_collide_net()
	for b: VolleyPlayer in [_player, _ai]:
		_collide_blob(b)
		if _phase != Phase.SERVE and _phase != Phase.RALLY:
			return
	_track_side()
	if ball.position.y + VolleyBall.RADIUS >= 0.0:
		ball.position.y = -VolleyBall.RADIUS
		sfx("mg_drop")
		pulse(0.5, 0.12)
		# Le point va au camp d'en face de là où la balle est tombée.
		var winner: int = 1 if ball.position.x < 0.0 else -1
		_award_point(winner, "")
		ball.vel = Vector2(ball.vel.x * 0.4, -absf(ball.vel.y) * 0.3)

# Balle morte (point joué) : elle finit sa course dans le sable, sans règle.
func _step_dead_ball(h: float) -> void:
	if ball.frozen:
		return
	ball.vel.y += VolleyBall.GRAVITY * h
	ball.position += ball.vel * h
	_collide_walls()
	_collide_net()
	if ball.position.y + VolleyBall.RADIUS >= 0.0:
		ball.position.y = -VolleyBall.RADIUS
		ball.vel.x *= 0.6
		ball.vel.y = -absf(ball.vel.y) * 0.3
		if absf(ball.vel.y) < 40.0:
			ball.vel = Vector2.ZERO
			ball.frozen = true

func _collide_walls() -> void:
	var r: float = VolleyBall.RADIUS
	if ball.position.x - r < -COURT_HALF:
		ball.position.x = -COURT_HALF + r
		ball.vel.x = absf(ball.vel.x) * VolleyBall.WALL_DAMP
	elif ball.position.x + r > COURT_HALF:
		ball.position.x = COURT_HALF - r
		ball.vel.x = -absf(ball.vel.x) * VolleyBall.WALL_DAMP
	if ball.position.y - r < CEILING:
		ball.position.y = CEILING + r
		ball.vel.y = absf(ball.vel.y) * VolleyBall.WALL_DAMP

func _collide_net() -> void:
	var r: float = VolleyBall.RADIUS
	var p: Vector2 = ball.position
	if p.y >= NET_TOP:
		# Flanc du filet : la balle reste du côté d'où elle vient.
		if absf(p.x) < NET_HALF_W + r:
			var s: float = float(_ball_side)
			ball.position.x = s * (NET_HALF_W + r)
			if ball.vel.x * s < 0.0:
				ball.vel.x = -ball.vel.x * VolleyBall.NET_DAMP
		return
	# Bande du haut : rebond rond sur le sommet.
	var c: Vector2 = Vector2(0.0, NET_TOP)
	var d: Vector2 = p - c
	var md: float = NET_HALF_W + r
	if d.length_squared() >= md * md:
		return
	var n: Vector2 = Vector2.UP
	if absf(d.x) < 0.5:
		# Pile au sommet : petite pente pour ne jamais rester en équilibre.
		n = Vector2(0.3 * float(_ball_side), -1.0).normalized()
	elif d.length_squared() > 0.0001:
		n = d.normalized()
	ball.position = c + n * md
	var vn: float = ball.vel.dot(n)
	if vn < 0.0:
		ball.vel -= (1.0 + VolleyBall.NET_DAMP) * vn * n

func _collide_blob(b: VolleyPlayer) -> void:
	var shape: Array = b.hit_shape(ball.position)
	var c: Vector2 = shape[0]
	var d: Vector2 = ball.position - c
	var min_d: float = float(shape[1]) + VolleyBall.RADIUS
	if d.length_squared() >= min_d * min_d:
		return
	var n: Vector2 = d.normalized() if d.length_squared() > 0.0001 else Vector2.UP
	ball.position = c + n * min_d
	var speed: float = HIT_SPEED + maxf(b.vel.dot(n), 0.0) * PUSH_TRANSFER
	# Smash : en l'air, au-dessus du filet, la balle part à plat vers l'adversaire.
	var toward: float = -float(b.side_sign)
	var smash: bool = not b.on_ground and n.x * toward > 0.55 and ball.position.y < NET_TOP
	var dir: Vector2 = n
	if smash:
		speed *= SMASH_BOOST
	else:
		var assist: float = FORWARD_ASSIST_AI if b == _ai else FORWARD_ASSIST_PLAYER
		dir = (n + Vector2(toward * assist, 0.0)).normalized()
		# Toujours un peu de hauteur : la balle doit pouvoir passer le filet.
		if dir.y > -MIN_LIFT:
			var sx: float = signf(dir.x) if absf(dir.x) > 0.001 else toward
			dir = Vector2(sx * sqrt(1.0 - MIN_LIFT * MIN_LIFT), -MIN_LIFT)
	ball.vel = dir * minf(speed, BALL_MAX_SPEED)
	ball.frozen = false
	if b.touch_cooldown > 0.0:
		return
	b.touch_cooldown = TOUCH_COOLDOWN
	_register_touch(b, smash)

func _register_touch(b: VolleyPlayer, smash: bool) -> void:
	if _phase == Phase.SERVE:
		_phase = Phase.RALLY
		_set_status("")
	if _touch_side != b.side_sign:
		_touch_side = b.side_sign
		_touches = 0
	_touches += 1
	b.bump()
	sfx("mg_hit", 0.9 + 0.08 * float(_touches))
	if smash:
		sfx("mg_perfect")
		pulse(0.45, 0.07)
		_start_shake(5.0, 0.18)
		_float_text("Pancada!", Color(1.0, 0.82, 0.2))
	_ai.replan()
	_update_pips()
	if _touches > MAX_TOUCHES:
		var who: String = "toi" if b.side_sign == 1 else "le rival"
		_award_point(-b.side_sign, "Quatre touches ! Point pour %s" % who)

# Balle passée de l'autre côté du filet : le compteur repart à zéro.
func _track_side() -> void:
	var side: int = -1 if ball.position.x < 0.0 else 1
	if side == _ball_side:
		return
	_ball_side = side
	_touch_side = 0
	_touches = 0
	_ai.replan()
	_update_pips()

# --- Points, service, fin ---

func _start_serve() -> void:
	_phase = Phase.SERVE
	_player.reset_at(-HOME_X)
	_ai.reset_at(HOME_X)
	ball.place(Vector2(float(_server) * SERVE_X, SERVE_Y))
	_ball_side = _server
	_touch_side = 0
	_touches = 0
	_ai.replan()
	_update_pips()
	if _server < 0:
		_set_status("À toi de servir : saute sous la balle")
	else:
		_set_status("Le rival sert...")

func _award_point(winner: int, msg: String) -> void:
	if _phase != Phase.SERVE and _phase != Phase.RALLY:
		return
	_phase = Phase.POINT
	_phase_timer = POINT_PAUSE
	if winner < 0:
		_score_player += 1
		sfx("mg_good")
		_set_status(msg if msg != "" else "Point pour toi !")
	else:
		_score_opponent += 1
		_set_status(msg if msg != "" else "Point pour le rival")
	_update_score()
	_server = -_server
	_ai.set_difficulty(_score_player + _score_opponent)

func _update_score() -> void:
	if score_label:
		score_label.text = "TOI  %d — %d  RIVAL" % [_score_player, _score_opponent]

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func quit_game() -> void:
	_end_match()

func _end_match() -> void:
	if _ended:
		return
	_ended = true
	_phase = Phase.OVER
	# Abandonner en menant reste une défaite (pas de quête validée en partant).
	var won: bool = final_qualifies(_score_player > _score_opponent)
	_set_status("Victoire !" if won else ("Fin — %d à %d" % [_score_player, _score_opponent]))
	await get_tree().create_timer(bilan_delay(1.5)).timeout
	var result: Dictionary = {
		"won": won,
		"score_player": _score_player,
		"score_opponent": _score_opponent,
		"payout": bet_amount * 2 if won else -bet_amount,
		"qualifies": won,
	}
	match_ended.emit(won, _score_player, _score_opponent)
	EventBus.minigame_ended.emit("beach_volley", result)

# --- Entrées : clavier/manette + boutons tactiles multi-doigts ---

func _read_player_input() -> void:
	# Joystick virtuel (comme dans le monde), stick/croix ou clavier.
	var axis: float = Input.get_axis("move_left", "move_right")
	# Commande « tout ou rien » : le genre se joue au placement précis.
	_player.input_axis = signf(axis) if absf(axis) >= 0.2 else 0.0
	_player.input_jump = _held[BTN_JUMP] \
		or Input.is_action_pressed("jump") \
		or Input.is_action_pressed("interact") \
		or Input.is_physical_key_pressed(KEY_W) \
		or Input.is_physical_key_pressed(KEY_UP)

func _wire_buttons() -> void:
	# Un seul bouton tactile (SAUTE) ; le déplacement passe par le joystick.
	for path in ["UI/JumpButton"]:
		var btn: Button = get_node_or_null(path) as Button
		if btn == null:
			continue
		# Les doigts sont suivis à la main (_input) : un Button ne voit qu'un
		# seul toucher, or on tient le joystick en sautant. Le bouton ne sert qu'au rendu.
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		SafeArea.apply(btn)
		_buttons.append(btn)

func _input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		_set_pointer(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		if _pointers.has(dr.index):
			_set_pointer(dr.index, dr.position, true)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_set_pointer(MOUSE_POINTER, mb.position, mb.pressed)
	elif event is InputEventMouseMotion and _pointers.has(MOUSE_POINTER):
		_set_pointer(MOUSE_POINTER, (event as InputEventMouseMotion).position, true)

# Toucher et souris émulée peuvent doubler un même doigt : sans effet, l'état
# « tenu » est l'union des pointeurs posés sur chaque bouton.
func _set_pointer(id: int, pos: Vector2, down: bool) -> void:
	if down:
		_pointers[id] = _button_at(pos)
	else:
		_pointers.erase(id)
	for i in _held.size():
		_held[i] = _pointers.values().has(i)
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(_held[i] if i < _held.size() else false)

func _button_at(pos: Vector2) -> int:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		if btn.is_visible_in_tree() and btn.get_global_rect().grow(16.0).has_point(pos):
			return i
	return -1

func _exit_tree() -> void:
	_pointers.clear()
	_held.fill(false)

# --- Rendu ---

func _process(delta: float) -> void:
	if ball == null:
		return
	# Ombre au sol : le point de chute se lit d'un coup d'œil.
	_ball_shadow.position = Vector2(ball.position.x, 2.0)
	var height: float = -ball.position.y - VolleyBall.RADIUS
	var k: float = clampf(1.0 - height / 420.0, 0.35, 1.0)
	_ball_shadow.scale = Vector2(VolleyBall.PIXEL * k, VolleyBall.PIXEL)
	_ball_shadow.modulate.a = lerpf(0.45, 1.0, k)
	# Repère en haut d'écran quand la balle sort par le haut.
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top: float = (inv * Vector2.ZERO).y
	if ball.position.y + VolleyBall.RADIUS < top:
		_arrow.visible = true
		_arrow.position = Vector2(ball.position.x, top + 10.0)
		var s: float = clampf(1.2 - (top - ball.position.y) / 500.0, 0.6, 1.2)
		_arrow.scale = Vector2(s, s)
	else:
		_arrow.visible = false
	if _cam:
		if _shake_time > 0.0:
			_shake_time -= delta
			_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		else:
			_cam.offset = Vector2.ZERO

func _start_shake(strength: float, time: float) -> void:
	_shake_strength = strength
	_shake_time = time

func _update_pips() -> void:
	# 3 pastilles devant chaque camp : touches déjà jouées du côté qui a la balle.
	for i in _pips.size():
		var side: int = -1 if i < MAX_TOUCHES else 1
		var used: bool = side == _touch_side and (i % MAX_TOUCHES) < _touches
		_pips[i].color = Color(1, 1, 1, 0.95) if used else Color(0.45, 0.33, 0.18, 0.35)

func _float_text(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 1))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	label.position = ball.position + Vector2(-44.0, -50.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)

# Décor codé (pas d'asset dédié) : ciel, mer et sable pleine largeur (étirés
# par MinigameBase), îles Cagarras à l'horizon, parasols et palmier de
# l'atlas, filet avec poteau, zones hors-jeu grisées derrière les murs.
func _build_court() -> void:
	_rect(Rect2(-960, -1000, 1920, 870), Color(0.5, 0.78, 0.93, 1), -10)
	_rect(Rect2(-960, -1000, 1920, 560), Color(0.4, 0.69, 0.9, 1), -10)
	_rect(Rect2(-960, -1000, 1920, 330), Color(0.33, 0.6, 0.86, 1), -10)
	for cl: Vector3 in [Vector3(-330, -330, 1.0), Vector3(150, -290, 0.8), Vector3(420, -360, 1.2)]:
		_cloud(Vector2(cl.x, cl.y), cl.z)
	for isl: Vector3 in [Vector3(-260, 90, 18), Vector3(-150, 50, 10), Vector3(190, 120, 24)]:
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-isl.y * 0.5, 0), Vector2(-isl.y * 0.25, -isl.z * 0.8),
			Vector2(0, -isl.z), Vector2(isl.y * 0.3, -isl.z * 0.7), Vector2(isl.y * 0.5, 0)])
		poly.position = Vector2(isl.x, -150)
		poly.color = Color(0.3, 0.45, 0.52, 1)
		poly.z_index = -9
		add_child(poly)
	_rect(Rect2(-960, -150, 1920, 130), Cfg.SEA_COLOR, -8)
	_rect(Rect2(-960, -150, 1920, 3), Cfg.SEA_COLOR.lightened(0.3), -8)
	_rect(Rect2(-960, -90, 1920, 3), Cfg.SEA_COLOR.lightened(0.15), -8)
	_rect(Rect2(-960, -24, 1920, 6), Color(0.97, 0.98, 0.96, 0.85), -7)
	_rect(Rect2(-960, -20, 1920, 720), Cfg.SAND_COLOR, -6)
	# Grain du sable (déterministe) et ligne de fond du terrain.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 70:
		var gx: float = snappedf(rng.randf_range(-700.0, 700.0), 3.0)
		var gy: float = snappedf(rng.randf_range(-12.0, 300.0), 3.0)
		_rect(Rect2(gx, gy, 3, 3), Cfg.SAND_COLOR.darkened(0.12), -5)
	_rect(Rect2(-COURT_HALF, 0, COURT_HALF * 2.0, 3), Cfg.SAND_COLOR.darkened(0.2), -5)
	# Parasols et palmier (atlas, densité pixel du jeu).
	for prop: Array in [
			[Cfg.UMBRELLA_RED_REGION, Vector2(-330, -16), 54.0],
			[Cfg.UMBRELLA_YELLOW_REGION, Vector2(310, -16), 54.0],
			[Cfg.UMBRELLA_BLUE_REGION, Vector2(560, -4), 80.0],
			[Cfg.PALM_TREE_REGION, Vector2(-590, -2), 150.0]]:
		var spr: Sprite2D = PropSprites.spawn(self, prop[0], prop[1], prop[2])
		spr.z_index = -4
	# Hors-jeu : au-delà des murs invisibles, tout est assombri.
	for sx: float in [-1.0, 1.0]:
		var x0: float = COURT_HALF if sx > 0.0 else -COURT_HALF - 700.0
		_rect(Rect2(x0, -1000, 700, 1700), Color(0.05, 0.08, 0.15, 0.22), -3)
		_rect(Rect2(sx * COURT_HALF - 3.0, -240, 6, 240), Color(0.55, 0.4, 0.26, 1), -2)
		_rect(Rect2(sx * COURT_HALF - 5.0, -248, 10, 10), Color(0.95, 0.35, 0.3, 1), -2)
	# Filet : poteau sur toute la hauteur (collision réelle), bande et maille.
	_rect(Rect2(-NET_HALF_W, NET_TOP, NET_HALF_W * 2.0, -NET_TOP), Color(0.55, 0.4, 0.26, 1), 2)
	_rect(Rect2(-NET_HALF_W + 1.0, NET_TOP, 2, -NET_TOP), Color(0.68, 0.52, 0.34, 1), 2)
	for row in 7:
		_rect(Rect2(-NET_HALF_W - 3.0, NET_TOP + 6.0 + row * 6.0, NET_HALF_W * 2.0 + 6.0, 2), Color(0.12, 0.12, 0.16, 0.75), 3)
	_rect(Rect2(-NET_HALF_W - 3.0, NET_TOP - 3.0, NET_HALF_W * 2.0 + 6.0, 6), Color(0.98, 0.97, 0.94, 1), 3)
	# Pastilles de touches, au premier plan dans le sable.
	for i in MAX_TOUCHES * 2:
		var side: float = -1.0 if i < MAX_TOUCHES else 1.0
		var cx: float = side * COURT_HALF * 0.5 + float(i % MAX_TOUCHES - 1) * 18.0
		_pips.append(_rect(Rect2(cx - 5.0, 24, 9, 9), Color(0, 0, 0, 0), -4))
	_ball_shadow = Sprite2D.new()
	_ball_shadow.texture = VolleyBall.ellipse_texture(10, 3, Color(0.25, 0.18, 0.08, 0.4))
	_ball_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_shadow.z_index = -1
	add_child(_ball_shadow)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(0, -8), Vector2(9, 6), Vector2(-9, 6)])
	_arrow.color = Color(1.0, 0.85, 0.3, 1)
	_arrow.z_index = 30
	_arrow.visible = false
	add_child(_arrow)

func _cloud(pos: Vector2, s: float) -> void:
	var c: Color = Color(1, 1, 1, 0.85)
	_rect(Rect2(pos.x, pos.y, 72.0 * s, 12), c, -9)
	_rect(Rect2(pos.x + 12.0 * s, pos.y - 9.0, 36.0 * s, 9), c, -9)
	_rect(Rect2(pos.x + 30.0 * s, pos.y - 15.0, 24.0 * s, 6), c, -9)

func _rect(r: Rect2, color: Color, z: int) -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = color
	c.z_index = z
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c
