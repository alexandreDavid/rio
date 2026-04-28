extends RefCounted
class_name FirstShakedownCutscene

# Cinématique : la toute première fois que le joueur prend la charrette de milho,
# PMPatrol vient automatiquement le racketter. Apprentissage scénarisé du fait que
# la rue n'est pas gratuite. Joue une seule fois (flag first_shakedown_played).
# Ensuite les rencontres random restent gérées par PMPatrol normalement.

const APPROACH_OFFSET_X: float = -70.0  # PMPatrol s'arrête à 70px à la gauche du joueur
const URGENT_WALK_SPEED: float = 110.0
const TENSION_PAUSE: float = 0.5
const POST_DIALOG_PAUSE: float = 0.4
const COOLDOWN_AFTER: float = 60.0  # bloque les random shakedowns 60 s après cette scène

static func run() -> void:
	if CampaignManager.has_flag("first_shakedown_played"):
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	var pm: Node2D = CutsceneRunner.get_tree().get_first_node_in_group("pm_patrol") as Node2D
	if pm == null:
		# Pas de PMPatrol dans la scène (intérieur, scène de test) — on saute.
		return
	var origin: Vector2 = pm.global_position

	await CutsceneRunner.play(func():
		var target: Vector2 = player.global_position + Vector2(APPROACH_OFFSET_X, 0)
		await CutsceneRunner.walk_node_to(pm, target, URGENT_WALK_SPEED)
		await CutsceneRunner.wait(TENSION_PAUSE)
		# Knot existant : le PM réclame son alvará. Le joueur peut payer 20 R$ ou refuser.
		await CutsceneRunner.say("pm", "cop_shakedown")
		CampaignManager.set_flag("first_shakedown_played")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
		# Le PM repart vers son point de patrouille.
		await CutsceneRunner.walk_node_to(pm, origin, 80.0)
		# Cooldown pour ne pas redéclencher la version random tout de suite.
		if pm.has_method("set_cooldown"):
			pm.call("set_cooldown", COOLDOWN_AFTER)
	)
