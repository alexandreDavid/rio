class_name DeliveryPoint
extends Node2D

# Zone de dépôt du colis : quand le joueur entre avec la quête active,
# l'objectif se complète et le paiement est versé.

@export var trigger: POITrigger
@export var quest_id: String = "deliver_package_01"
@export var objective_id: String = "deliver"
@export var payout: int = 50

var _triggered: bool = false

func _ready() -> void:
	if trigger == null:
		trigger = get_node_or_null("Trigger") as POITrigger
	if trigger:
		trigger.player_entered.connect(_on_entered)

func _on_entered() -> void:
	if _triggered:
		return
	if not QuestManager.is_active(quest_id):
		return
	_triggered = true
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv:
		inv.add_money(payout)
	QuestManager.complete_objective(quest_id, objective_id)
	print("[DeliveryPoint] colis livré, R$ %d crédités" % payout)
