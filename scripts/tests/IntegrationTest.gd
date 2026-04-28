extends Node

# Tests d'intégration headless : vérifie que le jeu est jouable et terminable.
# Exécution : `./run_tests.sh` (utilise godot --headless) ou lancement direct de
# la scène scenes/tests/IntegrationTest.tscn depuis l'éditeur.
#
# Le test simule programmatiquement le parcours complet :
#   Acte 1 → paiement 500 → Acte 2 → complétion quêtes voies → 25k → Acte 3 → 50k.
# Il vérifie aussi l'intégrité des .tres de quêtes, des données NPC, et du graphe
# de dialogues placeholder (next / accept_quest / finish_quest cohérents).
#
# Sortie : exit code 0 si tout passe, 1 sinon. Log lisible à l'écran.

const QUEST_RESOURCES: Array[String] = [
	"res://resources/quests/act1_heritage.tres",
	"res://resources/quests/act1_meet_ramos.tres",
	"res://resources/quests/act1_meet_tito.tres",
	"res://resources/quests/milho_01.tres",
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
	"res://resources/quests/act2_intro.tres",
	"res://resources/quests/act2_miguel_favela.tres",
	"res://resources/quests/act2_ramos_operacao.tres",
	"res://resources/quests/act2_padre_orfanato.tres",
	"res://resources/quests/act2_pecheur_secret.tres",
	"res://resources/quests/act2_contessa_gala.tres",
	"res://resources/quests/act3_policia_madrugada.tres",
	"res://resources/quests/act3_trafico_corrida.tres",
	"res://resources/quests/act3_prefeito_eleicao.tres",
	"res://resources/quests/act4_prefeito_audiencia.tres",
	"res://resources/quests/act4_policia_purga.tres",
	"res://resources/quests/act4_trafico_tributo.tres",
	"res://resources/quests/padre_corcovado_relic.tres",
	"res://resources/quests/ronaldo_dj_paoacucar.tres",
	"res://resources/quests/carlos_lagoa_volta.tres",
	"res://resources/quests/contessa_date.tres",
	"res://resources/quests/tourist_vip_tour.tres",
	"res://resources/quests/ronaldo_maracana_torcida.tres",
	"res://resources/quests/consortium_airport_pickup.tres",
	"res://resources/quests/ronaldo_aterro_basket.tres",
	"res://resources/quests/pedro_cagarras_sup.tres",
	"res://resources/quests/act4_carnaval_desfile.tres",
]

const NPC_DATA_DIR: String = "res://resources/npcs/"

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("")
	print("================ INTEGRATION TESTS ================")
	_test_autoloads_present()
	_test_quest_resources_load()
	_test_npc_data_resources_load()
	_test_dialogue_graph()
	_test_campaign_progression()
	_test_quest_completion_paths()
	_test_act4_transition()
	await _test_valet_minigame()
	_summary()
	get_tree().quit(0 if _failed == 0 else 1)

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

# --- Tests ---

func _test_autoloads_present() -> void:
	_section("Autoloads")
	for n in ["EventBus", "GameManager", "ReputationSystem", "TimeOfDay",
			"QuestManager", "DialogueBridge", "SaveSystem", "CampaignManager",
			"NPCScheduler"]:
		_assert(get_node_or_null("/root/" + n) != null, "autoload %s" % n)

func _test_quest_resources_load() -> void:
	_section("Chargement des quêtes")
	for path in QUEST_RESOURCES:
		var exists: bool = ResourceLoader.exists(path)
		_assert(exists, "existe: %s" % path)
		if not exists:
			continue
		var res: Resource = load(path)
		_assert(res is Quest, "instance Quest: %s" % path)
		if not (res is Quest):
			continue
		var q: Quest = res as Quest
		_assert(q.id != "", "%s a un id" % path)
		_assert(q.display_name != "", "%s a un display_name" % path)
		_assert(q.ink_knot != "", "%s a un ink_knot" % path)
		# Register in QuestManager for subsequent tests
		QuestManager.register_quest(q)

