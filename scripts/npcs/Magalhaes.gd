extends NPC

# Sr. Magalhães : gérant du condomínio Riserva Uno (Barra da Tijuca).
# Cible de la mission consortium_barra_security : le joueur l'intimide une fois
# (obj 1 = intimidate_magalhaes), puis revient signer le contrat (obj 2 = close_deal).

const QUEST_ID: String = "consortium_barra_security"
const OBJ_INTIMIDATE: String = "intimidate_magalhaes"
const OBJ_CLOSE: String = "close_deal"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	if QuestManager.is_completed(QUEST_ID):
		knot = "magalhaes_after_deal"
	elif QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_CLOSE):
		knot = "magalhaes_close_deal"
	elif QuestManager.is_active(QUEST_ID) \
			and not QuestManager.is_objective_done(QUEST_ID, OBJ_INTIMIDATE):
		knot = "magalhaes_first_visit"
	else:
		knot = "magalhaes_default"
	DialogueBridge.start_dialogue(data.id, knot)
