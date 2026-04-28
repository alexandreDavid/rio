class_name Pickable
extends Node2D

# Objet ramassable sur le sol : quand le joueur interagit avec, l'objectif
# de quête est coché et l'objet disparaît.
# Invisible + non interactif tant que la quête n'est pas active (évite le spam).

signal picked_up()

@export var interactable: Interactable
@export var quest_id: String = ""
@export var objective_id: String = ""
@export var only_if_quest_active: bool = true

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interacted)
	_refresh()
	EventBus.quest_accepted.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)

func _refresh() -> void:
	if not only_if_quest_active:
		return
	var active: bool = quest_id == "" or QuestManager.is_active(quest_id)
	visible = active
	if interactable:
		interactable.enabled = active

func _on_quest_changed(_id: String) -> void:
	_refresh()

func _on_interacted(_by: Node) -> void:
	if quest_id != "" and objective_id != "":
		QuestManager.complete_objective(quest_id, objective_id)
	picked_up.emit()
	if interactable:
		EventBus.interaction_lost.emit(interactable)
	queue_free()