func _test_npc_data_resources_load() -> void:
	_section("Chargement des NPCs")
	var dir: DirAccess = DirAccess.open(NPC_DATA_DIR)
	if dir == null:
		_assert(false, "ouverture %s" % NPC_DATA_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var path: String = NPC_DATA_DIR + fname
			var res: Resource = load(path)
			_assert(res is NPCData, "NPCData: %s" % path)
			if res is NPCData:
				var d: NPCData = res as NPCData
				_assert(d.id != "", "%s a un id" % fname)
		fname = dir.get_next()

func _test_dialogue_graph() -> void:
	_section("Graphe de dialogues placeholder")
	var dialogues: Dictionary = DialogueBridge.PLACEHOLDER_DIALOGUES
	var quest_ids: Array = QuestManager._quests.keys()
	for knot in dialogues:
		var dlg: Dictionary = dialogues[knot]
		var choices: Array = dlg.get("choices", [])
		_assert(choices.size() > 0, "knot '%s' a au moins 1 choix" % knot)
		var on_choose: Dictionary = dlg.get("on_choose", {})
		for idx_str in on_choose:
			var action = on_choose[idx_str]
			if typeof(action) != TYPE_DICTIONARY:
				_assert(false, "knot '%s' choix %s : action doit être Dictionary" % [knot, idx_str])
				continue
			if action.has("next"):
				_assert(dialogues.has(action.next),
					"knot '%s' choix %s : next '%s' existe" % [knot, idx_str, action.next])
			if action.has("accept_quest"):
				_assert(quest_ids.has(action.accept_quest),
					"knot '%s' choix %s : accept_quest '%s' enregistré" % [knot, idx_str, action.accept_quest])
			if action.has("finish_quest"):
				var fq = action.finish_quest
				_assert(quest_ids.has(fq.get("quest", "")),
					"knot '%s' choix %s : finish_quest.quest '%s' enregistré" % [knot, idx_str, fq.get("quest", "")])
				var q: Quest = QuestManager._quests.get(fq.get("quest", ""))
				if q:
					var obj_ids: Array = []
					for obj in q.objectives:
						obj_ids.append(obj.id)
					_assert(obj_ids.has(fq.get("objective", "")),
						"knot '%s' objectif '%s' existe sur quête '%s'" % [knot, fq.get("objective", ""), fq.get("quest", "")])

func _test_campaign_progression() -> void:
	_section("Progression des actes (dette 50k, seuils 500 et 25k)")
	# Reset état
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags.clear()

	_assert(CampaignManager.current_act == 1, "départ acte 1")
	_assert(CampaignManager.debt_remaining() == CampaignManager.DEBT_TOTAL, "dette initiale = %d" % CampaignManager.DEBT_TOTAL)

	# Paiement partiel qui ne franchit pas le seuil acte 1
	CampaignManager.pay_debt(100)
	_assert(CampaignManager.current_act == 1, "100 payés → toujours acte 1")

	# Franchit le seuil ACT1_THRESHOLD (500 total)
	CampaignManager.pay_debt(400)
	_assert(CampaignManager.debt_paid == 500, "cumul = 500")
	_assert(CampaignManager.current_act == 2, "500 payés → acte 2 (seuil %d)" % CampaignManager.ACT1_THRESHOLD)

	# Continue jusqu'à ACT2_THRESHOLD (25000 total)
	CampaignManager.pay_debt(CampaignManager.ACT2_THRESHOLD - 500)
	_assert(CampaignManager.debt_paid == CampaignManager.ACT2_THRESHOLD, "cumul = %d" % CampaignManager.ACT2_THRESHOLD)
	_assert(CampaignManager.current_act == 3, "25000 payés → acte 3")

	# Solde le reste
	CampaignManager.pay_debt(CampaignManager.DEBT_TOTAL)  # dépassement autorisé, clampé
	_assert(CampaignManager.debt_remaining() == 0, "dette soldée (remaining=0)")

	# Endgame
	CampaignManager.set_endgame(CampaignManager.Endgame.PREFEITO)
	_assert(CampaignManager.chosen_endgame == CampaignManager.Endgame.PREFEITO, "endgame Prefeito posé")

func _test_quest_completion_paths() -> void:
	_section("Complétion des quêtes clés")
	# Reset état quêtes + campagne
	QuestManager._state.clear()
	QuestManager._objectives.clear()
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.flags.clear()
	# Re-register (les quêtes ont été clear indirectement)
	for path in QUEST_RESOURCES:
		if ResourceLoader.exists(path):
			var q: Resource = load(path)
			if q is Quest:
				QuestManager.register_quest(q)

	# act1_heritage
	_assert(QuestManager.accept("act1_heritage"), "accept act1_heritage")
	_assert(QuestManager.is_active("act1_heritage"), "act1_heritage actif")
	QuestManager.complete_objective("act1_heritage", "meet_consortium")
	_assert(QuestManager.is_active("act1_heritage"), "encore actif après 1 objectif")
	QuestManager.complete_objective("act1_heritage", "earn_seed_money")
	QuestManager.complete_objective("act1_heritage", "first_payment")
	_assert(QuestManager.is_completed("act1_heritage"), "act1_heritage complétée")

	# act1_meet_ramos
	_assert(QuestManager.accept("act1_meet_ramos"), "accept act1_meet_ramos")
	QuestManager.complete_objective("act1_meet_ramos", "report_to_ramos")
	_assert(QuestManager.is_completed("act1_meet_ramos"), "act1_meet_ramos complétée")

	# act1_meet_tito
	_assert(QuestManager.accept("act1_meet_tito"), "accept act1_meet_tito")
	QuestManager.complete_objective("act1_meet_tito", "do_tito_favor")
	_assert(QuestManager.is_completed("act1_meet_tito"), "act1_meet_tito complétée")

	# milho_01 (quête tuto)
	_assert(QuestManager.accept("quest_milho_01"), "accept quest_milho_01")
	QuestManager.complete_objective("quest_milho_01", "pickup_cart")
	QuestManager.complete_objective("quest_milho_01", "return_cart")
	# sell_all est optionnel
	_assert(QuestManager.is_completed("quest_milho_01"), "quest_milho_01 complétée")

	# find_bracelet_01
	_assert(QuestManager.accept("find_bracelet_01"), "accept find_bracelet_01")
	QuestManager.complete_objective("find_bracelet_01", "find_bracelet")
	QuestManager.complete_objective("find_bracelet_01", "return_bracelet")
	_assert(QuestManager.is_completed("find_bracelet_01"), "find_bracelet_01 complétée")

	# flowers_for_beatriz
	_assert(QuestManager.accept("flowers_for_beatriz"), "accept flowers_for_beatriz")
	QuestManager.complete_objective("flowers_for_beatriz", "deliver_flowers")
	_assert(QuestManager.is_completed("flowers_for_beatriz"), "flowers_for_beatriz complétée")

	# bike_delivery
	_assert(QuestManager.accept("bike_delivery"), "accept bike_delivery")
	QuestManager.complete_objective("bike_delivery", "one_delivery")
	_assert(QuestManager.is_completed("bike_delivery"), "bike_delivery complétée")

	# church_statue
	_assert(QuestManager.accept("church_statue"), "accept church_statue")
	QuestManager.complete_objective("church_statue", "find_statue")
	QuestManager.complete_objective("church_statue", "return_statue")
	_assert(QuestManager.is_completed("church_statue"), "church_statue complétée")

	# pharmacy_tito
	_assert(QuestManager.accept("pharmacy_tito"), "accept pharmacy_tito")
	QuestManager.complete_objective("pharmacy_tito", "receive_medicine")
	QuestManager.complete_objective("pharmacy_tito", "deliver_medicine")
	_assert(QuestManager.is_completed("pharmacy_tito"), "pharmacy_tito complétée")

	# escort_contessa : gatée par CHARISMA >= 10
	ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 15)
	_assert(QuestManager.accept("escort_contessa"), "accept escort_contessa (charisma ok)")
	QuestManager.complete_objective("escort_contessa", "escort_to_bar")
	QuestManager.complete_objective("escort_contessa", "escort_back_to_palace")
	_assert(QuestManager.is_completed("escort_contessa"), "escort_contessa complétée")
	# Vérifie que le gating CHARISMA bloque quand trop bas
	QuestManager._state["escort_contessa"] = QuestManager.State.AVAILABLE
	ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 5)
	_assert(not QuestManager.accept("escort_contessa"), "refus accept escort_contessa (charisma < 10)")

