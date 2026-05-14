extends NPC

# Helena : curatrice du MAC Niemeyer. Reçoit le colis livré par Bruno
# (SIDE bruno_carga). Sinon dialogue d'ambiance par défaut.

const QUEST_ID: String = "bruno_carga"
const OBJ_DELIVER: String = "deliver_to_helena"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, "helena_default",
			"helena_chat_warm", "helena_chat_familiar",
			"helena_chat_morning", "helena_chat_afternoon", "helena_chat_evening")
	if QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER):
		knot = "helena_receive_carga"
	elif QuestManager.is_completed(QUEST_ID):
		knot = "helena_after_carga"
	DialogueBridge.start_dialogue(data.id, knot)
