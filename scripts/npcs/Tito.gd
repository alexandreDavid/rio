extends NPC

# Tito gère plusieurs états narratifs :
# - pedros_son : fils de Seu Pedro à ramener (priorité si active)
# - act1_meet_tito : faveur du Morro pour la voie Tráfico
# - act2_miguel_favela complétée : Tito propose un test de loyauté ("Vânia")
# - tito_loyalty_proven / declined : Tito clôt le moment, puis revient en thanks

const QUEST_PEDRO: String = "pedros_son"
const OBJ_PEDRO: String = "find_tito"
const QUEST_FAVOR: String = "act1_meet_tito"
const OBJ_FAVOR: String = "do_tito_favor"
const QUEST_PHARMA: String = "pharmacy_tito"
const OBJ_PHARMA: String = "deliver_medicine"
const QUEST_MIGUEL: String = "act2_miguel_favela"

func _ready() -> void:
	super._ready()
	# Si le joueur a balancé Tito à Ramos, il disparaît du morro (caché et non
	# interactif). Géré ici plutôt que via NPCScheduler pour ne pas téléporter
	# Tito en coordonnées Copa globales — il vit dans FavelaDoMorro.tscn.
	if CampaignManager.has_flag("ratted_on_tito"):
		visible = false
		if interactable:
			interactable.enabled = false
		set_process(false)

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
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

	# --- Test de loyauté acte 2 (après livraison Miguel) ---
	# Tito propose le défi "Vânia" une fois.
	if QuestManager.is_completed(QUEST_MIGUEL):
		# Joueur a passé le test → on joue la vidéo de récompense une fois.
		if CampaignManager.has_flag("tito_loyalty_proven") \
				and not CampaignManager.has_flag("tito_loyalty_done_seen"):
			DialogueBridge.start_dialogue(data.id, "tito_act2_loyalty_done")
			return
		# Joueur a refusé → on joue la pique une fois.
		if CampaignManager.has_flag("tito_loyalty_declined") \
				and not CampaignManager.has_flag("tito_loyalty_decline_seen"):
			DialogueBridge.start_dialogue(data.id, "tito_act2_loyalty_declined")
			return
		# Pas encore décidé → offre le test.
		if not CampaignManager.has_flag("tito_loyalty_proven") \
				and not CampaignManager.has_flag("tito_loyalty_declined"):
			DialogueBridge.start_dialogue(data.id, "tito_act2_loyalty_offer")
			return

	if QuestManager.is_completed(QUEST_FAVOR):
		knot = "tito_thanks"
	elif QuestManager.is_active(QUEST_FAVOR):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_FAVOR)
		if not objs.get(OBJ_FAVOR, false):
			knot = "tito_favor_ask"
	elif QuestManager.is_available(QUEST_FAVOR):
		knot = "tito_meet"
	DialogueBridge.start_dialogue(data.id, knot)
