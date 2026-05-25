extends NPC

# Padre Anselmo — patron de la VOIE PREFEITO (missions D1–D9). Le détail passe
# par les spots ; le Padre offre le pacte, rappelle D1, scelle le couronnement
# (l'élection). Conserve aussi ses SIDE : statue + relique du Corcovado.

const QUEST_STATUE: String = "church_statue"
const OBJ_FIND: String = "find_statue"
const OBJ_RETURN: String = "return_statue"
const QUEST_CORCOVADO: String = "padre_corcovado_relic"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier(data.id, data.ink_knot,
			"padre_chat_warm", "padre_chat_familiar")

	# --- VOIE PREFEITO : intro acte 2 puis pacte acte 3 ---
	# Disponible après que l'acte 1 ait été fermé (`act1_closed`).
	if QuestManager.is_completed("prologue_pedrinho") \
			and QuestManager.is_completed("act1_heritage") \
			and CampaignManager.has_flag("act1_closed") \
			and not CampaignManager.has_flag("voie_trafico") \
			and not CampaignManager.has_flag("voie_policia") \
			and not CampaignManager.has_flag("voie_consortium"):
		# Acte 2 = échantillon : offre D1 sans sceller la voie.
		if CampaignManager.current_act == 2 \
				and not CampaignManager.has_flag("voie_prefeito") \
				and not QuestManager.is_active("prefeito_d1_peticao") \
				and not QuestManager.is_completed("prefeito_d1_peticao"):
			DialogueBridge.start_dialogue(data.id, "padre_intro_d1_offer")
			return
		# Acte 3+ = pacte formel (scelle voie_prefeito).
		if CampaignManager.current_act >= 3 and not CampaignManager.has_flag("voie_prefeito"):
			DialogueBridge.start_dialogue(data.id, "padre_pacto_prefeito_offer")
			return
		if QuestManager.is_active("prefeito_d9_eleicao"):
			DialogueBridge.start_dialogue(data.id, "padre_prefeito_eleicao")
			return
		if QuestManager.is_active("prefeito_d1_peticao"):
			DialogueBridge.start_dialogue(data.id, "padre_pacto_prefeito_remind")
			return

	# Side quest : relique au Corcovado (après la statue).
	if QuestManager.is_active(QUEST_CORCOVADO):
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
