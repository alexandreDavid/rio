class_name HouseNightTrigger
extends Area2D

# Trigger placé dans HouseInterior près du SpawnPoint. Quand le joueur rentre
# dans la maison en acte 2 sans avoir encore fermé l'acte 1 (flag act1_closed),
# joue la cinématique Act1NightCutscene (nuit + réveil) une fois.

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
	if CampaignManager.current_act != 2:
		return
	if CampaignManager.has_flag("act1_closed"):
		return
	_fired = true
	_Act1Night.run()
