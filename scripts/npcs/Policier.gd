extends NPC

const QUEST: String = "police_report"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	# Fallback : phase de la journée si aucune quête active.
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"", "",
			"policier_chat_morning", "policier_chat_afternoon", "policier_chat_evening")
	if QuestManager.is_completed(QUEST):
		knot = "policier_done"
	elif QuestManager.is_active(QUEST):
		knot = "policier_remind"
	DialogueBridge.start_dialogue(data.id, knot)
