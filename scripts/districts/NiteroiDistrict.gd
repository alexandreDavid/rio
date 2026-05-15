extends AmbientDrifter

# Niterói : étend AmbientDrifter pour conserver les nuages/mouettes/bateaux
# animés, et câble la porte d'entrée du MAC vers le SpawnPoint de l'intérieur.

@onready var _mac_door: Node = get_node_or_null("DoorMAC")
@onready var _mac_interior_spawn: Node = get_node_or_null("MACInterior/SpawnPoint")
@onready var _mac_exit_door: Node = get_node_or_null("MACInterior/ExitDoor")

func _ready() -> void:
	# Drift décoratif géré par le parent.
	super._ready()
	_wire_mac_doors()

func _wire_mac_doors() -> void:
	if _mac_door and _mac_interior_spawn and _mac_interior_spawn is Node2D:
		if "destination" in _mac_door:
			_mac_door.destination = (_mac_interior_spawn as Node2D).global_position
	if _mac_exit_door and _mac_door and _mac_door is Node2D:
		if "destination" in _mac_exit_door:
			# +24 px sud pour réapparaître devant la porte, pas dessus.
			_mac_exit_door.destination = (_mac_door as Node2D).global_position + Vector2(0, 24)