func _test_act4_transition() -> void:
	_section("Transition acte 3 → 4 + acte 4 jouable")
	# Reset campagne pour un état propre.
	CampaignManager.current_act = 3
	CampaignManager.debt_paid = CampaignManager.ACT2_THRESHOLD  # 25k payés (juste sur acte 3)
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags = {"ratted_on_tito": true}  # voie Polícia ouverte
	# Avant la finale : pas en acte 4, pas d'endgame.
	_assert(CampaignManager.current_act == 3, "départ acte 3")
	_assert(CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE, "pas d'endgame")
	# Déclenche la finale Polícia → doit basculer acte 4 + scellement endgame + dette purgée.
	CampaignManager.complete_endgame(CampaignManager.Endgame.POLICIA)
	_assert(CampaignManager.current_act == 4, "acte 4 atteint après finale")
	_assert(CampaignManager.chosen_endgame == CampaignManager.Endgame.POLICIA, "endgame Polícia scellé")
	_assert(CampaignManager.debt_remaining() == 0, "dette purgée par finale")
	_assert(CampaignManager.reign_title() == "Chefe de Polícia", "titre de règne correct")
	# Acte 4 : la quête Polícia est dispo (required_act=4).
	_assert(QuestManager.is_available("act4_policia_purga"), "act4_policia_purga dispo en acte 4")
	# Les quêtes des autres voies aussi (gating narratif côté NPC, pas côté quête).
	_assert(QuestManager.is_available("act4_prefeito_audiencia"), "act4_prefeito_audiencia dispo")
	_assert(QuestManager.is_available("act4_trafico_tributo"), "act4_trafico_tributo dispo")
	# Acceptation et complétion d'une quête acte 4.
	_assert(QuestManager.accept("act4_policia_purga"), "accept purga")
	QuestManager.complete_objective("act4_policia_purga", "purge_morro")
	QuestManager.complete_objective("act4_policia_purga", "purge_calcadao")
	QuestManager.complete_objective("act4_policia_purga", "purge_atlantica")
	_assert(QuestManager.is_completed("act4_policia_purga"), "purga complétée (3 points)")

