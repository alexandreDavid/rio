extends "res://scripts/tests/IntegrationTestBase.gd"

# Groupe : Monde, spots & navigation. Extrait du monolithe IntegrationTest.
# run() rejoue les tests dans l'ordre d'origine (await préservé).

func run() -> void:
	await _test_interiors_no_overlap()
	await _test_mac_door_destination_wired()
	await _test_vehicles_follow_player_on_district_change()
	await _test_copacabana_palace_declutter()
	await _test_reactive_spots_visible()
	await _test_spot_actions_reference_valid_quests()
	await _test_beto_via_spots_end_to_end()
	await _test_district_spawn_clear_of_exits()
	await _test_walk_entries_clear_of_exits()
	_test_npc_base_knots_exist()
	_test_cutscene_dependencies()
	await _test_intro_bump_flow()
	_test_reactive_spots_default_variant()
	_test_runtime_spot_action_applies()
	_test_quest_objectives_reachable()
	_test_navigation_director_targets()
	_test_navigation_director_prologue_and_jantar()
	_test_dynamic_missions_not_farmable()
	_test_prologue_lock_and_spots()
	_test_intro_ngplus_bondinho()
	_test_facade_painter()
	await _test_pixel_font_and_theme()
	await _test_interior_dresser()
	await _test_quest_log_folded()
	await _test_mobile_controls_invariants()
	_test_random_events_multi_district()
	await _test_ambient_life_out_of_copa()
	_test_reputation_affinity_effects()
	_test_minigame_depth_contracts()
	_test_milho_rush()
	_test_regata_desembarque()
	_test_lisibilite_ui()


# Garde-fou : les intérieurs hors-monde (positions y≈-3000 dans Copacabana)
# doivent rester distants l'un de l'autre, sinon ils se rendent les uns sur
# les autres (cas réel : ForteColombo placé sur TioZeHouseInterior à (7200,
# -3000)). Pairwise distance ≥ MIN_DIST.
func _test_interiors_no_overlap() -> void:
	_section("Intérieurs hors monde — pas de chevauchement")
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn") as PackedScene
	if packed == null:
		_assert(false, "Copacabana.tscn charge")
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var interiors: Array = []
	for n in _all_descendants(root):
		if not (n is Node2D):
			continue
		# Un intérieur = un nœud avec un SpawnPoint (cible des BuildingDoor) —
		# le filtre par suffixe de nom laissait passer PenthouseLeblon/
		# OfficeIpanema/ArpoadorBar (cas réel : intérieurs de ZonaSul venus
		# chevaucher la bande de Copa après le littoral continu).
		if String(n.name).ends_with("Interior") \
				or (n.get_node_or_null("SpawnPoint") != null and n.get_parent() != root):
			interiors.append(n)
	const MIN_DIST: float = 500.0
	for i in interiors.size():
		for j in range(i + 1, interiors.size()):
			var a: Node2D = interiors[i] as Node2D
			var b: Node2D = interiors[j] as Node2D
			var d: float = a.global_position.distance_to(b.global_position)
			_assert(d >= MIN_DIST,
				"intérieurs '%s' et '%s' distants de %.0f px (min %.0f)"
					% [a.name, b.name, d, MIN_DIST])
	root.queue_free()
	await get_tree().process_frame


# Garde-fou : la porte d'entrée du MAC (Niterói) doit avoir une destination
# correctement câblée à runtime (vers MACInterior/SpawnPoint). Si le wiring
# silencieux échoue, destination reste Vector2.ZERO → joueur téléporté au
# monde origin = Copacabana. Cas réel signalé en jeu.
func _test_mac_door_destination_wired() -> void:
	_section("Niterói — DoorMAC.destination câblée vers MACInterior")
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn") as PackedScene
	if packed == null:
		_assert(false, "Copacabana.tscn charge")
		return
	var root: Node = packed.instantiate()
	add_child(root)
	# Attendre 2 frames pour laisser le call_deferred du wiring de Niterói
	# s'exécuter (NiteroiDistrict._ready fait call_deferred("_wire_mac_doors")).
	await get_tree().process_frame
	await get_tree().process_frame
	var niteroi: Node = _find_by_name_in(root, "NiteroiDistrict")
	_assert(niteroi != null, "NiteroiDistrict instancié")
	if niteroi != null:
		var door: Node = niteroi.get_node_or_null("DoorMAC")
		var spawn: Node = niteroi.get_node_or_null("MACInterior/SpawnPoint")
		_assert(door != null, "DoorMAC présent")
		_assert(spawn != null, "MACInterior/SpawnPoint présent")
		if door != null and "destination" in door:
			var dest: Vector2 = door.destination
			_assert(dest != Vector2.ZERO,
				"DoorMAC.destination câblée (≠ (0,0) — sinon téléport au monde origin = Copa)")
			if spawn is Node2D:
				var expected: Vector2 = (spawn as Node2D).global_position
				_assert(dest.distance_to(expected) < 5.0,
					"DoorMAC.destination = MAC SpawnPoint (delta < 5 px)")
	root.queue_free()
	await get_tree().process_frame


# Garde-fou véhicules : après un changement de district (taxi ou piéton),
# Politique véhicules : un seul de chaque type dans tout le jeu, chacun avec
# une `home_position` (pos d'instanciation). Au changement de district, tout
# véhicule non monté retourne à sa home_position — ne suit PAS le joueur.
func _test_vehicles_follow_player_on_district_change() -> void:
	_section("Véhicules — retour à la home_position au changement de district")
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn") as PackedScene
	if packed == null:
		_assert(false, "Copacabana.tscn charge")
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = GameManager.player
	_assert(player != null, "GameManager.player présent")
	if player == null:
		root.queue_free(); return
	var vehicles: Array = get_tree().get_nodes_in_group("vehicle")
	_assert(vehicles.size() >= 1, "Au moins un Rideable (groupe 'vehicle')")
	# Pas plus d'1 véhicule par type (Bike / Car / Sup).
	var counts: Dictionary = {}
	for v in vehicles:
		if v is Rideable:
			var vid: String = String((v as Rideable).vehicle_id)
			counts[vid] = int(counts.get(vid, 0)) + 1
	for vid in counts:
		_assert(int(counts[vid]) == 1,
			"un seul véhicule '%s' dans le monde entier (compté %d)" % [vid, counts[vid]])
	# Cache les home_positions avant de bouger.
	var homes: Dictionary = {}
	for v in vehicles:
		if v is Rideable and not (v as Rideable).is_ridden():
			homes[v] = (v as Node2D).global_position
	# Bouge le joueur loin et déplace les véhicules ailleurs manuellement, puis
	# travel_to → les véhicules doivent retomber sur leur home_position.
	for v in vehicles:
		if v is Node2D and v is Rideable and not (v as Rideable).is_ridden():
			(v as Node2D).global_position = Vector2(99999, 99999)  # ailleurs
	var fare: int = DistrictManager.get_fare("niteroi")
	var inv: Node = (player as Node).get_node_or_null("Inventory")
	if inv:
		inv.call("add_money", fare + 100)
	DistrictManager.travel_to("niteroi")
	await get_tree().process_frame
	for v in vehicles:
		if not (v is Rideable):
			continue
		if (v as Rideable).is_ridden():
			continue
		if not homes.has(v):
			continue
		var d: float = (v as Node2D).global_position.distance_to(homes[v])
		_assert(d < 5.0,
			"véhicule '%s' revenu à sa home_position (delta %.0f px)" % [v.name, d])
	root.queue_free()
	await get_tree().process_frame


func _test_copacabana_palace_declutter() -> void:
	_section("Copacabana — Palace décongestionné + Beto visible/atteignable")
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn") as PackedScene
	if packed == null:
		_assert(false, "Copacabana.tscn charge")
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame
	for nm in ["TraficoTioZeSpot", "PoliciaTioZeSpot", "ConsortiumTioZeSpot", "PrefeitoTioZeSpot"]:
		var s: Node = _find_by_name_in(root, nm)
		_assert(s != null and "required_flag" in s and String(s.required_flag) != "",
			"%s : required_flag posé (pas de foule fantôme au Palace)" % nm)
	var beto: Node = _find_by_name_in(root, "BetoSpot")
	_assert(beto != null, "BetoSpot présent")
	if beto != null:
		_assert(int(beto.character_seed) != 0,
			"Beto visible (character_seed ≠ 0 — sinon introuvable)")
		var bp: Vector2 = (beto as Node2D).global_position
		for nm2 in ["Concierge", "TouristVIP", "MadameDubois", "RenatoSpot", "TraficoTioZeSpot"]:
			var o: Node = _find_by_name_in(root, nm2)
			if o is Node2D:
				_assert(bp.distance_to((o as Node2D).global_position) > 120.0,
					"BetoSpot éloigné de '%s' (mission jouable)" % nm2)
	root.queue_free()
	await get_tree().process_frame


func _test_reactive_spots_visible() -> void:
	_section("ReactiveDialogueSpot — spots quêteurs visibles (anti-introuvable)")
	var scenes: Array = ["res://scenes/world/Copacabana.tscn"]
	var dir: DirAccess = DirAccess.open("res://scenes/districts/")
	if dir:
		dir.list_dir_begin()
		var fn: String = dir.get_next()
		while fn != "":
			if fn.ends_with(".tscn"):
				scenes.append("res://scenes/districts/" + fn)
			fn = dir.get_next()
	for sc in scenes:
		var packed: PackedScene = load(sc) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		add_child(root)
		await get_tree().process_frame
		_check_spots_visible(root, sc.get_file())
		root.queue_free()
		await get_tree().process_frame


# Palace décongestionné : les 4 « tio Zé concierge » (un par voie) doivent
# être gated par required_flag (sinon 4 figures identiques en permanence devant
# le Palace) et Beto doit être visible (character_seed) et hors du cluster
# Palace (sinon mission beto_lost injouable — il était invisible et noyé).
# Garde-fou général : toute action `accept_quest` / `finish_quest` portée par
# une variante de ReactiveDialogueSpot doit pointer vers une quête réellement
# enregistrée, et l'objectif (pour finish_quest) doit exister sur cette quête.
# Aurait attrapé C1 de l'audit (act3_policia_intel/intel_vizinha morts).
func _test_spot_actions_reference_valid_quests() -> void:
	_section("Spots — actions accept_quest/finish_quest valides")
	# Re-registre des quêtes pour garantir QuestManager._quests peuplé.
	for path in QUEST_RESOURCES:
		if ResourceLoader.exists(path):
			var q: Resource = load(path)
			if q is Quest:
				QuestManager.register_quest(q)
	var scenes: Array = ["res://scenes/world/Copacabana.tscn"]
	var dir: DirAccess = DirAccess.open("res://scenes/districts/")
	if dir:
		dir.list_dir_begin()
		var fn: String = dir.get_next()
		while fn != "":
			if fn.ends_with(".tscn"):
				scenes.append("res://scenes/districts/" + fn)
			fn = dir.get_next()
	for sc in scenes:
		var packed: PackedScene = load(sc) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		add_child(root)
		await get_tree().process_frame
		_check_spot_actions(root, sc.get_file())
		root.queue_free()
		await get_tree().process_frame


