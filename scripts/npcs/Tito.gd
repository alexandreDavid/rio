extends NPC

# Tito gère deux états narratifs :
# - pedros_son : fils de Seu Pedro à ramener (priorité si active)
# - act1_meet_tito : faveur du Morro pour la voie Tráfico

const QUEST_PEDRO: String = "pedros_son"
const OBJ_PEDRO: String = "find_tito"
const QUEST_FAVOR: String = "act1_meet_tito"
const OBJ_FAVOR: String = "do_tito_favor"
const QUEST_PHARMA: String = "pharmacy_tito"
const OBJ_PHARMA: String = "deliver_medicine"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # "tito_playing" par défaut
	# Livraison du médicament en priorité si la quête est active et pas encore livrée.
	if QuestManager.is_active(QUEST_PHARMA):
		var objs_p: Dictionary = QuestManager.get_objectives_state(QUEST_PHARMA)
		if not objs_p.get(OBJ_PHARMA, false):
			DialogueBridge.start_dialogue(data.id, "tito_receives_medicine")
			return
	if QuestManager.is_active(QUEST_PEDRO):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST_PEDRO)
		if not objectives.get(OBJ_PEDRO, false):
			DialogueBridge.start_dialogue(data.id, "tito_encounter")
			return
	if QuestManager.is_completed(QUEST_FAVOR):
		knot = "tito_thanks"
	elif QuestManager.is_active(QUEST_FAVOR):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_FAVOR)
		if not objs.get(OBJ_FAVOR, false):
			knot = "tito_favor_ask"
	DialogueBridge.start_dialogue(data.id, knot)
