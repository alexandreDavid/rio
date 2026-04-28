extends NPC

const QUEST: String = "livraison_cocos"
const TRIBUTO: String = "act4_trafico_tributo"
const TRIBUTO_OBJ: String = "tribute_chef"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_active(TRIBUTO):
		var trib: Dictionary = QuestManager.get_objectives_state(TRIBUTO)
		if not trib.get(TRIBUTO_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "chef_act4_tributo")
			return
	if QuestManager.is_completed(QUEST):
		knot = "chef_done"
	elif QuestManager.is_active(QUEST):
		knot = "chef_remind"
	DialogueBridge.start_dialogue(data.id, knot)
