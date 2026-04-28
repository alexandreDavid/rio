extends NPC

const QUEST: String = "ze_invitation"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST):
		knot = "ze_done"
	elif QuestManager.is_active(QUEST):
		knot = "ze_remind"
	DialogueBridge.start_dialogue(data.id, knot)
