class_name TaxiStand
extends Node2D

# Borne de taxi : ouvre l'overlay TaxiUI avec la liste des destinations dispos
# selon le district courant. La même prefab est instanciée à Copacabana ET dans
# chaque district — l'UI gère le routage en fonction de DistrictManager.current().

@export var interactable: Interactable

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	var ui: Node = get_tree().current_scene.get_node_or_null("TaxiUI")
	if ui and ui.has_method("open"):
		ui.open()
