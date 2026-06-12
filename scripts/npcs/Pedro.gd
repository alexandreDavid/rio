extends NPC

# Seu Pedro le pêcheur : recherche de Tito (acte 1) puis témoin du trafic en mer (acte 2).

const QUEST_SON: String = "pedros_son"
const QUEST_SECRET: String = "act2_pecheur_secret"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	# Fallback : phase de la journée si aucun état narratif ne capture.
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"", "",
			"pecheur_chat_morning", "pecheur_chat_afternoon", "pecheur_chat_evening")
	if QuestManager.is_active(QUEST_SECRET):
		# Tant que le joueur n'a pas vu les canots depuis la mureta (Botafogo),
		# Pedro renvoie à l'observation ; après, on choisit à qui parler.
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_SECRET)
		knot = "pecheur_act2_choose" if objs.get("observe_canots", false) else "pecheur_act2_remind"
	elif QuestManager.is_completed(QUEST_SECRET):
		knot = "pecheur_act2_done"
	elif QuestManager.is_available(QUEST_SECRET):
		knot = "pecheur_act2_offer"
	elif QuestManager.is_completed(QUEST_SON):
		knot = "pecheur_thanks"
	elif QuestManager.is_active(QUEST_SON):
		knot = "pecheur_remind"
	DialogueBridge.start_dialogue(data.id, knot)
