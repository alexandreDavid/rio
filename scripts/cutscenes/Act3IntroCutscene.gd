extends RefCounted
class_name Act3IntroCutscene

# Cinématique d'entrée d'acte 3 : à 25 000 R$ payés, Dom Nilton lui-même quitte
# son banc de l'Av. Atlântica et vient appeler le joueur. Marque officiellement
# le passage à la phase de choix de voie. Joue une seule fois (flag act3_intro_played).
# Si le joueur n'est pas sur Copacabana au moment de la bascule, on diffère
# (le check se relance à chaque district_changed).

const APPROACH_OFFSET_X: float = -90.0
const URGENT_WALK_SPEED: float = 110.0
const SUSPENSE_PAUSE: float = 0.6

static func run() -> void:
	if CampaignManager.has_flag("act3_intro_played"):
		return
	if GameManager.player == null:
		return
	# Si un dialogue est en cours (ex : paiement consortium qui vient de
	# déclencher l'acte 3), on attend qu'il se termine.
	if DialogueBridge.is_active():
		await DialogueBridge.dialogue_finished
	await CutsceneRunner.get_tree().create_timer(0.6).timeout
	if CampaignManager.has_flag("act3_intro_played"):
		return
	# Cinématique réservée au calçadão (sinon Nilton marche depuis l'autre bout
	# du monde — même travers que Seu João avant le fix).
	if DistrictManager.current() != "copacabana":
		return
	if NPCScheduler.get_npc("consortium") == null:
		return  # NPC absent (cas hors-scène)
	var player: Node2D = GameManager.player

	await CutsceneRunner.play(func():
		var target: Vector2 = player.global_position + Vector2(APPROACH_OFFSET_X, 0)
		await CutsceneRunner.walk_npc_to("consortium", target, URGENT_WALK_SPEED)
		CutsceneRunner.face_npc("consortium", CutsceneRunner.DIR_RIGHT)
		await CutsceneRunner.wait(SUSPENSE_PAUSE)
		await CutsceneRunner.say("consortium", "consortium_act3_intro")
		CampaignManager.set_flag("act3_intro_played")
	)
