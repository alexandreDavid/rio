extends NPC

# Dr. Bandeira : avocat à Ipanema. Reçoit l'enveloppe de Caldeira et donne
# le mot de passe pour Iván — étape intermédiaire de zona_sul_envelope.

const QUEST_ID: String = "zona_sul_envelope"
const OBJ_DELIVER: String = "deliver_to_bandeira"
const OBJ_VERIFY: String = "verify_with_ivan"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	if QuestManager.is_completed(QUEST_ID):
		knot = "bandeira_after_done"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_VERIFY):
		knot = "bandeira_after_received"
	elif QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_DELIVER):
		knot = "bandeira_receive"
	else:
		knot = "bandeira_default"
	DialogueBridge.start_dialogue(data.id, knot)
