class_name Interactable
extends Area2D

signal interacted(by: Node)
signal interaction_locked(by: Node)

@export var prompt: String = "Interagir"
@export var enabled: bool = true
# Clé = Axis int (ReputationSystem.Axis), valeur = seuil minimum. Vide = pas de verrou.
@export var required_reputation: Dictionary = {}
@export var locked_prompt: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true

func _on_body_entered(body: Node) -> void:
	if enabled and _is_player(body):
		EventBus.interaction_available.emit(self)

func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		EventBus.interaction_lost.emit(self)

func interact(by: Node) -> void:
	if not enabled:
		return
	if not meets_reputation():
		interaction_locked.emit(by)
		return
	interacted.emit(by)

func meets_reputation() -> bool:
	for axis_key in required_reputation:
		if ReputationSystem.get_value(int(axis_key)) < int(required_reputation[axis_key]):
			return false
	return true

func effective_prompt() -> String:
	if not meets_reputation() and locked_prompt != "":
		return locked_prompt
	return prompt

func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	return body is PlayerController
