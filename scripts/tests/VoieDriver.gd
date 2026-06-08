extends Node

# Tests « blindés » par VOIE, sur le vrai jeu (Main instancié). Pour chacune des
# 4 voies, on simule les interactions réelles et on vérifie le contrat complet :
#   1. Le patron PROPOSE son pacte à l'interaction en acte 3.
#   2. « Réfléchir » (choix 1) ne scelle PAS la voie et n'accepte aucune mission.
#   3. Accepter (choix 0) scelle la voie ET amorce la chaîne (1re mission).
#   4. La 2e mission (q2) devient accessible en acte 3.
#   5. EXCLUSIVITÉ : une fois la voie scellée, les 3 autres patrons ne proposent
#      plus leur pacte (refus / ambiance).
#   6. Le guidage ne renvoie plus vers « sceller un pacte » (voie détectée).

const VOIES: Array = [
	{"name": "Tráfico", "npc": "tito", "knot": "tito_pacto_trafico_offer", "flag": "voie_trafico", "q1": "trafico_a1_livraison", "q2": "trafico_a2_pickup"},
	{"name": "Polícia", "npc": "ramos", "knot": "ramos_pacto_policia_offer", "flag": "voie_policia", "q1": "policia_b1_intel", "q2": "policia_b2_filature"},
	{"name": "Consórcio", "npc": "magalhaes", "knot": "magalhaes_pacto_consortium_offer", "flag": "voie_consortium", "q1": "consortium_c1_recouvrement", "q2": "consortium_c2_loyers"},
	{"name": "Prefeito", "npc": "padre", "knot": "padre_pacto_prefeito_offer", "flag": "voie_prefeito", "q1": "prefeito_d1_peticao", "q2": "prefeito_d2_basquete"},
]

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	await _run()
	print("\n================= RÉSULTAT VOIES =================")
	print("  %d OK · %d ÉCHECS" % [_pass, _fail])
	print("=================================================")
	get_tree().quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  [✓] %s" % label)
	else:
		_fail += 1
		print("  [X] %s" % label)

func _run() -> void:
	await get_tree().process_frame
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 12:
		await get_tree().process_frame
	if GameManager.player == null:
		_ok(false, "joueur présent")
		return
	for v in VOIES:
		await _test_voie(v)

func _test_voie(v: Dictionary) -> void:
	print("\n──────── VOIE %s ────────" % v.name)
	_reset_act3_clean()
	await get_tree().process_frame
	var npc: Node2D = NPCScheduler.get_npc(v.npc)
	_ok(npc != null, "%s : patron '%s' présent dans le monde" % [v.name, v.npc])
	if npc == null:
		return

	# 1+2. PROPOSITION + « réfléchir » ne scelle pas.
	await _interact(npc)
	_ok(DialogueBridge._active_knot == v.knot, "%s : pacte proposé à l'interaction (acte 3)" % v.name)
	DialogueBridge.choose(1)  # « Plus tard — je réfléchis encore »
	await get_tree().process_frame
	_ok(not CampaignManager.has_flag(v.flag), "%s : « réfléchir » ne scelle PAS la voie" % v.name)
	_ok(not QuestManager.is_active(v.q1), "%s : « réfléchir » n'accepte aucune mission" % v.name)
	_ok(not DialogueBridge.is_active(), "%s : dialogue fermé après « réfléchir »" % v.name)

	# 3. ACCEPTER scelle + amorce la chaîne.
	await _interact(npc)
	_ok(DialogueBridge._active_knot == v.knot, "%s : pacte re-proposé (toujours pas scellé)" % v.name)
	DialogueBridge.choose(0)  # accepter
	await get_tree().process_frame
	_ok(CampaignManager.has_flag(v.flag), "%s : accepter SCELLE la voie" % v.name)
	_ok(QuestManager.is_active(v.q1) or QuestManager.is_completed(v.q1)
			or QuestManager.is_active(v.q2), "%s : 1re mission de la chaîne amorcée" % v.name)

	# 4. q2 (verrouillée en acte 2 par required_act=3) s'ouvre en acte 3 une fois
	#    q1 complétée (prérequis de chaîne).
	var q1q: Quest = QuestManager.get_quest(v.q1)
	if q1q != null and QuestManager.is_active(v.q1):
		for obj in q1q.objectives:
			QuestManager.complete_objective(v.q1, obj.id, false)
	_ok(QuestManager.is_available(v.q2) or QuestManager.is_active(v.q2)
			or QuestManager.is_completed(v.q2), "%s : 2e mission s'ouvre en acte 3 (après q1)" % v.name)

	# 5. EXCLUSIVITÉ : les autres patrons ne proposent plus leur pacte.
	for other in VOIES:
		if other.flag == v.flag:
			continue
		if DialogueBridge.is_active():
			DialogueBridge.end_dialogue()
		var onpc: Node2D = NPCScheduler.get_npc(other.npc)
		if onpc == null:
			continue
		await _interact(onpc)
		_ok(DialogueBridge._active_knot != other.knot,
				"%s scellée → %s ne propose PAS son pacte (%s)" % [v.name, other.npc, DialogueBridge._active_knot])

	# 6. Guidage : voie détectée (plus de « sceller un pacte »).
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
	NavigationDirector._recompute()
	var g: String = NavigationDirector.current_text().to_lower()
	print("    guidage = %s" % NavigationDirector.current_text())
	_ok(not ("sceller un pacte" in g), "%s : guidage ne dit plus « va sceller un pacte »" % v.name)

# --- Helpers ---

func _interact(npc: Node2D) -> void:
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	if GameManager.player is Node2D:
		(GameManager.player as Node2D).global_position = npc.global_position + Vector2(18, 0)
	await get_tree().process_frame
	if npc.has_method("_on_interacted"):
		await npc._on_interacted(null)
	await get_tree().process_frame

# État acte 3 propre : quêtes vierges, flags requis pour les pactes, aucune voie.
func _reset_act3_clean() -> void:
	if DialogueBridge.is_active():
		DialogueBridge.end_dialogue()
	for qid in QuestManager._quests.keys():
		QuestManager._state[qid] = QuestManager.State.AVAILABLE
	QuestManager._objectives.clear()
	CampaignManager.flags.clear()
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.current_act = 3
	CampaignManager.debt_paid = CampaignManager.ACT2_THRESHOLD
	_force_complete("prologue_pedrinho")
	_force_complete("act1_heritage")
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("met_consortium")
	CampaignManager.set_flag("act1_closed")
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING

func _force_complete(quest_id: String) -> void:
	if not QuestManager.is_active(quest_id):
		QuestManager.accept(quest_id)
	var q: Quest = QuestManager.get_quest(quest_id)
	if q == null:
		return
	for obj in q.objectives:
		QuestManager.complete_objective(quest_id, obj.id, false)
