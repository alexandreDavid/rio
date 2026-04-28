extends NPC

# Créancier de l'acte 1. Le knot dépend de la progression de la dette.

const QUEST_AIRPORT: String = "consortium_airport_pickup"
const OBJ_MEET: String = "meet_at_airport"
const OBJ_DELIVER: String = "deliver_to_consortium"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String
	# Side quest aéroport : prend la priorité tant qu'elle est en cours.
	if QuestManager.is_active(QUEST_AIRPORT):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_AIRPORT)
		# Salvatore livré au consortium → on clôture ici.
		if objs.get(OBJ_MEET, false) and not objs.get(OBJ_DELIVER, false):
			knot = "consortium_airport_done"
		else:
			knot = "consortium_airport_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Offre de mission : seulement après le premier contact avec le consortium,
	# et tant que la dette n'est pas soldée (sinon on n'a plus rien à se dire).
	if QuestManager.is_available(QUEST_AIRPORT) \
			and CampaignManager.has_flag("met_consortium") \
			and CampaignManager.debt_remaining() > 0:
		knot = "consortium_airport_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if CampaignManager.debt_remaining() <= 0:
		knot = "consortium_settled"
	elif not CampaignManager.has_flag("met_consortium"):
		knot = "consortium_intro"
	elif CampaignManager.debt_paid >= CampaignManager.ACT1_THRESHOLD and CampaignManager.current_act == 1:
		# Transition visuelle juste après le seuil — on bascule ensuite sur consortium_pay.
		knot = "consortium_after_threshold"
	else:
		knot = "consortium_pay"
	DialogueBridge.start_dialogue(data.id, knot)
