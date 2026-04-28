extends Node

# Autoload : DynamicMissionManager.
# Système de missions éphémères style GTA en parallèle des quêtes scénarisées.
# Maintient 3 missions actives à tout instant (une par catégorie) ; chaque
# complétion en regénère une de la même catégorie. Le tier monte avec le total
# accompli, faisant grimper le reward.

enum Category { VOYOU, POLICE, MAIRE }

const REWARD_TABLE: Array[int] = [50, 100, 200, 400, 800, 1200]
const REP_TABLE: Array[int] = [1, 2, 3, 4, 5, 5]
const REP_AXIS: Dictionary = {
	Category.VOYOU:  ReputationSystem.Axis.STREET,
	Category.POLICE: ReputationSystem.Axis.POLICE,
	Category.MAIRE:  ReputationSystem.Axis.CIVIC,
}

const CATEGORY_LABELS: Dictionary = {
	Category.VOYOU:  "Voyou",
	Category.POLICE: "Polícia",
	Category.MAIRE:  "Prefeitura",
}

const CATEGORY_COLORS: Dictionary = {
	Category.VOYOU:  Color(0.85, 0.5, 0.3, 1),
	Category.POLICE: Color(0.4, 0.6, 0.95, 1),
	Category.MAIRE:  Color(0.55, 0.85, 0.55, 1),
}

# Pool de missions par catégorie. Chaque entrée :
#  - title : court intitulé pour la fiche
#  - narrative : courte phrase d'ambiance
#  - points : Array[Vector2] — chaque marqueur à toucher dans l'ordre
const TEMPLATES: Dictionary = {
	Category.VOYOU: [
		{
			"title": "Récup' planque favela",
			"narrative": "Miguel a planqué un sac dans le Morro. Récupère-le sans te faire voir.",
			"points": [Vector2(200, -250)],
		},
		{
			"title": "Livraison Posto 1",
			"narrative": "Un client touriste attend un colis discret au Posto 1.",
			"points": [Vector2(2080, 168)],
		},
		{
			"title": "Tournée du Patrão",
			"narrative": "Trois points de collecte du Morro à la pointe de Leme.",
			"points": [Vector2(180, -240), Vector2(900, 220), Vector2(1900, 250)],
		},
		{
			"title": "Filature côté Atlântica",
			"narrative": "Suivre un type qui passe par la favela et l'avenue.",
			"points": [Vector2(220, -200), Vector2(1300, 32)],
		},
	],
	Category.POLICE: [
		{
			"title": "Patrouille calçadão",
			"narrative": "Inspecter trois zones du calçadão pour rassurer les touristes.",
			"points": [Vector2(400, 96), Vector2(1100, 96), Vector2(1800, 96)],
		},
		{
			"title": "Saisie côté Forte",
			"narrative": "Un sac suspect est signalé près du Forte.",
			"points": [Vector2(220, 280)],
		},
		{
			"title": "Contrôle des postos",
			"narrative": "Tour de surveillance des postos 4 et 1.",
			"points": [Vector2(670, 168), Vector2(2080, 168)],
		},
		{
			"title": "Filature suspect",
			"narrative": "Ramos signale un individu à pister.",
			"points": [Vector2(900, 220), Vector2(1300, 96), Vector2(1700, -96)],
		},
	],
	Category.MAIRE: [
		{
			"title": "Distribution de tracts",
			"narrative": "Distribuer la communication municipale en trois points.",
			"points": [Vector2(880, 96), Vector2(1500, 96), Vector2(2040, 96)],
		},
		{
			"title": "Inspection chantier calçadão",
			"narrative": "Vérifier l'état des travaux annoncés.",
			"points": [Vector2(640, 96)],
		},
		{
			"title": "Tournée des commerces",
			"narrative": "Visiter les commerces signataires de la pétition.",
			"points": [Vector2(880, -8), Vector2(1050, -8), Vector2(770, -10)],
		},
		{
			"title": "Aide à la favela",
			"narrative": "Apporter des vivres à deux points dans le Morro.",
			"points": [Vector2(160, -260), Vector2(240, -200)],
		},
	],
}

signal missions_changed
signal mission_completed(category: int, money: int, rep: int)
signal mission_progressed(category: int, progress: int, total: int)

