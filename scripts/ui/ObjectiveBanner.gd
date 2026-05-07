extends Control

# Bandeau d'objectif contextuel en haut de l'écran. Calcule en permanence
# "qu'est-ce que je dois faire MAINTENANT ?" à partir de l'état des quêtes,
# des flags narratifs, du district courant, du portage de la charrette et
# de l'argent en poche. Le texte se met à jour automatiquement à chaque
# changement d'état.

@onready var label: Label = $Panel/Label
@onready var panel: Panel = $Panel

func _ready() -> void:
	# Écoute tous les signaux qui peuvent changer l'objectif courant.
	EventBus.quest_accepted.connect(_on_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_event)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.corn_cart_state_changed.connect(_on_cart_state)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	if Engine.has_singleton("DistrictManager") or get_tree().root.has_node("DistrictManager"):
		DistrictManager.district_changed.connect(_on_district_changed)
	_refresh()

func _on_phase_changed(_phase: int) -> void:
	_refresh()

func _on_event(_id: String) -> void:
	_refresh()

func _on_quest_updated(_quest_id: String, _objective_id: String) -> void:
	_refresh()

func _on_debt_paid(_amount: int, _remaining: int) -> void:
	_refresh()

func _on_act_changed(_act: int) -> void:
	_refresh()

func _on_district_changed(_district_id: String) -> void:
	_refresh()

func _on_cart_state(_carrying: bool) -> void:
	_refresh()

func _on_money_changed(_amount: int) -> void:
	_refresh()

func _on_customer_served(_npc_id: String) -> void:
	_refresh()

func _refresh() -> void:
	var text: String = _compute_hint()
	if label:
		label.text = text
	if panel:
		panel.visible = text != ""

# Récupère le portefeuille du joueur (0 si indisponible).
func _player_money() -> int:
	if GameManager.player == null:
		return 0
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return 0
	return inv.money

# Vrai si la charrette de milho est portée par le joueur.
func _cart_carrying() -> bool:
	var cart: Node = get_tree().get_first_node_in_group("corn_cart")
	if cart == null or not cart.has_method("is_carrying"):
		return false
	return cart.call("is_carrying")

