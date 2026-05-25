extends NPC

# Capitão Ramos — patron de la VOIE POLÍCIA (missions B1–B9, cf. plan voies).
# Le détail des missions passe par le contact du calçadão et les spots ;
# Ramos n'offre que le pacte, rappelle B1 et scelle le couronnement
# (Operação Madrugada). Hors voie : salutation d'ambiance.

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	# Fallback affinité : si aucune condition ne s'applique, salutation qui
	# évolue avec le nombre de visites.
	var knot: String = NPCAffinity.knot_for_tier(data.id, data.ink_knot,
			"ramos_chat_warm", "ramos_chat_familiar")

	# --- VOIE POLÍCIA : pacte avec Ramos (priorité une fois le 1er acompte
	# payé, l'enfant retrouvé et la nuit passée à la maison — flag
	# `act1_closed` — tant qu'aucune autre voie n'est scellée).
	if QuestManager.is_completed("prologue_pedrinho") \
			and QuestManager.is_completed("act1_heritage") \
			and CampaignManager.has_flag("act1_closed") \
			and not CampaignManager.has_flag("voie_trafico") \
			and not CampaignManager.has_flag("voie_consortium") \
			and not CampaignManager.has_flag("voie_prefeito"):
		if not CampaignManager.has_flag("voie_policia"):
			DialogueBridge.start_dialogue(data.id, "ramos_pacto_policia_offer")
			return
		if QuestManager.is_active("policia_b9_madrugada"):
			DialogueBridge.start_dialogue(data.id, "ramos_policia_madrugada")
			return
		if QuestManager.is_active("policia_b1_intel"):
			DialogueBridge.start_dialogue(data.id, "ramos_pacto_policia_remind")
			return

	# Le commissaire (cousin de Mendonça, SIDE Península) a alerté Ramos sur le
	# racket consortium — il refuse de s'engager tant que rien n'est scellé.
	if CampaignManager.has_flag("commissaire_alerted") and CampaignManager.current_act < 4:
		DialogueBridge.start_dialogue(data.id, "ramos_commissaire_alerted")
		return

	DialogueBridge.start_dialogue(data.id, knot)
