extends NPC

# Concierge du Copacabana Palace.
# Acte 1 : quête find_bracelet_01 + dialogues d'accueil.
# Acte 2 : tombe le masque, c'est tio Zé. Une fois la quête act2_intro terminée,
# le flag tio_ze_revealed le fait disparaître via NPCScheduler.

const QUEST_BRACELET: String = "find_bracelet_01"
const QUEST_ACT2: String = "act2_intro"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot  # concierge_intro par défaut
	# Acte 2 : la révélation prime sur tout le reste.
	if QuestManager.is_active(QUEST_ACT2):
		knot = "concierge_act2_reveal"
	elif QuestManager.is_completed(QUEST_BRACELET):
		knot = "concierge_done"
	elif QuestManager.is_active(QUEST_BRACELET):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST_BRACELET)
		if objectives.get("find_bracelet", false):
			knot = "concierge_return"
		else:
			knot = "concierge_remind"
	DialogueBridge.start_dialogue(data.id, knot)
