extends RefCounted
class_name TitoAborde

# À la sortie de la maison du tio Zé une fois l'acte 1 fermé, Tito monte voir
# le neveu et propose son pacte (voie Tráfico). Le joueur peut refuser et
# aller voir Ramos / Magalhães / Padre — `tito_approached` est posé pour ne
# pas répéter l'approche.

const APPROACH_OFFSET: Vector2 = Vector2(0, 26)
const WALK_SPEED: float = 70.0
const RETURN_SPEED: float = 85.0

static func run() -> void:
	if CutsceneRunner.is_running() or DialogueBridge.is_active():
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	var tito: Node2D = NPCScheduler.get_npc("tito")
	# Fallback : si Tito n'est pas trouvable (test, état spécial), on déclenche
	# juste son knot directement sans la mise en scène.
	if tito == null or not is_instance_valid(tito):
		DialogueBridge.start_dialogue("tito", "tito_pacto_trafico_offer")
		return
	var home: Vector2 = tito.global_position
	await CutsceneRunner.play(func() -> void:
		var stop_at: Vector2 = player.global_position + APPROACH_OFFSET
		await CutsceneRunner.walk_node_to(tito, stop_at, WALK_SPEED)
		await CutsceneRunner.wait(0.2)
		await CutsceneRunner.say("tito", "tito_pacto_trafico_offer")
		if is_instance_valid(tito):
			await CutsceneRunner.walk_node_to(tito, home, RETURN_SPEED)
	)
