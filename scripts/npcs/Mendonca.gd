extends NPC

# Sr. Mendonça : président du Península Privé (Barra). Cible 3 de la chaîne
# de racket consortium. Le plus connecté — bodyguards, helipad, et un cousin
# commissaire qui va riposter. Signer enclenche `commissaire_alerted`.

const QUEST_ID: String = "consortium_peninsula"
const OBJ_INTIMIDATE: String = "intimidate_mendonca"
const OBJ_CLOSE: String = "close_deal_mendonca"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	if QuestManager.is_completed(QUEST_ID):
		knot = "mendonca_after_deal"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_CLOSE):
		knot = "mendonca_close_deal"
	elif QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE):
		knot = "mendonca_first_visit"
	else:
		knot = "mendonca_default"
	DialogueBridge.start_dialogue(data.id, knot)