# Beto end-to-end via les vrais spots (Seu Jorge favela → Beto calçadão →
# retour Jorge). Verrouille le découplage : VizinhaSpot ne donne plus la quête,
# Jorge oui ; flags renommés proprement.
func _test_beto_via_spots_end_to_end() -> void:
	_section("Beto — chaîne complète via les spots (Jorge → Beto → retour)")
	_reset_campaign_state()
	# Prérequis : Jorge n'offre la quête qu'après le prologue résolu.
	QuestManager.accept("prologue_pedrinho")
	for obj_id in ["ask_mae", "ask_vovo", "ask_garoto", "find_pedrinho", "bring_home"]:
		QuestManager.complete_objective("prologue_pedrinho", obj_id)
	_assert(QuestManager.is_completed("prologue_pedrinho"), "prérequis prologue OK")
	var fav: Node = (load(_FAVELA) as PackedScene).instantiate()
	add_child(fav)
	var cop: Node = (load(_COPA) as PackedScene).instantiate()
	add_child(cop)
	await get_tree().process_frame
	await get_tree().process_frame
	var jorge: Node = _find_by_name_in(fav, "JorgeSpot")
	var beto: Node = _find_by_name_in(cop, "BetoSpot")
	_assert(jorge != null and beto != null, "JorgeSpot et BetoSpot présents")
	# 1) Seu Jorge propose la quête.
	if jorge:
		jorge._on_interacted(null)
		if DialogueBridge.is_active():
			DialogueBridge.choose(0)
	_assert(QuestManager.is_active("beto_lost"),
		"beto_lost accepté via Seu Jorge (pas VizinhaSpot)")
	_assert(CampaignManager.has_flag("beto_quest_taken"),
		"flag beto_quest_taken posé")
	# 2) Beto sur le calçadão : objectif find_beto.
	if beto:
		beto._on_interacted(null)
		if DialogueBridge.is_active():
			DialogueBridge.choose(0)
	_assert(QuestManager.get_objectives_state("beto_lost").get("find_beto", false),
		"find_beto clos via BetoSpot")
	_assert(CampaignManager.has_flag("beto_found"),
		"flag beto_found posé")
	# 3) Retour chez Jorge : quête complétée.
	if jorge:
		jorge._on_interacted(null)
		if DialogueBridge.is_active():
			DialogueBridge.choose(0)
	_assert(QuestManager.is_completed("beto_lost"),
		"beto_lost complétée via retour chez Jorge")
	_assert(CampaignManager.has_flag("beto_returned"),
		"flag beto_returned posé")
	fav.queue_free()
	cop.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_reset_campaign_state()


func _test_district_spawn_clear_of_exits() -> void:
	_section("Districts — spawns hors des Area2D de sortie (anti ping-pong)")
	var dir: DirAccess = DirAccess.open("res://scenes/districts/")
	if dir == null:
		_assert(false, "ouverture scenes/districts/")
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tscn"):
			var packed: PackedScene = load("res://scenes/districts/" + fname) as PackedScene
			if packed:
				var root: Node = packed.instantiate()
				add_child(root)
				await get_tree().process_frame
				_check_spawns_vs_exits(root, fname)
				root.queue_free()
				await get_tree().process_frame
		fname = dir.get_next()


func _test_walk_entries_clear_of_exits() -> void:
	_section("WALK_ENTRIES — points d'arrivée hors des sorties (anti ping-pong piéton)")
	for target_id in DistrictManager.WALK_ENTRIES:
		if target_id == "copacabana":
			continue  # arrivées en world-space, audit séparé
		var scene_path: String = String(_DISTRICT_SCENE_PATHS.get(target_id, ""))
		if scene_path == "":
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		add_child(root)
		await get_tree().process_frame
		# Index exits by target_district pour retrouver « la sortie qui revient
		# vers le from_id de WALK_ENTRY ».
		var exits_by_target: Dictionary = {}
		for child in root.get_children():
			if child is DistrictExit:
				exits_by_target[String(child.target_district)] = child
		for from_id in DistrictManager.WALK_ENTRIES[target_id]:
			var local: Vector2 = DistrictManager.WALK_ENTRIES[target_id][from_id]
			var exit: DistrictExit = exits_by_target.get(from_id)
			if exit == null:
				continue  # sortie symétrique pas modélisée — pas de risque ping-pong
			var cs: CollisionShape2D = exit.get_node_or_null("CollisionShape2D")
			if cs == null or not (cs.shape is RectangleShape2D):
				continue
			var half: Vector2 = (cs.shape as RectangleShape2D).size * 0.5
			var c: Vector2 = exit.position + cs.position  # tous deux en local
			var inside: bool = absf(local.x - c.x) < half.x + _SPAWN_EXIT_MARGIN \
					and absf(local.y - c.y) < half.y + _SPAWN_EXIT_MARGIN
			_assert(not inside,
				"WALK_ENTRIES[%s][%s] %s hors de '%s' (sinon retour immédiat vers %s)"
					% [target_id, from_id, local, exit.name, from_id])
		root.queue_free()
		await get_tree().process_frame


