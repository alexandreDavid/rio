extends "res://scripts/tests/IntegrationTestBase.gd"

# Groupe : Chargement & intégrité. Extrait du monolithe IntegrationTest.
# run() rejoue les tests dans l'ordre d'origine (await préservé).

func run() -> void:
	_test_autoloads_present()
	_test_all_scenes_load()
	_test_quest_resources_load()
	_test_npc_data_resources_load()
	_test_dialogue_graph()
	_test_dialogue_choices_consistency()
	_test_npc_dispatch_knots()


# --- Tests ---

func _test_autoloads_present() -> void:
	_section("Autoloads")
	for n in ["EventBus", "GameManager", "ReputationSystem", "TimeOfDay",
			"QuestManager", "DialogueBridge", "SaveSystem", "CampaignManager",
			"NPCScheduler", "NavigationDirector"]:
		_assert(get_node_or_null("/root/" + n) != null, "autoload %s" % n)


# --- Tests playability étendus (ajoutés pour bloquer toute soft-lock) ---

# Charge chaque .tscn de scenes/ comme PackedScene. Une scène cassée (ext_resource
# manquante, sub_resource invalide) échoue ici dès le boot. Ça couvre un risque
# fréquent lors des refactorings de structure (déplacement d'autoload, etc).
func _test_all_scenes_load() -> void:
	_section("Toutes les scènes (.tscn) chargent en PackedScene")
	var scene_paths: Array = _list_scenes_under("res://scenes/")
	for path in scene_paths:
		var packed: PackedScene = load(path) as PackedScene
		_assert(packed != null, path)


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
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
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
				# accept_quest peut être String ou Array (les pactes acte 3 tentent
				# A1 puis A2 selon l'état). On vérifie chaque ID séparément.
				var accept_payload = action.accept_quest
				if accept_payload is Array:
					for qid in accept_payload:
						_assert(quest_ids.has(String(qid)),
							"knot '%s' choix %s : accept_quest '%s' enregistré (array)" % [knot, idx_str, qid])
				else:
					_assert(quest_ids.has(accept_payload),
						"knot '%s' choix %s : accept_quest '%s' enregistré" % [knot, idx_str, accept_payload])
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


func _test_dialogue_choices_consistency() -> void:
	_section("Cohérence choix ↔ actions du graphe dialogues")
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	for knot in dialogues:
		var dlg: Dictionary = dialogues[knot]
		var choices: Array = dlg.get("choices", [])
		var on_choose: Dictionary = dlg.get("on_choose", {})
		for idx_str in on_choose:
			var idx: int = int(idx_str)
			_assert(idx >= 0 and idx < choices.size(),
				"knot '%s' choix '%s' : index < %d" % [knot, idx_str, choices.size()])
			var action: Dictionary = on_choose[idx_str]
			# Au moins un verbe reconnu (sinon l'action est un no-op silencieux).
			var has_known: bool = false
			for v in KNOWN_VERBS:
				if action.has(v):
					has_known = true
					break
			_assert(has_known, "knot '%s' choix '%s' : au moins une action reconnue" % [knot, idx_str])


func _test_npc_dispatch_knots() -> void:
	_section("NPC dispatchers — tous les knots référencés existent")
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	for npc_id in NPC_DISPATCH_KNOTS:
		var knots: Array = NPC_DISPATCH_KNOTS[npc_id]
		for knot in knots:
			_assert(dialogues.has(knot), "NPC '%s' knot '%s' présent" % [npc_id, knot])

