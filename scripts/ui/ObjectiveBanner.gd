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
		# La rencontre Tito legacy a disparu (act1_meet_tito n'existe plus) —
		# on pousse simplement vers la sortie sud / Copa.
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
		# Acompte payé : l'acte 2 devrait s'enclencher dès la prochaine frame
		# (CampaignManager._check_act_advance). Si on est encore en acte 1,
		# c'est juste le tick avant la bascule — on pousse déjà vers le choix
		# du patron pour ne pas laisser le joueur sans direction.
		return "🎯 Acompte payé — Choisis ton patron : Tito (Morro) / Ramos (Bar do Policial) / Magalhães (Barra) / Padre (chapelle)"

	# --- Acte 2 (échantillon libre : tous les patrons jusqu'aux 5k) ---
	if act == 2:
		# Juste après bascule en acte 2 : retour favela pour digérer le moment.
		if CampaignManager.has_flag("should_visit_home") and not CampaignManager.has_flag("home_visit_done"):
			if district == "favela_morro":
				return "🎯 Monte voir tio Zé et la famille"
			return "🎯 Retourne voir ta famille à la favela"
		# La nuit doit passer dans la maison avant tout patron.
		if not CampaignManager.has_flag("act1_closed"):
			if district == "favela_morro":
				return "🎯 Rentre chez tio Zé — la nuit doit passer"
			return "🎯 Remonte à la favela — la nuit doit passer chez tio Zé"
		# Tito vient aborder le joueur à la sortie de la maison (1ère fois).
		if not CampaignManager.has_flag("tito_approached") \
				and not CampaignManager.has_flag("ratted_on_tito") \
				and _no_voie_chosen():
			if district == "favela_morro":
				return "🎯 Sors de la maison — Tito veut te parler"
		# Échantillon : 4 patrons à goûter (Tito, Ramos, Magalhães, Padre),
		# puis 5000 R$ pour ouvrir l'acte 3 (vrai choix de voie).
		if debt_paid < CampaignManager.ACT2_THRESHOLD:
			var still: int = CampaignManager.ACT2_THRESHOLD - debt_paid
			return "🎯 Goûte aux 4 patrons (Tito / Ramos / Magalhães / Padre) — %s R$ avant le vrai choix" % still

	# --- Acte 3 : nudge tant qu'aucune voie n'est scellée ---
	# Le hinting des missions intermédiaires de l'ancien spine (act3_policia_*,
	# act3_trafico_*, act3_prefeito_*) a été retiré avec la refonte en voies
	# A/B/C/D (missions données par les spots, hint pris en charge par les
	# variantes elles-mêmes via MAIN_NEXT_HINT côté HUD).
	if act == 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE:
		if _no_voie_chosen():
			return "🎯 Le vrai choix : va sceller un pacte (Tito / Ramos / Magalhães / Padre)"

	# --- Acte 4 : reinado ---
	if act == 4:
		return "🎯 Mène ton règne — défilé du Carnaval au Sambódromo"

	# Fallback : si aucun hint MAIN/acte ne s'applique, on surface le prochain
	# pas d'une quête SIDE active (la 1re trouvée dans QUEST_NEXT_HINT). Aide
	# le joueur à savoir vers quel quartier aller quand plusieurs SIDE tournent.
	var side_hint: String = _active_quest_hint()
	if side_hint != "":
		return side_hint
	return ""