# Garde-fou général : le knot de base (NPCData.ink_knot) est le fallback de
# _on_interacted. S'il manque dans PLACEHOLDER_DIALOGUES, start_dialogue
# n'émet ni ligne ni choix mais garde _active_npc_id → le jeu se fige (cas
# ramos_intro). On vérifie TOUS les NPCData, pas juste une liste manuelle.
func _test_npc_base_knots_exist() -> void:
	_section("NPC — knot de base (ink_knot) défini pour chaque NPCData")
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	var dir: DirAccess = DirAccess.open(NPC_DATA_DIR)
	if dir == null:
		_assert(false, "ouverture %s" % NPC_DATA_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res: Resource = load(NPC_DATA_DIR + fname)
			if res is NPCData:
				var nd: NPCData = res as NPCData
				_assert(nd.ink_knot != "" and dialogues.has(nd.ink_knot),
					"NPCData '%s' : knot de base '%s' présent (anti-freeze)"
						% [nd.id, nd.ink_knot])
		fname = dir.get_next()


func _test_cutscene_dependencies() -> void:
	_section("Dépendances des cinématiques (NPCs + knots)")
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	# Index NPCData par id pour vérifier la présence.
	var npc_ids: Dictionary = {}
	var dir: DirAccess = DirAccess.open(NPC_DATA_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var res: Resource = load(NPC_DATA_DIR + fname)
				if res is NPCData:
					npc_ids[(res as NPCData).id] = true
			fname = dir.get_next()
	for cs in CUTSCENE_REQUIREMENTS:
		for npc_id in cs.npcs:
			_assert(npc_ids.has(npc_id), "%s : NPCData '%s' présent" % [cs.name, npc_id])
		for knot in cs.knots:
			_assert(dialogues.has(knot), "%s : knot '%s' présent" % [cs.name, knot])


func _test_intro_bump_flow() -> void:
	_section("Cinématique bump : clic Sortir de la maison → Seu João débarque")
	# Sauvegarde flags
	var saved_flags: Dictionary = CampaignManager.flags.duplicate()
	CampaignManager.flags.clear()

	# Charge le monde Copacabana (instancie FavelaDoMorro, HouseInterior, Player…)
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn") as PackedScene
	_assert(packed != null, "Copacabana.tscn charge")
	var world: Node = packed.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player: Node = world.get_node_or_null("Player")
	_assert(player != null, "Player présent dans le monde")
	var house: Node = world.get_node_or_null("TioZeHouseInterior")
	_assert(house != null, "TioZeHouseInterior présent")
	var exit_door: Node = house.get_node_or_null("ExitDoor") if house else null
	_assert(exit_door != null, "ExitDoor présente dans HouseInterior")
	var sj: Node = NPCScheduler.get_npc("seu_joao")
	_assert(sj != null, "Seu João enregistré au scheduler")

	# État initial : Seu João caché + ExitDoor a le hook intro_bump_door
	if exit_door != null:
		_assert(exit_door.get("intro_bump_door") == true, "ExitDoor.intro_bump_door activé")
	if sj != null:
		_assert(not (sj as Node2D).visible, "Seu João caché au démarrage (avant bump)")
		var sj_inter: Node = sj.get_node_or_null("Interactable")
		if sj_inter != null and "enabled" in sj_inter:
			_assert(not sj_inter.enabled, "Seu João Interactable désactivé au démarrage")

	GameManager.player = player

	# Simule le clic Sortir : émet directement le signal interacted de la porte.
	if exit_door != null:
		var door_inter: Node = exit_door.get_node_or_null("Interactable")
		_assert(door_inter != null, "ExitDoor a un Interactable")
		if door_inter:
			door_inter.interacted.emit(player)
	# Attends quelques frames pour que la cutscene démarre (set position + visible)
	await get_tree().physics_frame
	await get_tree().physics_frame

	if sj != null:
		_assert((sj as Node2D).visible, "Seu João rendu visible par la cinématique")
	# Vérifie que le joueur n'a PAS été téléporté dehors (still inside la maison)
	var player_pos: Vector2 = (player as Node2D).global_position
	_assert(player_pos.x > 6000 and player_pos.x < 8000, "Joueur reste dans HouseInterior (pas téléporté)")

	# Cleanup : skip le reste de la cutscene (dialogue bloque sur dialogue_finished en headless)
	CampaignManager.set_flag("intro_bump_seen")
	world.queue_free()
	await get_tree().process_frame
	CampaignManager.flags = saved_flags


func _test_reactive_spots_default_variant() -> void:
	_section("ReactiveDialogueSpot — chaque spot a un fallback")
	for entry in REACTIVE_SPOTS:
		var packed: PackedScene = load(entry.scene) as PackedScene
		if packed == null:
			_assert(false, "scène %s charge" % entry.scene)
			continue
		var instance: Node = packed.instantiate()
		add_child(instance)
		for spot_name in entry.spots:
			var spot: Node = _find_by_name_in(instance, spot_name)
			_assert(spot != null, "%s/%s présent" % [entry.scene, spot_name])
			if spot == null:
				continue
			# Reset flags pour simuler un état neuf.
			var saved_flags: Dictionary = CampaignManager.flags.duplicate()
			CampaignManager.flags.clear()
			var act_save: int = CampaignManager.current_act
			CampaignManager.current_act = 1
			var v: Dictionary = spot._pick_variant()
			_assert(not v.is_empty(),
				"%s : variante par défaut existe (état vide)" % spot_name)
			# Restore.
			CampaignManager.flags = saved_flags
			CampaignManager.current_act = act_save
		instance.queue_free()
		await get_tree().process_frame


func _test_runtime_spot_action_applies() -> void:
	_section("ReactiveDialogueSpot — action runtime appliquée via choose()")
	# Régression : choose() lisait PLACEHOLDER_DIALOGUES et ignorait les
	# dialogues runtime → finish_quest/accept_quest des spots ne
	# s'appliquaient JAMAIS en jeu (prologue + 3 voies bloqués).
	if QuestManager._quests.get("prologue_pedrinho") == null:
		var q: Quest = load("res://resources/quests/prologue_pedrinho.tres") as Quest
		if q:
			QuestManager.register_quest(q)
	# Repart d'un état AVAILABLE propre (erase seul → UNAVAILABLE → accept refuse).
	QuestManager._objectives.erase("prologue_pedrinho")
	QuestManager._state["prologue_pedrinho"] = QuestManager.State.AVAILABLE
	_assert(QuestManager.accept("prologue_pedrinho"), "prologue_pedrinho accepté")
	DialogueBridge.register_runtime_dialogue("spot_regress_runtime", {
		"speaker": "Test",
		"text": "...",
		"choices": ["ok"],
		"on_choose": {"0": {"finish_quest": {"quest": "prologue_pedrinho", "objective": "ask_mae", "payout": 0}}},
	})
	DialogueBridge.start_dialogue("regress_runtime", "spot_regress_runtime")
	DialogueBridge.choose(0)
	_assert(QuestManager.is_objective_done("prologue_pedrinho", "ask_mae"),
		"finish_quest d'un knot runtime complète l'objectif via choose()")
	# Laisse l'état neutre (AVAILABLE, non démarré) pour les tests suivants.
	QuestManager._objectives.erase("prologue_pedrinho")
	QuestManager._state["prologue_pedrinho"] = QuestManager.State.AVAILABLE


func _test_quest_objectives_reachable() -> void:
	_section("Chaque objectif est complétable (dialogue OU script connu)")
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	# Construis l'index { quest_id: [objective_ids] } depuis les finish_quest dans dialogues.
	var dialogue_completions: Dictionary = {}
	for knot in dialogues:
		var on_choose: Dictionary = dialogues[knot].get("on_choose", {})
		for idx in on_choose:
			var act: Dictionary = on_choose[idx]
			if act.has("finish_quest"):
				var fq: Dictionary = act.finish_quest
				var qid: String = fq.get("quest", "")
				var oid: String = fq.get("objective", "")
				if qid != "" and oid != "":
					if not dialogue_completions.has(qid):
						dialogue_completions[qid] = []
					dialogue_completions[qid].append(oid)
	# Pour chaque quête, chaque objectif doit être complétable via dialogue ou liste connue.
	for path in QUEST_RESOURCES:
		if not ResourceLoader.exists(path):
			continue
		var q: Quest = load(path) as Quest
		if q == null:
			continue
		var dlg_obj_ids: Array = dialogue_completions.get(q.id, [])
		var script_obj_ids: Array = SCRIPT_COMPLETED_OBJECTIVES.get(q.id, [])
		for obj in q.objectives:
			if obj.optional:
				continue
			var reachable: bool = dlg_obj_ids.has(obj.id) or script_obj_ids.has(obj.id)
			_assert(reachable,
				"quête '%s' objectif '%s' complétable (dialogue ou script connu)" % [q.id, obj.id])


func _test_navigation_director_targets() -> void:
	_section("NavigationDirector — cibles de guidage")
	var nd: Node = get_node_or_null("/root/NavigationDirector")
	_assert(nd != null, "autoload NavigationDirector présent")
	if nd == null:
		return
	var step: Dictionary = nd.STEP
	var valid_anchors: Array = ["", "calcadao", "atlantica", "palace", "consortium", "taxi", "cart"]
	# 1. Intégrité de chaque entrée du registre de destinations.
	for key in step:
		var e: Dictionary = step[key]
		_assert(String(e.get("text", "")) != "", "STEP %s a un texte" % key)
		var d: String = e.get("dist", "")
		_assert(d == "" or DistrictManager.DISTRICTS.has(d), "STEP %s district valide (%s)" % [key, d])
		var a: String = e.get("anchor", "")
		_assert(a in valid_anchors or a.begins_with("npc:") or a.begins_with("spot:") or a.begins_with("node:") or a.begins_with("class:"),
			"STEP %s anchor valide (%s)" % [key, a])
		# Une ancre `spot:<npc_id>` doit désigner un ReactiveDialogueSpot existant.
		if a.begins_with("spot:"):
			_assert(_spot_npc_ids().has(a.substr(5)), "STEP %s : spot '%s' existe dans une scène" % [key, a.substr(5)])
	# 2. Chaque étape des quêtes MAIN de voie (A/B/C/D) a une cible résoluble.
	var voie_prefixes: Array = ["trafico_a", "policia_b", "consortium_c", "prefeito_d"]
	for path in QUEST_RESOURCES:
		var res: Resource = load(path)
		if not (res is Quest):
			continue
		var q: Quest = res as Quest
		if q.quest_type != Quest.QuestType.MAIN:
			continue
		var is_voie: bool = false
		for p in voie_prefixes:
			if q.id.begins_with(p):
				is_voie = true
				break
		if not is_voie:
			continue
		for obj in q.objectives:
			var key2: String = "%s/%s" % [q.id, obj.id]
			_assert(step.has(key2), "cible de guidage pour étape MAIN %s" % key2)


# --- Vérifications « le jeu est jouable en mobile » ---

# Tout le gameplay doit être atteignable au doigt : déplacement (joystick
# virtuel), interaction (bouton à l'écran), téléphone (bouton 📱 du HUD),
# choix de dialogue (boutons ≥ 44 pt). Aucune feature gated derrière le clavier.
func _test_mobile_controls_invariants() -> void:
	_section("Mobile — contrôles tactiles et cibles ≥ 44 pt")
	# Actions d'input présentes (le bouton tactile InteractButton émet l'action
	# "interact" ; le joystick pilote move_*).
	for act in ["interact", "move_forward", "move_back", "move_left", "move_right"]:
		_assert(InputMap.has_action(act), "action input '%s' définie" % act)
	# MobileControls : joystick + bouton interact tactile, dimensionnés ≥ 44 pt.
	var mc_packed: PackedScene = load("res://scenes/ui/MobileControls.tscn") as PackedScene
	_assert(mc_packed != null, "MobileControls.tscn charge")
	if mc_packed:
		var mc: Node = mc_packed.instantiate()
		add_child(mc)
		await get_tree().process_frame
		var ib: Button = mc.get_node_or_null("InteractButton") as Button
		var joy: Node = mc.get_node_or_null("Joystick")
		_assert(ib != null, "InteractButton (tactile) présent")
		_assert(joy != null, "Joystick virtuel présent")
		if ib:
			var sz: Vector2 = ib.size
			_assert(sz.x >= 44.0 and sz.y >= 44.0,
				"InteractButton ≥ 44×44 pt (actuel %dx%d)" % [sz.x, sz.y])
		# Sprint tactile : bouton 🏃 à bascule (le seuil de déflexion 0.85 du
		# joystick n'était pas utilisable en dirigeant finement — B4).
		var rb: Button = mc.get_node_or_null("RunButton") as Button
		_assert(rb != null, "RunButton (sprint tactile) présent")
		if rb:
			_assert(rb.toggle_mode, "RunButton en mode bascule")
			var rsz: Vector2 = rb.size
			_assert(rsz.x >= 44.0 and rsz.y >= 44.0,
				"RunButton ≥ 44×44 pt (actuel %dx%d)" % [rsz.x, rsz.y])
			rb.button_pressed = true
			await get_tree().process_frame
			_assert(Input.is_action_pressed("run"), "bascule 🏃 ON → action run tenue")
			var joy2: VirtualJoystick = mc.get_node_or_null("Joystick") as VirtualJoystick
			if joy2:
				_assert(joy2.external_run_hold, "le joystick ne relâche pas run pendant la bascule")
			rb.button_pressed = false
			await get_tree().process_frame
			_assert(not Input.is_action_pressed("run"), "bascule 🏃 OFF → action run relâchée")
		mc.queue_free()
		await get_tree().process_frame
	# Mini-jeux : contrôles tactiles dédiés disponibles.
	_assert(ResourceLoader.exists("res://scenes/ui/MinigameTouchControls.tscn"),
		"MinigameTouchControls.tscn présent (mini-jeux jouables au doigt)")
	# HUD : bouton 📱 d'ouverture du téléphone (entrée tactile vers les apps).
	var hud_packed: PackedScene = load("res://scenes/ui/HUD.tscn") as PackedScene
	_assert(hud_packed != null, "HUD.tscn charge")
	if hud_packed:
		var hud: Node = hud_packed.instantiate()
		add_child(hud)
		await get_tree().process_frame
		var phone_btn: Button = hud.get_node_or_null("MenuButton") as Button
		_assert(phone_btn != null and phone_btn.text.find("📱") >= 0,
			"HUD : bouton 📱 (ouvre le téléphone au doigt)")
		hud.queue_free()
		await get_tree().process_frame
	# DialogueUI : les choix sont des Button tappables ≥ 44 pt de haut.
	var du_packed: PackedScene = load("res://scenes/ui/DialogueUI.tscn") as PackedScene
	_assert(du_packed != null, "DialogueUI.tscn charge")
	if du_packed:
		var du: Node = du_packed.instantiate()
		add_child(du)
		await get_tree().process_frame
		# Appel direct du handler (déterministe — évite la flakiness du
		# round-trip de signal global selon l'ordre des tests).
		du._on_choices_presented(["Choix A", "Choix B"])
		await get_tree().process_frame
		var cont: Node = du.get_node_or_null("Panel/Choices")
		var ok_btn: bool = false
		if cont and cont.get_child_count() >= 2:
			var b0: Button = cont.get_child(0) as Button
			ok_btn = b0 != null and b0.custom_minimum_size.y >= 44.0
		_assert(ok_btn, "choix de dialogue = Button ≥ 44 pt de haut")
		du.queue_free()
		await get_tree().process_frame



# --- Vie aléatoire multi-districts (RandomEventManager) ---

# Intégrité du pool et du zonage : ids uniques, districts/zones valides, et
# la logique d'éligibilité (pure) filtre bien par district, phase et flag.
func _test_random_events_multi_district() -> void:
	_section("Vie aléatoire — événements multi-districts")
	# 1. Zonage : chaque district déclaré existe, chaque bbox est bien formée.
	for did in RandomEventManager.DISTRICT_ZONES:
		_assert(DistrictManager.DISTRICTS.has(did),
			"DISTRICT_ZONES : district valide (%s)" % did)
		var zones: Dictionary = RandomEventManager.DISTRICT_ZONES[did]
		_assert(not zones.is_empty(), "DISTRICT_ZONES %s : au moins une zone" % did)
		for z in zones:
			var bbox: Dictionary = zones[z]
			_assert(bbox.x[0] < bbox.x[1] and bbox.y[0] < bbox.y[1],
				"bbox bien formée : %s/%s" % [did, z])
	# 2. Pool : ids uniques, champs requis, restrictions districts valides et
	#    cohérentes (chaque district listé offre au moins une zone de l'event).
	var seen_ids: Dictionary = {}
	for e in RandomEventManager.EVENT_POOL:
		var eid: String = String(e.get("id", ""))
		_assert(eid != "" and not seen_ids.has(eid), "event id unique : %s" % eid)
		seen_ids[eid] = true
		for field in ["label", "speaker", "text", "icon"]:
			_assert(String(e.get(field, "")) != "", "event %s a %s" % [eid, field])
		_assert(not (e.get("spawn_zones", []) as Array).is_empty(),
			"event %s a des spawn_zones" % eid)
		var districts: Array = e.get("districts", ["copacabana"])
		for did in districts:
			_assert(RandomEventManager.DISTRICT_ZONES.has(did),
				"event %s : district connu (%s)" % [eid, did])
			var dz: Dictionary = RandomEventManager.DISTRICT_ZONES.get(did, {})
			var has_zone: bool = false
			for z in e.get("spawn_zones", []):
				if dz.has(z):
					has_zone = true
					break
			_assert(has_zone, "event %s : une zone existe dans %s" % [eid, did])
	# 3. Éligibilité : Copa garde son pool, les nouveaux districts ont le leur,
	#    les events non tagués restent à Copa, phases et flags filtrent.
	CampaignManager.flags.clear()
	var copa_pool: Array = RandomEventManager.eligible_events("copacabana", 0)
	_assert(copa_pool.size() >= 8, "Copa : pool matinal fourni (%d)" % copa_pool.size())
	var zs_pool: Array = RandomEventManager.eligible_events("zona_sul", 1)
	_assert(not zs_pool.is_empty(), "Zona Sul : pool après-midi non vide")
	var zs_ids: Array = zs_pool.map(func(e: Dictionary) -> String: return String(e.id))
	_assert("altinha_circle" in zs_ids, "Zona Sul : l'altinha tourne à Ipanema")
	_assert(not "samba_parade" in zs_ids,
		"Zona Sul : un event non tagué reste à Copa (samba_parade)")
	var bf_evening: Array = RandomEventManager.eligible_events("botafogo_flamengo", 2)
	var bf_ids: Array = bf_evening.map(func(e: Dictionary) -> String: return String(e.id))
	_assert("roda_pagode" in bf_ids, "Botafogo : le pagode du soir tourne à la mureta")
	var nit_ids: Array = RandomEventManager.eligible_events("niteroi", 1) \
		.map(func(e: Dictionary) -> String: return String(e.id))
	_assert("futebol_kids" in nit_ids, "Niterói : la pelada tourne à Icaraí")
	_assert(RandomEventManager.eligible_events("corcovado", 0).is_empty(),
		"District sans zonage : aucun event (corcovado)")
	# 4. Flags : un payoff différé n'apparaît qu'avec son flag.
	var no_flag_ids: Array = RandomEventManager.eligible_events("copacabana", 0) \
		.map(func(e: Dictionary) -> String: return String(e.id))
	_assert(not "recado_caxias" in no_flag_ids, "payoff sans flag : absent")
	CampaignManager.set_flag("voisin_exilado")
	var flag_ids: Array = RandomEventManager.eligible_events("copacabana", 0) \
		.map(func(e: Dictionary) -> String: return String(e.id))
	_assert("recado_caxias" in flag_ids, "payoff avec flag : présent")
	CampaignManager.flags.clear()
	# 5. Bouton altinha : bandes de plage valides.
	var mc: Script = load("res://scripts/ui/MobileControls.gd")
	var bands: Dictionary = mc.BEACH_BANDS
	for did in bands:
		_assert(DistrictManager.DISTRICTS.has(did), "BEACH_BANDS : district valide (%s)" % did)
		var b: Dictionary = bands[did]
		_assert(b.x[0] < b.x[1] and b.y[0] < b.y[1], "BEACH_BANDS %s : bande bien formée" % did)

# --- Vie ambiante hors Copa : soirs d'Arpoador/Icaraí, Forte et Aterro meublés ---

func _test_ambient_life_out_of_copa() -> void:
	_section("Vie ambiante hors Copa — soirs, Forte, Aterro")
	var expectations: Dictionary = {
		"res://scenes/districts/ZonaSul.tscn":
			["ArpoadorSunsetLife", "ArpoadorPalmasSpot"],
		"res://scenes/districts/Niteroi.tscn":
			["IcaraiNoiteLife", "IcaraiSerestaSpot"],
		"res://scenes/districts/ForteDeCopacabana.tscn":
			["FilaColomboSpot", "PescadorForteSpot", "VeteranoSpot", "ForteWanderer1"],
		"res://scenes/districts/BotafogoFlamengo.tscn":
			["PipaSpot", "CoalhoSpot", "AterroWanderer1"],
	}
	for path in expectations:
		var inst: Node = (load(path) as PackedScene).instantiate()
		add_child(inst)
		await get_tree().process_frame
		for node_name in expectations[path]:
			_assert(_find_by_name_in(inst, node_name) != null,
				"%s présent dans %s" % [node_name, path.get_file()])
		# Les conteneurs EveningOnly ne sont visibles que le soir.
		for evening_name in ["ArpoadorSunsetLife", "IcaraiNoiteLife"]:
			var ev: Node = _find_by_name_in(inst, evening_name)
			if ev and ev is Node2D:
				TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
				ev._on_phase_changed(TimeOfDay.Phase.MORNING)
				_assert(not (ev as Node2D).visible, "%s invisible le matin" % evening_name)
				ev._on_phase_changed(TimeOfDay.Phase.EVENING)
				_assert((ev as Node2D).visible, "%s visible le soir" % evening_name)
				TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
		inst.queue_free()
		await get_tree().process_frame


# --- Réputation & affinité qui travaillent (P5) ---

# La réputation d'activité est plafonnée, les signatures sont honnêtes
# (exercise = CHARISMA affiché, kite = kitesurf), et les effets mécaniques
# répondent : preço de amigo, le morro qui couvre, la PM qui laisse passer.
func _test_reputation_affinity_effects() -> void:
	_section("Réputation & affinité — effets manette en main")
	# 1. Cap ActivityRewards : 6 volleys qualifiants ne donnent que 3× la
	#    signature (le grind de réputation s'arrête au seuil mestre).
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, 0)
	ActivityRewards._qualify_counts.clear()
	for i in 6:
		EventBus.minigame_ended.emit("beach_volley", {"qualifies": true, "tip": 0})
	var street: int = ReputationSystem.get_value(ReputationSystem.Axis.STREET)
	_assert(street == 2 * ActivityRewards.REP_CAP_MULTIPLIER,
		"cap réputation d'activité : 6 volleys → STREET %d (attendu %d)"
			% [street, 2 * ActivityRewards.REP_CAP_MULTIPLIER])
	_assert(ActivityRewards.count("beach_volley") == 6,
		"le compteur mestre continue de compter au-delà du cap")
	# 2. Signatures honnêtes : exercise crédite CHARISMA (l'axe affiché),
	#    kitesurf a sa propre signature (fini les récompenses surf au kite).
	_assert(int(ActivityRewards.SIGNATURES["exercise"].axis) == ReputationSystem.Axis.CHARISMA,
		"exercise → CHARISMA (l'axe annoncé à l'écran)")
	_assert(ActivityRewards.SIGNATURES.has("kitesurf"), "signature kitesurf présente")
	var sg: SurfGame = SurfGame.new()
	_assert("minigame_id" in sg and String(sg.minigame_id) == "surf",
		"SurfGame expose minigame_id (défaut surf, surchargé kitesurf au kite)")
	sg.free()
	# 3. Preço de amigo : l'affinité du marchand baisse son prix (plancher 1).
	var sv: StreetVendor = StreetVendor.new()
	sv.vendor_id = "test_affinity"
	sv.price = 5
	_assert(sv.current_price() == 5, "vendeur inconnu : plein tarif")
	NPCAffinity.bump("vendor_test_affinity", NPCAffinity.ACQUAINTANCE_THRESHOLD)
	_assert(sv.current_price() == 4, "freguês connu : 1 R$ de moins")
	NPCAffinity.bump("vendor_test_affinity", NPCAffinity.FAMILIAR_THRESHOLD)
	_assert(sv.current_price() == 3, "freguês familier : preço de amigo (2 R$ de moins)")
	sv.price = 2
	_assert(sv.current_price() == 1, "le preço de amigo ne descend jamais sous 1 R$")
	sv.free()
	# 4. Le morro couvre : STREET ≥ seuil raccourcit l'abandon et la fatigue
	#    du poursuivant ; en dessous, config inchangée.
	var base: Dictionary = {"give_up_sec": 40.0, "tire_after_sec": 20.0}
	var cold: Dictionary = CobradorChase.adjusted_config(base, CobradorChase.STREET_COVER_THRESHOLD - 1)
	_assert(float(cold.give_up_sec) == 40.0, "STREET bas : poursuite inchangée")
	var covered: Dictionary = CobradorChase.adjusted_config(base, CobradorChase.STREET_COVER_THRESHOLD)
	_assert(float(covered.give_up_sec) < 40.0 and float(covered.tire_after_sec) < 20.0,
		"STREET haut : le poursuivant abandonne plus tôt et fatigue plus vite")
	_assert(float(base.give_up_sec) == 40.0, "adjusted_config ne mute pas la config d'origine")
	# 5. La PM laisse passer ses alliés (racket du calçadão).
	_assert(not PMPatrol.waves_through(PMPatrol.POLICE_PASS_THRESHOLD - 1),
		"POLICE bas : le racket s'applique")
	_assert(PMPatrol.waves_through(PMPatrol.POLICE_PASS_THRESHOLD),
		"POLICE haut : la patrouille salue au lieu de racketter")
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, 0)
	ActivityRewards._qualify_counts.clear()
	CampaignManager.flags.erase("mestre_beach_volley")


