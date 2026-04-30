extends Node

# Autoload : DistrictManager.
# Gère les déplacements du joueur entre les "districts" de Rio. Pour réduire la
# complexité, tous les districts sont instanciés une seule fois au démarrage à
# des coordonnées éloignées dans la scène monde Copacabana, et le joueur s'y
# téléporte via TaxiStand. Le tracking permet aux UI de connaître la position
# narrative actuelle ("le joueur est sur le Corcovado").

signal district_changed(district_id: String)

# id → métadonnées du district. Le spawn point est résolu dynamiquement via le
# Marker2D nommé "PlayerSpawn" à l'intérieur de la scène district.
const DISTRICTS: Dictionary = {
	"copacabana": {
		"label": "Copacabana — calçadão",
		"fare": 0,
		"node_name": "",  # district par défaut, on revient au TaxiStand
	},
	"corcovado": {
		"label": "Corcovado — Mirante do Cristo",
		"fare": 15,
		"node_name": "CorcovadoDistrict",
	},
	"pao_acucar": {
		"label": "Pão de Açúcar — pôr do sol (bondinho)",
		"fare": 25,
		"node_name": "PaoAcucarDistrict",
	},
	"lagoa": {
		"label": "Lagoa Rodrigo de Freitas",
		"fare": 12,
		"node_name": "LagoaDistrict",
	},
	"maracana": {
		"label": "Maracanã — torcida pela Seleção",
		"fare": 18,
		"node_name": "MaracanaDistrict",
	},
	"santos_dumont": {
		"label": "Aeroporto Santos Dumont",
		"fare": 30,
		"node_name": "SantosDumontDistrict",
	},
	"aterro_flamengo": {
		"label": "Aterro do Flamengo — basquete",
		"fare": 14,
		"node_name": "AterroFlamengoDistrict",
	},
	"cagarras": {
		"label": "Posto 6 — Ilhas Cagarras (SUP)",
		"fare": 10,
		"node_name": "CagarrasDistrict",
	},
	"sambodromo": {
		"label": "Sambódromo — desfile do Carnaval",
		"fare": 22,
		"node_name": "SambodromoDistrict",
	},
	"zona_sul": {
		"label": "Zona Sul (Arpoador / Ipanema / Leblon)",
		"fare": 12,
		"node_name": "ZonaSulDistrict",
	},
	"botafogo_flamengo": {
		"label": "Botafogo / Urca / Flamengo",
		"fare": 14,
		"node_name": "BotafogoFlamengoDistrict",
	},
	"favela_morro": {
		"label": "Favela do Morro — chez tio Zé",
		"fare": 8,
		"node_name": "FavelaDoMorroDistrict",
	},
}

# Position d'arrivée custom quand on entre via une sortie piétonne (pas via le
# PlayerSpawn par défaut). Permet de gérer plusieurs points d'entrée par
# district (ex. arriver à l'est de la Zona Sul depuis Copa, à l'ouest depuis Leblon).
const WALK_ENTRIES: Dictionary = {
	# id_district -> {from_id: Vector2 dans le world (copacabana) ou local (autres)}
	# /!\ Ces positions doivent être HORS des Area2D ExitTo... du district cible
	# pointant vers la source — sinon ping-pong infini (le joueur arrive,
	# touche immédiatement le trigger retour, repart, etc.).
	"copacabana": {
		"zona_sul":           Vector2(-240, 110),    # depuis Arpoador (ouest, après le Forte)
		"botafogo_flamengo":  Vector2(3070, -50),    # depuis le tunnel Leme (extrémité est)
		"favela_morro":       Vector2(1100, -100),   # arrivée depuis le morro — sud de ExitToFavela (-210)
	},
	"zona_sul": {
		"copacabana": Vector2(800, 130),  # arrivée depuis l'est (Copa) — ouest de ExitToCopa (905)
	},
	"botafogo_flamengo": {
		"copacabana": Vector2(0, 250),  # sortie nord du Túnel Novo — nord de ExitToCopa (365)
	},
	"favela_morro": {
		"copacabana": Vector2(0, 150),    # arrivée depuis le bas — nord de ExitToCopa (250) à 70 px
	},
}

# Position de retour à Copacabana (pied du TaxiStand sur l'Av. Atlântica).
const COPACABANA_RETURN_POS: Vector2 = Vector2(1700, 30)

var _current: String = "copacabana"

func current() -> String:
	return _current

