extends Node

# Base commune des tests d'intégration headless : compteurs, _assert/_section,
# helpers et constantes partagés. Les groupes (scripts/tests/groups/) en
# héritent ; le runner IntegrationTest.gd les orchestre.
#
# Vérifie que le jeu est jouable et terminable. Exécution : `./run_tests.sh`
# (godot --headless) ou lancement direct de scenes/tests/IntegrationTest.tscn
# depuis l'éditeur. Simule le parcours complet de chaque voie :
#   Acte 1 → 500 R$ → Acte 2 → 2000 R$ → Acte 3 → 6000 R$ → couronnement
#   (solde la dette de 50000 R$) → acte 5.
# Vérifie aussi l'intégrité des .tres de quêtes, des données NPC, et du graphe
# de dialogues (next / accept_quest / finish_quest cohérents).
#
# Sortie : exit code 0 si tout passe, 1 sinon. Log lisible à l'écran.

const QUEST_RESOURCES: Array[String] = [
	"res://resources/quests/prologue_pedrinho.tres",
	"res://resources/quests/trafico_a1_livraison.tres",
	"res://resources/quests/trafico_a2_pickup.tres",
	"res://resources/quests/trafico_a3_chauffeur.tres",
	"res://resources/quests/trafico_a4_ipanema.tres",
	"res://resources/quests/trafico_a5_intim.tres",
	"res://resources/quests/trafico_a6_cagarras.tres",
	"res://resources/quests/trafico_a7_tioze.tres",
	"res://resources/quests/trafico_a8_baia.tres",
	"res://resources/quests/trafico_a9_corrida.tres",
	"res://resources/quests/policia_b1_intel.tres",
	"res://resources/quests/policia_b2_filature.tres",
	"res://resources/quests/policia_b3_escorte.tres",
	"res://resources/quests/policia_b4_descente.tres",
	"res://resources/quests/policia_b5_reperage.tres",
	"res://resources/quests/policia_b6_tioze.tres",
	"res://resources/quests/policia_b7_saisie.tres",
	"res://resources/quests/policia_b8_seguranca.tres",
	"res://resources/quests/policia_b9_madrugada.tres",
	"res://resources/quests/consortium_c1_recouvrement.tres",
	"res://resources/quests/consortium_c2_loyers.tres",
	"res://resources/quests/consortium_c3_partenariat.tres",
	"res://resources/quests/consortium_c4_vip.tres",
	"res://resources/quests/consortium_c5_mac.tres",
	"res://resources/quests/consortium_c6_tioze.tres",
	"res://resources/quests/consortium_c7_condos.tres",
	"res://resources/quests/consortium_c8_menace.tres",
	"res://resources/quests/consortium_c9_pacto.tres",
	"res://resources/quests/prefeito_d1_peticao.tres",
	"res://resources/quests/prefeito_d2_basquete.tres",
	"res://resources/quests/prefeito_d3_mediation.tres",
	"res://resources/quests/prefeito_d4_procession.tres",
	"res://resources/quests/prefeito_d5_rally.tres",
	"res://resources/quests/prefeito_d6_mac.tres",
	"res://resources/quests/prefeito_d7_tioze.tres",
	"res://resources/quests/prefeito_d8_campagne.tres",
	"res://resources/quests/prefeito_d9_eleicao.tres",
	"res://resources/quests/act1_heritage.tres",
	"res://resources/quests/quest_milho_01.tres",
	"res://resources/quests/deliver_package_01.tres",
	"res://resources/quests/find_bracelet_01.tres",
	"res://resources/quests/ze_invitation.tres",
	"res://resources/quests/livraison_cocos.tres",
	"res://resources/quests/police_report.tres",
	"res://resources/quests/pedros_son.tres",
	"res://resources/quests/flowers_for_beatriz.tres",
	"res://resources/quests/bike_delivery.tres",
	"res://resources/quests/church_statue.tres",
	"res://resources/quests/pharmacy_tito.tres",
	"res://resources/quests/escort_contessa.tres",
	"res://resources/quests/lost_dog.tres",
	"res://resources/quests/bar_waiter.tres",
	"res://resources/quests/padaria_delivery.tres",
	"res://resources/quests/padaria_baking.tres",
	"res://resources/quests/valet_palace.tres",
	"res://resources/quests/act2_pecheur_secret.tres",
	"res://resources/quests/act2_contessa_gala.tres",
	"res://resources/quests/padre_corcovado_relic.tres",
	"res://resources/quests/ronaldo_dj_paoacucar.tres",
	"res://resources/quests/carlos_lagoa_volta.tres",
	"res://resources/quests/contessa_date.tres",
	"res://resources/quests/tourist_vip_tour.tres",
	"res://resources/quests/ronaldo_maracana_torcida.tres",
	"res://resources/quests/consortium_airport_pickup.tres",
	"res://resources/quests/ronaldo_aterro_basket.tres",
	"res://resources/quests/lucas_arpoador_surf.tres",
	"res://resources/quests/camila_ipanema_volley.tres",
	"res://resources/quests/diego_botafogo_capoeira.tres",
	"res://resources/quests/sofia_bondinho_tour.tres",
	"res://resources/quests/act4_carnaval_desfile.tres",
	"res://resources/quests/beto_lost.tres",
	"res://resources/quests/feijoada_bondinho.tres",
	"res://resources/quests/ipanema_yoga.tres",
	"res://resources/quests/cristo_photo.tres",
	"res://resources/quests/niteroi_envelope.tres",
	"res://resources/quests/maracana_jersey.tres",
	"res://resources/quests/assassinate_consortium.tres",
	"res://resources/quests/act4_palace_heist.tres",
	"res://resources/quests/act4_sambo_sabotage.tres",
	"res://resources/quests/act4_tio_ze_rescue.tres",
	"res://resources/quests/act4_press_expose.tres",
	"res://resources/quests/act4_bondinho_drop.tres",
	"res://resources/quests/sambo_plumes.tres",
	"res://resources/quests/barra_brief.tres",
	"res://resources/quests/zona_sul_envelope.tres",
	"res://resources/quests/consortium_barra_security.tres",
	"res://resources/quests/consortium_le_parc.tres",
	"res://resources/quests/consortium_peninsula.tres",
	"res://resources/quests/pacto_barra.tres",
	"res://resources/quests/bruno_carga.tres",
	"res://resources/quests/bruno_pesca_baia.tres",
	"res://resources/quests/quiz_maracana.tres",
	"res://resources/quests/baia_smuggle_intro.tres",
	"res://resources/quests/baia_silence_press.tres",
	"res://resources/quests/baia_pacto.tres",
]

