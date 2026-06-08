extends NPC

# Beatriz : vendeuse de Rio Style. SIDE : reçoit le bouquet de Jorge.

const QUEST: String = "flowers_for_beatriz"
const OBJ: String = "deliver_flowers"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # "vendeuse_intro"
	if QuestManager.is_active(QUEST):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objectives.get(OBJ, false):
			knot = "beatriz_receives_flowers"
	DialogueBridge.start_dialogue(data.id, knot)
