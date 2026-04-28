extends NPC

# Beatriz : vendeuse de Rio Style.
# Acte 1 : reçoit le bouquet de Jorge.
# Acte 2 : signe la pétition de l'orfanato si demandée.

const QUEST: String = "flowers_for_beatriz"
const OBJ: String = "deliver_flowers"
const ORFANATO: String = "act2_padre_orfanato"
const ORFANATO_OBJ: String = "signed_beatriz"
const AUDIENCIA: String = "act4_prefeito_audiencia"
const AUDIENCIA_OBJ: String = "heard_beatriz"
const TRIBUTO: String = "act4_trafico_tributo"
const TRIBUTO_OBJ: String = "tribute_beatriz"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # "vendeuse_intro"
	# Acte 4 priorité.
	if QuestManager.is_active(AUDIENCIA):
		var aud: Dictionary = QuestManager.get_objectives_state(AUDIENCIA)
		if not aud.get(AUDIENCIA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "beatriz_act4_audiencia")
			return
	if QuestManager.is_active(TRIBUTO):
		var trib: Dictionary = QuestManager.get_objectives_state(TRIBUTO)
		if not trib.get(TRIBUTO_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "beatriz_act4_tributo")
			return
	if QuestManager.is_active(ORFANATO):
		var orf: Dictionary = QuestManager.get_objectives_state(ORFANATO)
		if not orf.get(ORFANATO_OBJ, false):
			knot = "beatriz_act2_petition"
			DialogueBridge.start_dialogue(data.id, knot)
			return
	if QuestManager.is_active(QUEST):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objectives.get(OBJ, false):
			knot = "beatriz_receives_flowers"
	DialogueBridge.start_dialogue(data.id, knot)
