extends Node

# Tracks quest state and objectives. Autoload name: QuestManager.

enum State { UNAVAILABLE, AVAILABLE, ACTIVE, COMPLETED, FAILED }

var _state: Dictionary = {}          # quest_id -> State(int)
var _objectives: Dictionary = {}     # quest_id -> { objective_id -> bool }
var _quests: Dictionary = {}         # quest_id -> Quest resource
# Objectifs CHRONO en cours : quest_id -> { objective_id -> secondes restantes }.
# Tickés en _process ; expiration = échec de la quête (le client n'attend pas).
var _chronos: Dictionary = {}

func _ready() -> void:
	EventBus.minigame_ended.connect(_on_minigame_ended)
	EventBus.chase_ended.connect(_on_chase_ended)

func _process(delta: float) -> void:
	if _chronos.is_empty():
		return
	for quest_id in _chronos.keys():
		var per_obj: Dictionary = _chronos[quest_id]
		for objective_id in per_obj.keys():
			per_obj[objective_id] = float(per_obj[objective_id]) - delta
			var left: float = float(per_obj[objective_id])
			var quest: Quest = _quests.get(quest_id)
			var label: String = quest.display_name if quest else quest_id
			EventBus.chrono_updated.emit("quest:%s" % quest_id, label, max(left, 0.0))
			if left <= 0.0:
				EventBus.notification_requested.emit(
					"⏱ Trop tard — %s a échoué. Retourne voir qui te l'a confiée." % label,
					Color(0.95, 0.45, 0.4, 1))
				fail(quest_id)
				return

# --- Complétion mécanique (objectifs typés) ---

func _on_minigame_ended(minigame_id: String, result: Dictionary) -> void:
	var ok: bool = bool(result.get("qualifies", result.get("won", false)))
	if not ok:
		return
	_auto_complete_matching(func(obj: QuestObjective) -> bool:
		return obj.kind == QuestObjective.Kind.MINIJEU and obj.minigame_id == minigame_id)

func _on_chase_ended(chaser_id: String, escaped: bool) -> void:
	if not escaped:
		return
	_auto_complete_matching(func(obj: QuestObjective) -> bool:
		return obj.kind == QuestObjective.Kind.FUITE \
			and (obj.chaser_id == "" or obj.chaser_id == chaser_id))

func _auto_complete_matching(predicate: Callable) -> void:
	for quest_id in get_active_ids():
		var quest: Quest = _quests[quest_id]
		for obj in quest.objectives:
			if not is_objective_done(quest_id, obj.id) and predicate.call(obj):
				complete_objective(quest_id, obj.id)

func register_quest(quest: Quest) -> void:
	if quest.id == "":
		push_error("QuestManager: quest has empty id")
		return
	_quests[quest.id] = quest
	if not _state.has(quest.id):
		_state[quest.id] = State.AVAILABLE

func get_state(quest_id: String) -> int:
	return _state.get(quest_id, State.UNAVAILABLE)

func is_active(quest_id: String) -> bool:
	return get_state(quest_id) == State.ACTIVE

func is_completed(quest_id: String) -> bool:
	return get_state(quest_id) == State.COMPLETED

func is_failed(quest_id: String) -> bool:
	return get_state(quest_id) == State.FAILED

func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id)

func get_objectives_state(quest_id: String) -> Dictionary:
	return _objectives.get(quest_id, {})

func is_objective_done(quest_id: String, objective_id: String) -> bool:
	return bool(_objectives.get(quest_id, {}).get(objective_id, false))

func get_active_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _state:
		if _state[id] == State.ACTIVE:
			out.append(id)
	return out

func accept(quest_id: String) -> bool:
	# FAILED est ré-acceptable : une quête échouée (chrono expiré…) se relance
	# depuis son donneur — même philosophie que les poursuites/filatures ratées.
	if get_state(quest_id) != State.AVAILABLE and get_state(quest_id) != State.FAILED:
		return false
	if not meets_requirements(quest_id):
		return false
	_state[quest_id] = State.ACTIVE
	_objectives[quest_id] = {}
	var quest: Quest = _quests[quest_id]
	for obj in quest.objectives:
		_objectives[quest_id][obj.id] = false
		if obj.kind == QuestObjective.Kind.CHRONO and obj.time_limit_sec > 0.0:
			if not _chronos.has(quest_id):
				_chronos[quest_id] = {}
			_chronos[quest_id][obj.id] = obj.time_limit_sec
	EventBus.quest_accepted.emit(quest_id)
	return true

func meets_requirements(quest_id: String) -> bool:
	var quest: Quest = _quests.get(quest_id)
	if quest == null:
		return false
	if quest.required_act > 0 and CampaignManager.current_act < quest.required_act:
		return false
	for axis_key in quest.required_reputation:
		var threshold: int = quest.required_reputation[axis_key]
		if ReputationSystem.get_value(int(axis_key)) < threshold:
			return false
	for prereq_id in quest.prerequisite_quest_ids:
		if not is_completed(prereq_id):
			return false
	return true