# --- Profondeur des mini-jeux refondus (axe F : pêche & treino) ---

# Le risque/récompense doit être monotone : à la pêche, plus loin = poisson
# qui vaut plus, fenêtre de ferrage plus courte, puxadas plus dures ; au
# treino, chaque série est plus rapide avec une zone de forme plus étroite.
# Hora do rush (milho après l'acte 1) : règles pures, fregueses réels, mode
# rush de la carrocinha, et un service joué dans la vraie scène.
func _test_milho_rush() -> void:
	_section("Milho — Hora do rush")
	_assert(MilhoGame.cook_state(0.0) == MilhoGame.Cook.CRU, "cuisson : cru au départ")
	_assert(MilhoGame.cook_state(MilhoGame.COOK_PONTO) == MilhoGame.Cook.PONTO, "cuisson : no ponto à %.0f s" % MilhoGame.COOK_PONTO)
	_assert(MilhoGame.cook_state(MilhoGame.COOK_PASSADO) == MilhoGame.Cook.PASSADO, "cuisson : passado ensuite")
	_assert(MilhoGame.cook_state(MilhoGame.COOK_DESMANCHOU + 1.0) == MilhoGame.Cook.DESMANCHOU, "cuisson : desmanchou à la fin")
	var order: Array = ["manteiga", "sal"]
	_assert(MilhoGame.grade(order, ["sal", "manteiga"], MilhoGame.Cook.PONTO) == MilhoGame.Grade.PERFEITO, "note : bonne garniture (ordre libre) + no ponto = Perfeito")
	_assert(MilhoGame.grade(order, order, MilhoGame.Cook.CRU) == MilhoGame.Grade.BOA, "note : cru = Boa")
	_assert(MilhoGame.grade(order, order, MilhoGame.Cook.PASSADO) == MilhoGame.Grade.BOA, "note : passado = Boa")
	_assert(MilhoGame.grade(order, ["manteiga"], MilhoGame.Cook.PONTO) == MilhoGame.Grade.MOLE, "note : garniture fausse = Mole")
	_assert(MilhoGame.grade(order, order, MilhoGame.Cook.DESMANCHOU) == MilhoGame.Grade.MOLE, "note : desmanchou = Mole")
	_assert(MilhoGame.shows_order(0, false), "habitué inconnu : dit sa commande")
	_assert(not MilhoGame.shows_order(MilhoGame.KNOWN_AFTER, false), "habitué connu : « o de sempre »")
	_assert(not MilhoGame.shows_order(0, true), "2e passage dans le rush : « o de sempre »")
	_assert(MilhoGame.tip_for({"regular": true, "shows_order": false}, MilhoGame.Grade.PERFEITO) > MilhoGame.tip_for({"regular": true, "shows_order": true}, MilhoGame.Grade.PERFEITO), "pourboire : se souvenir paie plus")
	_assert(MilhoGame.tip_for({"kind": "gamin"}, MilhoGame.Grade.PERFEITO) == 0, "pourboire : le gamin ne paie pas")
	_assert(MilhoGame.tip_for({"regular": false}, MilhoGame.Grade.BOA) == 0, "pourboire : pas de tip sans Perfeito")
	var ids: Dictionary = {}
	for r in MilhoGame.REGULARS:
		_assert(ResourceLoader.exists("res://resources/npcs/%s.tres" % r.id), "freguês %s : NPC réel (affinité/jeitinho)" % r.id)
		_assert(not ids.has(r.id), "freguês %s : unique" % r.id)
		ids[r.id] = true
		var valid: bool = not r.order.is_empty()
		for t in r.order:
			valid = valid and MilhoGame.TOPPINGS.has(t)
		_assert(valid, "freguês %s : commande valide" % r.id)
	_assert(ActivityRewards.SIGNATURES.has("milho"), "signature d'activité « milho »")
	# La carrocinha passe en mode rush dès l'acte 2, sauf tutoriel en cours.
	_reset_campaign_state()
	var cart: CornCart = CornCart.new()
	CampaignManager.current_act = 1
	_assert(not cart.is_rush_mode(), "acte 1 : tournée à pied (tutoriel)")
	CampaignManager.current_act = 2
	_assert(cart.is_rush_mode(), "acte 2 : Hora do rush")
	QuestManager._state["quest_milho_01"] = QuestManager.State.ACTIVE
	_assert(not cart.is_rush_mode(), "tutoriel milho actif : pas de rush")
	cart.free()
	# Un service joué dans la vraie scène.
	_reset_campaign_state()
	var game: MilhoGame = load("res://scenes/minigames/Milho.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	_assert(game._pot_buttons.size() == MilhoGame.POT_SLOTS and game._queue_buttons.size() == MilhoGame.QUEUE_SLOTS, "scène : panela et file construites")
	var min_side: float = 999.0
	for b in game._pot_buttons + game._queue_buttons:
		min_side = minf(min_side, minf(b.size.x, b.size.y))
	_assert(min_side >= 88.0, "cibles tactiles larges (min %.0f px)" % min_side)
	game._on_pot_pressed(0)
	game._pot[0].t = MilhoGame.COOK_PONTO + 1.0
	game._on_pot_pressed(0)
	_assert(int(game._hand.get("cook", -1)) == MilhoGame.Cook.PONTO, "épi pris no ponto")
	game._on_topping_pressed("manteiga")
	game._on_topping_pressed("sal")
	var jorge: Dictionary = {}
	for r in MilhoGame.REGULARS:
		if r.id == "jorge":
			jorge = r
	game._queue[0] = {"regular": true, "id": "jorge", "name": "Jorge", "order": jorge.order, "line": jorge.line, "shows_order": true, "patience": 10.0, "seed": 1}
	var aff_before: int = NPCAffinity.count("jorge")
	game._on_client_pressed(0)
	_assert(game._score == 3 and game._perfeitos == 1, "Jorge servi Perfeito : 3 pts")
	_assert(game._cash == MilhoGame.PRICE + MilhoGame.TIP_REGULAR, "Jorge paie prix + pourboire d'habitué")
	_assert(int(CampaignManager.flags.get(MilhoGame.known_key("jorge"), 0)) == 1, "la carrocinha retient Jorge (1/%d)" % MilhoGame.KNOWN_AFTER)
	_assert(NPCAffinity.count("jorge") == aff_before + 1, "affinité Jorge +1 (jeitinho)")
	# 2e Perfeito dans le même rush : connu, mais pas de 2e bump d'affinité.
	game._pot[1] = {"t": MilhoGame.COOK_PONTO + 1.0}
	game._on_pot_pressed(1)
	game._on_topping_pressed("manteiga")
	game._on_topping_pressed("sal")
	game._queue[1] = {"regular": true, "id": "jorge", "name": "Jorge", "order": jorge.order, "line": jorge.line, "shows_order": false, "patience": 10.0, "seed": 1}
	game._on_client_pressed(1)
	_assert(int(CampaignManager.flags.get(MilhoGame.known_key("jorge"), 0)) == MilhoGame.KNOWN_AFTER, "Jorge devient freguês (o de sempre)")
	_assert(NPCAffinity.count("jorge") == aff_before + 1, "une seule hausse d'affinité par rush et par habitué")
	# Mauvaise garniture : il refuse.
	game._pot[2] = {"t": MilhoGame.COOK_PONTO + 1.0}
	game._on_pot_pressed(2)
	game._queue[2] = {"regular": false, "kind": "carioca", "name": "Carioca", "order": ["queijo"], "shows_order": true, "patience": 10.0, "seed": 2}
	var cash_before: int = game._cash
	game._on_client_pressed(2)
	_assert(game._cash == cash_before and game._score == 6, "garniture fausse : refus, rien payé")
	game.free()
	_reset_campaign_state()


# Marina (Regata) et Santos Dumont (Desembarque) : règles pures et contrats.
func _test_regata_desembarque() -> void:
	_section("Regata da Glória — polaire et virements")
	var north: float = -PI / 2.0
	_assert(RegataGame.polar(0.0) == 0.0 and RegataGame.polar(RegataGame.NO_GO_DEG - 1.0) == 0.0, "vent debout : la voile fasseye (vitesse 0)")
	_assert(RegataGame.polar(90.0) == 1.0, "travers : allure la plus rapide")
	_assert(RegataGame.polar(90.0) > RegataGame.polar(45.0) and RegataGame.polar(90.0) > RegataGame.polar(180.0), "travers > près et > vent arrière")
	_assert(is_equal_approx(RegataGame.off_wind_deg(north, north), 0.0), "cap face au vent = 0°")
	_assert(is_equal_approx(RegataGame.off_wind_deg(PI / 2.0, north), 180.0), "cap sous le vent = 180°")
	_assert(RegataGame.tack_side(north, north) == 0, "vent debout : pas d'amures")
	_assert(RegataGame.tack_side(north + deg_to_rad(60.0), north) == -RegataGame.tack_side(north - deg_to_rad(60.0), north), "deux bords = deux amures opposées")
	_assert(RegataGame.MARKS[0].y < RegataGame.START.y and RegataGame.MARKS.size() == RegataGame.MARK_NAMES.size(), "parcours : la 1re bouée est au vent")
	_assert(RegataGame.RIVAL_PATH[RegataGame.RIVAL_PATH.size() - 1] == RegataGame.MARKS[RegataGame.MARKS.size() - 1], "Bia finit sur la ligne d'arrivée")
	for i in range(1, RegataGame.RIVAL_PATH.size()):
		var dir: Vector2 = RegataGame.RIVAL_PATH[i] - RegataGame.RIVAL_PATH[i - 1]
		_assert(RegataGame.off_wind_deg(dir.angle(), north) >= RegataGame.NO_GO_DEG, "Bia : segment %d navigable (pas face au vent)" % i)
	_assert(ActivityRewards.SIGNATURES.has("regata"), "signature d'activité « regata »")
	_section("Desembarque — un seul bon passager")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var all_ok: bool = true
	var decoys_ok: bool = true
	for i in 40:
		var n: int = 6 + i % 6
		var decoys: int = 1 + (i % 6) / 2
		var r: Dictionary = DesembarqueGame.make_round(rng, n, decoys)
		var hits: int = 0
		var near: int = 0
		for p in r.passengers:
			if DesembarqueGame.matches(p, r.client):
				hits += 1
			else:
				var same: int = int(p.shirt == r.client.shirt) + int(p.hat == r.client.hat) + int(p.bag == r.client.bag)
				if same == 2:
					near += 1
		all_ok = all_ok and hits == 1 and r.passengers.size() == n
		decoys_ok = decoys_ok and near >= decoys
	_assert(all_ok, "40 manches : exactement un passager correspond, n passagers")
	_assert(decoys_ok, "40 manches : au moins `decoys` leurres à 2 indices sur 3")
	_assert(DesembarqueGame.QUALIFY_SCORE <= DesembarqueGame.ROUNDS * 3 and DesembarqueGame.QUALIFY_SCORE > DesembarqueGame.ROUNDS, "Desembarque : seuil exigeant mais atteignable")
	_assert(ActivityRewards.SIGNATURES.has("desembarque"), "signature d'activité « desembarque »")
	# Un client trouvé dans la vraie scène.
	var g: DesembarqueGame = load("res://scenes/minigames/Desembarque.tscn").instantiate()
	add_child(g)
	g.set_process(false)
	for i in 30:
		g._process(0.1)
	var target: Dictionary = {}
	for p in g._passengers:
		if DesembarqueGame.matches(p.attrs, g._client):
			target = p
	if target.is_empty():
		for i in 40:
			g._process(0.1)
			for p in g._passengers:
				if DesembarqueGame.matches(p.attrs, g._client):
					target = p
			if not target.is_empty():
				break
	_assert(not target.is_empty(), "scène : le bon passager finit par sortir de la porte")
	if not target.is_empty():
		g.tap_at(target.sprite.position)
		_assert(g._score >= 2 and g._cash >= DesembarqueGame.FARE and g._round == 1, "toucher le bon passager : course payée, client suivant")
	g.free()


# Corrections rapides de lisibilité (critique joueur neuf, 2026-10-12).
func _test_lisibilite_ui() -> void:
	_section("Lisibilité — écran titre, dialogue, prompts, repère joueur")
	var intro: GDScript = load("res://scripts/main/Intro.gd")
	_assert(intro.voie_label(CampaignManager.Endgame.PREFEITO) == "Prefeito", "écran titre : Prefeito n'est plus étiqueté Polícia")
	_assert(intro.voie_label(CampaignManager.Endgame.POLICIA) == "Polícia", "écran titre : Polícia")
	_assert(intro.voie_label(CampaignManager.Endgame.TRAFICO) == "Tráfico", "écran titre : Tráfico")
	_assert(intro.voie_label(CampaignManager.Endgame.CONSORTIUM) == "Consórcio", "écran titre : Consórcio")
	_assert(intro.voie_label(CampaignManager.Endgame.NONE) == "", "écran titre : pas de voie = rien")
	var dlg_script: GDScript = load("res://scripts/ui/DialogueUI.gd")
	var consts: Dictionary = dlg_script.get_script_constant_map()
	_assert(int(consts["TEXT_SIZE"]) >= 30, "dialogue : texte ≥ 30 px (≈ 11 pt sur iPhone)")
	var dlg: Node = load("res://scenes/ui/DialogueUI.tscn").instantiate()
	add_child(dlg)
	var line: String = dlg.format_line("*pose la louche* Mange, [filho].")
	_assert(line.begins_with("[i][color=") and line.find("pose la louche") != -1, "didascalie en italique atténué")
	_assert(line.find("[lb]filho]") != -1, "crochets du texte échappés (pas de BBCode parasite)")
	dlg.free()
	_assert(InputHints.act() == "✋" or InputHints.act() == "[E]", "prompt : ✋ en tactile, [E] au clavier")
	var hud_src: String = FileAccess.get_file_as_string("res://scripts/ui/HUD.gd")
	_assert(hud_src.find("\"[E] \" + prompt_text") == -1, "HUD : plus de « [E] » codé en dur")
	# Étiquette du monde : jamais au-delà de ×2.
	var l: Label = Label.new()
	l.text = "Carrocinha de tio Zé"
	l.add_theme_font_size_override("font_size", 18)
	PixelFont.style_world_label(l)
	_assert(l.get_theme_font_size("font_size") <= PixelFont.SIZE * 2, "étiquette du monde plafonnée à ×2")
	l.free()
	# Repère joueur : visible au départ, ré-armé par un saut de position.
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var m: PlayerMarker = PlayerMarker.new()
	holder.add_child(m)
	m._process(0.1)
	_assert(m.is_showing(), "repère visible au démarrage")
	m._process(PlayerMarker.SHOW_SEC + 1.0)
	_assert(not m.is_showing(), "repère éteint après quelques secondes")
	holder.global_position += Vector2(PlayerMarker.TELEPORT_PX + 50.0, 0)
	m._process(0.1)
	_assert(m.is_showing(), "téléportation → repère rallumé")
	holder.free()


func _test_minigame_depth_contracts() -> void:
	_section("Mini-jeux refondus — courbes de difficulté cohérentes")
	var bands: Array = FishingGame.BANDS
	_assert(bands.size() == 3, "pêche : 3 bandes d'eau")
	for i in range(1, bands.size()):
		_assert(int(bands[i].value) > int(bands[i - 1].value),
			"pêche : le poisson du %s vaut plus que celui du %s" % [bands[i].name, bands[i - 1].name])
		_assert(float(bands[i].strike_window) < float(bands[i - 1].strike_window),
			"pêche : fenêtre de ferrage plus courte au %s" % bands[i].name)
		_assert(float(bands[i].tension_pull) > float(bands[i - 1].tension_pull),
			"pêche : puxada plus dure au %s" % bands[i].name)
	_assert(FishingGame.QUALIFY_SCORE > int(bands[0].value),
		"pêche : qualifier exige plus qu'une tainha")
	var sets: Array = ExerciseGame.SETS
	_assert(sets.size() == 3, "treino : 3 séries")
	for i in range(1, sets.size()):
		_assert(float(sets[i].rise) > float(sets[i - 1].rise),
			"treino : %s plus rapide que %s" % [sets[i].name, sets[i - 1].name])
		_assert(float(sets[i].zone_w) < float(sets[i - 1].zone_w),
			"treino : zone de forme plus étroite au %s" % sets[i].name)
	var max_score: int = ExerciseGame.REPS_PER_SET * sets.size() * 3
	_assert(ExerciseGame.QUALIFY_SCORE > max_score / 3 and ExerciseGame.QUALIFY_SCORE < max_score,
		"treino : seuil qualifiant exigeant mais atteignable (%d / max %d)"
			% [ExerciseGame.QUALIFY_SCORE, max_score])


# npc_id de tous les ReactiveDialogueSpot déclarés dans les scènes (Copa + districts + intérieurs).
var _spot_ids_cache: Array = []
func _spot_npc_ids() -> Array:
	if not _spot_ids_cache.is_empty():
		return _spot_ids_cache
	var re: RegEx = RegEx.new()
	re.compile("npc_id = \"([a-z0-9_]+)\"")
	var files: Array = ["res://scenes/world/Copacabana.tscn"]
	files.append_array(_list_scenes_under("res://scenes/districts/"))
	files.append_array(_list_scenes_under("res://scenes/interiors/"))
	for f in files:
		var txt: String = FileAccess.get_file_as_string(f)
		for m in re.search_all(txt):
			_spot_ids_cache.append(m.get_string(1))
	return _spot_ids_cache


# Playtest 2026-10-07 — F2 : le prologue prime même quand act1_started est déjà
# posé (ordre réel : bump de Seu João, puis la mère de Pedrinho) ; F3 : le dîner
# ne rappelle qu'une fois par jour et, dans la favela, pointe la maison.
func _test_navigation_director_prologue_and_jantar() -> void:
	_section("NavigationDirector — prologue prioritaire et jantar quotidien")
	_reset_campaign_state()
	var saved_phase: int = TimeOfDay.current_phase
	var saved_dist: String = DistrictManager.current()
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
	CampaignManager.set_flag("act1_started")
	QuestManager.accept("act1_heritage")
	QuestManager.accept("prologue_pedrinho")
	DistrictManager.set_current("favela_morro")
	var sel: Dictionary = NavigationDirector._compute_selection()
	_assert(String(sel.get("text", "")).find("Pedrinho") != -1, "prologue actif + act1_started → guide la mère de Pedrinho (%s)" % sel.get("text", ""))
	_assert(String(sel.get("anchor", "")) == "spot:vizinha", "…avec une ancre spot: sur la mère")
	QuestManager.complete_objective("prologue_pedrinho", "ask_mae", false)
	sel = NavigationDirector._compute_selection()
	_assert(String(sel.get("anchor", "")) == "spot:vovo_morro", "étape 2 → ancre sur la vovó do morro (%s)" % sel.get("anchor", ""))
	TimeOfDay.current_phase = TimeOfDay.Phase.EVENING
	sel = NavigationDirector._compute_selection()
	_assert(String(sel.get("text", "")).find("dîner") == -1, "le soir ne coupe pas le prologue")
	# Jantar : acte 1 sans prologue, le soir.
	_reset_campaign_state()
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("met_consortium")
	CampaignManager.set_flag("first_sale_done")
	QuestManager.accept("act1_heritage")
	TimeOfDay.current_phase = TimeOfDay.Phase.EVENING
	DistrictManager.set_current("copacabana")
	sel = NavigationDirector._compute_selection()
	_assert(String(sel.get("text", "")).find("dîner") != -1 and sel.get("dist", "") == "favela_morro", "Copa le soir → rentre dîner au morro (%s)" % sel.get("text", ""))
	DistrictManager.set_current("favela_morro")
	sel = NavigationDirector._compute_selection()
	_assert(String(sel.get("text", "")).find("dîner") != -1 and sel.get("anchor", "") == "node:TioZeDoor",
		"favela le soir → la porte de la maison, pas l'escalier (%s / %s)" % [sel.get("text", ""), sel.get("anchor", "")])
	BuildingManager.is_inside = true
	sel = NavigationDirector._compute_selection()
	_assert(sel.get("anchor", "") == "spot:mae", "dans la maison le soir → mãe (%s)" % sel.get("anchor", ""))
	BuildingManager.is_inside = false
	CampaignManager.set_flag("jantar_day", TimeOfDay.day_count)
	sel = NavigationDirector._compute_selection()
	_assert(String(sel.get("text", "")).find("dîner") == -1, "dîner pris → plus de rappel ce jour-là (%s)" % sel.get("text", ""))
	# Acte 2, tous les patrons goûtés, le cash en poche : on dit d'aller payer.
	CampaignManager.set_flag("act1_closed")
	CampaignManager.set_flag("tito_approached")
	CampaignManager.current_act = 2
	CampaignManager.debt_paid = 1000
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
	DistrictManager.set_current("copacabana")
	for q in ["policia_b1_intel", "prefeito_d1_peticao", "trafico_a1_livraison", "consortium_c1_recouvrement"]:
		QuestManager._state[q] = QuestManager.State.COMPLETED
	var inv: Node = GameManager.player.get_node_or_null("Inventory") if GameManager.player else null
	if inv != null:
		var saved_money: int = inv.money
		inv.money = 0
		sel = NavigationDirector._compute_selection()
		_assert(String(sel.get("text", "")).find("Réunis") != -1, "acte 2 sans cash → réunir l'argent (%s)" % sel.get("text", ""))
		inv.money = 5000
		sel = NavigationDirector._compute_selection()
		_assert(String(sel.get("text", "")).find("verser") != -1 and sel.get("anchor", "") == "consortium",
			"acte 2 avec le cash → va verser au consortium (%s)" % sel.get("text", ""))
		inv.money = saved_money
	_assert(String(sel.get("text", "")).find("Descends") != -1, "…et la favela renvoie à Copa normalement")
	# La variante jantar de mãe : phase soir, une fois par jour, acte ≤ 3.
	TimeOfDay.current_phase = TimeOfDay.Phase.EVENING
	CampaignManager.current_act = 1
	var house: Node = (load("res://scenes/interiors/HouseInterior.tscn") as PackedScene).instantiate()
	add_child(house)
	var mae: Node = house.get_node_or_null("MotherSpot")
	_assert(mae != null, "MotherSpot présent")
	if mae != null:
		CampaignManager.flags.erase("jantar_day")
		var v: Dictionary = mae._pick_variant()
		_assert(String(v.get("id", "")) == "jantar", "le soir, mãe sert le jantar (variante '%s')" % v.get("id", ""))
		CampaignManager.set_flag("jantar_day", TimeOfDay.day_count)
		v = mae._pick_variant()
		_assert(String(v.get("id", "")) != "jantar", "jantar déjà pris aujourd'hui → autre variante")
		CampaignManager.flags.erase("jantar_day")
		TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
		v = mae._pick_variant()
		_assert(String(v.get("id", "")) != "jantar", "le matin → pas de jantar")
	house.queue_free()
	# Voie scellée sans mission active → le donneur de la prochaine mission
	# (B3 s'offre au spot de filature du morro, pas chez Ramos).
	_reset_campaign_state()
	CampaignManager.current_act = 3
	CampaignManager.set_flag("act1_closed")
	CampaignManager.set_flag("voie_policia")
	for q in ["prologue_pedrinho", "act1_heritage", "policia_b1_intel", "policia_b2_filature"]:
		QuestManager._state[q] = QuestManager.State.COMPLETED
	_assert(QuestManager.is_available("policia_b3_escorte"), "fixture : B3 disponible après B2")
	var vc: Dictionary = NavigationDirector._voie_continue()
	_assert(String(vc.get("anchor", "")) == "spot:policia_filature" or String(vc.get("anchor", "")).begins_with("npc:"),
		"voie Polícia après B2 → le donneur de B3 (%s)" % vc.get("anchor", ""))
	if String(vc.get("anchor", "")) == "spot:policia_filature":
		_assert(vc.get("dist", "") == "favela_morro", "…dans la favela (%s)" % vc.get("dist", ""))
	if NavigationDirector._find_world_node("spot:policia_filature") != null:
		_assert(String(vc.get("text", "")).find("Ramos") == -1, "…et le bandeau ne renvoie plus chez Ramos (%s)" % vc.get("text", ""))
	_reset_campaign_state()
	CampaignManager.set_flag("act1_started")
	# Finale Polícia : B9 active sans signal → Ramos d'abord, puis le morro.
	_reset_campaign_state()
	CampaignManager.current_act = 4
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("act1_closed")
	CampaignManager.set_flag("voie_policia")
	TimeOfDay.current_phase = TimeOfDay.Phase.MORNING
	QuestManager._state["policia_b9_madrugada"] = QuestManager.State.ACTIVE
	QuestManager._objectives["policia_b9_madrugada"] = {"complete_madrugada": false}
	var b9: Dictionary = NavigationDirector._compute_selection()
	_assert(String(b9.get("anchor", "")) == "npc:ramos", "B9 sans signal → Ramos (%s)" % b9.get("text", ""))
	CampaignManager.set_flag("madrugada_lancee")
	b9 = NavigationDirector._compute_selection()
	_assert(b9.get("dist", "") == "favela_morro", "B9 lancée → le morro (%s)" % b9.get("text", ""))
	_reset_campaign_state()
	CampaignManager.set_flag("act1_started")
	# Ancre npc: d'un PNJ d'intérieur → la porte de son bâtiment (Ramos → Academia).
	var ramos: Node2D = NPCScheduler.get_npc("ramos")
	if ramos != null:
		var target: Node = NavigationDirector._entrance_or_self(ramos)
		_assert(target != ramos and target is BuildingDoor, "npc:ramos → porte de l'Academia (%s)" % (target.name if target else "null"))
		if target is BuildingDoor:
			_assert((target as Node2D).global_position.y > -300.0 and (target as Node2D).global_position.y < 0.0,
				"…sur la carte de Copa, pas dans l'intérieur (%s)" % (target as Node2D).global_position)
	# F6 : la charrette portée est déposée à la bascule d'acte.
	var cart_scene: PackedScene = load("res://scenes/props/CornCart.tscn")
	if cart_scene != null:
		var cart: Node2D = cart_scene.instantiate()
		add_child(cart)
		cart.global_position = Vector2(100, 100)
		cart.pick_up(null)
		_assert(cart.is_carrying(), "fixture : charrette portée")
		cart._on_act_changed(2)
		_assert(not cart.is_carrying(), "bascule d'acte → charrette déposée")
		_assert(cart.interactable != null and cart.interactable.enabled, "…et de nouveau interactive (rush)")
		cart.queue_free()
	TimeOfDay.current_phase = saved_phase
	DistrictManager.set_current(saved_dist)
	_reset_campaign_state()


# Playtest 2026-10-07 — F1 : un job ne se re-tire pas aussitôt, et la paie
# suit la distance (un marqueur sous les pieds paie 30 %).
func _test_dynamic_missions_not_farmable() -> void:
	_section("Missions dynamiques — pas farmables sur place")
	var dm: Node = get_node_or_null("/root/DynamicMissionManager")
	_assert(dm != null, "autoload DynamicMissionManager présent")
	if dm == null:
		return
	var cat: int = DynamicMissionManager.Category.VOYOU
	var pool: Array = DynamicMissionManager.TEMPLATES[cat]
	var last: String = String(pool[0].get("title", ""))
	dm._last_title[cat] = last
	var repeated: int = 0
	for i in 30:
		dm._generate_for(cat)
		if String(dm.get_mission(cat).get("title", "")) == last:
			repeated += 1
	_assert(repeated == 0, "le dernier job joué n'est jamais re-tiré aussitôt (%d/30)" % repeated)
	var m: Dictionary = dm.get_mission(cat)
	_assert(int(m.get("base_money", 0)) == DynamicMissionManager.REWARD_TABLE[int(m.get("tier", 0))], "base_money = table du tier")
	if GameManager.player != null and is_instance_valid(GameManager.player):
		var player: Node2D = GameManager.player as Node2D
		var saved: Vector2 = player.global_position
		# Un job de Copa (sans district) : debout sur son 1er point → 30 %.
		var copa_tpl: Dictionary = {}
		for tpl in pool:
			if not tpl.has("district") and (tpl.get("points", []) as Array).size() == 1:
				copa_tpl = tpl
				break
		if not copa_tpl.is_empty():
			var t: Dictionary = copa_tpl.duplicate(true)
			t["category"] = cat
			t["tier"] = 0
			t["base_money"] = 80
			t["money"] = 80
			t["progress"] = 0
			t["accepted"] = false
			dm._active[cat] = t
			player.global_position = (t.points as Array)[0]
			_assert(dm.accept(cat), "acceptation sur place")
			_assert(int(dm.get_mission(cat).get("money", 0)) == 24, "job sous les pieds → 30 %% de la paie (%d)" % int(dm.get_mission(cat).get("money", 0)))
			dm._despawn_marker(cat)
			# Même job accepté à 1 000 px → pleine paie.
			var t2: Dictionary = copa_tpl.duplicate(true)
			t2["category"] = cat
			t2["tier"] = 0
			t2["base_money"] = 80
			t2["money"] = 80
			t2["progress"] = 0
			t2["accepted"] = false
			dm._active[cat] = t2
			player.global_position = (t2.points as Array)[0] + Vector2(1000, 0)
			_assert(dm.accept(cat), "acceptation à distance")
			_assert(int(dm.get_mission(cat).get("money", 0)) == 80, "job à 1 000 px → pleine paie (%d)" % int(dm.get_mission(cat).get("money", 0)))
			dm._despawn_marker(cat)
		player.global_position = saved
	dm._generate_for(cat)


# Playtest 2026-10-07 — F4 : le taxi respecte le verrou du prologue ; F5 : les
# clients du milho se ré-arment ; F7 : les spots de voie attendent l'acte 2.
func _test_prologue_lock_and_spots() -> void:
	_section("Prologue — verrou du taxi, clients du milho, spots de voie")
	_reset_campaign_state()
	QuestManager.accept("prologue_pedrinho")
	_assert(DistrictManager.travel_lock_reason() != "", "prologue actif → taxi verrouillé")
	var cur: String = DistrictManager.current()
	var target: String = "zona_sul" if cur != "zona_sul" else "copacabana"
	_assert(not DistrictManager.travel_to(target), "travel_to refusé pendant le prologue")
	_assert(DistrictManager.current() == cur, "…et on n'a pas bougé")
	_complete_quest_all_objectives("prologue_pedrinho")
	_assert(DistrictManager.travel_lock_reason() == "", "prologue résolu → taxi libre")
	# F5
	var cust_scene: PackedScene = load("res://scenes/npcs/Customer.tscn")
	if cust_scene != null:
		var cust: Node = cust_scene.instantiate()
		add_child(cust)
		cust.has_purchased = true
		EventBus.corn_cart_state_changed.emit(true)
		_assert(not bool(cust.has_purchased), "prendre la carrocinha ré-arme les clients")
		cust.has_purchased = true
		EventBus.time_of_day_changed.emit(TimeOfDay.Phase.AFTERNOON)
		_assert(not bool(cust.has_purchased), "une nouvelle phase ré-arme les clients")
		cust.queue_free()
	# F7
	CampaignManager.current_act = 1
	var favela: Node = (load("res://scenes/districts/FavelaDoMorro.tscn") as PackedScene).instantiate()
	add_child(favela)
	var hidden: int = 0
	var gated: Array = []
	for n in _all_descendants(favela):
		if n is ReactiveDialogueSpot and int(n.get("required_act")) >= 2:
			gated.append(n)
			if not (n as CanvasItem).visible and not n.interactable.enabled:
				hidden += 1
	_assert(gated.size() >= 7, "favela : %d spots de voie gated par l'acte" % gated.size())
	_assert(hidden == gated.size(), "acte 1 : tous masqués et non interactifs (%d/%d)" % [hidden, gated.size()])
	for name in ["VizinhaSpot", "VovoSpot", "GarotoSpot", "PedrinhoSpot"]:
		var sp: Node = favela.get_node_or_null(name)
		_assert(sp != null and (sp as CanvasItem).visible, "prologue : %s reste visible" % name)
	CampaignManager.current_act = 2
	EventBus.act_changed.emit(2)
	var shown: int = 0
	var expected: int = 0
	for n in gated:
		if String(n.get("required_flag")) != "":
			continue  # gated aussi par un flag de voie : reste masqué, normal
		expected += 1
		if (n as CanvasItem).visible and n.interactable.enabled:
			shown += 1
	_assert(shown == expected and expected > 0, "acte 2 : les spots de voie sans flag apparaissent (%d/%d)" % [shown, expected])
	favela.queue_free()
	_reset_campaign_state()


# Playtest 2026-10-07 — F8 : intro courte ; F9 : NG+ seulement à la demande ;
# F10 : le Pão de Açúcar se guide via Botafogo et le bondinho.
func _test_intro_ngplus_bondinho() -> void:
	_section("Intro courte, NG+ à la demande, route du bondinho")
	var knots: Dictionary = DialogueBridge.all_dialogues()
	var chain: Array = []
	var k: String = "game_intro_open"
	var total_chars: int = 0
	for i in 8:
		if not knots.has(k):
			break
		chain.append(k)
		total_chars += String(knots[k].get("text", "")).length()
		var oc: Dictionary = knots[k].get("on_choose", {})
		var nxt: Variant = oc.get("0", {}).get("next", null) if oc.has("0") else null
		if nxt == null:
			break
		k = String(nxt)
	_assert(chain == ["game_intro_open", "game_intro_disparu", "game_intro_time", "game_intro_controles"],
		"intro : 4 écrans, sans le sermon des voies (%s)" % str(chain))
	_assert(total_chars <= 1000, "intro : ≤ 1 000 caractères avant le premier pas (%d)" % total_chars)
	# F9
	_assert(not GameManager.ng_plus_requested, "fixture : pas de NG+ demandé")
	var saved_count: int = CampaignManager.ng_plus_count
	CampaignManager.ng_plus_count = 0
	CampaignManager.flags.erase("is_ng_plus")
	var boot: Node = load("res://scripts/main/MainBoot.gd").new()
	boot._load_ng_plus_meta()
	_assert(CampaignManager.ng_plus_count == 0 and not CampaignManager.has_flag("is_ng_plus"),
		"nouvelle partie sans demande → pas NG+ même si ng_plus.json existe")
	boot.free()
	CampaignManager.ng_plus_count = saved_count
	# F10 : route du bondinho
	var saved_dist: String = DistrictManager.current()
	DistrictManager.set_current("copacabana")
	var routed: Dictionary = NavigationDirector._route_via_bondinho(NavigationDirector._S("🎯 → Pão de Açúcar : jouer le set DJ", "pao_acucar", "", "Pão"))
	_assert(routed.get("dist", "") == "botafogo_flamengo" and String(routed.get("text", "")).find("Botafogo") != -1,
		"Pão de Açúcar depuis Copa → Botafogo d'abord (%s)" % routed.get("text", ""))
	DistrictManager.set_current("botafogo_flamengo")
	routed = NavigationDirector._route_via_bondinho(NavigationDirector._S("🎯 → Pão de Açúcar : jouer le set DJ", "pao_acucar", "", "Pão"))
	_assert(String(routed.get("anchor", "")) == "class:BondinhoLauncher", "à Botafogo → la borne du bondinho (%s)" % routed.get("anchor", ""))
	DistrictManager.set_current("pao_acucar")
	routed = NavigationDirector._route_via_bondinho(NavigationDirector._S("🎯 → Pão de Açúcar : jouer le set DJ", "pao_acucar", "", "Pão"))
	_assert(routed.get("dist", "") == "pao_acucar", "sur place → inchangé")
	DistrictManager.set_current(saved_dist)


# Rendu A — FacadePainter : taille native = taille/3, déterministe, porte et
# fenêtres présentes, contour sombre, et le relief en rects remplacé par un
# Sprite2D « Facade » en NEAREST ×3.
func _test_facade_painter() -> void:
	_section("FacadePainter — façades en pixel-art")
	# build_image (pas d'ImageTexture.get_image : en headless il attend le renderer).
	var img: Image = FacadePainter.build_image(Vector2(100, 64), Color(0.88, 0.78, 0.64), {"style": "copa", "seed": 7, "shop": true})
	_assert(img.get_size() == Vector2i(33, 21), "100×64 monde → 33×21 natifs (%s)" % img.get_size())
	var tex: ImageTexture = FacadePainter.build(Vector2(100, 64), Color(0.88, 0.78, 0.64), {"style": "copa", "seed": 7, "shop": true})
	var colors: Dictionary = {}
	var has_glass: bool = false
	var has_door: bool = false
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			colors[c.to_html(false)] = true
			# RGBA8 quantifie : tolérance d'un cran par canal.
			if _near_color(c, FacadePainter.WINDOW_GLASS):
				has_glass = true
			if _near_color(c, FacadePainter.DOOR_BASE):
				has_door = true
	_assert(colors.size() >= 8, "façade copa : au moins 8 couleurs (%d)" % colors.size())
	_assert(has_glass and has_door, "façade copa : vitres et porte présentes")
	var dark: Color = FacadePainter.ramp(Color(0.88, 0.78, 0.64)).dark
	_assert(_near_color(img.get_pixel(0, 0), dark) and _near_color(img.get_pixel(32, 20), dark), "contour sombre aux coins")
	var tex2: ImageTexture = FacadePainter.build(Vector2(100, 64), Color(0.88, 0.78, 0.64), {"style": "copa", "seed": 7, "shop": true})
	_assert(tex2 == tex, "même taille/couleur/options → même texture (cache)")
	var fav: ImageTexture = FacadePainter.build(Vector2(60, 40), Color(0.88, 0.35, 0.32), {"style": "favela", "seed": 3, "door_left": true})
	_assert(Vector2i(fav.get_size()) == Vector2i(20, 13), "maison 60×40 → 20×13 natifs")
	var tiny: ImageTexture = FacadePainter.build(Vector2(12, 12), Color(0.5, 0.5, 0.5), {})
	_assert(Vector2i(tiny.get_size()) == Vector2i(4, 4), "façade minuscule : simple aplat contouré")
	var igreja: ImageTexture = FacadePainter.build(Vector2(120, 90), Color(0.92, 0.88, 0.78), {"style": "igreja"})
	_assert(Vector2i(igreja.get_size()) == Vector2i(40, 30), "église 120×90 → 40×30")
	# Intégration : paint_relief pose un Sprite2D « Facade » ×3 NEAREST et plus de rects de fenêtres.
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var cr: ColorRect = ColorRect.new()
	cr.size = Vector2(100, 64)
	holder.add_child(cr)
	BuildingDressing.paint_relief(holder, cr.get_index(), Rect2(Vector2.ZERO, Vector2(100, 64)), Color(0.8, 0.7, 0.6), {"windows": true, "door": true})
	var spr: Sprite2D = holder.get_node_or_null("Facade") as Sprite2D
	_assert(spr != null, "paint_relief → Sprite2D 'Facade'")
	if spr != null:
		_assert(spr.scale == Vector2(3, 3) and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "…×3, NEAREST")
		# Origine au pied (tri en Y) : position = coin bas-gauche, offset remonte le dessin.
		_assert(spr.position == Vector2(0, 64) and spr.offset == Vector2(0, -21) and Vector2i(spr.texture.get_size()) == Vector2i(33, 21), "…calé dans la façade, origine au pied (%s / %s)" % [spr.position, spr.offset])
	_assert(holder.get_node_or_null("Window") == null and holder.get_node_or_null("Door") == null, "plus de fenêtres/porte en rects")
	_assert(holder.get_node_or_null("Shadow") != null, "l'ombre portée reste")
	holder.queue_free()


func _near_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


# Rendu G : police pixel (glyphes, échelles entières, contour cuit, secours
# emoji) et thème UI (cadres 9-slice, variations de type) dans le thème par défaut.
func _test_pixel_font_and_theme() -> void:
	print("\n--- Rendu G : police pixel + thème UI ---")
	var f1: FontFile = PixelFont.font(1, false)
	var f3: FontFile = PixelFont.font(3, true)
	_assert(f1 != null and f3 != null and f1 != f3, "PixelFont : polices ×1 et ×3 (contour) distinctes")
	_assert(PixelFont.font(2, false) == PixelFont.font(2, false), "PixelFont : mise en cache par (échelle, contour)")
	for ch in ["A", "z", "0", "é", "Ã", "ç", "Ç", "·", "✦", "—", "†"]:
		_assert(f1.has_char(ch.unicode_at(0)), "glyphe « %s » dessiné" % ch)
	_assert(not f1.has_char("🥖".unicode_at(0)) and f1.fallbacks.size() == 1, "emoji absent → police de secours")
	_assert(f1.fixed_size == 11 and f3.fixed_size == 33, "taille fixe = 11 × échelle")
	_assert(PixelFont.native_width("BAR DO MORRO") == 66, "largeur native BAR DO MORRO = 66 (%d)" % PixelFont.native_width("BAR DO MORRO"))
	var img: Image = f3.get_texture_image(0, Vector2i(33, 0), 0)
	_assert(img != null and img.get_width() >= 600, "atlas ×3 agrandi NEAREST (%s)" % (str(img.get_size()) if img else "null"))
	# Étiquette du monde : échelle bornée par la largeur, contour selon la luminance.
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var sign: Label = Label.new()
	sign.text = "BAR DO MORRO"
	sign.size = Vector2(140, 16)
	sign.add_theme_font_size_override("font_size", 11)
	holder.add_child(sign)
	PixelFont.style_world_label(sign)
	_assert(sign.get_theme_font_size("font_size") == 22 and sign.get_theme_font("font") == PixelFont.font(2, true), "enseigne 140 px large → ×2 contourée")
	var dark: Label = Label.new()
	dark.text = "tio Zé †"
	dark.size = Vector2(50, 14)
	dark.add_theme_font_size_override("font_size", 9)
	dark.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1, 1))
	holder.add_child(dark)
	PixelFont.style_world_label(dark)
	_assert(dark.get_theme_font("font") == PixelFont.font(2, false) and dark.size.x > 50.0, "étiquette sombre → sans contour, élargie plutôt que ×1 (%.0f px)" % dark.size.x)
	var small: Label = Label.new()
	small.text = "ILHAS CAGARRAS"
	small.add_theme_font_size_override("font_size", 8)
	holder.add_child(small)
	PixelFont.style_world_label(small)
	_assert(small.get_theme_font_size("font_size") == 11, "8 px demandés → ×1")
	holder.queue_free()
	# Thème : fusionné dans le thème par défaut, donc visible sous un CanvasLayer.
	UITheme.apply(get_tree().root)
	var base: Theme = ThemeDB.get_default_theme()
	_assert(base.get_stylebox("panel", "Panel") is StyleBoxTexture, "Panel → cadre 9-slice peint")
	_assert(base.get_stylebox("normal", "TouchButton") is StyleBoxTexture and base.get_type_variation_base("TouchButton") == &"Button", "TouchButton : variation de Button en pastille")
	_assert(base.get_type_variation_base("Pastille") == &"Label" and base.get_font("font", "PixelTitle") == PixelFont.font(2, false), "Pastille (Label) et PixelTitle (police pixel ×2)")
	var tex: Texture2D = (base.get_stylebox("panel", "Panel") as StyleBoxTexture).texture
	_assert(tex.get_width() == 36 and tex.get_height() == 36, "cadre 12×12 natifs ×3")
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var p: Panel = Panel.new()
	layer.add_child(p)
	await get_tree().process_frame
	_assert(p.get_theme_stylebox("panel") is StyleBoxTexture, "un Panel sous CanvasLayer reçoit le cadre du thème")
	layer.queue_free()


