class_name POITrigger
extends Area2D

signal player_entered()
signal player_entered_locked()
signal player_exited()

@export var poi_id: String = ""
@export var one_shot: bool = false
# Clé = Axis int, valeur = seuil minimum. Vide = pas de verrou.
@export var required_reputation: Dictionary = {}

var _fired: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true

func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	if not _meets_reputation():
		player_entered_locked.emit()
		return
	if one_shot and _fired:
		return
	_fired = true
	player_entered.emit()

func _meets_reputation() -> bool:
	for axis_key in required_reputation:
		if ReputationSystem.get_value(int(axis_key)) < int(required_reputation[axis_key]):
			return false
	return true

func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		player_exited.emit()

func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	return body is PlayerController
