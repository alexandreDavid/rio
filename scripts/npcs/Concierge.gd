extends NPC

# Concierge du Copacabana Palace — SIDE find_bracelet_01 + accueil.
# La révélation « le concierge est tio Zé » passe désormais par les spots
# tio Zé des voies (trafico/policia/consortium/prefeito_tioze).

const QUEST_BRACELET: String = "find_bracelet_01"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot  # concierge_intro par défaut
	if QuestManager.is_completed(QUEST_BRACELET):
		knot = "concierge_done"
	elif QuestManager.is_active(QUEST_BRACELET):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST_BRACELET)
		if objectives.get("find_bracelet", false):
			knot = "concierge_return"
		else:
			knot = "concierge_remind"
	DialogueBridge.start_dialogue(data.id, knot)
