extends NPC

# Yara : étudiante en arts plastiques au MAC. Pas de quête — sa parole donne
# du grain au district, varie selon l'heure (TimeOfDay).

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"", "",
			"yara_chat_morning", "yara_chat_afternoon", "yara_chat_evening")
	DialogueBridge.start_dialogue(data.id, knot)
