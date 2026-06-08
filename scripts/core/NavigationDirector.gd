extends Node

# Cerveau de guidage. Source de vérité unique pour « quel est mon objectif
# MAINTENANT, et où est-il ? ». Toutes les surfaces UI (boussole, bandeau
# d'objectif) ne font que LIRE ce cerveau — elles ne recalculent plus rien
# chacune de leur côté. Autoload name: NavigationDirector.
#
# Deux niveaux :
#   1. La SÉLECTION (_sel) — quel objectif, recalculée uniquement aux
#      changements d'état (quêtes, dette, acte, district, charrette…). Donne le
#      texte (QUOI), le district cible et un ancrage spatial (OÙ).
#   2. La RÉSOLUTION LIVE (get_live) — convertit la sélection en cible écran à
#      chaque frame (positions de PNJ/charrette qui bougent), sans relancer la
#      priorité. C'est ce que la boussole consomme.

signal nav_target_changed()

enum Kind { NONE, POINT, TRAVEL }

# Sentinelle « pas de position résoluble ».
const NO_POS: Vector2 = Vector2(INF, INF)
# Au-delà, on considère que le nœud est dans un AUTRE district (les districts
# sont instanciés très loin, 6000..16000 px) — on ne pointe pas une flèche à
# travers la carte, on bascule en mode voyage.
const MAX_POINT_DIST: float = 5000.0

# Ancrages fixes de Copacabana (cf. CopacabanaGenerator + Copacabana.tscn).
const ANCHOR_CALCADAO: Vector2 = Vector2(1000, 104)
const ANCHOR_ATLANTICA: Vector2 = Vector2(1550, 48)
const ANCHOR_PALACE: Vector2 = Vector2(1700, -18)
const ANCHOR_TAXI: Vector2 = Vector2(1700, 30)
const ANCHOR_CONSORTIUM: Vector2 = Vector2(1550, 48)
# Porte de l'église (Copa) — le Padre vit dans ChurchInterior, on pointe le
# bâtiment à entrer plutôt que le nœud lointain de l'intérieur. CHURCH_X=1500,
# CHURCH_Y=SECOND_ROW_Y(-160) dans CopacabanaGenerator.
const ANCHOR_CHURCH: Vector2 = Vector2(1500, -150)

# Les 4 patrons à goûter en acte 2 (mission intro, sans pacte) puis à sceller en
# acte 3 (pacte = vrai choix de voie). Ordre = priorité de recommandation :
# Copa d'abord (Ramos, Padre) pour un premier pas sans taxi, puis Favela, Barra.
const PATRONS: Array = [
	{"q": "policia_b1_intel",          "dist": "copacabana",   "anchor": "npc:ramos",      "short": "Ramos · Academia (Copa)"},
	{"q": "prefeito_d1_peticao",       "dist": "copacabana",   "anchor": "church",         "short": "Padre · l'église"},
	{"q": "trafico_a1_livraison",      "dist": "favela_morro", "anchor": "npc:tito",       "short": "Tito · Favela"},
	{"q": "consortium_c1_recouvrement","dist": "barra_tijuca", "anchor": "npc:magalhaes",  "short": "Magalhães · Barra"},
]