func _test_valet_minigame() -> void:
	_section("Mini-jeu Valet — boucle complète")
	var valet_scene: PackedScene = load("res://scenes/minigames/Valet.tscn")
	_assert(valet_scene != null, "Valet.tscn charge")
	if valet_scene == null:
		return
	var game: Node2D = valet_scene.instantiate() as Node2D
	add_child(game)
	_assert(game._tutorial_visible, "Tuto visible au démarrage")
	game._close_tutorial()
	_assert(not game._tutorial_visible, "Tuto fermé")
	# Premier spawn : déclenché par _process après SPAWN_DELAY_INITIAL en jeu réel ;
	# pour le test on appelle directement.
	game._spawn_arriving_car()
	_assert(game._cars.size() == 1, "Première voiture spawnée à l'entrée")
	_assert(game._cars[0].status == game.CarStatus.ARRIVING, "Statut initial = ARRIVING")
	_assert(not game._cars[0].requested_pending, "Pas encore demandée")

	# Pickup de la voiture à l'entrée.
	var car_node: ColorRect = game._cars[0].node
	game._player_pos = car_node.position + Vector2(game.CAR_W * 0.5, game.CAR_H * 0.5)
	game._action_pickup()
	_assert(game._carried_idx == 0, "Voiture en main après pickup")
	_assert(game._cars[0].status == game.CarStatus.CARRIED, "Statut → CARRIED")

	# Drop dans la place 0.
	game._player_pos = game.SLOTS[0]
	game._action_drop()
	_assert(game._carried_idx == -1, "Mains libres après garage")
	_assert(game._cars[0].status == game.CarStatus.PARKED, "Statut → PARKED")
	_assert(game._occupied_slots.has(0), "Place 0 marquée occupée")

	# Force l'expiration de la patience puis tick _update_cars.
	game._cars[0].parked_at = -100.0
	game._update_cars()
	_assert(game._cars[0].status == game.CarStatus.REQUESTED, "Patience expirée → REQUESTED")
	_assert(game._cars[0].requested_pending, "Flag requested_pending levé")

	# Pickup de la voiture demandée — le bug fixé doit conserver le flag.
	game._player_pos = game.SLOTS[0]
	game._action_pickup()
	_assert(game._carried_idx == 0, "Pickup voiture demandée OK")
	_assert(game._cars[0].status == game.CarStatus.CARRIED, "Statut courant = CARRIED")
	_assert(game._cars[0].requested_pending, "requested_pending PERSISTE après pickup (bug fixé)")
	_assert(not game._occupied_slots.has(0), "Place 0 libérée à la prise")

	# Tentative de re-garer la voiture demandée → doit être bloquée.
	game._player_pos = game.SLOTS[1]
	game._action_drop()
	_assert(game._carried_idx == 0, "Re-garage d'une voiture demandée bloqué")
	_assert(not game._occupied_slots.has(1), "Place 1 reste libre")

	# Restitution à l'entrée → tip versé, client servi.
	var drop_center: Vector2 = game.DROP_ZONE.position + game.DROP_ZONE.size * 0.5
	game._player_pos = drop_center
	var tips_before: int = game._total_tips
	var served_before: int = game._customers_served
	game._action_drop()
	_assert(game._carried_idx == -1, "Voiture livrée (mains libres)")
	_assert(game._customers_served == served_before + 1, "Compteur clients +1")
	_assert(game._total_tips > tips_before, "Tip > 0 versé")
	_assert(game._cars[0].status == game.CarStatus.DELIVERED, "Statut final = DELIVERED")

	# Tentative de livraison sans voiture demandée — doit être un no-op.
	# On spawn une nouvelle voiture, pickup, et tente de la livrer immédiatement.
	game._spawn_arriving_car()
	var idx2: int = game._cars.size() - 1
	var car2: ColorRect = game._cars[idx2].node
	game._player_pos = car2.position + Vector2(game.CAR_W * 0.5, game.CAR_H * 0.5)
	game._action_pickup()
	_assert(game._carried_idx == idx2, "Pickup 2ème voiture")
	game._player_pos = drop_center
	var tips_now: int = game._total_tips
	var served_now: int = game._customers_served
	game._action_drop()
	_assert(game._carried_idx == idx2, "Drop refusé (voiture pas demandée)")
	_assert(game._total_tips == tips_now, "Pas de tip versé")
	_assert(game._customers_served == served_now, "Pas de client servi")

	# Cleanup
	game.queue_free()
	await get_tree().process_frame

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
