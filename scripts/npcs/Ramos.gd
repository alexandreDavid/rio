extends NPC

# Capitão Ramos : recrutement (acte 1), Operação Carnaval (acte 2), Madrugada (acte 3),
# Purga (acte 4 Polícia).

const QUEST_ACT1: String = "act1_meet_ramos"
const OBJ_ACT1: String = "report_to_ramos"
const QUEST_ACT2: String = "act2_ramos_operacao"
const QUEST_INTEL: String = "act3_policia_intel"
const QUEST_ACT3: String = "act3_policia_madrugada"
const QUEST_PURGA: String = "act4_policia_purga"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # "ramos_intro"
	# Acte 4 : règne du Chefe.
	if CampaignManager.current_act >= 4 and CampaignManager.chosen_endgame == CampaignManager.Endgame.POLICIA:
		if QuestManager.is_completed(QUEST_PURGA):
			knot = "ramos_act4_done"
		elif QuestManager.is_active(QUEST_PURGA):
			knot = "ramos_act4_remind"
		elif QuestManager.is_available(QUEST_PURGA):
			knot = "ramos_act4_purga"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Acte 3 : enquête intermédiaire (intel) puis finale Polícia (madrugada).
	# Chaîne : intel_offer → intel_remind → intel_close (rapport) → act3_offer → act3_close.
	if CampaignManager.current_act >= 3 and _eligible_for_act3():
		if QuestManager.is_completed(QUEST_ACT3):
			knot = "ramos_act3_done"
		elif QuestManager.is_active(QUEST_ACT3):
			knot = "ramos_act3_offer"
		elif QuestManager.is_available(QUEST_ACT3) and QuestManager.is_completed(QUEST_INTEL):
			knot = "ramos_act3_offer"
		elif QuestManager.is_active(QUEST_INTEL):
			var iobjs: Dictionary = QuestManager.get_objectives_state(QUEST_INTEL)
			if iobjs.get("intel_vizinha", false) and iobjs.get("intel_seu_joao", false) \
					and not iobjs.get("report_ramos", false):
				knot = "ramos_act3_intel_close"
			else:
				knot = "ramos_act3_intel_remind"
		elif QuestManager.is_available(QUEST_INTEL):
			knot = "ramos_act3_intel_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_active(QUEST_ACT2):
		knot = "ramos_act2_offer"
	elif QuestManager.is_completed(QUEST_ACT2):
		if CampaignManager.has_flag("ratted_on_tito"):
			knot = "ramos_act2_done_loyal"
		else:
			knot = "ramos_act2_done_cold"
	elif QuestManager.is_available(QUEST_ACT2) and QuestManager.is_completed(QUEST_ACT1):
		knot = "ramos_act2_offer"
	elif QuestManager.is_completed(QUEST_ACT1):
		knot = "ramos_thanks"
	elif QuestManager.is_active(QUEST_ACT1):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_ACT1)
		if not objs.get(OBJ_ACT1, false):
			knot = "ramos_active"
	DialogueBridge.start_dialogue(data.id, knot)

func _eligible_for_act3() -> bool:
	if CampaignManager.has_flag("ratted_on_tito") or CampaignManager.has_flag("pecheur_to_ramos"):
		return true
	# Fallback : dette soldée en acte 3 sans voie verrouillée → Ramos accueille.
	return CampaignManager.current_act >= 3 and CampaignManager.debt_remaining() == 0
