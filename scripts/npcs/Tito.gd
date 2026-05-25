extends NPC

# Tito — patron de la VOIE TRÁFICO (missions A1–A9). Le détail passe par le
# contact du calçadão et les spots ; Tito offre le pacte, rappelle A1, scelle
# le couronnement (la corrida). Conserve ses SIDE : pharmacie + fils de Pedro.

const QUEST_PEDRO: String = "pedros_son"
const OBJ_PEDRO: String = "find_tito"
const QUEST_PHARMA: String = "pharmacy_tito"
const OBJ_PHARMA: String = "deliver_medicine"

func _ready() -> void:
	super._ready()
	# Si le joueur a balancé Tito à Ramos, il disparaît du morro.
	if CampaignManager.has_flag("ratted_on_tito"):
		visible = false
		if interactable:
			interactable.enabled = false
		set_process(false)

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier(data.id, data.ink_knot,
			"tito_chat_warm", "tito_chat_familiar")

	# --- VOIE TRÁFICO : pacte avec Tito ---
	# Le pacte n'est accessible qu'après que l'acte 1 ait été fermé
	# (nuit passée dans la maison du tio Zé — flag `act1_closed`).
	if QuestManager.is_completed("prologue_pedrinho") \
			and QuestManager.is_completed("act1_heritage") \
			and CampaignManager.has_flag("act1_closed") \
			and not CampaignManager.has_flag("ratted_on_tito"):
		if not CampaignManager.has_flag("voie_trafico") \
				and not CampaignManager.has_flag("voie_policia") \
				and not CampaignManager.has_flag("voie_consortium") \
				and not CampaignManager.has_flag("voie_prefeito"):
			DialogueBridge.start_dialogue(data.id, "tito_pacto_trafico_offer")
			return
		if QuestManager.is_active("trafico_a9_corrida"):
			DialogueBridge.start_dialogue(data.id, "tito_trafico_corrida")
			return
		if QuestManager.is_active("trafico_a1_livraison"):
			DialogueBridge.start_dialogue(data.id, "tito_pacto_trafico_remind")
			return

	# SIDE : livraison du médicament (priorité si active et pas livrée).
	if QuestManager.is_active(QUEST_PHARMA):
		var objs_p: Dictionary = QuestManager.get_objectives_state(QUEST_PHARMA)
		if not objs_p.get(OBJ_PHARMA, false):
			DialogueBridge.start_dialogue(data.id, "tito_receives_medicine")
			return
	# SIDE : fils de Seu Pedro à ramener.
	if QuestManager.is_active(QUEST_PEDRO):
		var objectives: Dictionary = QuestManager.get_objectives_state(QUEST_PEDRO)
		if not objectives.get(OBJ_PEDRO, false):
			DialogueBridge.start_dialogue(data.id, "tito_encounter")
			return

	DialogueBridge.start_dialogue(data.id, knot)
