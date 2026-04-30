extends Node

# Système de positionnement dynamique des NPCs, orienté narratif.
# Autoload name: NPCScheduler.
#
# Les NPCs référencent des "home positions" par clé (ex. "seu_joao@posto4").
# Le scheduler expose une position en fonction :
#   (1) de l'acte courant (CampaignManager.current_act)
#   (2) de la phase de la journée (TimeOfDay.current_phase)
#   (3) de flags narratifs explicites (CampaignManager.flags)
#
# Ordonnancement des règles (première qui matche gagne) :
#   - flag-based (ex. "tio_ze_revealed" -> Concierge disparaît)
#   - act+phase
#   - act-only
#   - phase-only
#   - default
#
# Les NPCs s'enregistrent via register() dans leur _ready() ; le scheduler
# leur pousse la position initiale puis les retag à chaque act_changed /
# time_of_day_changed / flag set.

signal npc_repositioned(npc_id: String, pos: Vector2)

# Règles par défaut. Clé = npc_id. Valeur = Array de règles, évaluées dans l'ordre.
# Chaque règle : { "flag": String?, "act": int?, "phase": int?, "pos": Vector2 }
# Le premier match complet gagne ; sinon on utilise la dernière règle sans condition.
const DEFAULT_SCHEDULE: Dictionary = {
	# seu_joao vit désormais dans la maison du morro (HouseInterior, hors monde joué).
	# Pas de règle ici pour ne pas le téléporter sur le calçadão au démarrage.
	"miguel": [
		{"act": 2, "pos": Vector2(200, -220)},  # s'installe dans la favela en acte 2
		{"pos": Vector2(866, 96)},
	],
	"tito": [
		{"flag": "ratted_on_tito", "pos": Vector2(9999, -9999)},  # hors map s'il s'est fait balancer
		{"pos": Vector2(180, -270)},
	],
	"concierge": [
		{"flag": "tio_ze_revealed", "pos": Vector2(9999, -9999)},  # disparaît quand on découvre que c'est Zé
		{"pos": Vector2(1700, 96)},
	],
	"ramos": [
		# Capitão Ramos : devant l'Academia en journée, au bar le soir.
		{"phase": 2, "pos": Vector2(1380, -96)},  # EVENING -> Bar do Policial
		{"pos": Vector2(700, -96)},               # devant Academia (sur Nossa Senhora)
	],
	"consortium": [
		# Dom Nilton & sa bande traînent sur l'Av. Atlântica, côté commerces.
		{"pos": Vector2(1550, 48)},
	],
	"carlos": [{"pos": Vector2(880, -8)}],
	# padre vit désormais dans ChurchInterior — pas de règle ici pour ne pas le téléporter dehors.
	# farmaceutico vit désormais dans PharmacyInterior — pas de règle ici.
	"contessa": [{"pos": Vector2(1760, 96)}],
	# chef_restaurant vit dans RestaurantInterior — pas de règle ici.
	# padeiro vit dans PadariaInterior — pas de règle ici.
	"otavio": [{"pos": Vector2(1860, 96)}],
	# vendeuse_boutique vit désormais dans ShopInterior — pas de règle ici pour ne pas
	# la téléporter dans la rue au démarrage.
	"ze_bar": [{"pos": Vector2(500, 96)}],
	"jorge": [{"pos": Vector2(1335, -100)}],
	"musicien": [{"pos": Vector2(600, 96)}],
	# joggeur : patrouille gérée par NPCPatrol — pas de règle scheduler pour ne pas l'interrompre.
	"pecheur": [{"pos": Vector2(200, 200)}],
	"coconut_vendor": [{"pos": Vector2(420, 200)}],
	"military_pm": [{"pos": Vector2(100, 96)}],
	"tourist_vip": [{"pos": Vector2(1780, 96)}],
	"policier": [{"pos": Vector2(1200, 96)}],
}

# Overrides runtime (set via admin/debug ou par des quêtes). Même format que DEFAULT_SCHEDULE.
var _overrides: Dictionary = {}
# NPCs enregistrés en scène (npc_id -> Node2D).
var _registered: Dictionary = {}

