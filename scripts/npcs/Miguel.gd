extends NPC

# Miguel : colis (acte 1), convoi favela (acte 2), Última corrida (acte 3),
# Coleta (acte 4 Tráfico).

const DELIVERY_QUEST: String = "deliver_package_01"
const ACT2_QUEST: String = "act2_miguel_favela"
const PICKUP_QUEST: String = "act3_trafico_pickup"
const ACT3_QUEST: String = "act3_trafico_corrida"
const QUEST_TRIBUTO: String = "act4_trafico_tributo"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # "miguel_intro"
	# Acte 4 : règne du Patrão.
	if CampaignManager.current_act >= 4 and CampaignManager.chosen_endgame == CampaignManager.Endgame.TRAFICO:
		if QuestManager.is_completed(QUEST_TRIBUTO):
			knot = "miguel_act4_done"
		elif QuestManager.is_active(QUEST_TRIBUTO):
			knot = "miguel_act4_remind"
		elif QuestManager.is_available(QUEST_TRIBUTO):
			knot = "miguel_act4_tributo"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Acte 3 : test pickup (Botafogo) puis finale Tráfico (corrida).
	if CampaignManager.current_act >= 3 and _eligible_for_act3():
		if QuestManager.is_completed(ACT3_QUEST):
			knot = "miguel_act3_done"
		elif QuestManager.is_active(ACT3_QUEST):
			knot = "miguel_act3_offer"
		elif QuestManager.is_available(ACT3_QUEST) and QuestManager.is_completed(PICKUP_QUEST):
			knot = "miguel_act3_offer"
		elif QuestManager.is_active(PICKUP_QUEST):
			var pobjs: Dictionary = QuestManager.get_objectives_state(PICKUP_QUEST)
			if pobjs.get("pickup_botafogo", false) and not pobjs.get("pickup_deliver", false):
				knot = "miguel_act3_pickup_close"
			else:
				knot = "miguel_act3_pickup_remind"
		elif QuestManager.is_available(PICKUP_QUEST):
			knot = "miguel_act3_pickup_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_active(ACT2_QUEST):
		knot = "miguel_act2_remind"
	elif QuestManager.is_completed(ACT2_QUEST):
		knot = "miguel_act2_done"
	elif QuestManager.is_available(ACT2_QUEST):
		knot = "miguel_act2_offer"
	elif QuestManager.is_active(DELIVERY_QUEST):
		knot = "miguel_waiting"
	elif QuestManager.is_completed(DELIVERY_QUEST):
		knot = "miguel_done"
	DialogueBridge.start_dialogue(data.id, knot)

func _eligible_for_act3() -> bool:
	# Le Morro n'oublie pas une balance — voie Tráfico fermée si tu as donné Tito.
	if CampaignManager.has_flag("ratted_on_tito"):
		return false
	if QuestManager.is_completed(ACT2_QUEST):
		return true
	# Fallback : dette soldée en acte 3 sans verrouillage → Miguel accueille.
	return CampaignManager.current_act >= 3 and CampaignManager.debt_remaining() == 0