const NPC_DATA_DIR: String = "res://resources/npcs/"

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

# --- Helpers ---

func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  [✓] %s" % label)
	else:
		_failed += 1
		_failures.append(label)
		print("  [X] %s" % label)

func _section(name: String) -> void:
	print("")
	print("— %s —" % name)

func _list_scenes_under(root: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = root + entry
		if dir.current_is_dir():
			out.append_array(_list_scenes_under(full + "/"))
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	return out

# Pour chaque knot avec on_choose, l'index de chaque choix doit être < taille
# du tableau choices, et chaque action doit avoir au moins une primitive connue
# (next, accept_quest, finish_quest, set_flag, set_endgame, pay_debt, pay_bribe,
# earn, rep). Un choix sans action ferme implicitement le dialogue (autorisé).
const KNOWN_VERBS: Array = [
	"next", "accept_quest", "finish_quest", "set_flag", "set_endgame",
	"pay_debt", "pay_bribe", "earn", "rep", "return_cart", "complete_minigame",
]

# Knots référencés par les NPC dispatchers. Si un NPC essaie de jouer un knot
# inexistant, le dialogue se ferme silencieusement et le joueur est perdu —
# c'est le scénario soft-lock le plus pernicieux. On vérifie en dur que tous
# sont présents dans PLACEHOLDER_DIALOGUES.
# Knots de routing post-refonte : pactes de voie + SIDE conservés. Le légacy
# act1_meet/act2/act3/act4 a été supprimé (voies A/B/C/D via spots).
const NPC_DISPATCH_KNOTS: Dictionary = {
	"seu_joao": [
		"seu_joao_heritage", "seu_joao_intro_tutorial", "seu_joao_intro",
		"seu_joao_reminder", "seu_joao_return",
		"seu_joao_prologue_nudge", "seu_joao_prologue_remind",
		"seu_joao_carnaval_offer", "seu_joao_carnaval_remind", "seu_joao_carnaval_done",
		"seu_joao_evening_first_payment", "seu_joao_evening_carnaval_eve",
		"seu_joao_ng_plus_intro",
	],
	"vizinha": [
		"mae_prologue_offer", "mae_prologue_offer_b", "mae_prologue_plea",
	],
	"tito": [
		"tito_encounter", "tito_receives_medicine",
		"tito_pacto_trafico_offer", "tito_pacto_trafico_remind", "tito_trafico_corrida",
	],
	"ramos": [
		"ramos_intro", "ramos_chat_warm", "ramos_chat_familiar",
		"ramos_commissaire_alerted",
		"ramos_pacto_policia_offer", "ramos_pacto_policia_remind", "ramos_policia_madrugada",
	],
	"padre": [
		"padre_receives", "padre_remind", "padre_thanks",
		"padre_corcovado_offer", "padre_corcovado_remind", "padre_corcovado_receives",
		"padre_pacto_prefeito_offer", "padre_pacto_prefeito_remind", "padre_prefeito_eleicao",
	],
	"magalhaes": [
		"magalhaes_pacto_consortium_offer", "magalhaes_pacto_consortium_remind",
		"magalhaes_consortium_pacto", "magalhaes_consortium_done",
	],
	"miguel": [
		"miguel_waiting", "miguel_done",
	],
	"pm": [
		"cop_shakedown",
		"cop_shakedown_recurring", "cop_shakedown_recurring_act2", "cop_shakedown_recurring_act3",
	],
	"consortium": [
		"consortium_intro", "consortium_threat", "consortium_pay",
		"consortium_after_threshold", "consortium_settled",
		"consortium_airport_offer", "consortium_airport_remind", "consortium_airport_done",
		"consortium_act3_intro",
	],
	"caldeira": [
		"caldeira_offer", "caldeira_remind_deliver", "caldeira_remind_verify",
		"caldeira_return", "caldeira_after_done",
	],
	"bandeira": [
		"bandeira_receive", "bandeira_after_received", "bandeira_after_done", "bandeira_default",
	],
	"ivan": [
		"ivan_verify", "ivan_after_verified", "ivan_after_done", "ivan_default",
	],
}

# Spots quêteurs visibles : un ReactiveDialogueSpot sans character_seed ni
# character_appearance ne dessine RIEN — le joueur ne peut pas le trouver
# (cas « le contact du capitão est introuvable »). Tout spot est censé être un
# personnage SAUF ceux explicitement logiques (un lieu qu'on inspecte).
const _LOGICAL_SPOTS: Array = ["PedrinhoSpot"]  # « Inspecter la citerne » (lieu)

func _check_spots_visible(root: Node, scene: String) -> void:
	for node in _all_descendants(root):
		if not (node is ReactiveDialogueSpot):
			continue
		if _LOGICAL_SPOTS.has(String(node.name)):
			continue
		var visible_sprite: bool = int(node.character_seed) != 0 \
				or not (node.character_appearance as Dictionary).is_empty()
		_assert(visible_sprite,
			"%s : spot '%s' (npc=%s) a un sprite (sinon introuvable)"
				% [scene, node.name, String(node.npc_id)])

func _all_descendants(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_descendants(c))
	return out

func _check_spot_actions(root: Node, scene: String) -> void:
	for node in _all_descendants(root):
		if not (node is ReactiveDialogueSpot):
			continue
		for variant in (node.variants as Array):
			var v: Dictionary = variant as Dictionary
			var actions: Dictionary = v.get("actions", {})
			if actions.has("accept_quest"):
				var qid: String = String(actions["accept_quest"])
				_assert(QuestManager._quests.has(qid),
					"%s/%s : accept_quest '%s' existe"
						% [scene, node.name, qid])
			if actions.has("finish_quest"):
				var info: Dictionary = actions["finish_quest"]
				var qid2: String = String(info.get("quest", ""))
				var oid: String = String(info.get("objective", ""))
				var q: Quest = QuestManager._quests.get(qid2) as Quest
				_assert(q != null,
					"%s/%s : finish_quest quête '%s' existe"
						% [scene, node.name, qid2])
				if q != null:
					var found: bool = false
					for o in q.objectives:
						if String(o.id) == oid:
							found = true
							break
					_assert(found,
						"%s/%s : objectif '%s' existe sur '%s'"
							% [scene, node.name, oid, qid2])

# Anti ping-pong : un Marker2D de spawn placé DANS l'Area2D d'un DistrictExit
# fait re-déclencher la sortie dès l'arrivée → le joueur est renvoyé en boucle
# et le quartier devient inatteignable (cas PaoAcucar : on n'arrivait jamais au
# pão, on finissait à Barra). On vérifie chaque district : aucun spawn ne doit
# tomber dans un exit (marge = demi-corps joueur).
const _SPAWN_EXIT_MARGIN: float = 24.0

func _check_spawns_vs_exits(root: Node, scene: String) -> void:
	var spawns: Array = []
	var exits: Array = []
	for child in root.get_children():
		if child is Marker2D and String(child.name).begins_with("PlayerSpawn"):
			spawns.append(child)
		if child is DistrictExit:
			exits.append(child)
	for spawn in spawns:
		var sp: Vector2 = (spawn as Marker2D).global_position
		for exit in exits:
			var cs: CollisionShape2D = exit.get_node_or_null("CollisionShape2D")
			if cs == null or not (cs.shape is RectangleShape2D):
				continue
			var half: Vector2 = (cs.shape as RectangleShape2D).size * 0.5
			var c: Vector2 = cs.global_position
			var inside: bool = absf(sp.x - c.x) < half.x + _SPAWN_EXIT_MARGIN \
					and absf(sp.y - c.y) < half.y + _SPAWN_EXIT_MARGIN
			_assert(not inside, "%s : spawn '%s' hors de '%s'"
					% [scene, spawn.name, exit.name])

# Anti ping-pong piéton : un WALK_ENTRY (point d'arrivée à pied) qui tombe DANS
# l'Area2D de la sortie pointant vers le district source renvoie immédiatement
# le joueur d'où il vient. Cas réel : passage Botafogo↔ZonaSul / Barra↔ZonaSul.
# Pour chaque district avec WALK_ENTRIES, on vérifie que chaque point d'arrivée
# est hors de la sortie qui pointe vers le from_id correspondant.
const _DISTRICT_SCENE_PATHS: Dictionary = {
	"favela_morro":      "res://scenes/districts/FavelaDoMorro.tscn",
	"zona_sul":          "res://scenes/districts/ZonaSul.tscn",
	"botafogo_flamengo": "res://scenes/districts/BotafogoFlamengo.tscn",
	"corcovado":         "res://scenes/districts/Corcovado.tscn",
	"maracana":          "res://scenes/districts/Maracana.tscn",
	"santos_dumont":     "res://scenes/districts/SantosDumont.tscn",
	"pao_acucar":        "res://scenes/districts/PaoAcucar.tscn",
	"sambodromo":        "res://scenes/districts/Sambodromo.tscn",
	"barra_tijuca":      "res://scenes/districts/BarraDaTijuca.tscn",
	"niteroi":           "res://scenes/districts/Niteroi.tscn",
}

# Cinématiques scriptées : chacune utilise walk_npc_to(npc_id) + say(npc_id, knot).
# Si le knot disparaît ou si le NPCData n'a pas l'id attendu, la cutscene se
# bloque silencieusement. On vérifie ici les dépendances connues.
const CUTSCENE_REQUIREMENTS: Array = [
	{"name": "IntroSeuJoao", "npcs": ["seu_joao"], "knots": ["seu_joao_heritage", "seu_joao_intro_tutorial", "seu_joao_ng_plus_intro"]},
	{"name": "Act3IntroCutscene", "npcs": ["consortium"], "knots": ["consortium_act3_intro"]},
	# FirstShakedownCutscene : PMPatrol n'a pas de NPCData (id "pm" attribué directement
	# dans DialogueBridge.start_dialogue), on vérifie juste le knot.
	{"name": "FirstShakedownCutscene", "npcs": [], "knots": ["cop_shakedown"]},
]

# Chaque ReactiveDialogueSpot doit avoir au moins une variante sans condition
# (ou avec des conditions toujours vraies par défaut). Sinon, dans un état où
# aucune variante ne match, _pick_variant retourne {} et l'interaction est
# silencieuse — le joueur clique et rien ne se passe. Soft-lock invisible.
const REACTIVE_SPOTS: Array = [
	{"scene": "res://scenes/interiors/HouseInterior.tscn", "spots": ["MotherSpot", "GrandmaSpot"]},
	{"scene": "res://scenes/districts/FavelaDoMorro.tscn", "spots": ["VizinhaSpot"]},
	{"scene": "res://scenes/world/Copacabana.tscn", "spots": ["BetoSpot"]},
]

func _find_by_name_in(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found: Node = _find_by_name_in(child, target)
		if found:
			return found
	return null

# Pour chaque quête, vérifie que chaque objectif est référencé quelque part
# dans le graphe dialogues via finish_quest, OU dans une des sources scriptées
# connues (CarnavalLauncher, mini-jeux, etc.). Un objectif sans complétion =
# quête bloquante.
# Carte des objectifs complétés depuis le code script (pas via dialogue
# finish_quest). Sources : minigame launchers, DeliveryPoint nodes, Pickable
# nodes, CornCart, _link_quest_on_flag dans DialogueBridge, MainBoot
# (district_changed pour tour VIP), pay_debt branche acte 1.
const SCRIPT_COMPLETED_OBJECTIVES: Dictionary = {
	# Acte 1 — completés via DialogueBridge.pay_debt + _link_quest_on_flag.
	"act1_heritage": ["meet_consortium", "earn_seed_money", "first_payment"],
	# Charrette milho — CornCart.gd
	"quest_milho_01": ["pickup_cart", "return_cart", "sell_all"],
	# DeliveryPoint nodes (scenes/world/Copacabana.tscn)
	"deliver_package_01": ["deliver"],
	# Pickable nodes (Bracelet, Statue, LostDog) — completion à l'interaction
	"find_bracelet_01": ["find_bracelet"],
	"church_statue": ["find_statue"],
	"lost_dog": ["find_dog"],
	# Mini-jeux : leurs Launchers complètent l'objectif final.
	"valet_palace": ["first_valet_shift"],
	"bike_delivery": ["one_delivery"],
	"carlos_lagoa_volta": ["complete_lap"],
	"padaria_baking": ["first_batch"],
	"act4_carnaval_desfile": ["lead_samba"],
	"ronaldo_dj_paoacucar": ["play_set"],
	"ronaldo_maracana_torcida": ["lead_torcida"],
	"ronaldo_aterro_basket": ["win_basket_session"],
	"lucas_arpoador_surf": ["win_surf_session"],
	"camila_ipanema_volley": ["win_volley_match"],
	"diego_botafogo_capoeira": ["tip_diego"],
	"sofia_bondinho_tour": ["guide_to_summit"],
	"bruno_pesca_baia": ["haul_baia"],
	# Viewpoint dans le district Corcovado.
	"padre_corcovado_relic": ["bless_at_corcovado"],
	# MainBoot._on_district_changed coche les étapes du tour à l'arrivée.
	"tourist_vip_tour": ["see_corcovado", "see_paoacucar", "see_lagoa"],
	# Prologue — enfant disparu, objectifs complétés via ReactiveDialogueSpot
	# (mère/vovó/Juca/Pedrinho), pas dans PLACEHOLDER.
	"prologue_pedrinho": ["ask_mae", "ask_vovo", "ask_garoto", "find_pedrinho", "bring_home"],
	# Voie Tráfico A1–A3 : drop/pickup via TraficoContactSpot (runtime),
	# drive_botafogo auto-coché par MainBoot à l'arrivée à Botafogo.
	"trafico_a1_livraison": ["drop_calcadao"],
	"trafico_a2_pickup": ["pickup_palace"],
	"trafico_a3_chauffeur": ["drive_botafogo"],
	# A4–A8 : objectifs complétés via ReactiveDialogueSpot (Zona Sul / favela /
	# Cagarras / Palace / Niterói). A9 execute_run via knot PLACEHOLDER Tito.
	"trafico_a4_ipanema": ["deal_ipanema"],
	"trafico_a5_intim": ["silence_voisin"],
	"trafico_a6_cagarras": ["receive_cargo"],
	"trafico_a7_tioze": ["heed_warning"],
	"trafico_a8_baia": ["cross_baia"],
	# Voie Polícia B1–B8 : objectifs via ReactiveDialogueSpot. B9
	# complete_madrugada via knot PLACEHOLDER ramos_policia_madrugada.
	"policia_b1_intel": ["report_face"],
	"policia_b2_filature": ["map_network"],
	"policia_b3_escorte": ["escort_patrol"],
	"policia_b4_descente": ["bust_dealer"],
	"policia_b5_reperage": ["scout_corcovado"],
	"policia_b6_tioze": ["hear_concierge"],
	"policia_b7_saisie": ["seize_cargo"],
	"policia_b8_seguranca": ["secure_crowd"],
	# Voie Consortium C1–C8 : objectifs via ReactiveDialogueSpot. C9 seal_pacto
	# via knot PLACEHOLDER magalhaes_consortium_pacto.
	"consortium_c1_recouvrement": ["collect_calcadao"],
	"consortium_c2_loyers": ["collect_condos"],
	"consortium_c3_partenariat": ["force_signature"],
	"consortium_c4_vip": ["drive_vip"],
	"consortium_c5_mac": ["launder_mac"],
	"consortium_c6_tioze": ["hear_concierge"],
	"consortium_c7_condos": ["align_condos"],
	"consortium_c8_menace": ["break_holdout"],
	# Voie Prefeito D1–D8 : objectifs via ReactiveDialogueSpot. D9 win_election
	# via knot PLACEHOLDER padre_prefeito_eleicao.
	"prefeito_d1_peticao": ["gather_signatures"],
	"prefeito_d2_basquete": ["run_tournament"],
	"prefeito_d3_mediation": ["defuse_conflict"],
	"prefeito_d4_procession": ["escort_procession"],
	"prefeito_d5_rally": ["lead_rally"],
	"prefeito_d6_mac": ["inaugurate_expo"],
	"prefeito_d7_tioze": ["receive_dossier"],
	"prefeito_d8_campagne": ["flip_calcadao"],
	# Side quest favela — ReactiveDialogueSpot actions.
	"beto_lost": ["find_beto", "tell_vizinha"],
	"feijoada_bondinho": ["deliver_summit"],
	"ipanema_yoga": ["fetch_mat"],
	"cristo_photo": ["shoot_cristo"],
	"niteroi_envelope": ["deliver_envelope"],
	"maracana_jersey": ["find_jersey", "return_jersey"],
	"sambo_plumes": ["fetch_plumes", "deliver_plumes"],
	"barra_brief": ["deliver_brief", "confirm_back"],
	# Side quest Barra Riserva Uno — Magalhães script + Nilton dialog actions.
	# Acte 4 (Os Grandes Lances) — FixerSpot variants.
	"assassinate_consortium": ["execute_hit"],
	"act4_palace_heist": ["loot_palace_safe"],
	"act4_sambo_sabotage": ["sabotage_rival_float"],
	"act4_tio_ze_rescue": ["free_tio_ze"],
	"act4_press_expose": ["deliver_dossier"],
	"act4_bondinho_drop": ["drop_cash_summit"],
	"consortium_barra_security": ["intimidate_magalhaes", "close_deal"],
	"consortium_le_parc": ["intimidate_carrasco", "close_deal_carrasco"],
	"consortium_peninsula": ["intimidate_mendonca", "close_deal_mendonca"],
}

# Réinitialise l'état campagne/quêtes pour une simulation propre.
func _reset_campaign_state() -> void:
	QuestManager._state.clear()
	QuestManager._objectives.clear()
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags.clear()
	for path in QUEST_RESOURCES:
		if ResourceLoader.exists(path):
			var q: Resource = load(path)
			if q is Quest:
				QuestManager.register_quest(q)
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, 0)

# Driver générique : joue une voie de bout en bout via les VRAIS mécanismes
# (knot du pacte → ReactiveDialogueSpots pilotés au doigt → hooks d'arrivée →
# knot du couronnement → Carnaval → Épilogue). Le joueur « erre » : à chaque
# cycle on interagit tous les spots de la voie ; chaque spot n'agit que si sa
# variante matche l'état courant → robuste à l'ordre close/offer.
func _run_voie_e2e(cfg: Dictionary) -> void:
	_section("Jouabilité — voie %s de bout en bout (mécanismes réels)" % cfg.name)
	_reset_campaign_state()
	_complete_quest_all_objectives("prologue_pedrinho")
	_complete_quest_all_objectives("act1_heritage")
	_assert(QuestManager.is_completed("prologue_pedrinho"), "%s : prologue résolu" % cfg.name)
	_assert(QuestManager.is_completed("act1_heritage"), "%s : 1er acompte payé" % cfg.name)
	# La chaîne d'une voie (q2 → q9) se joue en ACTE 3 : en acte 2 seules les
	# 1res missions (a1/b1/c1/d1) sont accessibles. On place donc l'acte 3 avant
	# de sceller le pacte et de dérouler la chaîne.
	CampaignManager.current_act = 3

	# Pacte avec le patron (knot PLACEHOLDER, comme au doigt dans le dialogue).
	DialogueBridge.start_dialogue(cfg.pact_npc, cfg.pact_knot)
	DialogueBridge.choose(0)
	_assert(CampaignManager.has_flag(cfg.voie_flag), "%s : pacte engagé" % cfg.name)
	_assert(QuestManager.is_active(cfg.q1), "%s : 1re mission acceptée via le pacte" % cfg.name)

	# Instancie chaque scène utilisée une seule fois, met en cache les spots.
	var inst: Dictionary = {}
	var spots: Array = []
	for st in cfg.stations:
		var sp: String = st[0]
		if not inst.has(sp):
			inst[sp] = (load(sp) as PackedScene).instantiate()
			add_child(inst[sp])
	await get_tree().process_frame
	await get_tree().process_frame
	for st in cfg.stations:
		var node: Node = _find_by_name_in(inst[st[0]], st[1])
		_assert(node != null, "%s : spot '%s' présent (in-game)" % [cfg.name, st[1]])
		if node:
			spots.append(node)

	# Boucle « joueur qui circule » : interagit tous les spots jusqu'à ce que
	# la dernière mission (Q9) soit acceptée (prête pour le couronnement).
	var cycles: int = 26
	while not (QuestManager.is_active(cfg.q9) or QuestManager.is_completed(cfg.q9)) and cycles > 0:
		for spot in spots:
			spot._on_interacted(null)
			if DialogueBridge.is_active():
				DialogueBridge.choose(0)
		for ar in cfg.get("arrival", []):
			if QuestManager.is_active(ar[0]):
				var os: Dictionary = QuestManager.get_objectives_state(ar[0])
				if not os.get(ar[1], false):
					QuestManager.complete_objective(ar[0], ar[1])
		cycles -= 1
	_assert(QuestManager.is_active(cfg.q9) or QuestManager.is_completed(cfg.q9),
		"%s : chaîne parcourue jusqu'au couronnement (Q9)" % cfg.name)
	for sp in inst:
		inst[sp].queue_free()
	await get_tree().process_frame

	# Couronnement : knot du patron → set_endgame.
	DialogueBridge.start_dialogue(cfg.pact_npc, cfg.crown_knot)
	DialogueBridge.choose(0)
	_assert(CampaignManager.chosen_endgame == cfg.endgame,
		"%s : couronnement → endgame scellé" % cfg.name)
	_assert(CampaignManager.current_act == 5, "%s : acte 5 atteint (règne)" % cfg.name)

	# Finale : Carnaval → Épilogue (jeu terminable).
	_assert(QuestManager.is_available("act4_carnaval_desfile"),
		"%s : act4_carnaval_desfile disponible" % cfg.name)
	QuestManager.accept("act4_carnaval_desfile")
	QuestManager.complete_objective("act4_carnaval_desfile", "lead_samba")
	_assert(QuestManager.is_completed("act4_carnaval_desfile"),
		"%s : Carnaval mené → Épilogue débloqué" % cfg.name)
	_reset_campaign_state()

const _COPA: String = "res://scenes/world/Copacabana.tscn"
const _FAVELA: String = "res://scenes/districts/FavelaDoMorro.tscn"
const _BOTAFOGO: String = "res://scenes/districts/BotafogoFlamengo.tscn"
const _ZONASUL: String = "res://scenes/districts/ZonaSul.tscn"
const _CORCOVADO: String = "res://scenes/districts/Corcovado.tscn"
const _NITEROI: String = "res://scenes/districts/Niteroi.tscn"
const _MARACANA: String = "res://scenes/districts/Maracana.tscn"
const _BARRA: String = "res://scenes/districts/BarraDaTijuca.tscn"
const _SANTOS: String = "res://scenes/districts/SantosDumont.tscn"

# Simulation complète d'une voie : pose la rep nécessaire, paie la dette
# jusqu'au seuil, accepte les quêtes acte 3 + 4, complète chaque objectif
# attendu, vérifie qu'on atteint le moment épilogue (act4_carnaval_desfile
# is_completed). Trois sims distinctes pour les trois voies.

func _complete_quest_all_objectives(quest_id: String) -> void:
	if QuestManager.is_completed(quest_id):
		return
	if not QuestManager.is_active(quest_id):
		QuestManager.accept(quest_id)
	var q: Quest = QuestManager._quests.get(quest_id)
	if q == null:
		return
	for obj in q.objectives:
		if not obj.optional:
			QuestManager.complete_objective(quest_id, obj.id)

# Niveau 1 : géométrie des sorties de district. Pour chaque district scene :
#   1. Au moins une `DistrictExit` doit exister (le joueur peut sortir).
#   2. Chaque `DistrictExit` doit avoir une CollisionShape2D suffisamment grande
#      pour ne pas créer de soft-lock — minimum 8000 px² OU largeur ≥ 200 px
#      perpendiculairement aux murs adjacents.
#   3. Pour chaque mur perpendiculaire à la sortie (mur du fond), la sortie doit
#      couvrir au moins 50% de sa largeur — sinon un joueur descendant en biais
#      finit coincé sans déclencher la trigger (le bug de la favela).
const EXIT_MIN_AREA: float = 8000.0
const EXIT_MIN_COVERAGE_RATIO: float = 0.5
# Exits narratifs étroits (départ SUP, etc.) — exemptés du test de couverture.
const _NARRATIVE_EXITS: Array = ["ExitToCagarras"]

# Districts piétons-marchables (cf. DistrictManager.WALK_ENTRIES). Les autres
# (Corcovado, PaoAcucar, etc.) sont accédés uniquement en taxi par design —
# pas besoin d'une DistrictExit piétonne, le retour est géré par TaxiStand.
const WALKABLE_DISTRICT_SCENES: Array = [
	"FavelaDoMorro.tscn",
	"ZonaSul.tscn",
	"BotafogoFlamengo.tscn",
]

# Parcourt l'arbre, collecte les DistrictExit et les StaticBody2D nommés "wall"
# (ou avec un parent nommé "Walls", convention du codebase).
func _collect_exits_and_walls(root: Node, exits: Array, walls: Array) -> void:
	if root is DistrictExit:
		exits.append(root)
	if root is StaticBody2D and root.get_parent() and root.get_parent().name == "Walls":
		walls.append(root)
	for child in root.get_children():
		_collect_exits_and_walls(child, exits, walls)

func _exit_collision_size(exit_node: Node) -> Vector2:
	for child in exit_node.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			return ((child as CollisionShape2D).shape as RectangleShape2D).size
	return Vector2.ZERO

# Pour chaque mur du Walls/, regarde s'il est sur la trajectoire naturelle du
# joueur vers la sortie (mur perpendiculaire à la direction de sortie). Si oui,
# la projection de la sortie sur ce mur doit couvrir ≥ EXIT_MIN_COVERAGE_RATIO
# de la longueur du mur. Sinon : un joueur off-axis se coince contre le mur.
# Variante "au moins un axe" : suffit que la sortie couvre ≥ 50% du mur le
# plus proche sur un des deux axes (x ou y). En pratique, un exit horizontal
# au bas du district couvre la dimension x du mur du bas — ce qui rattrape un
# joueur descendant en biais. Pas besoin que la dimension y couvre les murs
# latéraux (ils ne sont pas dans la trajectoire de descente).
func _exit_covers_blocking_wall_one_axis(exit_node: Node, exit_size: Vector2, walls: Array) -> bool:
	var exit_pos: Vector2 = (exit_node as Node2D).global_position
	if walls.is_empty():
		return true
	var horizontal_ok: bool = false
	var vertical_ok: bool = false
	var any_horizontal: bool = false
	var any_vertical: bool = false
	for wall in walls:
		var wsize: Vector2 = _exit_collision_size(wall)
		if wsize == Vector2.ZERO:
			continue
		var wpos: Vector2 = (wall as Node2D).global_position
		if wsize.x > wsize.y:
			# Mur horizontal (top/bottom).
			if abs(exit_pos.y - wpos.y) <= exit_size.y / 2.0 + wsize.y / 2.0 + 100.0:
				any_horizontal = true
				if exit_size.x / wsize.x >= EXIT_MIN_COVERAGE_RATIO:
					horizontal_ok = true
		else:
			# Mur vertical (left/right).
			if abs(exit_pos.x - wpos.x) <= exit_size.x / 2.0 + wsize.x / 2.0 + 100.0:
				any_vertical = true
				if exit_size.y / wsize.y >= EXIT_MIN_COVERAGE_RATIO:
					vertical_ok = true
	# Si aucun mur "blocking" trouvé, on accepte (cas hypothétique).
	if not any_horizontal and not any_vertical:
		return true
	# Sinon, il faut que l'axe correspondant à un mur trouvé soit couvert.
	# On considère "ok" si au moins un axe parmi ceux ayant un mur est ok.
	return horizontal_ok or vertical_ok

# Niveau 2 : simulation physique réelle. Pour chaque district marchable, on
# instancie un CharacterBody2D au PlayerSpawn, on lui applique chaque frame
# une velocity dirigée vers la sortie, et on vérifie que body_entered de
# l'Area2D ExitToCopa fire dans le délai imparti. Ça pige les obstacles
# internes (mur mal placé, gap dans la trigger), pas juste la géométrie statique.
const WALK_TEST_SPEED: float = 140.0
const WALK_TEST_MAX_FRAMES: int = 600  # ~10 s à 60 Hz
const WALK_TEST_PROGRESS_WINDOW: int = 90  # nb frames sans progrès → bloqué

func _index_exits_by_target(root: Node, out: Dictionary) -> void:
	if root is DistrictExit:
		var ex: DistrictExit = root
		var arr: Array = out.get(ex.target_district, [])
		arr.append(ex)
		out[ex.target_district] = arr
	for child in root.get_children():
		_index_exits_by_target(child, out)

# Calcule le Rect2 monde couvert par la collision shape d'un DistrictExit.
func _exit_world_rect(exit_node: Node) -> Rect2:
	var size: Vector2 = _exit_collision_size(exit_node)
	if size == Vector2.ZERO:
		return Rect2()
	var pos: Vector2 = (exit_node as Node2D).global_position
	return Rect2(pos - size / 2.0, size)

func _summary() -> void:
	print("")
	print("===================================================")
	print("  %d passés · %d échecs" % [_passed, _failed])
	if _failed > 0:
		print("")
		print("ÉCHECS :")
		for f in _failures:
			print("  - %s" % f)
	print("===================================================")
	print("")
