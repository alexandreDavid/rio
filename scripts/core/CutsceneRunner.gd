extends Node

# Autoload : CutsceneRunner.
# Orchestre les cinématiques scriptées : marche d'un NPC vers un point, dialogue,
# attente, gel des inputs joueur, etc. Les cutscenes sont écrites comme de simples
# fonctions/Callable async qui utilisent les helpers de ce runner.
#
# Exemple :
#   await CutsceneRunner.play(func():
#       await CutsceneRunner.walk_npc_to("seu_joao", player.global_position + Vector2(-80, 0))
#       await CutsceneRunner.say("seu_joao", "seu_joao_heritage"))
#
# Le runner gère :
#   - Verrou is_running pour ne pas empiler deux cutscenes
#   - Gel des inputs joueur pendant la cinématique
#   - Signaux cutscene_started / cutscene_ended

signal cutscene_started
signal cutscene_ended

# Conventions partagées (mêmes valeurs que NPC.gd pour cohérence).
const DIR_DOWN: int = 0
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const DIR_LEFT: int = 3

const DEFAULT_WALK_SPEED: float = 90.0

var _running: bool = false

func is_running() -> bool:
	return _running

# Joue une cutscene fournie comme Callable async. Bloque jusqu'à la fin.
func play(callable: Callable) -> void:
	if _running:
		push_warning("[CutsceneRunner] cutscene déjà en cours, ignorée")
		return
	_running = true
	cutscene_started.emit()
	_freeze_player()
	# Attend la cinématique. Le Callable peut utiliser les await CutsceneRunner.xxx.
	await callable.call()
	_unfreeze_player()
	cutscene_ended.emit()
	_running = false

# --- Helpers utilisables depuis les cutscenes ---

# Fait marcher un NPC vers une position cible, avec animation walk-sheet si dispo.
func walk_npc_to(npc_id: String, target: Vector2, speed: float = DEFAULT_WALK_SPEED) -> void:
	var npc: Node2D = NPCScheduler.get_npc(npc_id)
	if npc == null:
		await get_tree().process_frame
		return
	var dx: float = target.x - npc.global_position.x
	var dy: float = target.y - npc.global_position.y
	var dir: int = DIR_DOWN
	if abs(dx) > abs(dy):
		dir = DIR_RIGHT if dx > 0 else DIR_LEFT
	else:
		dir = DIR_DOWN if dy > 0 else DIR_UP
	if npc.has_method("play_walk"):
		npc.call("play_walk", dir)
	var dist: float = npc.global_position.distance_to(target)
	var duration: float = max(0.2, dist / speed)
	var t: Tween = create_tween()
	t.tween_property(npc, "global_position", target, duration)
	await t.finished
	if npc.has_method("stop_walk"):
		npc.call("stop_walk")

# Variante pour un Node2D quelconque (pas forcément un NPC enregistré au scheduler).
# Utile pour PMPatrol, props mobiles, etc.
func walk_node_to(node: Node2D, target: Vector2, speed: float = DEFAULT_WALK_SPEED) -> void:
	if node == null or not is_instance_valid(node):
		await get_tree().process_frame
		return
	# Si le node a play_walk/stop_walk (NPC), on en profite pour l'animation de marche.
	if node.has_method("play_walk"):
		var dx: float = target.x - node.global_position.x
		var dy: float = target.y - node.global_position.y
		var dir: int = DIR_DOWN
		if abs(dx) > abs(dy):
			dir = DIR_RIGHT if dx > 0 else DIR_LEFT
		else:
			dir = DIR_DOWN if dy > 0 else DIR_UP
		node.call("play_walk", dir)
	var dist: float = node.global_position.distance_to(target)
	var duration: float = max(0.2, dist / speed)
	var t: Tween = create_tween()
	t.tween_property(node, "global_position", target, duration)
	await t.finished
	if node.has_method("stop_walk"):
		node.call("stop_walk")

# Lance un dialogue et bloque jusqu'à sa fin.
func say(npc_id: String, knot: String) -> void:
	DialogueBridge.start_dialogue(npc_id, knot)
	await DialogueBridge.dialogue_finished

# Pause de N secondes (pour temporiser entre actions).
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# Tourne un NPC dans une direction sans le faire marcher.
func face_npc(npc_id: String, dir: int) -> void:
	var npc: Node2D = NPCScheduler.get_npc(npc_id)
	if npc and npc.has_method("face"):
		npc.call("face", dir)

# --- Gel des inputs joueur ---

func _freeze_player() -> void:
	if GameManager.player:
		var p: Node = GameManager.player
		p.velocity = Vector2.ZERO if "velocity" in p else p.velocity
		p.set_physics_process(false)
		p.set_process_unhandled_input(false)

func _unfreeze_player() -> void:
	if GameManager.player:
		var p: Node = GameManager.player
		p.set_physics_process(true)
		p.set_process_unhandled_input(true)
