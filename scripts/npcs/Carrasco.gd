extends NPC

# Sr. Carrasco : gérant du Le Parc Residences (Barra). Cible 2 de la chaîne
# de racket consortium. Plus défiant que Magalhães — Magalhães l'a prévenu.

const QUEST_ID: String = "consortium_le_parc"
const OBJ_INTIMIDATE: String = "intimidate_carrasco"
const OBJ_CLOSE: String = "close_deal_carrasco"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	if QuestManager.is_completed(QUEST_ID):
		knot = "carrasco_after_deal"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_CLOSE):
		knot = "carrasco_close_deal"
	elif QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE):
		knot = "carrasco_first_visit"
	else:
		knot = "carrasco_default"
	DialogueBridge.start_dialogue(data.id, knot)
