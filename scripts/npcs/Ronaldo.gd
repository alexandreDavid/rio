extends NPC

# Ronaldo le musicien : invitation chez Zé (acte 1), DJ au Pão de Açúcar,
# torcida au Maracanã, cachet pour le gala (acte 2).

const QUEST: String = "ze_invitation"
const OBJ: String = "tell_ronaldo"
const QUEST_GALA: String = "act2_contessa_gala"
const GALA_OBJ: String = "secured_band"
const QUEST_DJ: String = "ronaldo_dj_paoacucar"
const QUEST_TORCIDA: String = "ronaldo_maracana_torcida"
const QUEST_BASKET: String = "ronaldo_aterro_basket"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	# Acte 2 : gala (priorité haute si la quête est active).
	if QuestManager.is_active(QUEST_GALA):
		var orf: Dictionary = QuestManager.get_objectives_state(QUEST_GALA)
		if not orf.get(GALA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "ronaldo_act2_gala")
			return
	# Side quest : basket à l'Aterro do Flamengo (priorité haute si active, dispo après la torcida).
	if QuestManager.is_active(QUEST_BASKET):
		knot = "ronaldo_basket_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST_BASKET):
		knot = "ronaldo_basket_done"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_available(QUEST_BASKET) and QuestManager.is_completed(QUEST_TORCIDA):
		knot = "ronaldo_basket_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Side quest : torcida au Maracanã (priorité après le gala). Dispo après le DJ.
	if QuestManager.is_active(QUEST_TORCIDA):
		knot = "ronaldo_torcida_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST_TORCIDA):
		knot = "ronaldo_torcida_done"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_available(QUEST_TORCIDA) and QuestManager.is_completed(QUEST_DJ):
		knot = "ronaldo_torcida_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Side quest : DJ au coucher de soleil. Dispo après ze_invitation complétée.
	if QuestManager.is_active(QUEST_DJ):
		knot = "ronaldo_dj_remind"
	elif QuestManager.is_completed(QUEST_DJ):
		knot = "ronaldo_dj_done"
	elif QuestManager.is_available(QUEST_DJ) and QuestManager.is_completed(QUEST):
		knot = "ronaldo_dj_offer"
	elif QuestManager.is_active(QUEST):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objectives.get(OBJ, false):
			knot = "ronaldo_invitation"
	DialogueBridge.start_dialogue(data.id, knot)
