class_name MaePrologueTrigger
extends Area2D

# Zone invisible posée quelques pas hors de la maison du tio. Quand le joueur
# la traverse pour la 1re fois — après le bump d'héritage et tant que le
# prologue n'a pas démarré — la mère de Pedrinho vient l'aborder d'elle-même
# (cutscene MaeAborde). Remplace l'obligation de reparler à Seu João.

const _MaeAborde: Script = preload("res://scripts/cutscenes/MaeAborde.gd")

var _fired: bool = false

func _ready() -> void:
	collision_mask = 1  # couche du joueur (PlayerController)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _fired or body == null or not body.is_in_group("player"):
		return
	# L'héritage (bump Seu João) doit être passé, et la quête pas encore lancée.
	if not CampaignManager.has_flag("intro_bump_seen"):
		return
	if QuestManager.is_active("prologue_pedrinho") \
			or QuestManager.is_completed("prologue_pedrinho"):
		return
	_fired = true
	_MaeAborde.run("offer")
