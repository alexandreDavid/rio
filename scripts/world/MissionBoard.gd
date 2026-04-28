class_name MissionBoard
extends Node2D

# Tableau de missions éphémères posé sur le calçadão.
# L'interaction ouvre l'overlay UI MissionBoardUI qui montre les 3 missions
# actives (Voyou / Polícia / Prefeitura) et permet d'en accepter une.

@export var interactable: Interactable

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	var ui: Node = get_tree().current_scene.get_node_or_null("MissionBoardUI")
	if ui and ui.has_method("open"):
		ui.open()
