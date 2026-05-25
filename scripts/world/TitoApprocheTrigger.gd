class_name TitoApprocheTrigger
extends Area2D

# Trigger placé en favela près de TioZeDoor. Quand le joueur sort de la maison
# une fois l'acte 1 fermé (flag act1_closed), Tito monte le voir pour proposer
# son pacte (cutscene TitoAborde). One-shot via flag tito_approached.

const _TitoAborde: Script = preload("res://scripts/cutscenes/TitoAborde.gd")

func _ready() -> void:
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	# Ne se déclenche que si l'acte 1 a été fermé (nuit passée), pas encore
	# de voie scellée, et pas déjà abordé.
	if not CampaignManager.has_flag("act1_closed"):
		return
	if CampaignManager.has_flag("tito_approached"):
		return
	if CampaignManager.has_flag("ratted_on_tito"):
		return
	for f in ["voie_trafico", "voie_policia", "voie_consortium", "voie_prefeito"]:
		if CampaignManager.has_flag(f):
			return
	CampaignManager.set_flag("tito_approached")
	_TitoAborde.run()
