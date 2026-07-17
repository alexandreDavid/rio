class_name VolleyMatch
extends Node2D

signal match_ended(won: bool, score_player: int, score_opponent: int)

@export var target_score: int = 5
@export var bet_amount: int = 0
@export var ball: VolleyBall
@export var score_label: Label
@export var status_label: Label
@export var serve_offset: Vector2 = Vector2(10, -80)

var _score_player: int = 0
var _score_opponent: int = 0
var _ended: bool = false
var _waiting_for_serve: bool = false
var _serve_button: Button = null
var _player: VolleyPlayer = null
var _ai: VolleyAI = null
var _cam: Camera2D = null
var _flash: ColorRect = null
var _move_left_held: bool = false
var _move_right_held: bool = false
var _shake_time: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	print("")
	print("===== VOLLEY MATCH START =====")
	EventBus.minigame_started.emit("beach_volley")

	# Fallbacks NodePath (le bug habituel)
	if ball == null:
		ball = get_node_or_null("Ball") as VolleyBall
	if score_label == null:
		score_label = get_node_or_null("UI/Score") as Label
	if status_label == null:
		status_label = get_node_or_null("UI/Status") as Label
	_player = get_node_or_null("Player") as VolleyPlayer
	_ai = get_node_or_null("AI") as VolleyAI

	# Boutons tactiles (mobile-first ; MobileControls se masque pendant les
	# mini-jeux, donc le déplacement ◀ ▶ doit vivre ici. Clavier = bonus dev).
	_serve_button = get_node_or_null("UI/ServeButton") as Button
	if _serve_button:
		_serve_button.pressed.connect(_launch_serve)
	var jump_btn: Button = get_node_or_null("UI/JumpButton") as Button
	if jump_btn:
		jump_btn.pressed.connect(_on_jump_pressed)
	var hit_btn: Button = get_node_or_null("UI/HitButton") as Button
	if hit_btn:
		hit_btn.pressed.connect(_on_hit_pressed)
	var left_btn: Button = get_node_or_null("UI/MoveLeftButton") as Button
	if left_btn:
		left_btn.button_down.connect(func() -> void: _set_touch_move(-1.0, true))
		left_btn.button_up.connect(func() -> void: _set_touch_move(-1.0, false))
	var right_btn: Button = get_node_or_null("UI/MoveRightButton") as Button
	if right_btn:
		right_btn.button_down.connect(func() -> void: _set_touch_move(1.0, true))
		right_btn.button_up.connect(func() -> void: _set_touch_move(1.0, false))
	var quit_btn: CanvasLayer = get_node_or_null("MinigameQuitButton")
	if quit_btn and quit_btn.has_signal("quit_pressed"):
		quit_btn.quit_pressed.connect(_end_match)

	# Flash plein écran pour les frappes parfaites (créé en code : pas d'asset).
	var ui: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	if ui:
		_flash = ColorRect.new()
		_flash.name = "HitFlash"
		_flash.color = Color(1, 1, 1, 0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(_flash)

	# Initialisation du match (ground group + caméra + signal ball + score) —
	# DOIT rester dans _ready : si on relogue ça dans _on_hit_pressed, chaque
	# frappe re-initialise le match et déclenche un nouveau service (= reboot).
	var ground: Node = get_node_or_null("Ground")
	if ground and not ground.is_in_group("ground"):
		ground.add_to_group("ground")
	print("[VolleyMatch] ball=%s score_label=%s ground=%s" % [ball, score_label, ground])
	_cam = get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_cam.make_current()
	if ball:
		ball.touched_ground.connect(_on_ball_ground)
		# Gel immédiat : sinon la balle tombe pendant le délai d'intro et
		# offre un point à l'IA avant le premier service.
		ball.freeze_ball()
		print("[VolleyMatch] ball.touched_ground connecté")
	_update_score()
	print("===== VOLLEY MATCH READY =====")
	print("")
	await get_tree().create_timer(0.8).timeout
	_serve()

func _process(delta: float) -> void:
	# Screenshake léger des frappes parfaites.
	if _shake_time <= 0.0 or _cam == null:
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_cam.offset = Vector2.ZERO
	else:
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength

func _set_touch_move(dir: float, held: bool) -> void:
	if dir < 0.0:
		_move_left_held = held
	else:
		_move_right_held = held
	if _player:
		_player.touch_axis = (-1.0 if _move_left_held else 0.0) + (1.0 if _move_right_held else 0.0)

func _on_jump_pressed() -> void:
	# Bouton « Sauter » : bondir relève le point de contact → frappe plus tendue.
	if _player:
		_player.try_jump()

func _on_hit_pressed() -> void:
	if _ended or _waiting_for_serve or _player == null:
		return
	var quality: int = _player.try_hit()
	if quality < 0:
		return
	if status_label:
		status_label.text = ""
	_show_hit_feedback(quality)
	if quality == VolleyBall.QUALITY_PERFECT:
		var airborne: bool = not _player.is_on_floor()
		_start_shake(6.0 if airborne else 3.0, 0.18)
		_flash_screen()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_Q:
		print("[VolleyMatch] Q — abandon")
		_end_match()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_E:
		_on_hit_pressed()
		get_viewport().set_input_as_handled()
		return
	if _waiting_for_serve and event.physical_keycode == KEY_SPACE:
		_launch_serve()
		get_viewport().set_input_as_handled()

func _serve() -> void:
	if ball == null or _ended:
		return
	var pos: Vector2 = _serve_position()
	ball.reset_to(pos)
	ball.freeze_ball()
	_waiting_for_serve = true
	if status_label:
		status_label.text = "Touchez SERVIR pour lancer"
	if _serve_button:
		_serve_button.visible = true
	print("[VolleyMatch] service positionné à %s — attente du joueur" % pos)

func _launch_serve() -> void:
	if not _waiting_for_serve or ball == null:
		return
	_waiting_for_serve = false
	if _serve_button:
		_serve_button.visible = false
	ball.unfreeze_ball()
	# Petit lancer vertical : au joueur de FRAPPER quand la balle redescend.
	ball.linear_velocity = Vector2(0.0, -300.0)
	if status_label:
		status_label.text = "FRAPPE quand la balle redescend !"
	print("[VolleyMatch] service lancé")

func _serve_position() -> Vector2:
	if _player:
		return _player.global_position + serve_offset
	return Vector2(-100, -160)

func _on_ball_ground(side_is_player: bool) -> void:
	if _ended:
		return
	if side_is_player:
		_score_opponent += 1
		if status_label:
			status_label.text = "Point adverse"
	else:
		_score_player += 1
		if status_label:
			status_label.text = "Point pour toi !"
	print("[VolleyMatch] score: joueur=%d adversaire=%d" % [_score_player, _score_opponent])
	_update_score()
	# L'IA monte légèrement en régime à chaque point joué.
	if _ai:
		_ai.set_difficulty(_score_player + _score_opponent)
	if _score_player >= target_score or _score_opponent >= target_score:
		_end_match()
	else:
		await get_tree().create_timer(1.2).timeout
		_serve()

func _update_score() -> void:
	if score_label:
		score_label.text = "%d  —  %d" % [_score_player, _score_opponent]

# Label flottant « Perfeito! / Boa! / Mole... » au-dessus de la balle.
func _show_hit_feedback(quality: int) -> void:
	if ball == null:
		return
	var text: String
	var color: Color
	match quality:
		VolleyBall.QUALITY_PERFECT:
			text = "Perfeito!"
			color = Color(1.0, 0.82, 0.2)
		VolleyBall.QUALITY_GOOD:
			text = "Boa!"
			color = Color(0.5, 0.92, 0.55)
		_:
			text = "Mole..."
			color = Color(0.82, 0.82, 0.82)
	var label: Label = Label.new()
	label.text = text
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	label.position = ball.global_position + Vector2(-34.0, -46.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 28.0, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tw.chain().tween_callback(label.queue_free)

func _start_shake(strength: float, time: float) -> void:
	_shake_strength = strength
	_shake_time = time

func _flash_screen() -> void:
	if _flash == null:
		return
	_flash.color.a = 0.16
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.22)

func _end_match() -> void:
	_ended = true
	var won: bool = _score_player > _score_opponent
	if status_label:
		status_label.text = "Victoire !" if won else ("Fin — %d à %d" % [_score_player, _score_opponent])
	print("[VolleyMatch] fin — won=%s score=%d/%d" % [won, _score_player, _score_opponent])
	await get_tree().create_timer(1.5).timeout
	var result: Dictionary = {
		"won": won,
		"score_player": _score_player,
		"score_opponent": _score_opponent,
		"payout": bet_amount * 2 if won else -bet_amount,
		"qualifies": won,
	}
	match_ended.emit(won, _score_player, _score_opponent)
	EventBus.minigame_ended.emit("beach_volley", result)
