extends NPC

# Mestre Diego : capoeirista de la praia de Botafogo. Performance flash en
# échange d'un tip. Quête complétée via dialog (pay_bribe + finish_quest dans
# le knot diego_offer).

const QUEST_ID: String = "diego_botafogo_capoeira"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST_ID):
		knot = "diego_done"
	elif QuestManager.is_active(QUEST_ID):
		knot = "diego_offer"
	elif QuestManager.is_available(QUEST_ID):
		knot = "diego_intro"
	DialogueBridge.start_dialogue(data.id, knot)
