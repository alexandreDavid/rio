class_name HouseNightTrigger
extends Area2D

# Trigger placé dans HouseInterior près du SpawnPoint. Quand le joueur RENTRE à
# la maison APRÈS avoir payé l'acompte (act1_heritage complétée) et pas encore
# fermé l'acte 1 (act1_closed), joue la cinématique Act1NightCutscene (parler à
# tio Zé + nuit). C'est CE retour qui ferme l'acte 1 et ouvre l'acte 2.

const _Act1Night: Script = preload("res://scripts/cutscenes/Act1NightCutscene.gd")

var _fired: bool = false

func _ready() -> void:
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _fired or body == null or not body.is_in_group("player"):
		return
	# Acompte payé (act1_heritage finie) requis : c'est le retour à la maison
	# APRÈS le paiement qui clôt l'acte 1. Avant ça (début de partie), on ne
	# déclenche rien même si le joueur démarre dans la maison.
	if not QuestManager.is_completed("act1_heritage"):
		return
	if CampaignManager.has_flag("act1_closed"):
		return
	_fired = true
	_Act1Night.run()
