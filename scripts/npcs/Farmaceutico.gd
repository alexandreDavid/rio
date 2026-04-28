extends NPC

# Dona Carmen : pharmacienne. Médicament pour Tito (acte 1) puis pétition orfanato (acte 2).

const QUEST: String = "pharmacy_tito"
const OBJ_PICKUP: String = "receive_medicine"
const OBJ_DELIVER: String = "deliver_medicine"
const ORFANATO: String = "act2_padre_orfanato"
const ORFANATO_OBJ: String = "signed_carmen"
const AUDIENCIA: String = "act4_prefeito_audiencia"
const AUDIENCIA_OBJ: String = "heard_carmen"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # farma_intro
	if QuestManager.is_active(AUDIENCIA):
		var aud: Dictionary = QuestManager.get_objectives_state(AUDIENCIA)
		if not aud.get(AUDIENCIA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "carmen_act4_audiencia")
			return
	if QuestManager.is_active(ORFANATO):
		var orf: Dictionary = QuestManager.get_objectives_state(ORFANATO)
		if not orf.get(ORFANATO_OBJ, false):
			knot = "carmen_act2_petition"
			DialogueBridge.start_dialogue(data.id, knot)
			return
	if QuestManager.is_completed(QUEST):
		knot = "farma_thanks"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if objs.get(OBJ_DELIVER, false):
			knot = "farma_reward"
		else:
			knot = "farma_remind"
	DialogueBridge.start_dialogue(data.id, knot)
