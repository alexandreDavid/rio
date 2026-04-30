extends RefCounted
class_name IntroSeuJoao

# Cinématique d'introduction : tio Zé (Seu João) attend dans la maison du morro,
# vient annoncer la mort de l'oncle et la dette de cinquante mille reais.
# Joue une seule fois (flag intro_seen).

const APPROACH_OFFSET_X: float = -50.0  # à 50 px du joueur (espace réduit en intérieur)
const POST_DIALOGUE_PAUSE: float = 0.4

static func run() -> void:
	if CampaignManager.has_flag("intro_seen"):
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	await CutsceneRunner.play(func():
		var target: Vector2 = player.global_position + Vector2(APPROACH_OFFSET_X, 0)
		await CutsceneRunner.walk_npc_to("seu_joao", target)
		CutsceneRunner.face_npc("seu_joao", CutsceneRunner.DIR_RIGHT)
		await CutsceneRunner.wait(0.2)
		# Run+ : tio Zé acknowledge le déjà-vu avant l'héritage canonique.
		# Le knot heritage reste le même (pivot quest), on précède juste d'un beat.
		if CampaignManager.ng_plus_count > 0:
			await CutsceneRunner.say("seu_joao", "seu_joao_ng_plus_intro")
		# Dialogue d'héritage (existant, accepte la quête act1_heritage).
		await CutsceneRunner.say("seu_joao", "seu_joao_heritage")
		CampaignManager.set_flag("intro_seen")
		await CutsceneRunner.wait(POST_DIALOGUE_PAUSE)
		# Tutoriel narratif : tio Zé pointe la carrocinha + Copa + acompte.
		await CutsceneRunner.say("seu_joao", "seu_joao_intro_tutorial")
		# Tio Zé reste dans la maison — pas de retour au calçadão.
	)