func _ready() -> void:
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.time_of_day_changed.connect(_on_phase_changed)

func register(npc_id: String, node: Node2D) -> void:
	if npc_id == "":
		return
	_registered[npc_id] = node
	reposition(npc_id)

func unregister(npc_id: String) -> void:
	_registered.erase(npc_id)

# Accès public au noeud d'un NPC par son id (utilisé par le CutsceneRunner).
func get_npc(npc_id: String) -> Node2D:
	var n: Node2D = _registered.get(npc_id)
	if n != null and is_instance_valid(n):
		return n
	return null

const WALK_SPEED: float = 80.0  # px/s pour l'animation de marche du scheduler

func reposition(npc_id: String, animate: bool = false) -> void:
	var node: Node2D = _registered.get(npc_id)
	if node == null or not is_instance_valid(node):
		return
	# Si aucune règle n'est définie (NPC dans un intérieur, ou non piloté), on laisse
	# la position déclarée dans la scène intacte.
	if not _overrides.has(npc_id) and not DEFAULT_SCHEDULE.has(npc_id):
		return
	var pos: Vector2 = compute_position(npc_id)
	var dist: float = node.global_position.distance_to(pos)
	# Animation de marche uniquement si demandé ET distance significative ET NPC supporte play_walk.
	if animate and dist > 8.0 and node.has_method("play_walk"):
		_animate_walk(node, pos)
	else:
		node.global_position = pos
	npc_repositioned.emit(npc_id, pos)

func _animate_walk(node: Node2D, target: Vector2) -> void:
	var delta_v: Vector2 = target - node.global_position
	var dir: int = 0  # Direction.DOWN par défaut
	if abs(delta_v.x) > abs(delta_v.y):
		dir = 2 if delta_v.x > 0 else 3  # RIGHT / LEFT
	else:
		dir = 0 if delta_v.y > 0 else 1  # DOWN / UP
	node.call("play_walk", dir)
	var duration: float = max(0.4, delta_v.length() / WALK_SPEED)
	var t: Tween = node.create_tween()
	t.tween_property(node, "global_position", target, duration)
	t.finished.connect(func(): node.call("stop_walk"))

func reposition_all(animate: bool = false) -> void:
	for npc_id in _registered:
		reposition(npc_id, animate)

func compute_position(npc_id: String) -> Vector2:
	var rules: Array = _overrides.get(npc_id, DEFAULT_SCHEDULE.get(npc_id, []))
	var act: int = CampaignManager.current_act
	var phase: int = TimeOfDay.current_phase
	var fallback: Vector2 = Vector2.ZERO
	var found_fallback: bool = false
	for rule in rules:
		var has_cond: bool = false
		if rule.has("flag"):
			has_cond = true
			if not CampaignManager.has_flag(rule.flag):
				continue
		if rule.has("act"):
			has_cond = true
			if rule.act != act:
				continue
		if rule.has("phase"):
			has_cond = true
			if rule.phase != phase:
				continue
		if has_cond:
			return rule.pos
		if not found_fallback:
			fallback = rule.pos
			found_fallback = true
	return fallback

# --- Overrides runtime (utilisable depuis les quêtes / debug console) ---

func override(npc_id: String, rules: Array) -> void:
	_overrides[npc_id] = rules
	reposition(npc_id)

func clear_override(npc_id: String) -> void:
	_overrides.erase(npc_id)
	reposition(npc_id)

# --- Réactions aux changements d'état ---

func _on_act_changed(_new_act: int) -> void:
	# Animation : les NPCs marchent vers leur nouvelle position au changement d'acte.
	reposition_all(true)

func _on_phase_changed(_phase: int) -> void:
	reposition_all(true)

# Appelé par CampaignManager.set_flag() via notification manuelle si besoin
# (les flags narratifs ne passent pas par un signal dédié pour l'instant).
func on_flag_set(_key: String) -> void:
	reposition_all(true)

# --- Persistance ---

func serialize() -> Dictionary:
	return {"overrides": _overrides.duplicate(true)}

func deserialize(data: Dictionary) -> void:
	_overrides = data.get("overrides", {}).duplicate(true) if data.get("overrides") != null else {}
