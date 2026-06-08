extends NPC

# Dona Carmen : pharmacienne. SIDE : médicament pour Tito.

const QUEST: String = "pharmacy_tito"
const OBJ_DELIVER: String = "deliver_medicine"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # farma_intro
	if QuestManager.is_completed(QUEST):
		knot = "farma_thanks"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if objs.get(OBJ_DELIVER, false):
			knot = "farma_reward"
		else:
			knot = "farma_remind"
	DialogueBridge.start_dialogue(data.id, knot)