# Registre des destinations par étape de quête. Clé = "quest_id/obj_id".
# Couvre les SIDE inter-districts ET les voies A/B/C/D — le toast HUD jalon
# n'apparaît qu'au moment de la complétion d'une étape, la bannière prend
# le relais en permanence pour le « où aller maintenant ».
const QUEST_NEXT_HINT: Dictionary = {
	# --- VOIE TRÁFICO (A1 → A9) ---
	"trafico_a1_livraison/drop_calcadao": "🎯 → Copa (calçadão, face mer) : déposer le paquet au contact",
	"trafico_a2_pickup/pickup_palace": "🎯 → Copa Palace : récupérer la sacoche chez le groom",
	"trafico_a3_chauffeur/drive_botafogo": "🎯 → Botafogo (Bondinho) : conduire le coffre",
	"trafico_a4_ipanema/deal_ipanema": "🎯 → Zona Sul (Ipanema, posto 9) : refourguer la marchandise",
	"trafico_a5_intim/silence_voisin": "🎯 → Favela : faire taire le voisin qui t'a vu",
	"trafico_a6_cagarras/receive_cargo": "🎯 → Zona Sul (île au large) : réceptionner le chargement (SUP)",
	"trafico_a7_tioze/heed_warning": "🎯 → Copa Palace : écouter le vieux concierge",
	"trafico_a8_baia/cross_baia": "🎯 → Niterói : traverser la baie avec la grosse livraison",
	"trafico_a9_corrida/execute_run": "🎯 → Favela : retrouver Tito pour la corrida finale",
	# --- VOIE POLÍCIA (B1 → B9) ---
	"policia_b1_intel/report_face": "🎯 → Copa (calçadão) : rapporter le visage à l'agent en civil",
	"policia_b2_filature/map_network": "🎯 → Copa : cartographier le réseau avec l'agent",
	"policia_b3_escorte/escort_patrol": "🎯 → Botafogo : conduire la patrouille",
	"policia_b4_descente/bust_dealer": "🎯 → Zona Sul (Arpoador) : descendre sur le dealer",
	"policia_b5_reperage/scout_corcovado": "🎯 → Corcovado : repérer la remise",
	"policia_b6_tioze/hear_concierge": "🎯 → Copa Palace : écouter le concierge",
	"policia_b7_saisie/seize_cargo": "🎯 → Niterói : saisir la cargaison",
	"policia_b8_seguranca/secure_crowd": "🎯 → Maracanã : sécuriser la foule",
	"policia_b9_madrugada/complete_madrugada": "🎯 → Bar do Policial : rejoindre Ramos pour la Madrugada",
	# --- VOIE CONSORTIUM (C1 → C9) ---
	"consortium_c1_recouvrement/collect_calcadao": "🎯 → Copa (calçadão) : recouvrer auprès des vendeurs",
	"consortium_c2_loyers/collect_condos": "🎯 → Copa (av. Atlântica) : encaisser chez les commerçants",
	"consortium_c3_partenariat/force_signature": "🎯 → Barra (Riserva Uno) : forcer la signature",
	"consortium_c4_vip/drive_vip": "🎯 → Zona Sul (Leblon) : conduire le VIP",
	"consortium_c5_mac/launder_mac": "🎯 → Santos Dumont : blanchir via le MAC",
	"consortium_c6_tioze/hear_concierge": "🎯 → Copa Palace : écouter le concierge",
	"consortium_c7_condos/align_condos": "🎯 → Copa (Atlântica) : aligner les copros",
	"consortium_c8_menace/break_holdout": "🎯 → Niterói : briser le récalcitrant",
	"consortium_c9_pacto/seal_pacto": "🎯 → Barra : sceller le pacte avec Magalhães",
	# --- VOIE PREFEITO (D1 → D9) ---
	"prefeito_d1_peticao/gather_signatures": "🎯 → Copa : faire signer la pétition au calçadão",
	"prefeito_d2_basquete/run_tournament": "🎯 → Aterro (Botafogo) : organiser le tournoi de basket",
	"prefeito_d3_mediation/defuse_conflict": "🎯 → Aterro (Botafogo) : désamorcer le conflit",
	"prefeito_d4_procession/escort_procession": "🎯 → Favela : escorter la procession du Padre",
	"prefeito_d5_rally/lead_rally": "🎯 → Zona Sul (Ipanema) : mener le rallye",
	"prefeito_d6_mac/inaugurate_expo": "🎯 → Maracanã : inaugurer l'expo officielle",
	"prefeito_d7_tioze/receive_dossier": "🎯 → Niterói : recevoir le dossier du concierge",
	"prefeito_d8_campagne/flip_calcadao": "🎯 → Copa (calçadão) : retourner les commerçants",
	"prefeito_d9_eleicao/win_election": "🎯 → Copa : remporter l'élection",
	# SIDE acte 1/2 inter-districts récentes
	"feijoada_bondinho/deliver_summit": "🎯 → Pão de Açúcar : livrer la feijoada (bondinho de Botafogo)",
	"ipanema_yoga/fetch_mat": "🎯 → Zona Sul (Ipanema/Leblon) : récup' du tapis chez le resto",
	"cristo_photo/shoot_cristo": "🎯 → Corcovado : déclencher la photo au mirante",
	"niteroi_envelope/deliver_envelope": "🎯 → Niterói : remettre l'enveloppe face au MAC",
	"maracana_jersey/find_jersey": "🎯 → Botafogo (Aterro) : maillot 71 chez le revendeur",
	"maracana_jersey/return_jersey": "🎯 → Maracanã : rendre le maillot à Seu Wanderley",
	"sambo_plumes/fetch_plumes": "🎯 → Niterói : récupérer les plumes chez Tomé (face MAC)",
	"sambo_plumes/deliver_plumes": "🎯 → Sambódromo : ramener les plumes à Dona Lurdes",
	"barra_brief/deliver_brief": "🎯 → Zona Sul (Leblon) : faire signer Bertoluci",
	"barra_brief/confirm_back": "🎯 → Barra (Riserva Uno) : retour chez l'avocate",
	# SIDE existantes inter-districts
	"beto_lost/find_beto": "🎯 → Copacabana (calçadão) : coincer Beto chez les Ray-Ban",
	"beto_lost/tell_vizinha": "🎯 → Favela : rapporter à Seu Jorge",
	"sofia_bondinho_tour/guide_to_summit": "🎯 → Pão de Açúcar : guide Sofia au sommet (bondinho)",
	"ronaldo_dj_paoacucar/play_set": "🎯 → Pão de Açúcar : jouer le set DJ",
	"ze_invitation/tell_ronaldo": "🎯 → Copacabana (av. Atlântica) : prévenir Ronaldo",
	"consortium_airport_pickup/meet_at_airport": "🎯 → Santos Dumont : récupérer Don Salvatore",
	"consortium_airport_pickup/deliver_to_consortium": "🎯 → Copacabana : ramener à Dom Nilton",
	"escort_contessa/escort_to_bar": "🎯 → Copacabana : escorter la Contessa jusqu'au bar",
	"escort_contessa/escort_back_to_palace": "🎯 → Copacabana Palace : raccompagner la Contessa",
	"bruno_carga/deliver_to_helena": "🎯 → Niterói : livrer la carga à Helena (MAC)",
}

func _active_quest_hint() -> String:
	for qid in QuestManager.get_active_ids():
		var state: Dictionary = QuestManager.get_objectives_state(qid)
		for obj_id in state:
			if state[obj_id]:
				continue  # objectif déjà clos
			var key: String = "%s/%s" % [qid, obj_id]
			if QUEST_NEXT_HINT.has(key):
				return String(QUEST_NEXT_HINT[key])
	return ""

# Vrai si aucune des 4 voies n'a encore été scellée.
func _no_voie_chosen() -> bool:
	for f in CampaignManager.VOIE_FLAGS:
		if CampaignManager.has_flag(f):
			return false
	return true