# Destinations par étape de quête. Clé = "quest_id/obj_id".
# { text, dist (id district cible), anchor (ancrage local si dist == courant), short }
# anchor : "" | "calcadao" | "atlantica" | "palace" | "consortium" | "cart" | "npc:<id>"
# Repris/structuré depuis l'ancien ObjectiveBanner.QUEST_NEXT_HINT — désormais
# source unique ici (le bandeau lit ce cerveau).
const STEP: Dictionary = {
	# --- PROLOGUE : recherche de Pedrinho (1re quête principale) ---
	"prologue_pedrinho/ask_mae": {"text": "🎯 Parle à la mère de Pedrinho (favela)", "dist": "favela_morro", "anchor": "", "short": "La mère"},
	"prologue_pedrinho/ask_vovo": {"text": "🎯 Demande à la vovó ce qu'elle a vu (chez tio Zé)", "dist": "favela_morro", "anchor": "", "short": "Vovó (maison)"},
	"prologue_pedrinho/ask_garoto": {"text": "🎯 Fais parler Juca, le gamin qui jouait avec Pedrinho (favela)", "dist": "favela_morro", "anchor": "", "short": "Juca"},
	"prologue_pedrinho/find_pedrinho": {"text": "🎯 Cherche Pedrinho dans la vieille citerne (haut du morro, près de la chapelle)", "dist": "favela_morro", "anchor": "", "short": "La citerne"},
	"prologue_pedrinho/bring_home": {"text": "🎯 Ramène Pedrinho à sa mère", "dist": "favela_morro", "anchor": "", "short": "La mère"},
	# --- VOIE TRÁFICO (A1 → A9) ---
	"trafico_a1_livraison/drop_calcadao": {"text": "🎯 → Copa (calçadão, face mer) : déposer le paquet au contact", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"trafico_a2_pickup/pickup_palace": {"text": "🎯 → Copa Palace : récupérer la sacoche chez le groom", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"trafico_a3_chauffeur/drive_botafogo": {"text": "🎯 → Botafogo (Bondinho) : conduire le coffre", "dist": "botafogo_flamengo", "anchor": "", "short": "Botafogo"},
	"trafico_a4_ipanema/deal_ipanema": {"text": "🎯 → Zona Sul (Ipanema, posto 9) : refourguer la marchandise", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"trafico_a5_intim/silence_voisin": {"text": "🎯 → Favela : faire taire le voisin qui t'a vu", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"trafico_a6_cagarras/receive_cargo": {"text": "🎯 → Zona Sul (île au large) : réceptionner le chargement (SUP)", "dist": "zona_sul", "anchor": "", "short": "Cagarras"},
	"trafico_a7_tioze/heed_warning": {"text": "🎯 → Copa Palace : écouter le vieux concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"trafico_a8_baia/cross_baia": {"text": "🎯 → Niterói : traverser la baie avec la grosse livraison", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"trafico_a9_corrida/execute_run": {"text": "🎯 → Favela : retrouver Tito pour la corrida finale", "dist": "favela_morro", "anchor": "npc:tito", "short": "Tito (Favela)"},
	# --- VOIE POLÍCIA (B1 → B9) ---
	"policia_b1_intel/report_face": {"text": "🎯 → Copa (calçadão) : rapporter le visage à l'agent en civil", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"policia_b2_filature/map_network": {"text": "🎯 → Copa : cartographier le réseau avec l'agent", "dist": "copacabana", "anchor": "calcadao", "short": "Copa"},
	"policia_b3_escorte/escort_patrol": {"text": "🎯 → Botafogo : conduire la patrouille", "dist": "botafogo_flamengo", "anchor": "", "short": "Botafogo"},
	"policia_b4_descente/bust_dealer": {"text": "🎯 → Zona Sul (Arpoador) : descendre sur le dealer", "dist": "zona_sul", "anchor": "", "short": "Arpoador"},
	"policia_b5_reperage/scout_corcovado": {"text": "🎯 → Corcovado : repérer la remise", "dist": "corcovado", "anchor": "", "short": "Corcovado"},
	"policia_b6_tioze/hear_concierge": {"text": "🎯 → Copa Palace : écouter le concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"policia_b7_saisie/seize_cargo": {"text": "🎯 → Niterói : saisir la cargaison", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"policia_b8_seguranca/secure_crowd": {"text": "🎯 → Maracanã : sécuriser la foule", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"policia_b9_madrugada/complete_madrugada": {"text": "🎯 → Bar do Policial : rejoindre Ramos pour la Madrugada", "dist": "copacabana", "anchor": "npc:ramos", "short": "Ramos"},
	# --- VOIE CONSORTIUM (C1 → C9) ---
	"consortium_c1_recouvrement/collect_calcadao": {"text": "🎯 → Copa (calçadão) : recouvrer auprès des vendeurs", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"consortium_c2_loyers/collect_condos": {"text": "🎯 → Copa (av. Atlântica) : encaisser chez les commerçants", "dist": "copacabana", "anchor": "atlantica", "short": "Av. Atlântica"},
	"consortium_c3_partenariat/force_signature": {"text": "🎯 → Barra (Riserva Uno) : forcer la signature", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	"consortium_c4_vip/drive_vip": {"text": "🎯 → Zona Sul (Leblon) : conduire le VIP", "dist": "zona_sul", "anchor": "", "short": "Leblon"},
	"consortium_c5_mac/launder_mac": {"text": "🎯 → Santos Dumont : blanchir via le MAC", "dist": "santos_dumont", "anchor": "", "short": "Santos Dumont"},
	"consortium_c6_tioze/hear_concierge": {"text": "🎯 → Copa Palace : écouter le concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"consortium_c7_condos/align_condos": {"text": "🎯 → Copa (Atlântica) : aligner les copros", "dist": "copacabana", "anchor": "atlantica", "short": "Av. Atlântica"},
	"consortium_c8_menace/break_holdout": {"text": "🎯 → Niterói : briser le récalcitrant", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"consortium_c9_pacto/seal_pacto": {"text": "🎯 → Barra : sceller le pacte avec Magalhães", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	# --- VOIE PREFEITO (D1 → D9) ---
	"prefeito_d1_peticao/gather_signatures": {"text": "🎯 → Copa : faire signer la pétition au calçadão", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"prefeito_d2_basquete/run_tournament": {"text": "🎯 → Aterro (Botafogo) : organiser le tournoi de basket", "dist": "aterro_flamengo", "anchor": "", "short": "Aterro"},
	"prefeito_d3_mediation/defuse_conflict": {"text": "🎯 → Aterro (Botafogo) : désamorcer le conflit", "dist": "aterro_flamengo", "anchor": "", "short": "Aterro"},
	"prefeito_d4_procession/escort_procession": {"text": "🎯 → Favela : escorter la procession du Padre", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"prefeito_d5_rally/lead_rally": {"text": "🎯 → Zona Sul (Ipanema) : mener le rallye", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"prefeito_d6_mac/inaugurate_expo": {"text": "🎯 → Maracanã : inaugurer l'expo officielle", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"prefeito_d7_tioze/receive_dossier": {"text": "🎯 → Niterói : recevoir le dossier du concierge", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"prefeito_d8_campagne/flip_calcadao": {"text": "🎯 → Copa (calçadão) : retourner les commerçants", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"prefeito_d9_eleicao/win_election": {"text": "🎯 → Copa : remporter l'élection", "dist": "copacabana", "anchor": "atlantica", "short": "Copa"},
	# --- SIDE inter-districts ---
	"feijoada_bondinho/deliver_summit": {"text": "🎯 → Pão de Açúcar : livrer la feijoada (bondinho de Botafogo)", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ipanema_yoga/fetch_mat": {"text": "🎯 → Zona Sul (Ipanema/Leblon) : récup' du tapis chez le resto", "dist": "zona_sul", "anchor": "", "short": "Zona Sul"},
	"cristo_photo/shoot_cristo": {"text": "🎯 → Corcovado : déclencher la photo au mirante", "dist": "corcovado", "anchor": "", "short": "Corcovado"},
	"niteroi_envelope/deliver_envelope": {"text": "🎯 → Niterói : remettre l'enveloppe face au MAC", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"maracana_jersey/find_jersey": {"text": "🎯 → Botafogo (Aterro) : maillot 71 chez le revendeur", "dist": "aterro_flamengo", "anchor": "", "short": "Aterro"},
	"maracana_jersey/return_jersey": {"text": "🎯 → Maracanã : rendre le maillot à Seu Wanderley", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"sambo_plumes/fetch_plumes": {"text": "🎯 → Niterói : récupérer les plumes chez Tomé (face MAC)", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"sambo_plumes/deliver_plumes": {"text": "🎯 → Sambódromo : ramener les plumes à Dona Lurdes", "dist": "sambodromo", "anchor": "", "short": "Sambódromo"},
	"barra_brief/deliver_brief": {"text": "🎯 → Zona Sul (Leblon) : faire signer Bertoluci", "dist": "zona_sul", "anchor": "", "short": "Leblon"},
	"barra_brief/confirm_back": {"text": "🎯 → Barra (Riserva Uno) : retour chez l'avocate", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	"beto_lost/find_beto": {"text": "🎯 → Copacabana (calçadão) : coincer Beto chez les Ray-Ban", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"beto_lost/tell_vizinha": {"text": "🎯 → Favela : rapporter à Seu Jorge", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"sofia_bondinho_tour/guide_to_summit": {"text": "🎯 → Pão de Açúcar : guide Sofia au sommet (bondinho)", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ronaldo_dj_paoacucar/play_set": {"text": "🎯 → Pão de Açúcar : jouer le set DJ", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ze_invitation/tell_ronaldo": {"text": "🎯 → Copacabana (av. Atlântica) : prévenir Ronaldo", "dist": "copacabana", "anchor": "atlantica", "short": "Av. Atlântica"},
	"consortium_airport_pickup/meet_at_airport": {"text": "🎯 → Santos Dumont : récupérer Don Salvatore", "dist": "santos_dumont", "anchor": "", "short": "Santos Dumont"},
	"consortium_airport_pickup/deliver_to_consortium": {"text": "🎯 → Copacabana : ramener à Dom Nilton", "dist": "copacabana", "anchor": "consortium", "short": "Consortium"},
	"escort_contessa/escort_to_bar": {"text": "🎯 → Copacabana : escorter la Contessa jusqu'au bar", "dist": "copacabana", "anchor": "atlantica", "short": "Bar"},
	"escort_contessa/escort_back_to_palace": {"text": "🎯 → Copacabana Palace : raccompagner la Contessa", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"bruno_carga/deliver_to_helena": {"text": "🎯 → Niterói : livrer la carga à Helena (MAC)", "dist": "niteroi", "anchor": "", "short": "Niterói"},
}

# Sélection courante (recalculée aux événements). Voir _S().
var _sel: Dictionary = {}

func _ready() -> void:
	# Mêmes signaux que l'ancien ObjectiveBanner : tout ce qui peut changer
	# l'objectif courant déclenche un recalcul de la sélection.
	EventBus.quest_accepted.connect(_on_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_event)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.corn_cart_state_changed.connect(_on_cart_state)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	DistrictManager.district_changed.connect(_on_district_changed)
	_recompute()

# --- API publique (lue par ObjectiveBanner + Compass) ---

# Texte du QUOI (peut être vide). Lu par le bandeau d'objectif.
func current_text() -> String:
	return _sel.get("text", "")

# Cible résolue pour la frame courante. Lu par la boussole.
# { text, kind, world_pos, label, color }
func get_live() -> Dictionary:
	var out: Dictionary = {
		"text": _sel.get("text", ""),
		"kind": Kind.NONE,
		"world_pos": Vector2.ZERO,
		"label": _sel.get("short", ""),
		"color": Color(0.96, 0.82, 0.36, 1.0),
	}
	if _sel.is_empty() or out.text == "":
		return out
	out.color = voie_color()
	var dist: String = _sel.get("dist", "")
	var cur: String = DistrictManager.current()
	# Cible dans un autre district → mode voyage (la boussole pointe le taxi).
	if dist != "" and dist != cur:
		out.kind = Kind.TRAVEL
		if out.label == "":
			out.label = _short_district(dist)
		return out
	# Même district (ou inconnu) → tente une position précise.
	var pos: Vector2 = _resolve_point(_sel.get("anchor", ""), cur)
	if pos != NO_POS:
		out.kind = Kind.POINT
		out.world_pos = pos
	return out

# --- Calcul de la sélection ---

func _S(text: String, dist: String = "", anchor: String = "", short: String = "") -> Dictionary:
	return {"text": text, "dist": dist, "anchor": anchor, "short": short}

func _recompute() -> void:
	_sel = _compute_selection()
	nav_target_changed.emit()

# Porté depuis ObjectiveBanner._compute_hint : l'ordre des conditions == priorité.
# Différence clé : quand le macro-hint d'acte est générique (acte 3/4, fallback),
# on préfère l'étape précise de la quête active (STEP) — c'est ce qui corrigeait
# le « avance dans ta voie » trop vague.
func _compute_selection() -> Dictionary:
	var act: int = CampaignManager.current_act
	var district: String = DistrictManager.current()
	var debt_paid: int = CampaignManager.debt_paid
	var money: int = _player_money()
	var carrying: bool = _cart_carrying()
	var is_evening: bool = TimeOfDay.current_phase == TimeOfDay.Phase.EVENING

	# --- Prologue + Acte 1 : démarrage ---
	if not CampaignManager.has_flag("act1_started"):
		# La recherche de Pedrinho EST la première quête principale : tant qu'elle
		# est active, on guide ses étapes plutôt que de pousser vers Seu João.
		if QuestManager.is_active("prologue_pedrinho"):
			var pro: Dictionary = _active_step()
			if not pro.is_empty():
				return pro
		if not CampaignManager.has_flag("intro_bump_seen"):
			return _S("🎯 Sors de la maison — Seu João arrive avec des nouvelles")
		return _S("🎯 Parle à tio Zé", "", "npc:seu_joao", "Tio Zé")

	# --- Soir : la famille attend pour le jantar ---
	if is_evening and act <= 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE \
			and district != "favela_morro":
		return _S("🌙 Rentre dîner — tio Zé et mãe attendent", "favela_morro", "", "Maison")

	# --- Acte 1 — clôture : acompte payé (act1_heritage finie) mais retour maison
	#     + nuit chez tio Zé pas encore faits → rentrer parler à tio Zé. C'est CE
	#     retour qui ferme l'acte 1 et ouvre l'acte 2. ---
	if act == 1 and QuestManager.is_completed("act1_heritage") \
			and not CampaignManager.has_flag("act1_closed"):
		if district == "favela_morro":
			return _S("🎯 Rentre dans la maison parler à tio Zé (la nuit va tomber)", "", "npc:seu_joao", "Maison · tio Zé")
		return _S("🎯 Acompte payé — rentre à la favela parler à tio Zé", "favela_morro", "", "Maison · tio Zé")

	# --- Dans la favela ---
	if district == "favela_morro":
		# « Prends la carrocinha » est une instruction d'acte 1 (démarrage du milho).
		# En acte 2+, ne pas la ressortir : la logique d'acte (famille / nuit /
		# patrons) doit prendre la main.
		if act == 1 and not carrying and not CampaignManager.has_flag("first_sale_done"):
			return _S("🎯 Prends la carrocinha à côté de chez tio Zé", "", "cart", "Carrocinha")
		if CampaignManager.has_flag("should_visit_home") and not CampaignManager.has_flag("home_visit_done"):
			return _S("🎯 Monte voir tio Zé et la famille", "", "npc:seu_joao", "Tio Zé")
		# En acte 1, le défaut favela = redescendre vendre. En acte 2+, on laisse
		# la logique d'acte décider (Tito est ici : _patron_target le ciblera).
		if act == 1:
			return _S("🎯 ↓ Descends l'escalier vers Copacabana", "copacabana", "", "↓ Copa")

	# --- Acte 1 sur Copacabana ---
	if act == 1 and district == "copacabana":
		if not CampaignManager.has_flag("met_consortium"):
			return _S("🎯 Va voir Dom Nilton (consortium) sur l'Av. Atlântica", "", "consortium", "Consortium")
		if debt_paid < CampaignManager.ACT1_THRESHOLD:
			var still_to_pay: int = CampaignManager.ACT1_THRESHOLD - debt_paid
			if money >= still_to_pay:
				return _S("🎯 Va déposer %d R$ d'acompte au consortium" % still_to_pay, "", "consortium", "Consortium")
			if not carrying and not CampaignManager.has_flag("first_sale_done"):
				return _S("🎯 Prends la carrocinha (favela) puis vends au calçadão", "favela_morro", "cart", "Favela")
			if carrying:
				return _S("🎯 Sers les clients du calçadão (R$ %d / %d)" % [money, still_to_pay], "", "calcadao", "Calçadão")
			return _S("🎯 Continue de gagner R$ — il manque %d pour l'acompte" % (still_to_pay - money), "", "calcadao", "Calçadão")
		return _S("🎯 Acompte payé — rentre à la favela parler à tio Zé", "favela_morro", "", "Maison · tio Zé")

	# --- Acte 2 : échantillon des 4 patrons (1re mission de chaque voie) ---
	# La clôture de l'acte 1 (retour maison + nuit chez tio Zé) est désormais un
	# prérequis de l'acte 2 — plus besoin de la gérer ici.
	if act == 2:
		if not CampaignManager.has_flag("tito_approached") \
				and not CampaignManager.has_flag("ratted_on_tito") \
				and _no_voie_chosen():
			if district == "favela_morro":
				return _S("🎯 Sors de la maison — Tito veut te parler")
		if debt_paid < CampaignManager.ACT2_THRESHOLD:
			# Si une mission intro de patron est en cours → guider vers SON étape.
			var st2: Dictionary = _active_step()
			if not st2.is_empty():
				return st2
			# Voie déjà scellée → continuer CETTE voie (ne pas renvoyer vers un
			# autre patron qui rejetterait le joueur).
			if not _no_voie_chosen():
				var vc2: Dictionary = _voie_continue()
				if not vc2.is_empty():
					return vc2
			# Sinon → diriger vers un patron concret à goûter (le plus proche).
			var pt2: Dictionary = _patron_target(false)
			if not pt2.is_empty():
				return pt2
			# Tous goûtés → reste à réunir l'argent (milho, missions).
			var still: int = CampaignManager.ACT2_THRESHOLD - debt_paid
			return _S("🎯 Réunis %s R$ (milho au calçadão, missions) pour ouvrir l'acte 3" % still, "", "calcadao", "Calçadão")

	# --- Acte 3 : nudge tant qu'aucune voie n'est scellée ---
	if act == 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE:
		if _no_voie_chosen():
			var ptp: Dictionary = _patron_target(true)
			if not ptp.is_empty():
				return ptp
			return _S("🎯 Le vrai choix : va sceller un pacte (Tito / Ramos / Magalhães / Padre)")
		var st3: Dictionary = _active_step()
		if not st3.is_empty():
			return st3
		# Pas de mission active mais voie scellée → renvoyer vers le patron de la voie.
		var vc3: Dictionary = _voie_continue()
		if not vc3.is_empty():
			return vc3
		if debt_paid < CampaignManager.ACT3_THRESHOLD:
			var still3: int = CampaignManager.ACT3_THRESHOLD - debt_paid
			return _S("🎯 Avance dans ta voie — %s R$ avant les Grands Lances (acte 4)" % still3)

	# --- Acte 4 : Os Grandes Lances ---
	if act == 4:
		var st4: Dictionary = _active_step()
		if not st4.is_empty():
			return st4
		return _S("🎯 Os Grandes Lances — gros coup, couronnement, ou assassinat du consortium")

	# --- Acte 5 : reinado ---
	if act == 5:
		return _S("🎯 Mène ton règne — défilé du Carnaval au Sambódromo", "sambodromo", "", "Sambódromo")

	# Fallback : prochaine étape d'une quête active connue.
	var side: Dictionary = _active_step()
	if not side.is_empty():
		return side
	return {}

# Première étape non close d'une quête active (MAIN prioritaire) présente dans STEP.
func _active_step() -> Dictionary:
	var ids: Array[String] = QuestManager.get_active_ids()
	var mains: Array[String] = []
	var sides: Array[String] = []
	for id in ids:
		var q: Quest = QuestManager.get_quest(id)
		if q != null and q.quest_type == Quest.QuestType.MAIN:
			mains.append(id)
		else:
			sides.append(id)
	var ordered: Array[String] = mains + sides
	for qid in ordered:
		var state: Dictionary = QuestManager.get_objectives_state(qid)
		for obj_id in state:
			if state[obj_id]:
				continue  # objectif déjà clos
			var key: String = "%s/%s" % [qid, obj_id]
			if STEP.has(key):
				return STEP[key]
	return {}

# --- Résolution spatiale ---

func _resolve_point(anchor: String, cur: String) -> Vector2:
	if anchor == "":
		return NO_POS
	if anchor == "cart":
		return _node_pos_guard(get_tree().get_first_node_in_group("corn_cart"))
	if anchor.begins_with("npc:"):
		return _node_pos_guard(NPCScheduler.get_npc(anchor.substr(4)))
	# Ancrages fixes valides uniquement quand on est physiquement à Copacabana.
	if cur == "copacabana":
		match anchor:
			"calcadao": return ANCHOR_CALCADAO
			"atlantica": return ANCHOR_ATLANTICA
			"palace": return ANCHOR_PALACE
			"taxi": return ANCHOR_TAXI
			"consortium": return ANCHOR_CONSORTIUM
			"church": return ANCHOR_CHURCH
	return NO_POS

# Recommande UN patron concret à rejoindre (corrige l'acte 2 « goûte aux 4
# patrons » sans cible). `pacto` = true en acte 3 (sceller la voie : tous les
# patrons restent candidats) ; false en acte 2 (échantillon : on saute ceux dont
# la mission intro est déjà prise ou finie). Préfère un patron du district courant
# pour un pas immédiat, sinon le premier de l'ordre (Copa d'abord).
func _patron_target(pacto: bool) -> Dictionary:
	# Les 4 patrons ne PARLENT qu'une fois la nuit de l'acte 1 passée (act1_closed) :
	# y envoyer le joueur avant = il interagit et le patron ne propose rien. On ne
	# recommande donc un patron qu'à partir de ce moment.
	if not CampaignManager.has_flag("act1_closed"):
		return {}
	# Une voie déjà scellée → on ne suggère plus de patrons (les voies sont
	# mutuellement exclusives ; sinon on envoie le joueur voir un patron qui le
	# rejettera, ex. Ramos après avoir choisi Tito).
	if not _no_voie_chosen():
		return {}
	var cur: String = DistrictManager.current()
	var pool: Array = []
	for p in PATRONS:
		if not pacto and (QuestManager.is_completed(p.q) or QuestManager.is_active(p.q)):
			continue
		pool.append(p)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = {}
	for p in pool:
		if p.dist == cur:
			chosen = p
			break
	if chosen.is_empty():
		chosen = pool[0]
	var verb: String = "sceller un pacte avec" if pacto else "voir"
	return _S("🎯 Va %s %s" % [verb, chosen.short], chosen.dist, chosen.anchor, chosen.short)

# Position d'un nœud, ou NO_POS s'il est invalide / trop loin (= autre district).
func _node_pos_guard(n: Node) -> Vector2:
	if n == null or not is_instance_valid(n) or not (n is Node2D):
		return NO_POS
	var p: Vector2 = (n as Node2D).global_position
	if GameManager.player != null and p.distance_to(GameManager.player.global_position) > MAX_POINT_DIST:
		return NO_POS
	return p

# --- Helpers d'état (repris d'ObjectiveBanner) ---

func _player_money() -> int:
	if GameManager.player == null:
		return 0
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return 0
	return inv.money

func _cart_carrying() -> bool:
	var cart: Node = get_tree().get_first_node_in_group("corn_cart")
	if cart == null or not cart.has_method("is_carrying"):
		return false
	return cart.call("is_carrying")

# Quand une voie est scellée mais qu'aucune mission n'est active, renvoie vers
# le patron de CETTE voie pour décrocher la suite de la chaîne.
func _voie_continue() -> Dictionary:
	if CampaignManager.has_flag("voie_trafico"):
		return _S("🎯 Continue ta voie Tráfico — retrouve Tito à la Favela", "favela_morro", "npc:tito", "Tito · Favela")
	if CampaignManager.has_flag("voie_policia"):
		return _S("🎯 Continue ta voie Polícia — retrouve Ramos", "copacabana", "npc:ramos", "Ramos · Academia (Copa)")
	if CampaignManager.has_flag("voie_consortium"):
		return _S("🎯 Continue ta voie Consórcio — retrouve Magalhães (Barra)", "barra_tijuca", "npc:magalhaes", "Magalhães · Barra")
	if CampaignManager.has_flag("voie_prefeito"):
		return _S("🎯 Continue ta voie Prefeito — retrouve le Padre (église)", "copacabana", "church", "Padre · l'église")
	return {}

func _no_voie_chosen() -> bool:
	for f in CampaignManager.VOIE_FLAGS:
		if CampaignManager.has_flag(f):
			return false
	return true

# Couleur d'identité de la voie scellée (boussole + bord du panneau Objectif).
# Doré tant qu'aucune voie n'est choisie.
func voie_color() -> Color:
	if CampaignManager.has_flag("voie_trafico"):
		return Color(0.92, 0.55, 0.3, 1.0)   # orange — morro
	if CampaignManager.has_flag("voie_policia"):
		return Color(0.4, 0.62, 0.95, 1.0)    # bleu — police
	if CampaignManager.has_flag("voie_consortium"):
		return Color(0.62, 0.38, 0.62, 1.0)   # violet — consórcio
	if CampaignManager.has_flag("voie_prefeito"):
		return Color(0.55, 0.85, 0.55, 1.0)   # vert — prefeito
	return Color(0.96, 0.82, 0.36, 1.0)        # doré — pas encore de voie

# Label court d'un district (« Niterói — barcas… » → « Niterói »).
func _short_district(dist: String) -> String:
	var label: String = DistrictManager.get_label(dist)
	var dash: int = label.find(" —")
	return label.substr(0, dash) if dash > 0 else label

# --- Réactions aux événements ---

func _on_event(_id: String) -> void: _recompute()
func _on_quest_updated(_q: String, _o: String) -> void: _recompute()
func _on_debt_paid(_a: int, _r: int) -> void: _recompute()
func _on_act_changed(_act: int) -> void: _recompute()
func _on_district_changed(_d: String) -> void: _recompute()
func _on_cart_state(_c: bool) -> void: _recompute()
func _on_money_changed(_a: int) -> void: _recompute()
func _on_customer_served(_id: String) -> void: _recompute()
func _on_phase_changed(_p: int) -> void: _recompute()