# Rendu H : la maison habillée — sol peint, mur du fond + fenêtres, relief des
# meubles en enfants (suivent la visibilité), étiquettes pixel, idempotence.
func _test_interior_dresser() -> void:
	print("\n--- Rendu H : habillage des intérieurs ---")
	var packed: PackedScene = load("res://scenes/interiors/HouseInterior.tscn") as PackedScene
	_assert(packed != null, "HouseInterior.tscn charge")
	if packed == null:
		return
	var house: Node2D = packed.instantiate()
	add_child(house)
	await get_tree().process_frame
	var rects_before: int = house.find_children("*", "ColorRect", true, false).size()
	_assert(InteriorDresser.is_interior(house), "scène reconnue comme intérieur")
	_assert(InteriorDresser.floor_kind(house) == "planks", "maison → plancher")
	InteriorDresser.dress(house)
	var floor: ColorRect = house.get_node("Floor") as ColorRect
	_assert(floor.get_node_or_null("FloorTiles") is Sprite2D and floor.get_node_or_null("BackWall") is Sprite2D, "sol peint + mur du fond (enfants du sol)")
	_assert(floor.get_node_or_null("Window0") is Sprite2D and floor.get_node_or_null("WallB") is ColorRect, "fenêtre + bandes de mur")
	var outer: ColorRect = floor.get_node_or_null("OuterWall") as ColorRect
	_assert(outer != null and outer.show_behind_parent and outer.offset_left < 0.0, "mur extérieur derrière le sol")
	var bed: ColorRect = house.get_node("Bed/Frame") as ColorRect
	_assert(bed.get_node_or_null("OutlineT") != null and bed.get_node_or_null("Shadow") != null and bed.get_node_or_null("Grain") is Sprite2D, "lit : contour, ombre, grain de bois")
	var rug: ColorRect = house.get_node("Rug") as ColorRect
	_assert(rug.get_node_or_null("OutlineT") != null and rug.get_node_or_null("Shadow") == null, "tapis translucide : contour sans ombre")
	var memorial: Label = house.get_node("MemorialLabel") as Label
	_assert(memorial.has_theme_font_override("font"), "étiquette du mémorial en police pixel")
	# Les ajouts suivent la visibilité du rect (bascules par flag).
	bed.visible = false
	_assert(not (bed.get_node("OutlineT") as CanvasItem).is_visible_in_tree(), "relief masqué avec son meuble")
	bed.visible = true
	var count: int = house.find_children("*", "ColorRect", true, false).size()
	InteriorDresser.dress(house)
	_assert(house.find_children("*", "ColorRect", true, false).size() == count and count > rects_before, "idempotent (%d rects, %d avant)" % [count, rects_before])
	# Les collisions n'ont pas bougé : rien de tout ça n'est un corps.
	_assert(house.find_children("*", "StaticBody2D", true, false).size() == 7, "aucun corps ajouté")
	house.queue_free()


# Rendu G : Diário replié derrière un badge, ouverture au tap (épinglée) ou
# automatique quelques secondes à l'acceptation d'une quête.
func _test_quest_log_folded() -> void:
	print("\n--- Rendu G : Diário replié ---")
	var packed: PackedScene = load("res://scenes/ui/QuestLog.tscn") as PackedScene
	var log: Control = packed.instantiate()
	add_child(log)
	await get_tree().process_frame
	_assert(not log.is_open(), "replié par défaut")
	var badge: Button = log.get_node("Badge") as Button
	_assert(badge != null and badge.text.begins_with("Quêtes") and badge.size.y >= 44.0, "badge lisible « Quêtes N » (%s)" % badge.text)
	log.toggle()
	_assert(log.is_open(), "tap → ouvert")
	log.toggle()
	_assert(not log.is_open(), "second tap → replié")
	log.peek()
	_assert(log.is_open(), "peek (nouvelle quête) → ouvert")
	log.fold()
	_assert(not log.is_open(), "fold() → replié")
	log.queue_free()

