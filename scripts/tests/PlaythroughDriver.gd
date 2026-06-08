extends Node

# Pilote de playthrough RÉEL (headless). Instancie la vraie scène Main (monde +
# joueur + PNJ + DialogueUI), puis SIMULE les actions utilisateur : place le
# joueur près d'un PNJ, déclenche sa vraie interaction (_on_interacted → routage
# de dialogue), avance les choix, et VÉRIFIE l'argent / la dette / l'état après
# chaque action. But : reproduire les bugs signalés (Ramos n'offre pas, paiement
# non déduit) sur le vrai code, pas sur des appels abstraits.

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	await _run()
	print("\n================= RÉSULTAT PLAYTHROUGH =================")
	print("  %d OK · %d ÉCHECS" % [_pass, _fail])
	print("=======================================================")
	get_tree().quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  [✓] %s" % label)
	else:
		_fail += 1
		print("  [X] %s" % label)

func _step(s: String) -> void:
	print("\n── %s" % s)

func _run() -> void:
	await get_tree().process_frame
	# 1. Instancier le vrai jeu.
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	add_child(main)
	# Laisse MainBoot._ready (register quests), le spawn du monde, les NPC._ready
	# (register au scheduler) et les call_deferred (load/intro) se faire.
	for i in 12:
		await get_tree().process_frame

	var player: Node = GameManager.player
	_ok(player != null, "joueur présent (GameManager.player)")
	if player == null:
		return
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	_ok(inv != null, "inventaire présent")
	if inv == null:
		return

	# 2. État propre acte 1 (efface un éventuel save chargé + dialogue résiduel
	#    déclenché par le state chargé, ex. cinématique de nuit en acte 2).
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	_reset_act1()
	await get_tree().process_frame
	inv.money = 0
	EventBus.money_changed.emit(0)

	# 3. Prérequis hors-scope forcés : prologue complété + quête héritage acceptée.
	_force_complete("prologue_pedrinho")
	_ok(QuestManager.is_completed("prologue_pedrinho"), "prologue complété (prérequis)")
	CampaignManager.set_flag("act1_started")
	QuestManager.accept("act1_heritage")
	_ok(QuestManager.is_active("act1_heritage"), "act1_heritage acceptée")

	DistrictManager.set_current("copacabana")
	await get_tree().process_frame

	# 4. RÉEL : rencontrer le consortium → meet_consortium doit se compléter.
	_step("Rencontre du consortium (interaction réelle)")
	var cons: Node2D = NPCScheduler.get_npc("consortium")
	_ok(cons != null, "PNJ consortium dans le monde")
	if cons == null:
		return
	await _interact(cons)
	print("    knot ouvert = %s" % DialogueBridge._active_knot)
	await _advance_until_closed(6)
	_ok(CampaignManager.has_flag("met_consortium"), "flag met_consortium posé après la rencontre")
	_ok(QuestManager.is_objective_done("act1_heritage", "meet_consortium"),
			"objectif 'meet_consortium' complété")

	# 5. RÉEL : payer le consortium → l'argent doit baisser EXACTEMENT du montant.
	_step("Paiement de l'acompte (500 R$) — vérif déduction sans rebond")
	inv.money = 600
	EventBus.money_changed.emit(600)
	var before: int = inv.money
	var ach_before: int = AchievementSystem.count_unlocked()
	await _interact(cons)
	print("    knot paiement = %s" % DialogueBridge._active_knot)
	if DialogueBridge.is_active():
		DialogueBridge.choose(1)  # "Poser R$ 500"
		await get_tree().process_frame
		await get_tree().process_frame
	print("    argent %d → %d (attendu %d) · debt_paid=%d · succès débloqués +%d" % [
			before, inv.money, before - 500, CampaignManager.debt_paid,
			AchievementSystem.count_unlocked() - ach_before])
	_ok(inv.money == before - 500, "argent déduit de 500 sans rebond (attendu %d, obtenu %d)" % [before - 500, inv.money])
	_ok(CampaignManager.debt_paid >= 500, "dette payée >= 500")

	# 6. Le paiement SEUL ne suffit plus : il faut rentrer parler à tio Zé.
	_step("Acte 1 maintenu après paiement seul (retour maison requis)")
	_ok(CampaignManager.current_act == 1, "reste en acte 1 après le seul paiement (act=%d)" % CampaignManager.current_act)
	NavigationDirector._recompute()
	var gh: String = NavigationDirector.current_text().to_lower()
	print("    guidage post-paiement = %s" % NavigationDirector.current_text())
	_ok(("tio zé" in gh) or ("maison" in gh) or ("favela" in gh), "guide vers le retour maison / tio Zé")

	# 7. Retour maison + nuit chez tio Zé (act1_closed) → bascule acte 2.
	_step("Retour maison + nuit (act1_closed) → acte 2")
	CampaignManager.set_flag("act1_closed")
	_ok(CampaignManager.current_act == 2, "acte 2 SEULEMENT après le retour maison (act=%d)" % CampaignManager.current_act)

	# 8. Acte 2 = 1re mission de chaque voie uniquement (a1/b1/c1/d1), pas la 2e.
	_step("Acte 2 = 1re mission de chaque voie seulement")
	_ok(QuestManager.is_available("policia_b1_intel"), "b1 (1re Polícia) disponible en acte 2")
	_ok(not QuestManager.is_available("policia_b2_filature"), "b2 (2e Polícia) VERROUILLÉE en acte 2 (required_act 3)")
	_ok(QuestManager.is_available("trafico_a1_livraison") or QuestManager.is_completed("trafico_a1_livraison"), "a1 (1re Tráfico) accessible en acte 2")
	_ok(not QuestManager.is_available("trafico_a2_pickup"), "a2 (2e Tráfico) VERROUILLÉE en acte 2")
	# Dom Nilton en acte 2 : seul le boss à l'aéroport, PAS les protections Barra.
	_ok(QuestManager.is_available("consortium_airport_pickup"), "aéroport (Don Salvatore) dispo en acte 2")
	_ok(not QuestManager.is_available("consortium_barra_security"), "protections Barra VERROUILLÉES en acte 2 (required_act 3)")
	_ok(not QuestManager.is_available("consortium_le_parc"), "Le Parc VERROUILLÉ en acte 2")
	_ok(not QuestManager.is_available("consortium_peninsula"), "Península VERROUILLÉE en acte 2")

	# 9. RÉEL : Ramos doit proposer sa mission B1.
	_step("Ramos propose-t-il la mission ? (interaction réelle)")
	# Termine tout dialogue résiduel.
	while DialogueBridge.is_active():
		DialogueBridge.choose(0)
		await get_tree().process_frame
	var ramos: Node2D = NPCScheduler.get_npc("ramos")
	_ok(ramos != null, "PNJ Ramos dans le monde")
	if ramos == null:
		return
	await _interact(ramos)
	print("    knot Ramos = %s (attendu ramos_intro_b1_offer)" % DialogueBridge._active_knot)
	_ok(DialogueBridge._active_knot == "ramos_intro_b1_offer",
			"Ramos lance ramos_intro_b1_offer")

	# 9. GUIDAGE nouveau flux : acompte payé mais retour maison PAS fait → on
	#    guide vers tio Zé (aucun patron tant que l'acte 1 n'est pas clos), puis
	#    le retour maison (act1_closed) bascule en acte 2 = échantillon.
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	_step("Guidage clôture acte 1 (acompte payé, retour maison pas encore fait)")
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING  # évite le check « rentre dîner » (soir)
	CampaignManager.current_act = 1
	CampaignManager.flags.clear()
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("met_consortium")
	CampaignManager.set_flag("first_sale_done")
	# act1_heritage est déjà complétée (étape 5) ; act1_closed ABSENT exprès.
	DistrictManager.set_current("copacabana")
	NavigationDirector._recompute()
	var g1: String = NavigationDirector.current_text().to_lower()
	print("    guidage (acte 1, Copa) = %s" % NavigationDirector.current_text())
	_ok(("tio zé" in g1) or ("maison" in g1) or ("favela" in g1), "guide vers le retour maison / tio Zé")
	_ok(not ("ramos" in g1), "aucun patron tant que l'acte 1 n'est pas clos")

	CampaignManager.set_flag("act1_closed")  # retour maison + nuit
	NavigationDirector._recompute()
	print("    après clôture : acte=%d · guidage = %s" % [CampaignManager.current_act, NavigationDirector.current_text()])
	_ok(CampaignManager.current_act == 2, "le retour maison fait basculer en acte 2")

	# 10. Voie SCELLÉE (cas du save bloqué : voie_trafico + a1/a2 finies) :
	#     le guidage doit faire CONTINUER la voie (Tito), pas renvoyer chez Ramos.
	_step("Guidage avec voie Tráfico déjà scellée (ne doit PLUS dire « Va voir Ramos »)")
	CampaignManager.set_flag("voie_trafico")
	for q in ["trafico_a1_livraison", "trafico_a2_pickup"]:
		QuestManager._state[q] = QuestManager.State.COMPLETED
	NavigationDirector._recompute()
	var g4: String = NavigationDirector.current_text().to_lower()
	print("    guidage (voie Tráfico) = %s" % NavigationDirector.current_text())
	_ok("tito" in g4 or "tráfico" in g4 or "trafico" in g4, "guide vers la suite de la voie Tráfico (Tito)")
	_ok(not ("ramos" in g4), "ne renvoie PLUS vers Ramos (voie exclusive)")

	# 11. Pacte acte 3 : chaque patron doit offrir un choix « réfléchir » qui
	#     N'engage PAS la voie (le joueur peut décliner et revenir).
	_step("Pacte acte 3 — option « réfléchir » (décliner sans sceller)")
	var pactos: Array = [
		{"npc": "ramos", "knot": "ramos_pacto_policia_offer", "flag": "voie_policia"},
		{"npc": "magalhaes", "knot": "magalhaes_pacto_consortium_offer", "flag": "voie_consortium"},
		{"npc": "padre", "knot": "padre_pacto_prefeito_offer", "flag": "voie_prefeito"},
	]
	for pc in pactos:
		if DialogueBridge.is_active():
			DialogueBridge.end_dialogue()
		CampaignManager.flags.erase(pc.flag)
		DialogueBridge.start_dialogue(pc.npc, pc.knot)
		DialogueBridge.choose(1)  # « Plus tard — je réfléchis encore »
		await get_tree().process_frame
		_ok(not CampaignManager.has_flag(pc.flag), "%s : « réfléchir » ne scelle PAS %s" % [pc.npc, pc.flag])
		_ok(not DialogueBridge.is_active(), "%s : dialogue fermé après « réfléchir »" % pc.npc)

