extends RefCounted
class_name Act3FinaleCutscenes

# Cinématiques jouées juste après le set_endgame (depuis EndingScreen) et avant
# l'affichage du panneau de fin. Chaque voie a sa phrase de bénédiction délivrée
# par le mentor de la voie — un dernier dialogue avant le règne.

const PRE_DIALOG_PAUSE: float = 0.6   # silence dramatique avant la phrase
const POST_DIALOG_PAUSE: float = 0.8  # respiration avant le panneau de fin

# Voie Polícia : Ramos officialise le titre.
static func run_policia() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("ramos", "ramos_act3_done")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Voie Tráfico : Miguel passe la main.
static func run_trafico() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("miguel", "miguel_act3_done")
		await CutsceneRunner.wait(POST_DIALOG_PAUSE)
	)

# Voie Prefeito : Padre bénit publiquement.
static func run_prefeito() -> void:
	await CutsceneRunner.play(func():
		await CutsceneRunner.wait(PRE_DIALOG_PAUSE)
		await CutsceneRunner.say("padre", "padre_act3_done")
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
