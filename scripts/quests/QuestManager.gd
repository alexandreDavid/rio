extends Node

# Tracks quest state and objectives. Autoload name: QuestManager.

enum State { UNAVAILABLE, AVAILABLE, ACTIVE, COMPLETED, FAILED }

var _state: Dictionary = {}          # quest_id -> State(int)
var _objectives: Dictionary = {}     # quest_id -> { objective_id -> bool }
var _quests: Dictionary = {}         # quest_id -> Quest resource

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

func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id)

func get_objectives_state(quest_id: String) -> Dictionary:
	return _objectives.get(quest_id, {})

func get_active_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _state:
		if _state[id] == State.ACTIVE:
			out.append(id)
	return out

func accept(quest_id: String) -> bool:
	if get_state(quest_id) != State.AVAILABLE:
		return false
	if not meets_requirements(quest_id):
		return false
	_state[quest_id] = State.ACTIVE
	_objectives[quest_id] = {}
	var quest: Quest = _quests[quest_id]
	for obj in quest.objectives:
		_objectives[quest_id][obj.id] = false
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

func complete_objective(quest_id: String, objective_id: String) -> void:
	if get_state(quest_id) != State.ACTIVE:
		return
	if not _objectives[quest_id].has(objective_id):
		push_warning("QuestManager: unknown objective %s on %s" % [objective_id, quest_id])
		return
	_objectives[quest_id][objective_id] = true
	EventBus.quest_updated.emit(quest_id, objective_id)
	if _all_mandatory_done(quest_id):
		_complete(quest_id)

func fail(quest_id: String) -> void:
	if get_state(quest_id) != State.ACTIVE:
		return
	_state[quest_id] = State.FAILED
	EventBus.quest_failed.emit(quest_id)

func _all_mandatory_done(quest_id: String) -> bool:
	var quest: Quest = _quests[quest_id]
	for obj in quest.objectives:
		if obj.optional:
			continue
		if not _objectives[quest_id].get(obj.id, false):
			return false
	return true

func _complete(quest_id: String) -> void:
	_state[quest_id] = State.COMPLETED
	var quest: Quest = _quests[quest_id]
	if quest.money_reward != 0 and GameManager.player:
		var inv: Node = GameManager.player.get_node_or_null("Inventory")
		if inv:
			inv.add_money(quest.money_reward)
	for axis_key in quest.reputation_rewards:
		ReputationSystem.modify(axis_key, quest.reputation_rewards[axis_key])
	EventBus.quest_completed.emit(quest_id)

func serialize() -> Dictionary:
	return {"state": _state.duplicate(), "objectives": _objectives.duplicate(true)}

func deserialize(data: Dictionary) -> void:
	_state = data.get("state", {})
	_objectives = data.get("objectives", {})