# --- Helpers d'interaction réelle ---

# Place le joueur collé au PNJ (évite le tween d'approche) puis déclenche sa
# vraie méthode d'interaction (routage de dialogue spécifique au PNJ).
func _interact(npc: Node2D) -> void:
	# Purge défensive : un dialogue résiduel bloquerait la nouvelle interaction.
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	if GameManager.player is Node2D:
		(GameManager.player as Node2D).global_position = npc.global_position + Vector2(18, 0)
	await get_tree().process_frame
	if npc.has_method("_on_interacted"):
		await npc._on_interacted(null)
	await get_tree().process_frame

# Avance un dialogue informatif/chaîné en choisissant la 1re option jusqu'à
# fermeture (max N pour éviter une boucle infinie).
func _advance_until_closed(max_steps: int) -> void:
	var n: int = 0
	while DialogueBridge.is_active() and n < max_steps:
		DialogueBridge.choose(0)
		await get_tree().process_frame
		n += 1

# --- État ---

func _reset_act1() -> void:
	for qid in QuestManager._quests.keys():
		QuestManager._state[qid] = QuestManager.State.AVAILABLE
	QuestManager._objectives.clear()
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags.clear()

func _force_complete(quest_id: String) -> void:
	if not QuestManager.is_active(quest_id):
		QuestManager.accept(quest_id)
	var q: Quest = QuestManager.get_quest(quest_id)
	if q == null:
		return
	for obj in q.objectives:
		QuestManager.complete_objective(quest_id, obj.id, false)
