extends NPC

# Don Salvatore : boss de São Paulo qui débarque à Santos Dumont.
# Apparaît dans le district SantosDumont uniquement quand la quête de pickup est active.
# Sa première interaction complète l'objectif "meet_at_airport". Après cette
# rencontre, il suit physiquement le joueur (cross-district : Santos Dumont →
# Copacabana) jusqu'au consortium pour la livraison.

const QUEST: String = "consortium_airport_pickup"
const OBJ_MEET: String = "meet_at_airport"
const OBJ_DELIVER: String = "deliver_to_consortium"

func _ready() -> void:
	super._ready()
	EventBus.quest_accepted.connect(_on_quest_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.quest_failed.connect(_on_quest_event)
	_sync_follow_state()

func _on_quest_event(_quest_id: String) -> void:
	_sync_follow_state()

func _on_quest_updated(_quest_id: String, _objective_id: String) -> void:
	_sync_follow_state()

func _sync_follow_state() -> void:
	# Suit uniquement entre la rencontre à l'aéroport et la livraison au consortium.
	if not QuestManager.is_active(QUEST):
		stop_following()
		return
	var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
	var met: bool = objs.get(OBJ_MEET, false)
	var delivered: bool = objs.get(OBJ_DELIVER, false)
	if met and not delivered:
		start_following()
	else:
		stop_following()

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot  # salvatore_intro (par défaut)
	if QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objs.get(OBJ_MEET, false):
			knot = "salvatore_arrival"
		elif not objs.get(OBJ_DELIVER, false):
			knot = "salvatore_waiting"
		else:
			knot = "salvatore_intro"
	elif QuestManager.is_completed(QUEST):
		knot = "salvatore_done"
	DialogueBridge.start_dialogue(data.id, knot)
