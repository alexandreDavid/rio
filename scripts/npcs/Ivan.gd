extends NPC

# Iván : barman discret au Bar do Pôr-do-Sol (Arpoador). Confirme le nom
# et complète l'objectif verify_with_ivan de zona_sul_envelope.

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
		knot = "ivan_after_done"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_VERIFY) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_RETURN):
		knot = "ivan_after_verified"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_VERIFY):
		knot = "ivan_verify"
	else:
		knot = "ivan_default"
	DialogueBridge.start_dialogue(data.id, knot)
