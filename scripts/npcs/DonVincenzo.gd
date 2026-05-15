extends NPC

# Don Vincenzo "O Padrinho" : parrain de la Mafia da Baía, opère depuis le
# Café da Praça à Niterói. Donneur de la chaîne SIDE :
#   baia_smuggle_intro → baia_silence_press → baia_pacto

const QUEST_SMUGGLE: String = "baia_smuggle_intro"
const QUEST_SILENCE: String = "baia_silence_press"
const QUEST_PACTO: String = "baia_pacto"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	DialogueBridge.start_dialogue(data.id, _pick_knot())

func _pick_knot() -> String:
	# Pacto final — terminé : satisfaction tranquille.
	if QuestManager.is_completed(QUEST_PACTO):
		return "vincenzo_after_pacto"
	if QuestManager.is_active(QUEST_PACTO):
		return "vincenzo_pacto_seal"
	if QuestManager.is_available(QUEST_PACTO):
		return "vincenzo_pacto_offer"
	# Silence du journaliste.
	if QuestManager.is_completed(QUEST_SILENCE):
		return "vincenzo_silence_done"
	if QuestManager.is_active(QUEST_SILENCE):
		return "vincenzo_silence_remind"
	if QuestManager.is_available(QUEST_SILENCE):
		return "vincenzo_silence_offer"
	# Premier passage.
	if QuestManager.is_completed(QUEST_SMUGGLE):
		return "vincenzo_smuggle_done"
	if QuestManager.is_active(QUEST_SMUGGLE):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_SMUGGLE)
		if objs.get("pickup_packet", false) and not objs.get("deliver_packet", false):
			return "vincenzo_smuggle_deliver"
		return "vincenzo_smuggle_remind"
	if QuestManager.is_available(QUEST_SMUGGLE):
		return "vincenzo_smuggle_offer"
	return "vincenzo_default"
