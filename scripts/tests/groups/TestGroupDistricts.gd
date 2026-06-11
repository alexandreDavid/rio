extends "res://scripts/tests/IntegrationTestBase.gd"

# Groupe : Districts & mini-jeux. Extrait du monolithe IntegrationTest.
# run() rejoue les tests dans l'ordre d'origine (await préservé).

func run() -> void:
	await _test_district_exit_geometry()
	await _test_district_walk_to_exit()
	await _test_walk_entries_no_pingpong()
	await _test_valet_minigame()


func _test_district_exit_geometry() -> void:
	_section("Sorties de district — couverture géométrique anti-soft-lock")
	var district_scenes: Array = _list_scenes_under("res://scenes/districts/")
	for scene_path in district_scenes:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			continue
		var fname: String = scene_path.get_file()
		var instance: Node = packed.instantiate()
		add_child(instance)
		# Trouve toutes les DistrictExit + tous les murs StaticBody2D.
		var exits: Array = []
		var walls: Array = []
		_collect_exits_and_walls(instance, exits, walls)
		# (1) Au moins une sortie pour les districts marchables.
		if WALKABLE_DISTRICT_SCENES.has(fname):
			_assert(exits.size() >= 1, "%s : au moins 1 DistrictExit (district marchable)" % fname)
		# (2) Aire minimale et (3) couverture, pour CHAQUE DistrictExit présent.
		for exit_node in exits:
			var size: Vector2 = _exit_collision_size(exit_node)
			if size == Vector2.ZERO:
				_assert(false, "%s/%s : DistrictExit sans RectangleShape2D" % [fname, exit_node.name])
				continue
			var area: float = size.x * size.y
			_assert(area >= EXIT_MIN_AREA,
				"%s/%s : aire ≥ %d (actuel %dx%d=%d)" % [
					fname, exit_node.name, EXIT_MIN_AREA,
					size.x, size.y, area])
			# (3) Couverture : au moins UN axe (x ou y) doit couvrir ≥ 50% du
			# mur perpendiculaire le plus proche. Suffit pour piéger un joueur
			# descendant en biais (l'axe de l'exit le rattrape sur sa direction
			# principale). Allowlist : les sorties « narratives » (ex. départ
			# SUP vers les Cagarras) sont délibérément étroites — on les exempte.
			if not _NARRATIVE_EXITS.has(String(exit_node.name)):
				var coverage_ok: bool = _exit_covers_blocking_wall_one_axis(exit_node, size, walls)
				_assert(coverage_ok,
					"%s/%s : couvre ≥ %d%% du mur de fond sur au moins un axe" % [
						fname, exit_node.name,
						int(EXIT_MIN_COVERAGE_RATIO * 100)])
		instance.queue_free()
		await get_tree().process_frame


