extends NPC

# Vendeuse de coco : si la quête de livraison est active, dialogue dédié.

const QUEST: String = "livraison_cocos"
const OBJ: String = "talk_lucia"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	if QuestManager.is_active(QUEST):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objectives.get(OBJ, false):
			knot = "lucia_to_chef"
	DialogueBridge.start_dialogue(data.id, knot)
