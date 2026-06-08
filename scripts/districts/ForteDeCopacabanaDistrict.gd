extends Node2D

# Forte de Copacabana — district à part entière. Trois portes d'établissement
# (Café Colombo, Confeitaria 18, Museu Histórico do Exército) câblées au
# runtime vers les SpawnPoints des intérieurs instanciés DANS la scène (en
# zone hors-carte, comme Barra pour ses interiors).
#
# Le wiring est différé d'une frame pour garantir que les transforms parent
# (Forte positionné par Copa) sont settlés avant de lire global_position.

@onready var _door_colombo: Node = get_node_or_null("DoorColombo")
@onready var _door_confeitaria: Node = get_node_or_null("DoorConfeitaria")
@onready var _door_museu: Node = get_node_or_null("DoorMuseu")

func _ready() -> void:
	call_deferred("_wire_doors")

func _wire_doors() -> void:
	_wire(_door_colombo, "ForteColomboInterior/SpawnPoint", "ForteColomboInterior/ExitDoor")
	_wire(_door_confeitaria, "ForteConfeitariaInterior/SpawnPoint", "ForteConfeitariaInterior/ExitDoor")
	_wire(_door_museu, "ForteMuseuInterior/SpawnPoint", "ForteMuseuInterior/ExitDoor")

func _wire(door: Node, spawn_path: String, exit_path: String) -> void:
	if door == null:
		push_warning("[ForteDistrict] porte introuvable — wiring sauté")
		return
	var spawn: Node = get_node_or_null(spawn_path)
	var exit_door: Node = get_node_or_null(exit_path)
	if not (spawn is Node2D):
		push_warning("[ForteDistrict] %s introuvable" % spawn_path)
		return
	if "destination" in door:
		door.destination = (spawn as Node2D).global_position
	if exit_door != null and door is Node2D and "destination" in exit_door:
		# Réapparaît juste sud de la porte (pas dessus).
		exit_door.destination = (door as Node2D).global_position + Vector2(0, 24)
