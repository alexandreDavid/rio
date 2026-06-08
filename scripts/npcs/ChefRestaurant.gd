extends NPC

const QUEST: String = "livraison_cocos"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST):
		knot = "chef_done"
	elif QuestManager.is_active(QUEST):
		knot = "chef_remind"
	DialogueBridge.start_dialogue(data.id, knot)