# Heuristique : à partir des flags + quêtes + district + état charrette + argent,
# dérive le prochain pas. L'ordre des conditions == l'ordre de priorité (1ère qui match).
func _compute_hint() -> String:
	var act: int = CampaignManager.current_act
	var district: String = DistrictManager.current()
	var debt_paid: int = CampaignManager.debt_paid
	var money: int = _player_money()
	var carrying: bool = _cart_carrying()
	var is_evening: bool = TimeOfDay.current_phase == TimeOfDay.Phase.EVENING

	# --- Acte 1 : démarrage ---
	# Avant le bump cutscene : tio Zé n'est pas encore dans la maison. Mãe et
	# vovó attendent des nouvelles. Le joueur doit sortir pour déclencher
	# l'événement (Seu João débarque par la porte).
	if not CampaignManager.has_flag("act1_started"):
		if not CampaignManager.has_flag("intro_bump_seen"):
			return "🎯 Sors de la maison — Seu João arrive avec des nouvelles"
		return "🎯 Parle à tio Zé"

	# --- Soir : la famille attend pour le jantar ---
	# Avant que les pivots de fin (acte 4 / endgame chosen) ne prennent la main,
	# le soir ramène le joueur à la maison. Pas de nag s'il y est déjà.
	if is_evening and act <= 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE \
			and district != "favela_morro":
		return "🌙 Rentre dîner — tio Zé et mãe attendent"

	# Sortie de la maison → prendre la charrette puis descendre.
	if district == "favela_morro":
		if not carrying and not CampaignManager.has_flag("first_sale_done"):
			return "🎯 Prends la carrocinha à côté de chez tio Zé"
		# Retour à la favela après le premier acompte → revoir la famille.
		if CampaignManager.has_flag("should_visit_home") and not CampaignManager.has_flag("home_visit_done"):
			return "🎯 Monte voir tio Zé et la famille"
		# Acte 1 : Tito habite ici. Si la rencontre est dispo/active, pointe vers lui.
		if act == 1 and not QuestManager.is_completed("act1_meet_tito"):
			if QuestManager.is_active("act1_meet_tito"):
				return "🎯 Tito attend son service — fais-lui confiance"
			if QuestManager.is_available("act1_meet_tito"):
				return "🎯 Trouve Tito — il joue plus haut dans le morro"
		return "🎯 ↓ Descends l'escalier vers Copacabana"

	# --- Acte 1 sur Copacabana ---
	if act == 1 and district == "copacabana":
		# Première rencontre consortium pas encore faite.
		if not CampaignManager.has_flag("met_consortium"):
			return "🎯 Va voir Dom Nilton (consortium) sur l'Av. Atlântica"
		# Pas encore d'acompte : il faut générer du cash.
		if debt_paid < CampaignManager.ACT1_THRESHOLD:
			var still_to_pay: int = CampaignManager.ACT1_THRESHOLD - debt_paid
			# Joueur a déjà l'acompte en poche → aller poser au consortium.
			if money >= still_to_pay:
				return "🎯 Va déposer %d R$ d'acompte au consortium" % still_to_pay
			# Sinon, vendre du milho (avec ou sans charrette).
			if not carrying and not CampaignManager.has_flag("first_sale_done"):
				return "🎯 Prends la carrocinha (favela) puis vends au calçadão"
			if carrying:
				return "🎯 Sers les clients du calçadão (R$ %d / %d)" % [money, still_to_pay]
			return "🎯 Continue de gagner R$ — il manque %d pour l'acompte" % (still_to_pay - money)
		# Acompte payé : pousser vers les deux mentors (pivots du passage à l'acte 2).
		var ramos_done: bool = QuestManager.is_completed("act1_meet_ramos")
		var tito_done: bool = QuestManager.is_completed("act1_meet_tito")
		if not ramos_done and not tito_done:
			return "🎯 Acte 1 continue — rencontre Ramos (Bar do Policial) et Tito (↑ Morro)"
		if not ramos_done:
			return "🎯 Va voir Capitão Ramos — Bar do Policial (côté Atlântica)"
		if not tito_done:
			return "🎯 Monte au Morro rencontrer Tito"

	# --- Acte 2 (chaîne linéaire ramos → padre → miguel) ---
	if act == 2:
		# Juste après bascule en acte 2 : retour favela pour digérer le moment.
		if CampaignManager.has_flag("should_visit_home") and not CampaignManager.has_flag("home_visit_done"):
			if district == "favela_morro":
				return "🎯 Monte voir tio Zé et la famille"
			return "🎯 Retourne voir ta famille à la favela"
		# La chaîne MAIN guide ; le seuil de dette est complémentaire.
		var act2_chain_hint: String = _next_main_hint_act2()
		if act2_chain_hint != "":
			return act2_chain_hint
		if debt_paid < CampaignManager.ACT2_THRESHOLD:
			var still: int = CampaignManager.ACT2_THRESHOLD - debt_paid
			return "🎯 Continue de payer la dette (%s R$ avant l'acte 3)" % still

	# --- Acte 3 : missions intermédiaires par voie (priorité sur "choisis ta voie") ---
	if act == 3:
		var inferred_path: int = _infer_act3_path()
		if inferred_path != CampaignManager.Endgame.NONE:
			var act3_hint: String = _act3_path_hint(district, inferred_path)
			if act3_hint != "":
				return act3_hint
		else:
			return "🎯 Choisis ta voie : Prefeito / Polícia / Tráfico"

	# --- Acte 4 : reinado ---
	if act == 4:
		return "🎯 Mène ton règne — défilé du Carnaval au Sambódromo"

	# Fallback
	return ""

# Hint pour la chaîne linéaire d'acte 2 : ramos_operacao → padre_orfanato → miguel_favela.
# Renvoie la prochaine étape selon la quête active (priorité) puis disponible.
func _next_main_hint_act2() -> String:
	# 1. Quête active : pousse vers son giver pour la conclure.
	for qid_active in ["act2_ramos_operacao", "act2_padre_orfanato", "act2_miguel_favela"]:
		if QuestManager.is_active(qid_active):
			return _hint_for_active_act2(qid_active)
	# 2. Sinon, prochaine disponible.
	for qid_avail in ["act2_intro", "act2_ramos_operacao", "act2_padre_orfanato", "act2_miguel_favela"]:
		if QuestManager.is_available(qid_avail):
			return _hint_for_offer_act2(qid_avail)
	return ""

func _hint_for_active_act2(qid: String) -> String:
	match qid:
		"act2_ramos_operacao":
			return "🎯 Operação Carnaval : tranche pour Ramos (Bar do Policial)"
		"act2_padre_orfanato":
			return "🎯 Pétition Orfanato : trois signatures à recueillir"
		"act2_miguel_favela":
			return "🎯 Convoi de Miguel : descends le sac côté Forte"
	return ""

