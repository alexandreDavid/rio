extends NPC

# Carlos : café ISSIMO + livraisons vélo (SIDE). Conserve aussi le gala SIDE
# de la Contessa et le tour de la Lagoa.

const QUEST: String = "bike_delivery"
const OBJ: String = "one_delivery"
const GALA: String = "act2_contessa_gala"
const GALA_OBJ: String = "secured_sponsor"
const LAGOA: String = "carlos_lagoa_volta"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"carlos_chat_warm", "carlos_chat_familiar",
			"carlos_chat_morning", "carlos_chat_afternoon", "carlos_chat_evening")
	if QuestManager.is_active(GALA):
		var gala_state: Dictionary = QuestManager.get_objectives_state(GALA)
		if not gala_state.get(GALA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "carlos_act2_gala")
			return
	# Side quest : tour de la Lagoa (après une livraison vélo).
	if QuestManager.is_active(LAGOA):
		DialogueBridge.start_dialogue(data.id, "carlos_lagoa_remind")
		return
	elif QuestManager.is_available(LAGOA) and QuestManager.is_completed(QUEST):
		DialogueBridge.start_dialogue(data.id, "carlos_lagoa_offer")
		return
	if QuestManager.is_completed(QUEST):
		knot = "carlos_thanks"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		knot = "carlos_remind" if not objs.get(OBJ, false) else "carlos_thanks"
	DialogueBridge.start_dialogue(data.id, knot)
