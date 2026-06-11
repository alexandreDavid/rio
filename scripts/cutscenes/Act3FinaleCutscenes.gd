extends RefCounted
class_name Act3FinaleCutscenes

# Cinématiques jouées juste après le set_endgame (depuis EndingScreen) et avant
# l'affichage du panneau de fin. Chaque voie a sa phrase de bénédiction délivrée
# par le mentor de la voie — un dernier dialogue avant le règne.

const PRE_DIALOG_PAUSE: float = 0.6   # silence dramatique avant la phrase
const POST_DIALOG_PAUSE: float = 0.8  # respiration avant le panneau de fin

# Voie Polícia : la phrase de couronnement a déjà été jouée via le knot du
# pacte (ramos_policia_madrugada) juste avant le set_endgame ; ici, simple
# respiration dramatique avant le panneau de fin (REIGN_INTROS).
static func run_policia() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("consortium", "nilton_settlement_policia")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Voie Tráfico : couronnement déjà joué via tito_trafico_corrida.
static func run_trafico() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("consortium", "nilton_settlement_trafico")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Voie Prefeito : couronnement déjà joué via padre_prefeito_eleicao.
static func run_prefeito() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("consortium", "nilton_settlement_prefeito")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Voie Consortium : Magalhães scelle le pacte.
static func run_consortium() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("magalhaes", "magalhaes_consortium_done")
		await CutsceneRunner.say("consortium", "nilton_settlement_consortium")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Dispatcher : appelle la cutscene correspondant à la voie choisie.
static func run_for(path: int) -> void:
	match path:
		CampaignManager.Endgame.POLICIA:
			await run_policia()
		CampaignManager.Endgame.TRAFICO:
			await run_trafico()
		CampaignManager.Endgame.PREFEITO:
			await run_prefeito()
		CampaignManager.Endgame.CONSORTIUM:
			await run_consortium()
