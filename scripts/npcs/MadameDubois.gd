extends NPC

# Madame Dubois : dialogue standard par défaut. Si la quête du rapport de police
# est active et que l'objectif n'est pas encore coché, elle reçoit le rapport.

const QUEST: String = "police_report"
const OBJ: String = "deliver_report"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_active(QUEST):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objectives.get(OBJ, false):
			knot = "dubois_receives_report"
	DialogueBridge.start_dialogue(data.id, knot)
