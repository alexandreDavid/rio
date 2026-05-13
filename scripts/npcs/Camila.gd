extends NPC

# Camila : volleyeuse à Ipanema. Propose un match volley sur le sable.
# Quête complétée quand le joueur gagne le match (cf. VolleyLauncher).

const QUEST_ID: String = "camila_ipanema_volley"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST_ID):
		knot = "camila_done"
	elif QuestManager.is_active(QUEST_ID):
		knot = "camila_remind"
	elif QuestManager.is_available(QUEST_ID):
		knot = "camila_offer"
	DialogueBridge.start_dialogue(data.id, knot)