# Une quête principale (MAIN) est-elle complétée ? Pratique pour CampaignManager.
func is_main_quest_completed(quest_id: String) -> bool:
	var quest: Quest = _quests.get(quest_id)
	if quest == null:
		return false
	if quest.quest_type != Quest.QuestType.MAIN:
		return false
	return is_completed(quest_id)

# Liste les prérequis encore non complétés pour quest_id. Utilisé par DialogueBridge
# pour expliquer pourquoi une acceptation a échoué et pour les outils de debug.
func missing_prerequisites(quest_id: String) -> Array[String]:
	var out: Array[String] = []
	var quest: Quest = _quests.get(quest_id)
	if quest == null:
		return out
	for prereq_id in quest.prerequisite_quest_ids:
		if not is_completed(prereq_id):
			out.append(prereq_id)
	return out

func is_available(quest_id: String) -> bool:
	return get_state(quest_id) == State.AVAILABLE and meets_requirements(quest_id)

# Seuils de réputation encore non atteints pour quest_id. Chaque entrée :
# {axis, threshold, current}. Sert à expliquer un lock côté dialogue/UI.
func missing_reputation(quest_id: String) -> Array:
	var out: Array = []
	var quest: Quest = _quests.get(quest_id)
	if quest == null:
		return out
	for axis_key in quest.required_reputation:
		var axis: int = int(axis_key)
		var threshold: int = int(quest.required_reputation[axis_key])
		var current: int = ReputationSystem.get_value(axis)
		if current < threshold:
			out.append({"axis": axis, "threshold": threshold, "current": current})
	return out

func complete_objective(quest_id: String, objective_id: String, auto_pay_reward: bool = true) -> void:
	# `auto_pay_reward` = true par défaut : la complétion finale paie automatiquement
	# le `money_reward` de la quête. Les appelants qui ont déjà versé le payout via
	# leur propre canal (DialogueBridge avec `finish_quest.payout`) passent false
	# pour éviter le double paiement.
	if get_state(quest_id) != State.ACTIVE:
		return
	if not _objectives[quest_id].has(objective_id):
		push_warning("QuestManager: unknown objective %s on %s" % [objective_id, quest_id])
		return
	_objectives[quest_id][objective_id] = true
	if _chronos.has(quest_id):
		_chronos[quest_id].erase(objective_id)
		if _chronos[quest_id].is_empty():
			_clear_chronos(quest_id)
	EventBus.quest_updated.emit(quest_id, objective_id)
	if _all_mandatory_done(quest_id):
		_complete(quest_id, auto_pay_reward)

func fail(quest_id: String) -> void:
	if get_state(quest_id) != State.ACTIVE:
		return
	_clear_chronos(quest_id)
	_state[quest_id] = State.FAILED
	EventBus.quest_failed.emit(quest_id)

func _clear_chronos(quest_id: String) -> void:
	if _chronos.erase(quest_id):
		EventBus.chrono_cleared.emit("quest:%s" % quest_id)

func _all_mandatory_done(quest_id: String) -> bool:
	var quest: Quest = _quests[quest_id]
	for obj in quest.objectives:
		if obj.optional:
			continue
		if not _objectives[quest_id].get(obj.id, false):
			return false
	return true

func _complete(quest_id: String, auto_pay_reward: bool = true) -> void:
	_clear_chronos(quest_id)
	_state[quest_id] = State.COMPLETED
	var quest: Quest = _quests[quest_id]
	if auto_pay_reward and quest.money_reward != 0 and GameManager.player:
		var inv: Node = GameManager.player.get_node_or_null("Inventory")
		if inv:
			inv.add_money(quest.money_reward)
	for axis_key in quest.reputation_rewards:
		ReputationSystem.modify(axis_key, quest.reputation_rewards[axis_key])
	EventBus.quest_completed.emit(quest_id)

func serialize() -> Dictionary:
	return {
		"state": _state.duplicate(),
		"objectives": _objectives.duplicate(true),
		"chronos": _chronos.duplicate(true),
	}

func deserialize(data: Dictionary) -> void:
	# Tolérance aux quêtes disparues : une save peut référencer un quest_id
	# retiré depuis (refactor de contenu). On écarte ces entrées plutôt que de
	# garder un état orphelin (que _complete() déréférencerait via _quests[id]).
	# Les quêtes sont toutes enregistrées au boot avant ce load, donc _quests
	# est complet ici.
	_state = _keep_known(data.get("state", {}))
	_objectives = _keep_known(data.get("objectives", {}))
	_chronos = _keep_known(data.get("chronos", {}))

func _keep_known(saved: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	var dropped: int = 0
	for quest_id in saved:
		if _quests.has(quest_id):
			kept[quest_id] = saved[quest_id]
		else:
			dropped += 1
	if dropped > 0:
		push_warning("QuestManager: %d quête(s) inconnue(s) ignorée(s) au chargement" % dropped)
	return kept