func _test_district_walk_to_exit() -> void:
	_section("Cheminement physique : spawn → ExitToCopa (move_and_slide)")
	# Map district_id de _current à attribuer pour chaque scène, sinon walk_to
	# court-circuite (même district source/cible). Cf. bug rapporté favela.
	var current_for_scene: Dictionary = {
		"FavelaDoMorro.tscn":      "favela_morro",
		"ZonaSul.tscn":            "zona_sul",
		"BotafogoFlamengo.tscn":   "botafogo_flamengo",
	}
	for fname in WALKABLE_DISTRICT_SCENES:
		var scene_path: String = "res://scenes/districts/" + fname
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			_assert(false, "%s : charge en PackedScene" % fname)
			continue
		var scene_root: Node = packed.instantiate()
		add_child(scene_root)
		await get_tree().physics_frame

		var spawn_node: Node = scene_root.get_node_or_null("PlayerSpawn")
		var exit_node: Node = scene_root.get_node_or_null("ExitToCopa")
		if spawn_node == null or exit_node == null:
			_assert(false, "%s : PlayerSpawn + ExitToCopa présents" % fname)
			scene_root.queue_free()
			await get_tree().process_frame
			continue
		# Verrou narratif : si la sortie exige une quête complétée (prologue),
		# on vérifie qu'elle bloque tant que non résolue, puis on la satisfait
		# pour pouvoir tester le cheminement physique normal.
		var gate_q: String = String(exit_node.get("require_quest_completed"))
		if gate_q != "":
			var qpath: String = "res://resources/quests/%s.tres" % gate_q
			if ResourceLoader.exists(qpath):
				var gq: Quest = load(qpath) as Quest
				if gq and QuestManager._quests.get(gq.id) == null:
					QuestManager.register_quest(gq)
			_assert(exit_node._is_locked(),
				"%s/ExitToCopa : verrouillé tant que '%s' non complétée" % [fname, gate_q])
			_complete_quest_all_objectives(gate_q)
			_assert(not exit_node._is_locked(),
				"%s/ExitToCopa : déverrouillé après '%s'" % [fname, gate_q])

		var spawn_pos: Vector2 = (spawn_node as Node2D).global_position
		var exit_pos: Vector2 = (exit_node as Node2D).global_position

		# Construit un test-body minimal qui matche la shape du Player.
		var body: CharacterBody2D = CharacterBody2D.new()
		body.add_to_group("player")
		var col: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(14, 20)
		col.shape = rect
		body.add_child(col)
		scene_root.add_child(body)
		body.global_position = spawn_pos

		# Pose DistrictManager._current sur le district SOURCE pour que
		# walk_to("copacabana") ne soit pas court-circuité.
		var saved_district: String = DistrictManager.current()
		DistrictManager.set_current(current_for_scene[fname])

		# Capture deux signaux distincts :
		#  - body_entered de l'Area2D : la trigger physique fire
		#  - district_changed : walk_to passe et change effectivement le district
		var hit_state: Dictionary = {"reached": false, "district_changed": false}
		var listener: Callable = func(_b: Node) -> void:
			hit_state["reached"] = true
		var dc_listener: Callable = func(new_id: String) -> void:
			if new_id == "copacabana":
				hit_state["district_changed"] = true
		(exit_node as Area2D).body_entered.connect(listener)
		DistrictManager.district_changed.connect(dc_listener)

		# Boucle de simulation : avance vers la sortie, détecte un blocage si
		# la distance ne diminue plus pendant trop de frames consécutives.
		var last_distance: float = body.global_position.distance_to(exit_pos)
		var frames_without_progress: int = 0
		var frames_used: int = 0
		var blocked: bool = false
		for frame in WALK_TEST_MAX_FRAMES:
			if hit_state["reached"]:
				break
			frames_used = frame
			var delta: Vector2 = exit_pos - body.global_position
			if delta.length() <= 1.0:
				# Au cas où on est pile sur l'exit sans avoir reçu le signal
				# (bug de detection) : on tient ça pour reached aussi.
				hit_state["reached"] = true
				break
			body.velocity = delta.normalized() * WALK_TEST_SPEED
			body.move_and_slide()
			var d: float = body.global_position.distance_to(exit_pos)
			if d < last_distance - 0.5:
				last_distance = d
				frames_without_progress = 0
			else:
				frames_without_progress += 1
				if frames_without_progress >= WALK_TEST_PROGRESS_WINDOW:
					blocked = true
					break
			await get_tree().physics_frame

		var diag: String = "%s : joueur atteint ExitToCopa (%d frames" % [fname, frames_used]
		if blocked:
			diag += ", bloqué à %s, dist restante %d" % [str(body.global_position.round()), int(last_distance)]
		diag += ")"
		_assert(hit_state["reached"], diag)
		# Vérification du fix bug favela : la trigger doit avoir effectivement
		# fait avancer DistrictManager (et pas juste fire body_entered dans le vide).
		_assert(hit_state["district_changed"],
			"%s : DistrictManager.district_changed → 'copacabana' suite au trigger ExitToCopa" % fname)

		# Cleanup : déconnecte avant de libérer (sinon warning Godot).
		if (exit_node as Area2D).body_entered.is_connected(listener):
			(exit_node as Area2D).body_entered.disconnect(listener)
		if DistrictManager.district_changed.is_connected(dc_listener):
			DistrictManager.district_changed.disconnect(dc_listener)
		# Restaure l'état de DistrictManager pour ne pas polluer les tests suivants.
		DistrictManager.set_current(saved_district)
		body.queue_free()
		scene_root.queue_free()
		await get_tree().process_frame


# Pour chaque WALK_ENTRIES[target][source] = arrival_pos, vérifie que arrival_pos
# n'est pas dans la collision shape de l'ExitTo<source> de la scène cible.
# Sinon : ping-pong infini (le joueur arrive sur le trigger retour, repart, etc.).
func _test_walk_entries_no_pingpong() -> void:
	_section("WALK_ENTRIES — pas de ping-pong avec les ExitTo retour")
	# Construit l'index target_district → scène. Pour copacabana, c'est la
	# world scene Copacabana.tscn. Pour un district, c'est sa propre scène.
	var district_to_scene: Dictionary = {
		"copacabana":         "res://scenes/world/Copacabana.tscn",
		"favela_morro":       "res://scenes/districts/FavelaDoMorro.tscn",
		"zona_sul":           "res://scenes/districts/ZonaSul.tscn",
		"botafogo_flamengo":  "res://scenes/districts/BotafogoFlamengo.tscn",
	}
	for target_id in DistrictManager.WALK_ENTRIES:
		var sources: Dictionary = DistrictManager.WALK_ENTRIES[target_id]
		var scene_path: String = district_to_scene.get(target_id, "")
		if scene_path == "":
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		_assert(packed != null, "%s : scène cible charge" % target_id)
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		add_child(instance)
		await get_tree().physics_frame
		# Index toutes les DistrictExit du target par leur target_district. Un même
		# target peut avoir plusieurs exits (ex. Túnel Novo + Túnel Velho pour
		# Botafogo) — on les valide toutes.
		var exits_by_target: Dictionary = {}
		_index_exits_by_target(instance, exits_by_target)
		for source_id in sources:
			var arrival_pos: Vector2 = sources[source_id]
			# arrival_pos est en world coords pour copacabana, en local pour les
			# districts. On le ramène en world via le node `instance` (Node2D).
			var arrival_world: Vector2 = arrival_pos
			if target_id != "copacabana" and instance is Node2D:
				arrival_world = (instance as Node2D).global_position + arrival_pos
			# Tous les exits qui pointent vers source_id (= chemins retour) doivent
			# laisser arrival_world hors de leur trigger.
			var return_exits: Array = exits_by_target.get(source_id, [])
			for return_exit in return_exits:
				var rect: Rect2 = _exit_world_rect(return_exit)
				if rect == Rect2():
					continue
				_assert(not rect.has_point(arrival_world),
					"%s arrival from '%s' (%s) hors de %s.%s %s" % [
						target_id, source_id, str(arrival_pos),
						source_id, return_exit.name, str(rect)])
		instance.queue_free()
		await get_tree().process_frame


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

