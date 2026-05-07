extends RefCounted
class_name IntroSeuJoaoBump

# Cinématique d'ouverture : le joueur clique « Sortir » de la maison du tio Zé
# pour la 1re fois. Au lieu du téléport, Seu João débarque par la porte (vient
# de l'escalier de la favela), entre dans la pièce, bloque le passage, et
# annonce la disparition de Zé + la dette du consortium.
# Joue une seule fois (flag intro_bump_seen). Le BuildingDoor.intro_bump_door
# nous passe la porte appelante en argument pour qu'on calcule la position
# d'arrivée à partir d'elle.

# Position de spawn : Seu João apparaît à 60px sud de la porte (visible juste
# en dessous, comme s'il finissait de monter l'escalier — donne le temps au
# joueur de le voir entrer dans la pièce).
const ENTRY_OFFSET_Y: float = 60.0
# Position d'arrêt : 18px sud du joueur — entre le joueur et la porte (donc
# bloque visuellement le passage).
const BUMP_OFFSET_FROM_PLAYER: Vector2 = Vector2(0, 18)
const ENTRY_WALK_SPEED: float = 60.0   # plus lent que default 90 → entrée bien lisible
const RETURN_WALK_SPEED: float = 80.0
const BUMP_SHAKE_AMPLITUDE: float = 4.0
const BUMP_SHAKE_DURATION: float = 0.18
const TENSION_PAUSE: float = 0.3
const POST_DIALOG_PAUSE: float = 0.4
# Position normale de SeuJoao dans HouseInterior (local -60, 50). HouseInterior
# est instancié dans Copacabana à (7200, -3000). Global = (7140, -2950).
const HOUSE_REST_POS: Vector2 = Vector2(7140, -2950)

static func run(door: Node2D = null) -> void:
	if CampaignManager.has_flag("intro_bump_seen"):
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	var sj: Node2D = NPCScheduler.get_npc("seu_joao")
	if sj == null:
		return

	# Référentiel : la porte (sinon fallback joueur).
	var door_pos: Vector2 = door.global_position if door != null else player.global_position
	# Spawn Seu João juste sud de la porte. .show() pour être sûr que l'ancêtre
	# soit visible aussi (au cas où on aurait modifié visible sur un parent).
	sj.global_position = door_pos + Vector2(0, ENTRY_OFFSET_Y)
	sj.show()
	sj.modulate = Color(1, 1, 1, 1)  # au cas où une animation précédente l'aurait fade-out
	if "interactable" in sj and sj.interactable:
		sj.interactable.enabled = false

	await CutsceneRunner.play(func():
		# Entre dans la pièce et s'arrête juste sud du joueur (lui bloque le
		# passage vers la porte).
		var bump_target: Vector2 = player.global_position + BUMP_OFFSET_FROM_PLAYER
		await CutsceneRunner.walk_node_to(sj, bump_target, ENTRY_WALK_SPEED)
		CutsceneRunner.face_npc("seu_joao", CutsceneRunner.DIR_UP)
		await _bump_shake(player)
		await CutsceneRunner.wait(TENSION_PAUSE)
		# Dialogue d'héritage (chaîne accept_quest act1_heritage + flag act1_started).
		if CampaignManager.ng_plus_count > 0:
			await CutsceneRunner.say("seu_joao", "seu_joao_ng_plus_intro")
		await CutsceneRunner.say("seu_joao", "seu_joao_heritage")
		CampaignManager.set_flag("intro_bump_seen")
		CampaignManager.set_flag("intro_seen")
		# Persiste immédiatement : set_flag ne déclenche pas d'auto-save donc
		# si le joueur quitte juste après la cutscene, les flags seraient
		# perdus → bump rejoué au reload.
		SaveSystem.save_game()
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
		await CutsceneRunner.say("seu_joao", "seu_joao_intro_tutorial")
		# Walk Seu João vers sa place habituelle (table) — visible et naturel,
		# pas un téléport sec.
		await CutsceneRunner.walk_node_to(sj, HOUSE_REST_POS, RETURN_WALK_SPEED)
		CutsceneRunner.face_npc("seu_joao", CutsceneRunner.DIR_DOWN)
		# Garantit visible + interactable activé après la cutscene.
		sj.show()
		sj.modulate = Color(1, 1, 1, 1)
		if "interactable" in sj and sj.interactable:
			sj.interactable.enabled = true
	)

# Petit tremblement horizontal du joueur pour suggérer le choc physique.
static func _bump_shake(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin: Vector2 = player.position
	var t: Tween = player.create_tween()
	t.tween_property(player, "position", origin + Vector2(BUMP_SHAKE_AMPLITUDE, 0), BUMP_SHAKE_DURATION * 0.25)
	t.tween_property(player, "position", origin + Vector2(-BUMP_SHAKE_AMPLITUDE, 0), BUMP_SHAKE_DURATION * 0.5)
	t.tween_property(player, "position", origin, BUMP_SHAKE_DURATION * 0.25)
	await t.finished
