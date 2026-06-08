extends RefCounted
class_name MaeAborde

# La mère de Pedrinho aborde le joueur d'elle-même au lieu de l'obliger à
# reparler à Seu João :
#   - mode "offer" : le joueur fait quelques pas hors de la maison → la mère
#     vient lui confier la recherche de l'enfant (donne prologue_pedrinho).
#   - mode "plea"  : le joueur tente de quitter le morro sans avoir résolu la
#     mission → la mère le rattrape et le supplie (à la place du panneau texte).
#
# La mère réutilise le ReactiveDialogueSpot "VizinhaSpot" (groupe mae_prologue)
# comme acteur : on le fait marcher jusqu'au joueur puis revenir chez lui.

const APPROACH_OFFSET: Vector2 = Vector2(0, 22)  # s'arrête juste sud du joueur
const WALK_SPEED: float = 70.0
const RETURN_SPEED: float = 85.0
const REACH_PAUSE: float = 0.15

static func run(mode: String) -> void:
	if CutsceneRunner.is_running() or DialogueBridge.is_active():
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	var knot: String = "mae_prologue_offer" if mode == "offer" else "mae_prologue_plea"
	var mae: Node2D = CutsceneRunner.get_tree().get_first_node_in_group("mae_prologue") as Node2D
	# Garde-fou : si la mère n'est pas dans la scène, on ne bloque pas la
	# progression — on donne quand même la quête (offer) sans la mise en scène.
	if mae == null or not is_instance_valid(mae):
		if mode == "offer" \
				and not QuestManager.is_active("prologue_pedrinho") \
				and not QuestManager.is_completed("prologue_pedrinho"):
			DialogueBridge.start_dialogue("vizinha", knot)
		return
	var home: Vector2 = mae.global_position
	await CutsceneRunner.play(func() -> void:
		var stop_at: Vector2 = player.global_position + APPROACH_OFFSET
		await CutsceneRunner.walk_node_to(mae, stop_at, WALK_SPEED)
		await CutsceneRunner.wait(REACH_PAUSE)
		await CutsceneRunner.say("vizinha", knot)
		# Elle retourne à sa place (banc / fenêtre) — pas de téléport sec.
		if is_instance_valid(mae):
			await CutsceneRunner.walk_node_to(mae, home, RETURN_SPEED)
	)
