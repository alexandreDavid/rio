class_name DistrictEntrance
extends Node2D

# Point d'entrée vers un district (gratuit, par interaction). Différence avec
# DistrictExit (Area2D trigger) : ici le joueur doit appuyer sur Interagir,
# pas juste marcher dessus. Utile pour les portes diégétiques (entrée
# d'aéroport, lobby, etc.) qu'on ne veut pas déclencher en passant.

@export var interactable: Interactable
@export var target_district: String = ""
@export var prompt_text: String = "Entrer"

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = prompt_text
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	if target_district == "":
		return
	DistrictManager.walk_to(target_district)
