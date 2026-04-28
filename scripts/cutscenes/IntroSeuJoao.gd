extends RefCounted
class_name IntroSeuJoao

# Cinématique d'introduction : Seu João vient à la rencontre du joueur depuis sa
# charrette de milho et lui raconte la mort de tio Zé + la dette. Joue une seule
# fois (flag intro_seen), au démarrage d'une nouvelle partie.

const APPROACH_OFFSET_X: float = -90.0  # Seu João s'arrête à 90px à la gauche du joueur
const CART_REST_POS: Vector2 = Vector2(1260, 100)  # position habituelle de Seu João
const POST_DIALOGUE_PAUSE: float = 0.4

static func run() -> void:
	# Évite la rejouée si déjà vue.
	if CampaignManager.has_flag("intro_seen"):
		return
	if GameManager.player == null:
		return
	var player: Node2D = GameManager.player
	# Joue la cinématique via le runner — il gère le freeze input et le verrou anti-empilement.
	await CutsceneRunner.play(func():
		var target: Vector2 = player.global_position + Vector2(APPROACH_OFFSET_X, 0)
		await CutsceneRunner.walk_npc_to("seu_joao", target)
		# Le NPC tourne vers le joueur pour parler.
		CutsceneRunner.face_npc("seu_joao", CutsceneRunner.DIR_RIGHT)
		await CutsceneRunner.wait(0.2)
		# Dialogue d'héritage (déjà existant, accepte la quête act1_heritage).
		await CutsceneRunner.say("seu_joao", "seu_joao_heritage")
		# Marque l'intro comme vue pour ne pas la rejouer.
		CampaignManager.set_flag("intro_seen")
		await CutsceneRunner.wait(POST_DIALOGUE_PAUSE)
		# Seu João retourne à sa charrette.
		await CutsceneRunner.walk_npc_to("seu_joao", CART_REST_POS)
	)
