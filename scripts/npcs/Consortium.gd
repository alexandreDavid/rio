extends NPC

# Créancier de l'acte 1. Le knot dépend de la progression de la dette.

const QUEST_AIRPORT: String = "consortium_airport_pickup"
const OBJ_MEET: String = "meet_at_airport"
const OBJ_DELIVER: String = "deliver_to_consortium"
const QUEST_BARRA: String = "consortium_barra_security"
const OBJ_INTIMIDATE: String = "intimidate_magalhaes"
const OBJ_CLOSE: String = "close_deal"
const QUEST_LE_PARC: String = "consortium_le_parc"
const OBJ_INTIMIDATE_LP: String = "intimidate_carrasco"
const OBJ_CLOSE_LP: String = "close_deal_carrasco"
const QUEST_PENINSULA: String = "consortium_peninsula"
const OBJ_INTIMIDATE_PN: String = "intimidate_mendonca"
const OBJ_CLOSE_PN: String = "close_deal_mendonca"

# Le joueur a de quoi franchir le seuil de l'acte : Dom Nilton encaisse
# d'abord, le rappel de sa course attendra (le bandeau dit « va verser », et
# le premier choix du rappel était « J'y vais » — 14 min perdues au playtest
# du 2026-11-19). Le rappel garde son choix « J'ai de l'argent » pour le reste.
func _remind_or_pay(remind: String) -> String:
	var threshold: int = CampaignManager.next_act_threshold()
	var missing: int = threshold - CampaignManager.debt_paid
	if threshold <= 0 or missing <= 0 or GameManager.player == null:
		return remind
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	return "consortium_pay" if inv != null and inv.money >= missing else remind

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String
	# Side quest aéroport : prend la priorité tant qu'elle est en cours.
	if QuestManager.is_active(QUEST_AIRPORT):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_AIRPORT)
		# Salvatore livré au consortium → on clôture ici.
		if objs.get(OBJ_MEET, false) and not objs.get(OBJ_DELIVER, false):
			knot = "consortium_airport_done"
		else:
			knot = _remind_or_pay("consortium_airport_remind")
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Side quest Península : prend la priorité — c'est la plus tardive.
	if QuestManager.is_active(QUEST_PENINSULA):
		if QuestManager.is_objective_done(QUEST_PENINSULA, OBJ_CLOSE_PN):
			knot = "consortium_peninsula_done"
		elif QuestManager.is_objective_done(QUEST_PENINSULA, OBJ_INTIMIDATE_PN):
			knot = "consortium_peninsula_after_intimidate"
		else:
			knot = _remind_or_pay("consortium_peninsula_remind")
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Side quest Le Parc : si active, rappel ou closing.
	if QuestManager.is_active(QUEST_LE_PARC):
		if QuestManager.is_objective_done(QUEST_LE_PARC, OBJ_CLOSE_LP):
			knot = "consortium_le_parc_done"
		elif QuestManager.is_objective_done(QUEST_LE_PARC, OBJ_INTIMIDATE_LP):
			knot = "consortium_le_parc_after_intimidate"
		else:
			knot = _remind_or_pay("consortium_le_parc_remind")
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Side quest Barra : si active, rappel ou closing selon où on en est.
	if QuestManager.is_active(QUEST_BARRA):
		if QuestManager.is_objective_done(QUEST_BARRA, OBJ_CLOSE):
			knot = "consortium_barra_done"
		elif QuestManager.is_objective_done(QUEST_BARRA, OBJ_INTIMIDATE):
			knot = "consortium_barra_after_intimidate"
		else:
			knot = _remind_or_pay("consortium_barra_remind")
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Offre Le Parc : prereq = Barra terminée + dette restante.
	if QuestManager.is_available(QUEST_LE_PARC) \
			and QuestManager.is_completed(QUEST_BARRA) \
			and CampaignManager.debt_remaining() > 0:
		knot = "consortium_le_parc_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Offre Península : prereq = Le Parc terminée + dette restante.
	if QuestManager.is_available(QUEST_PENINSULA) \
			and QuestManager.is_completed(QUEST_LE_PARC) \
			and CampaignManager.debt_remaining() > 0:
		knot = "consortium_peninsula_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Offre Barra : disponible après l'aéroport (prereq), met_consortium, dette restante.
	if QuestManager.is_available(QUEST_BARRA) \
			and CampaignManager.has_flag("met_consortium") \
			and CampaignManager.debt_remaining() > 0:
		knot = "consortium_barra_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Offre aéroport : seulement après que l'acte 1 ait été fermé (nuit
	# passée à la maison du tio Zé — flag `act1_closed`). Avant ça, le
	# joueur n'a pas encore le souffle pour aller chercher un boss à Santos
	# Dumont. Reste gated sur met_consortium + dette restante.
	if QuestManager.is_available(QUEST_AIRPORT) \
			and CampaignManager.has_flag("met_consortium") \
			and CampaignManager.has_flag("act1_closed") \
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
