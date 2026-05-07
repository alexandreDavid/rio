extends NPC

# Touriste VIP au Copacabana Palace.
# Reçoit le rapport de police (quête police_report, narrativement c'est Madame Dubois).
# Propose aussi un tour guidé multi-districts (quête tourist_vip_tour) ; pendant
# ce tour il suit physiquement le joueur, y compris au taxi (cross-district).

const QUEST_REPORT: String = "police_report"
const OBJ_REPORT: String = "deliver_report"
const QUEST_TOUR: String = "tourist_vip_tour"

func _ready() -> void:
	super._ready()
	EventBus.quest_accepted.connect(_on_quest_event)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.quest_failed.connect(_on_quest_event)
	_sync_follow_state()

func _on_quest_event(_quest_id: String) -> void:
	_sync_follow_state()

func _sync_follow_state() -> void:
	if QuestManager.is_active(QUEST_TOUR):
		start_following()
	else:
		stop_following()

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot
	# Priorité : recevoir le rapport de police s'il est en attente.
	if QuestManager.is_active(QUEST_REPORT):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST_REPORT)
		if not objectives.get(OBJ_REPORT, false):
			DialogueBridge.start_dialogue(data.id, "dubois_receives_report")
			return
	# Tour guidé : offrir / rappeler / remercier.
	if QuestManager.is_active(QUEST_TOUR):
		knot = "tourist_vip_tour_remind"
	elif QuestManager.is_completed(QUEST_TOUR):
		knot = "tourist_vip_tour_done"
	elif QuestManager.is_available(QUEST_TOUR):
		knot = "tourist_vip_tour_offer"
	DialogueBridge.start_dialogue(data.id, knot)