func _hint_for_offer_act2(qid: String) -> String:
	match qid:
		"act2_intro":
			return "🎯 Va voir le Concierge au Copacabana Palace"
		"act2_ramos_operacao":
			return "🎯 Va voir Ramos — Bar do Policial / poste de police"
		"act2_padre_orfanato":
			return "🎯 Va voir le Padre — chapelle Nossa Senhora"
		"act2_miguel_favela":
			return "🎯 Monte au Morro voir Miguel"
	return ""

# Détecte la voie engagée à partir de l'état des quêtes intermédiaires/finales.
# `chosen_endgame` n'est posé qu'à la complétion du finale — trop tard pour piloter
# la bannière pendant la mission intermédiaire.
func _infer_act3_path() -> int:
	if CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE:
		return CampaignManager.chosen_endgame
	for qid in ["act3_policia_intel", "act3_policia_madrugada"]:
		if QuestManager.is_active(qid) or QuestManager.is_completed(qid):
			return CampaignManager.Endgame.POLICIA
	for qid in ["act3_trafico_pickup", "act3_trafico_corrida"]:
		if QuestManager.is_active(qid) or QuestManager.is_completed(qid):
			return CampaignManager.Endgame.TRAFICO
	for qid in ["act3_prefeito_endorsements", "act3_prefeito_eleicao"]:
		if QuestManager.is_active(qid) or QuestManager.is_completed(qid):
			return CampaignManager.Endgame.PREFEITO
	return CampaignManager.Endgame.NONE

# Hint contextuel pour la voie engagée en acte 3 : pointe vers le mentor au début,
# vers les sources d'intel/pickup/endorsements pendant la mission intermédiaire,
# vers le mentor pour le rapport final, puis vers le finale.
func _act3_path_hint(district: String, path: int) -> String:
	if path == CampaignManager.Endgame.POLICIA:
		var iquest: String = "act3_policia_intel"
		if QuestManager.is_completed(iquest):
			return "🎯 Va voir Ramos — l'Operação Madrugada t'attend"
		if QuestManager.is_active(iquest):
			var iobjs: Dictionary = QuestManager.get_objectives_state(iquest)
			var has_v: bool = iobjs.get("intel_vizinha", false)
			var has_z: bool = iobjs.get("intel_seu_joao", false)
			if has_v and has_z:
				return "🎯 Rapporte le dossier à Ramos (poste de police)"
			if district == "favela_morro":
				if not has_v:
					return "🎯 Soutire-lui une info — la voisine du Morro"
				return "🎯 Recoupe avec ce que sait tio Zé"
			return "🎯 Monte au Morro — voisine + tio Zé pour Ramos"
		return "🎯 Va voir Ramos — il a un dossier à monter"
	if path == CampaignManager.Endgame.TRAFICO:
		var pquest: String = "act3_trafico_pickup"
		if QuestManager.is_completed(pquest):
			return "🎯 Retrouve Miguel — la corrida se prépare"
		if QuestManager.is_active(pquest):
			var pobjs: Dictionary = QuestManager.get_objectives_state(pquest)
			if not pobjs.get("pickup_botafogo", false):
				return "🎯 → Bondinho de Botafogo : récupère le sac"
			return "🎯 Rapporte le sac à Miguel (Morro)"
		return "🎯 Va voir Miguel — il a un test pour toi"
	if path == CampaignManager.Endgame.PREFEITO:
		var equest: String = "act3_prefeito_endorsements"
		if QuestManager.is_completed(equest):
			return "🎯 Retourne au Padre — la coalition tient"
		if QuestManager.is_active(equest):
			var eobjs: Dictionary = QuestManager.get_objectives_state(equest)
			var has_c: bool = eobjs.get("endorse_carlos", false)
			var has_p: bool = eobjs.get("endorse_padeiro", false)
			var has_pa: bool = eobjs.get("endorse_padre", false)
			if has_c and has_p and not has_pa:
				return "🎯 Reviens voir le Padre — coalition à sceller"
			if not has_c:
				return "🎯 Convaincs Carlos (café ISSIMO) de signer"
			if not has_p:
				return "🎯 Convaincs le padeiro (Padaria São Sebastião)"
			return "🎯 Retourne voir le Padre"
		return "🎯 Va voir le Padre — coalition à monter"
	return ""
