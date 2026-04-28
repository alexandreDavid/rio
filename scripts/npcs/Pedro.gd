extends NPC

# Seu Pedro le pêcheur : recherche de Tito (acte 1) puis témoin du trafic en mer (acte 2).
# Side quest aquatique : tour des Cagarras en stand-up paddle (après pedros_son).

const QUEST_SON: String = "pedros_son"
const QUEST_SECRET: String = "act2_pecheur_secret"
const QUEST_SUP: String = "pedro_cagarras_sup"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	# Side quest SUP — gating : disponible après l'aide à la famille (pedros_son).
	if QuestManager.is_active(QUEST_SUP):
		knot = "pecheur_cagarras_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST_SUP):
		knot = "pecheur_cagarras_done"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_available(QUEST_SUP) and QuestManager.is_completed(QUEST_SON):
		knot = "pecheur_cagarras_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_active(QUEST_SECRET):
		knot = "pecheur_act2_remind"
	elif QuestManager.is_completed(QUEST_SECRET):
		knot = "pecheur_act2_done"
	elif QuestManager.is_available(QUEST_SECRET):
		knot = "pecheur_act2_offer"
	elif QuestManager.is_completed(QUEST_SON):
		knot = "pecheur_thanks"
	elif QuestManager.is_active(QUEST_SON):
		knot = "pecheur_remind"
	DialogueBridge.start_dialogue(data.id, knot)
