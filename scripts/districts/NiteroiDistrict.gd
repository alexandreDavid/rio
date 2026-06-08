extends AmbientDrifter

# Niterói : étend AmbientDrifter pour conserver les nuages/mouettes/bateaux
# animés, et câble la porte d'entrée du MAC vers le SpawnPoint de l'intérieur.
# Bug historique : si le wiring échouait silencieusement (node null à _ready),
# DoorMAC.destination restait à Vector2.ZERO → joueur téléporté au monde (0,0)
# = en plein Copacabana. On résout les nodes DANS la fonction (plus de @onready
# capturé trop tôt), on log fort si quelque chose manque, et le wiring est
# différé d'une frame pour garantir que les transforms parent (Niterói
# positionné par Copa) sont bien settlés.

func _ready() -> void:
	# Drift décoratif géré par le parent.
	super._ready()
	call_deferred("_wire_mac_doors")

func _wire_mac_doors() -> void:
	var door: Node = get_node_or_null("DoorMAC")
	var spawn: Node = get_node_or_null("MACInterior/SpawnPoint")
	var exit_door: Node = get_node_or_null("MACInterior/ExitDoor")
	if door == null:
		push_warning("[NiteroiDistrict] DoorMAC introuvable — wiring annulé")
		return
	if not (spawn is Node2D):
		push_warning("[NiteroiDistrict] MACInterior/SpawnPoint introuvable — DoorMAC laisserait destination=(0,0) → téléport au monde origin (Copa)")
		return
	if "destination" in door:
		door.destination = (spawn as Node2D).global_position
	if exit_door != null and door is Node2D and "destination" in exit_door:
		# +24 px sud pour réapparaître devant la porte, pas dessus.
		exit_door.destination = (door as Node2D).global_position + Vector2(0, 24)