var _active: Dictionary = {}        # category(int) -> mission Dictionary
var _tier: Dictionary = {}          # category(int) -> int (compteur de complétions)

# Marqueurs spawnés en jeu : category -> Node (le marqueur courant)
var _markers: Dictionary = {}

func _ready() -> void:
	_tier = {Category.VOYOU: 0, Category.POLICE: 0, Category.MAIRE: 0}
	for cat in Category.values():
		_generate_for(cat)

# --- API publique ---

func get_mission(cat: int) -> Dictionary:
	return _active.get(cat, {})

func get_tier(cat: int) -> int:
	return int(_tier.get(cat, 0))

func is_accepted(cat: int) -> bool:
	var m: Dictionary = _active.get(cat, {})
	return not m.is_empty() and m.get("accepted", false)

func accept(cat: int) -> bool:
	var m: Dictionary = _active.get(cat, {})
	if m.is_empty() or m.get("accepted", false):
		return false
	m["accepted"] = true
	m["progress"] = 0
	missions_changed.emit()
	_spawn_marker(cat)
	return true

# Appelé par DynamicMissionMarker quand le joueur entre dans la zone du point courant.
func mark_progress(cat: int) -> void:
	var m: Dictionary = _active.get(cat, {})
	if m.is_empty() or not m.get("accepted", false):
		return
	m["progress"] = int(m.get("progress", 0)) + 1
	var total: int = (m.points as Array).size()
	mission_progressed.emit(cat, int(m["progress"]), total)
	if int(m["progress"]) >= total:
		_complete(cat)
	else:
		_spawn_marker(cat)

# --- Logique interne ---

func _generate_for(cat: int) -> void:
	var pool: Array = TEMPLATES[cat]
	var t: Dictionary = pool[randi() % pool.size()].duplicate(true)
	var tier: int = clamp(int(_tier.get(cat, 0)), 0, REWARD_TABLE.size() - 1)
	t["category"] = cat
	t["tier"] = tier
	t["money"] = REWARD_TABLE[tier]
	t["rep"] = REP_TABLE[tier]
	t["progress"] = 0
	t["accepted"] = false
	_active[cat] = t
	missions_changed.emit()

func _complete(cat: int) -> void:
	var m: Dictionary = _active[cat]
	var money: int = int(m.money)
	var rep: int = int(m.rep)
	# Argent
	if GameManager.player:
		var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
		if inv:
			inv.add_money(money)
	# Réputation
	var axis: int = REP_AXIS[cat]
	ReputationSystem.modify(axis, rep)
	_tier[cat] = int(_tier.get(cat, 0)) + 1
	mission_completed.emit(cat, money, rep)
	_despawn_marker(cat)
	_generate_for(cat)

func _spawn_marker(cat: int) -> void:
	_despawn_marker(cat)
	var m: Dictionary = _active.get(cat, {})
	if m.is_empty() or not m.get("accepted", false):
		return
	var idx: int = int(m.get("progress", 0))
	var points: Array = m.get("points", [])
	if idx >= points.size():
		return
	var pos: Vector2 = points[idx]
	var marker_scene: PackedScene = load("res://scenes/props/DynamicMissionMarker.tscn")
	if marker_scene == null:
		return
	var marker: Node = marker_scene.instantiate()
	marker.set("category", cat)
	marker.set("position", pos)
	# Couleur selon catégorie
	if marker.has_method("apply_color"):
		marker.apply_color(CATEGORY_COLORS[cat])
	# On l'attache au monde courant.
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		world = get_tree().current_scene
	world.add_child(marker)
	_markers[cat] = marker

func _despawn_marker(cat: int) -> void:
	var m: Node = _markers.get(cat)
	if m and is_instance_valid(m):
		m.queue_free()
	_markers.erase(cat)

# --- Persistance ---

func serialize() -> Dictionary:
	return {
		"tier": _tier.duplicate(),
		"active": _active.duplicate(true),
	}

func deserialize(data: Dictionary) -> void:
	if data.has("tier"):
		_tier = data["tier"].duplicate()
	if data.has("active"):
		_active = data["active"].duplicate(true)
	# Respawn les marqueurs des missions acceptées.
	for cat in Category.values():
		if is_accepted(cat):
			_spawn_marker(cat)
	missions_changed.emit()
