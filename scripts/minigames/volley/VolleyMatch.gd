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

	# Groupe ground forcé (syntaxe tscn pas fiable)
	var ground: Node = get_node_or_null("Ground")
	if ground and not ground.is_in_group("ground"):
		ground.add_to_group("ground")
	print("[VolleyMatch] ball=%s score_label=%s ground=%s" % [ball, score_label, ground])

	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()

	if ball:
		ball.touched_ground.connect(_on_ball_ground)
		print("[VolleyMatch] ball.touched_ground connecté")

	_update_score()
	print("===== VOLLEY MATCH READY =====")
	print("")
	await get_tree().create_timer(0.8).timeout
	_serve()

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
		status_label.text = "Espace pour servir"
	print("[VolleyMatch] service positionné à %s — attente Espace" % pos)

func _launch_serve() -> void:
	if not _waiting_for_serve or ball == null:
		return
	_waiting_for_serve = false
	ball.unfreeze_ball()
	if status_label:
		status_label.text = ""
	print("[VolleyMatch] service lancé")

func _serve_position() -> Vector2:
	var player_node: Node2D = get_node_or_null("Player") as Node2D
	if player_node:
		return player_node.global_position + serve_offset
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
	if _score_player >= target_score or _score_opponent >= target_score:
		_end_match()
	else:
		await get_tree().create_timer(1.2).timeout
		_serve()

func _update_score() -> void:
	if score_label:
		score_label.text = "%d  —  %d" % [_score_player, _score_opponent]

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
	}
	match_ended.emit(won, _score_player, _score_opponent)
	EventBus.minigame_ended.emit("beach_volley", result)
