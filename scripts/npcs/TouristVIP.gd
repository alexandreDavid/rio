extends NPC

# Touriste VIP au Copacabana Palace.
# Reçoit le rapport de police (quête police_report, narrativement c'est Madame Dubois).
# Propose aussi un tour guidé multi-districts (quête tourist_vip_tour).

const QUEST_REPORT: String = "police_report"
const OBJ_REPORT: String = "deliver_report"
const QUEST_TOUR: String = "tourist_vip_tour"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
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
