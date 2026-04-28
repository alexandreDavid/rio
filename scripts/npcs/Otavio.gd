extends NPC

# Otávio, chef-valet du Copa Palace.
# Quête valet_palace au premier contact. Une fois bouclée, les shifts sont lancés
# directement depuis le ValetStation (prop dédié), Otávio reste un point d'accueil.

const QUEST: String = "valet_palace"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # otavio_intro
	if QuestManager.is_completed(QUEST):
		knot = "otavio_done"
	elif QuestManager.is_active(QUEST):
		knot = "otavio_remind"
	DialogueBridge.start_dialogue(data.id, knot)
