extends NPC

const QUEST: String = "police_report"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST):
		knot = "policier_done"
	elif QuestManager.is_active(QUEST):
		knot = "policier_remind"
	DialogueBridge.start_dialogue(data.id, knot)
