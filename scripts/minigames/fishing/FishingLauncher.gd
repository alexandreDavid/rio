class_name FishingLauncher
extends Node2D

@export var interactable: Interactable
@export var match_scene: PackedScene
@export var bet_amount: int = 20

var _active_match: Node = null
var _world_cache: Node = null
var _ui_cache: Node = null

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interact)

func _on_interact(_by: Node) -> void:
	if _active_match or match_scene == null:
		return
	var inv: Inventory = _player_inventory()
	if bet_amount > 0 and inv and not inv.spend_money(bet_amount):
		return
	_launch()

func _launch() -> void:
	_active_match = match_scene.instantiate()
	if "bet_amount" in _active_match:
		_active_match.bet_amount = bet_amount
	var root: Node = get_tree().current_scene
	_world_cache = root.get_node_or_null("World")
	_ui_cache = root.get_node_or_null("UI")
	if _world_cache:
		_world_cache.visible = false
		_world_cache.process_mode = Node.PROCESS_MODE_DISABLED
	if _ui_cache:
		_ui_cache.visible = false
	root.add_child(_active_match)
	if _active_match.has_signal("match_ended"):
		_active_match.match_ended.connect(_on_match_ended)

const FISHING_QUEST_HOOKS: Dictionary = {
	"mateus_cagarras_pesca": "haul_catch",
	"bruno_pesca_baia": "haul_baia",
}

func _on_match_ended(_won: bool, payout: int) -> void:
	var inv: Inventory = _player_inventory()
	if inv and payout > 0:
		inv.add_money(payout)
	# Sessions de pêche : la 1re avec un payout > 0 coche l'objectif des
	# quêtes liées (Mateus Cagarras, Bruno Niterói). Itère sur le dict pour
	# rester ouvert à de nouveaux hooks.
	if payout > 0:
		for qid in FISHING_QUEST_HOOKS:
			if QuestManager.is_active(qid):
				QuestManager.complete_objective(qid, FISHING_QUEST_HOOKS[qid])
	if _active_match:
		_active_match.queue_free()
		_active_match = null
	if _world_cache:
		_world_cache.visible = true
		_world_cache.process_mode = Node.PROCESS_MODE_INHERIT
		_world_cache = null
	if _ui_cache:
		_ui_cache.visible = true
		_ui_cache = null
	if GameManager.player:
		var player_cam: Camera2D = GameManager.player.get_node_or_null("Camera2D")
		if player_cam:
			player_cam.make_current()

func _player_inventory() -> Inventory:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Inventory") as Inventory