# Setter explicite. À utiliser quand le joueur change de district sans passer
# par travel_to / walk_to — typiquement au démarrage (la nouvelle partie commence
# dans la favela via la maison de tio Zé) ou dans un cas de cinématique scriptée.
# Émet district_changed comme les autres mécanismes d'entrée pour cohérence.
func set_current(district_id: String) -> void:
	if not DISTRICTS.has(district_id):
		push_warning("[DistrictManager] set_current: district inconnu : %s" % district_id)
		return
	if _current == district_id:
		return
	_current = district_id
	district_changed.emit(district_id)

func get_label(district_id: String) -> String:
	return DISTRICTS.get(district_id, {}).get("label", district_id)

func get_fare(district_id: String) -> int:
	return int(DISTRICTS.get(district_id, {}).get("fare", 0))

# Liste des destinations disponibles depuis la position courante (toutes sauf la courante).
func available_destinations() -> Array:
	var out: Array = []
	for id in DISTRICTS:
		if id != _current:
			out.append(id)
	return out

func travel_to(district_id: String) -> bool:
	if not DISTRICTS.has(district_id):
		push_warning("[DistrictManager] district inconnu : %s" % district_id)
		return false
	if district_id == _current:
		return false
	# Paiement de la course si applicable.
	var fare: int = get_fare(district_id)
	if fare > 0:
		var inv: Inventory = _player_inventory()
		if inv == null or not inv.spend_money(fare):
			return false  # pas assez d'argent
	# Téléportation.
	var target: Vector2 = _resolve_spawn(district_id)
	if GameManager.player:
		GameManager.player.global_position = target
	_current = district_id
	district_changed.emit(district_id)
	return true

# Sortie piétonne : pas de paiement, point d'arrivée fonction du district
# d'origine si défini dans WALK_ENTRIES, sinon spawn par défaut. Si le joueur
# est sur un véhicule (vehicle != null), le véhicule traverse aussi — le
# joueur reste monté à l'arrivée.
func walk_to(district_id: String, vehicle: Node = null) -> bool:
	if not DISTRICTS.has(district_id):
		push_warning("[DistrictManager] district inconnu : %s" % district_id)
		return false
	if district_id == _current:
		return false
	var from_id: String = _current
	var target: Vector2 = _walk_target(district_id, from_id)
	# On téléporte le joueur dans tous les cas. Si véhicule, on téléporte aussi
	# le véhicule à la même position — la _physics_process du Rideable replacera
	# le joueur sur la selle au tick suivant.
	if GameManager.player:
		GameManager.player.global_position = target
	if vehicle and vehicle is Node2D:
		(vehicle as Node2D).global_position = target
		# Annule l'inertie pour éviter de défoncer un mur à l'arrivée.
		if vehicle is CharacterBody2D:
			(vehicle as CharacterBody2D).velocity = Vector2.ZERO
	_current = district_id
	district_changed.emit(district_id)
	return true

func _walk_target(district_id: String, from_id: String) -> Vector2:
	# 1. Entrée custom (selon district d'origine)
	var per_district: Dictionary = WALK_ENTRIES.get(district_id, {})
	if per_district.has(from_id):
		var local: Vector2 = per_district[from_id]
		# Si Copacabana : la position est en world space direct.
		if district_id == "copacabana":
			return local
		# Sinon : position locale dans le district, on convertit en world space.
		var district_node: Node = _find_district_node(district_id)
		if district_node and district_node is Node2D:
			return (district_node as Node2D).global_position + local
	# 2. Fallback : PlayerSpawn par défaut
	return _resolve_spawn(district_id)

func _find_district_node(district_id: String) -> Node:
	if district_id == "copacabana":
		return null
	var node_name: String = DISTRICTS[district_id].get("node_name", "")
	if node_name == "":
		return null
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return null
	return world.get_node_or_null(node_name)

func _resolve_spawn(district_id: String) -> Vector2:
	if district_id == "copacabana":
		return COPACABANA_RETURN_POS
	var node_name: String = DISTRICTS[district_id].get("node_name", "")
	if node_name == "":
		return COPACABANA_RETURN_POS
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return COPACABANA_RETURN_POS
	var district_node: Node = world.get_node_or_null(node_name)
	if district_node == null:
		push_warning("[DistrictManager] district '%s' n'est pas dans la scène" % node_name)
		return COPACABANA_RETURN_POS
	var spawn: Node2D = district_node.get_node_or_null("PlayerSpawn") as Node2D
	if spawn:
		return spawn.global_position
	return district_node.global_position if district_node is Node2D else COPACABANA_RETURN_POS

func _player_inventory() -> Inventory:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Inventory") as Inventory

# --- Persistance ---

func serialize() -> Dictionary:
	return {"current": _current}

func deserialize(data: Dictionary) -> void:
	_current = data.get("current", "copacabana")
