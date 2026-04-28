extends NPC

# Padre Anselmo : statue (acte 1), orfanato (acte 2), élection (acte 3), audiences (acte 4 Prefeito).

const QUEST_STATUE: String = "church_statue"
const OBJ_FIND: String = "find_statue"
const OBJ_RETURN: String = "return_statue"
const QUEST_CORCOVADO: String = "padre_corcovado_relic"
const QUEST_ORFANATO: String = "act2_padre_orfanato"
const QUEST_ELEICAO: String = "act3_prefeito_eleicao"
const QUEST_AUDIENCIA: String = "act4_prefeito_audiencia"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # padre_intro
	# Acte 4 : règne du Coronel.
	if CampaignManager.current_act >= 4 and CampaignManager.chosen_endgame == CampaignManager.Endgame.PREFEITO:
		if QuestManager.is_completed(QUEST_AUDIENCIA):
			knot = "padre_act4_done"
		elif QuestManager.is_active(QUEST_AUDIENCIA):
			knot = "padre_act4_remind"
		elif QuestManager.is_available(QUEST_AUDIENCIA):
			knot = "padre_act4_audiencia"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Acte 3 : finale Prefeito.
	if CampaignManager.current_act >= 3 and _eligible_for_act3():
		if QuestManager.is_completed(QUEST_ELEICAO):
			knot = "padre_act3_done"
		elif QuestManager.is_active(QUEST_ELEICAO):
			knot = "padre_act3_offer"
		elif QuestManager.is_available(QUEST_ELEICAO):
			knot = "padre_act3_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Acte 2 : pétition orfanato.
	if QuestManager.is_active(QUEST_ORFANATO):
		knot = "padre_act2_remind"
	elif QuestManager.is_completed(QUEST_ORFANATO):
		knot = "padre_act2_done"
	elif QuestManager.is_available(QUEST_ORFANATO):
		knot = "padre_act2_offer"
	# Side quest : bénédiction de la relique au Corcovado (après la statue).
	elif QuestManager.is_active(QUEST_CORCOVADO):
		var c_objs: Dictionary = QuestManager.get_objectives_state(QUEST_CORCOVADO)
		if c_objs.get("bless_at_corcovado", false) and not c_objs.get("return_relic", false):
			knot = "padre_corcovado_receives"
		else:
			knot = "padre_corcovado_remind"
	elif QuestManager.is_available(QUEST_CORCOVADO) and QuestManager.is_completed(QUEST_STATUE):
		knot = "padre_corcovado_offer"
	elif QuestManager.is_completed(QUEST_STATUE):
		knot = "padre_thanks"
	elif QuestManager.is_active(QUEST_STATUE):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_STATUE)
		if objs.get(OBJ_FIND, false) and not objs.get(OBJ_RETURN, false):
			knot = "padre_receives"
		else:
			knot = "padre_remind"
	DialogueBridge.start_dialogue(data.id, knot)

func _eligible_for_act3() -> bool:
	if QuestManager.is_completed(QUEST_ORFANATO):
		return true
	# Fallback : dette soldée en acte 3 sans verrouillage → le Padre accueille.
	return CampaignManager.current_act >= 3 and CampaignManager.debt_remaining() == 0
