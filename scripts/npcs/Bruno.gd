extends NPC

# Bruno : vieux capitaine du ferry Rio↔Niterói. Donneur de la SIDE
# "bruno_carga" — un colis pour Helena au MAC. Quête remontée par le
# joueur en deux interactions : accept ici, livre chez Helena.

const QUEST_ID: String = "bruno_carga"
const OBJ_DELIVER: String = "deliver_to_helena"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier(data.id, "bruno_default",
			"bruno_chat_warm", "bruno_chat_familiar")
	if QuestManager.is_completed(QUEST_ID):
		knot = "bruno_after_carga"
	elif QuestManager.is_active(QUEST_ID):
		knot = "bruno_remind"
	elif QuestManager.is_available(QUEST_ID):
		knot = "bruno_offer"
	DialogueBridge.start_dialogue(data.id, knot)
