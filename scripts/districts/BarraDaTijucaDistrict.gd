extends Node2D

# Wiring runtime des portes intérieures du district Barra da Tijuca. Mêmes
# principes que ZonaSulDistrict — résout les global_position au _ready pour
# éviter les hardcoded coords qui se cassent quand on bouge le district.

@onready var _shopping_spawn: Node = get_node_or_null("BarraShoppingInterior/SpawnPoint")
@onready var _door_shopping: Node = get_node_or_null("DoorShopping")
@onready var _le_parc_spawn: Node = get_node_or_null("LeParcInterior/SpawnPoint")
@onready var _door_le_parc: Node = get_node_or_null("DoorLeParc")
@onready var _peninsula_spawn: Node = get_node_or_null("PeninsulaInterior/SpawnPoint")
@onready var _door_peninsula: Node = get_node_or_null("DoorPeninsula")

func _ready() -> void:
	_wire_door(_door_shopping, _shopping_spawn)
	_wire_exit("BarraShoppingInterior/ExitDoor", _door_shopping)
	_wire_door(_door_le_parc, _le_parc_spawn)
	_wire_exit("LeParcInterior/ExitDoor", _door_le_parc)
	_wire_door(_door_peninsula, _peninsula_spawn)
	_wire_exit("PeninsulaInterior/ExitDoor", _door_peninsula)

func _wire_door(door: Node, spawn: Node) -> void:
	if door == null or spawn == null or not (spawn is Node2D):
		return
	if "destination" in door:
		door.destination = (spawn as Node2D).global_position

func _wire_exit(exit_path: String, entry_door: Node) -> void:
	var exit_door: Node = get_node_or_null(exit_path)
	if exit_door == null or entry_door == null or not (entry_door is Node2D):
		return
	if "destination" in exit_door:
		exit_door.destination = (entry_door as Node2D).global_position + Vector2(0, 24)
