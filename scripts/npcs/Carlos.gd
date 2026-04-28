extends NPC

# Carlos : café ISSIMO + livraisons vélo.
# Acte 2 : signe la pétition de l'orfanato si demandée.

const QUEST: String = "bike_delivery"
const OBJ: String = "one_delivery"
const ORFANATO: String = "act2_padre_orfanato"
const ORFANATO_OBJ: String = "signed_carlos"
const GALA: String = "act2_contessa_gala"
const GALA_OBJ: String = "secured_sponsor"
const AUDIENCIA: String = "act4_prefeito_audiencia"
const AUDIENCIA_OBJ: String = "heard_carlos"
const TRIBUTO: String = "act4_trafico_tributo"
const TRIBUTO_OBJ: String = "tribute_carlos"
const LAGOA: String = "carlos_lagoa_volta"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # carlos_intro
	# Acte 4 priorité : doléance (Prefeito) ou tribut (Tráfico).
	if QuestManager.is_active(AUDIENCIA):
		var aud: Dictionary = QuestManager.get_objectives_state(AUDIENCIA)
		if not aud.get(AUDIENCIA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "carlos_act4_audiencia")
			return
	if QuestManager.is_active(TRIBUTO):
		var trib: Dictionary = QuestManager.get_objectives_state(TRIBUTO)
		if not trib.get(TRIBUTO_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "carlos_act4_tributo")
			return
	if QuestManager.is_active(GALA):
		var gala_state: Dictionary = QuestManager.get_objectives_state(GALA)
		if not gala_state.get(GALA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "carlos_act2_gala")
			return
	if QuestManager.is_active(ORFANATO):
		var orf: Dictionary = QuestManager.get_objectives_state(ORFANATO)
		if not orf.get(ORFANATO_OBJ, false):
			knot = "carlos_act2_petition"
			DialogueBridge.start_dialogue(data.id, knot)
			return
	# Side quest : tour de la Lagoa (après une livraison vélo).
	if QuestManager.is_active(LAGOA):
		knot = "carlos_lagoa_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	elif QuestManager.is_available(LAGOA) and QuestManager.is_completed(QUEST):
		knot = "carlos_lagoa_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST):
		knot = "carlos_thanks"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		knot = "carlos_remind" if not objs.get(OBJ, false) else "carlos_thanks"
	DialogueBridge.start_dialogue(data.id, knot)
