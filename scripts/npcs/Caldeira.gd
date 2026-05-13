extends NPC

# Sra. Caldeira : veuve riche dans sa cobertura de Leblon. Donne et clôt
# la quête zona_sul_envelope (porteur d'enveloppe discrète).

const QUEST_ID: String = "zona_sul_envelope"
const OBJ_DELIVER: String = "deliver_to_bandeira"
const OBJ_VERIFY: String = "verify_with_ivan"
const OBJ_RETURN: String = "return_to_caldeira"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	if QuestManager.is_completed(QUEST_ID):
		knot = "caldeira_after_done"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_VERIFY) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_RETURN):
		knot = "caldeira_return"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_VERIFY):
		knot = "caldeira_remind_verify"
	elif QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER):
		knot = "caldeira_remind_deliver"
	elif not QuestManager.is_active(QUEST_ID) and not QuestManager.is_completed(QUEST_ID):
		knot = "caldeira_offer"
	else:
		knot = "caldeira_offer"
	DialogueBridge.start_dialogue(data.id, knot)
