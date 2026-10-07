extends District

# Câblage runtime des portes d'entrée des intérieurs Zona Sul + drift décoratif
# hérité d'AmbientDrifter (mouettes, nuages, bateau à voile dans la zone plage).
# Les intérieurs sont instanciés en local loin de la zone jouée (cf. ZonaSul.tscn).
# Comme ZonaSul est elle-même décalée dans le monde Copacabana, on ne peut pas
# hardcoder les global_position dans la scène — on les résout au _ready en
# lisant le SpawnPoint de chaque intérieur.

@onready var _penthouse_spawn: Node = get_node_or_null("PenthouseLeblon/SpawnPoint")
@onready var _office_spawn: Node = get_node_or_null("OfficeIpanema/SpawnPoint")
@onready var _bar_spawn: Node = get_node_or_null("ArpoadorBar/SpawnPoint")

@onready var _door_penthouse: Node = get_node_or_null("DoorPenthouse")
@onready var _door_office: Node = get_node_or_null("DoorOffice")
@onready var _door_bar: Node = get_node_or_null("DoorBar")

func _ready() -> void:
	# Drift parent : scan des groupes drift_west / drift_east / drift_bob.
	super._ready()
	_wire_door(_door_penthouse, _penthouse_spawn)
	_wire_door(_door_office, _office_spawn)
	_wire_door(_door_bar, _bar_spawn)
	# Idem côté intérieurs : si le joueur charge une save où il était à
	# l'intérieur, la sortie doit fallback sur la porte d'entrée extérieure.
	_wire_exit("PenthouseLeblon/ExitDoor", _door_penthouse)
	_wire_exit("OfficeIpanema/ExitDoor", _door_office)
	_wire_exit("ArpoadorBar/ExitDoor", _door_bar)

func _wire_door(door: Node, spawn: Node) -> void:
	if door == null or spawn == null:
		return
	if not (spawn is Node2D):
		return
	if "destination" in door:
		door.destination = (spawn as Node2D).global_position

func _wire_exit(exit_path: String, entry_door: Node) -> void:
	var exit_door: Node = get_node_or_null(exit_path)
	if exit_door == null or entry_door == null:
		return
	if not (entry_door is Node2D):
		return
	if "destination" in exit_door:
		# +24 px sud pour réapparaître devant la porte, pas dessus.
		exit_door.destination = (entry_door as Node2D).global_position + Vector2(0, 24)
