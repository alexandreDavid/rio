extends RefCounted
class_name Act2RevealCutscene

# Cinématique d'entrée d'acte 2 : le Concierge quitte le Palace et vient lui-même
# au joueur révéler qu'il est tio Zé. Plus dramatique qu'un déplacement manuel.
# Joue une seule fois (flag act2_reveal_played).

const APPROACH_OFFSET_X: float = -90.0  # le Concierge s'arrête à 90px à la gauche du joueur
const TELEPORT_OFFSET_X: float = -260.0 # téléport initial : à 260px à gauche du joueur
const URGENT_WALK_SPEED: float = 180.0  # plus rapide (urgence) — sur la dernière distance après téléport
const SUSPENSE_PAUSE: float = 0.6       # le Concierge fixe le joueur avant de parler

static func run() -> void:
	if CampaignManager.has_flag("act2_reveal_played"):
		return
	if GameManager.player == null:
		return
	# La scène n'a de sens que sur le calçadão de Copa : le Concierge marche
	# du Palace vers le joueur. Si on est dans la favela / un intérieur / un
	# autre district (ex: skip debug Cmd+2 dans la maison), on défère —
	# MainBoot.on_district_changed la rejouera dès le retour à Copa.
	if DistrictManager.current() != "copacabana":
		return
	# Si un dialogue est actif (ex: paiement consortium qui a déclenché l'acte 2),
	# on attend qu'il se termine avant de démarrer la cutscene.
	if DialogueBridge.is_active():
		await DialogueBridge.dialogue_finished
	# Petit délai pour laisser respirer la transition avant la cinématique.
	await CutsceneRunner.get_tree().create_timer(0.8).timeout
	if CampaignManager.has_flag("act2_reveal_played"):
		return  # double-check au cas où un autre déclencheur l'aurait jouée pendant l'attente
	var player: Node2D = GameManager.player
	if NPCScheduler.get_npc("concierge") == null:
		return  # NPC absent (par ex. déjà révélé via flag tio_ze_revealed)

	await CutsceneRunner.play(func():
		# Téléport le Concierge à 260px à gauche du joueur (hors champ proche),
		# puis fait juste les derniers 170px à pied — évite 60s de freeze quand
		# le Concierge devrait traverser la moitié de la map.
		var concierge: Node2D = NPCScheduler.get_npc("concierge")
		if concierge:
			concierge.global_position = player.global_position + Vector2(TELEPORT_OFFSET_X, 0)
		var target: Vector2 = player.global_position + Vector2(APPROACH_OFFSET_X, 0)
		await CutsceneRunner.walk_npc_to("concierge", target, URGENT_WALK_SPEED)
		# Le Concierge se tourne face au joueur et marque une pause de suspense.
		CutsceneRunner.face_npc("concierge", CutsceneRunner.DIR_RIGHT)
		await CutsceneRunner.wait(SUSPENSE_PAUSE)
		# Knot de révélation existant (chaîne automatiquement vers explanation/farewell,
		# qui à la fin pose le flag tio_ze_revealed et complète la quête act2_intro).
		await CutsceneRunner.say("concierge", "concierge_act2_reveal")
		CampaignManager.set_flag("act2_reveal_played")
	)
