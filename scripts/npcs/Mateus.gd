extends NPC

# Mateus : pêcheur des Cagarras. Concours de pêche en haute mer.
# Quête complétée quand le joueur termine une session pêche réussie
# (cf. FishingLauncher hook pour mateus_cagarras_pesca).

const QUEST_ID: String = "mateus_cagarras_pesca"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST_ID):
		knot = "mateus_done"
	elif QuestManager.is_active(QUEST_ID):
		knot = "mateus_remind"
	elif QuestManager.is_available(QUEST_ID):
		knot = "mateus_offer"
	DialogueBridge.start_dialogue(data.id, knot)
