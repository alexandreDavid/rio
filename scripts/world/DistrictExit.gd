class_name DistrictExit
extends Area2D

# Sortie de quartier piétonne. Quand le joueur entre dans la zone, il est
# téléporté vers la position cible (taux 0 — c'est à pied, pas en taxi).

@export var target_district: String = "copacabana"
@export var label_text: String = "→ Quartier"

@onready var label_node: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if label_node:
		label_node.text = label_text

func _on_body_entered(body: Node) -> void:
	# Joueur à pied : sortie directe.
	if body.is_in_group("player"):
		DistrictManager.walk_to(target_district)
		return
	# Joueur sur un véhicule : le véhicule traverse aussi — on reste monté.
	if body is Rideable and (body as Rideable).is_ridden():
		DistrictManager.walk_to(target_district, body)
