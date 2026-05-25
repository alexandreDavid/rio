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

	# --- VOIE POLÍCIA : intro acte 2 puis pacte acte 3 ---
	# Disponible une fois le 1er acompte payé + nuit passée (`act1_closed`).
	if QuestManager.is_completed("prologue_pedrinho") \
			and QuestManager.is_completed("act1_heritage") \
			and CampaignManager.has_flag("act1_closed") \
			and not CampaignManager.has_flag("voie_trafico") \
			and not CampaignManager.has_flag("voie_consortium") \
			and not CampaignManager.has_flag("voie_prefeito"):
		# Acte 2 = échantillon : offre B1 sans sceller la voie.
		if CampaignManager.current_act == 2 \
				and not CampaignManager.has_flag("voie_policia") \
				and not QuestManager.is_active("policia_b1_intel") \
				and not QuestManager.is_completed("policia_b1_intel"):
			DialogueBridge.start_dialogue(data.id, "ramos_intro_b1_offer")
			return
		# Acte 3+ = pacte formel (scelle voie_policia).
		if CampaignManager.current_act >= 3 and not CampaignManager.has_flag("voie_policia"):
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
