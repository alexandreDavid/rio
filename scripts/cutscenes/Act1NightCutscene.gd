extends RefCounted
class_name Act1NightCutscene

# Acte 1 → 2 : déclenchée quand le joueur rentre dans la maison du tio Zé après
# avoir payé les 500 reais. Joue 2 répliques de Narrateur (la nuit puis le
# réveil), pose le flag `act1_closed` qui déverrouille les pactes de voie et
# l'approche de Tito à la sortie.

static func run() -> void:
	if CampaignManager.has_flag("act1_closed"):
		return
	if CutsceneRunner.is_running() or DialogueBridge.is_active():
		return
	await CutsceneRunner.play(func() -> void:
		await CutsceneRunner.say("narrateur", "act1_night_fall")
	)
	# Filet de sécurité : si le set_flag du knot final n'a pas tiré (ex. test
	# qui bypass DialogueBridge.choose), on force le flag ici.
	if not CampaignManager.has_flag("act1_closed"):
		CampaignManager.set_flag("act1_closed")
