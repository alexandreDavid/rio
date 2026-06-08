extends NPC

# Seu Tonio, padeiro de la Padaria São Sebastião.
# Vente courante + livraison à Dona Irene + minijeu de fournée (SIDE).

const QUEST: String = "padaria_delivery"
const QUEST_BAKING: String = "padaria_baking"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"padaria_chat_warm", "padaria_chat_familiar",
			"padaria_chat_morning", "padaria_chat_afternoon", "padaria_chat_evening")
	if QuestManager.is_active(QUEST):
		knot = "padaria_remind"
	elif QuestManager.is_active(QUEST_BAKING):
		knot = "padaria_baking_remind"
	elif QuestManager.is_completed(QUEST_BAKING):
		knot = "padaria_intro"
	elif QuestManager.is_available(QUEST_BAKING) and QuestManager.is_completed(QUEST):
		knot = "padaria_baking_offer"
	DialogueBridge.start_dialogue(data.id, knot)
