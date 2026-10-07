class_name CornCart
extends Node2D

# Charrette de milho. Acte 1 : tournée à pied (stock 3, paiement à chaque
# vente) — le tutoriel de l'héritage. Dès l'acte 2, la carrocinha lance la
# « Hora do rush » (MilhoGame) : service sous pression où l'on gagne en
# connaissant ses fregueses.

signal stock_changed(remaining: int)
signal shift_ended(total_earned: int, commission: int)
signal carry_state_changed(carrying: bool)

const INITIAL_STOCK: int = 3
const PRICE_FAIR: int = 5
const PRICE_GOUGE: int = 15

@export var interactable: Interactable
@export var quest_id: String = "quest_milho_01"

var stock: int = INITIAL_STOCK
var _total_earned: int = 0
var _shift_active: bool = false
var _carrying: bool = false
var _original_position: Vector2 = Vector2.ZERO
const CARRY_DISTANCE: float = 24.0
const RUSH_SCENE: String = "res://scenes/minigames/Milho.tscn"
const RUSH_PROMPT: String = "🌽 Hora do rush (milho)"

var _walk_prompt: String = ""
var _active_rush: Node = null
var _world_cache: Node = null
var _ui_cache: Node = null

func _ready() -> void:
	add_to_group("corn_cart")
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interacted)
		interactable.enabled = _should_be_enabled()
		_walk_prompt = interactable.prompt
		_refresh_prompt()
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.act_changed.connect(_on_act_changed)

func _should_be_enabled() -> bool:
	# La charrette est utilisable dès que l'héritage a été accepté (acte 1 démarré)
	# OU que la quête milho_01 est explicitement acceptée (compat rétro).
	if QuestManager.is_active(quest_id) or QuestManager.is_completed(quest_id):
		return true
	if CampaignManager.has_flag("act1_started"):
		return true
	return false

# Après l'acte 1 (et hors tutoriel milho en cours), la carrocinha sert au rush.
func is_rush_mode() -> bool:
	return CampaignManager.current_act >= 2 and not QuestManager.is_active(quest_id)

func _refresh_prompt() -> void:
	if interactable:
		interactable.prompt = RUSH_PROMPT if is_rush_mode() else _walk_prompt

func is_carrying() -> bool:
	return _carrying

func revenue() -> int:
	return _total_earned

func pick_up(_player: Node) -> void:
	if _carrying:
		return
	_original_position = global_position
	_carrying = true
	if interactable:
		interactable.enabled = false
		EventBus.interaction_lost.emit(interactable)
	start_shift()
	carry_state_changed.emit(true)
	EventBus.corn_cart_state_changed.emit(true)
	QuestManager.complete_objective(quest_id, "pickup_cart")

func drop_off(_inventory: Inventory) -> int:
	if not _carrying:
		return 0
	_carrying = false
	if _original_position != Vector2.ZERO:
		global_position = _original_position
	carry_state_changed.emit(false)
	EventBus.corn_cart_state_changed.emit(false)
	_shift_active = false
	shift_ended.emit(_total_earned, _total_earned)
	QuestManager.complete_objective(quest_id, "return_cart")
	return _total_earned

func _physics_process(_delta: float) -> void:
	if not (_carrying and GameManager.player):
		return
	# Trace derrière le joueur : offset opposé à sa direction de regard
	var facing: Vector2 = Vector2.DOWN
	if "_facing" in GameManager.player:
		facing = GameManager.player._facing
	if facing.length() < 0.01:
		facing = Vector2.DOWN
	global_position = GameManager.player.global_position - facing * CARRY_DISTANCE

func start_shift() -> void:
	stock = INITIAL_STOCK
	_total_earned = 0
	_shift_active = true
	stock_changed.emit(stock)
	EventBus.corn_stock_changed.emit(stock)

func sell(price: int, reputation_delta: Dictionary = {}) -> bool:
	if not _carrying or not _shift_active or stock <= 0:
		return false
	stock -= 1
	_total_earned += price
	stock_changed.emit(stock)
	EventBus.corn_stock_changed.emit(stock)
	# Paiement immédiat au joueur.
	var inv: Inventory = _player_inventory()
	if inv:
		inv.add_money(price)
	_apply_reputation(reputation_delta)
	if stock == 0:
		QuestManager.complete_objective(quest_id, "sell_all")
	return true

func give_away(reputation_delta: Dictionary = {}) -> bool:
	if not _carrying or not _shift_active or stock <= 0:
		return false
	stock -= 1
	stock_changed.emit(stock)
	EventBus.corn_stock_changed.emit(stock)
	_apply_reputation(reputation_delta)
	if stock == 0:
		QuestManager.complete_objective(quest_id, "sell_all")
	return true

func end_shift(_inventory: Inventory) -> int:
	# Signature conservée pour compatibilité, mais le paiement est déjà fait par sale.
	_shift_active = false
	shift_ended.emit(_total_earned, _total_earned)
	return _total_earned

func _on_quest_accepted(accepted_id: String) -> void:
	if interactable and (accepted_id == quest_id or accepted_id == "act1_heritage"):
		interactable.enabled = true

func _on_act_changed(_new_act: int) -> void:
	# Au cas où le flag act1_started ait été posé sans passer par quest_accepted.
	if interactable and not interactable.enabled:
		interactable.enabled = _should_be_enabled()
	_refresh_prompt()

func _on_interacted(by: Node) -> void:
	if _carrying:
		return
	if is_rush_mode():
		_launch_rush()
		return
	pick_up(by)

# Pattern launcher : le monde et le HUD se masquent le temps du rush.
func _launch_rush() -> void:
	if _active_rush:
		return
	var packed: PackedScene = load(RUSH_SCENE)
	if packed == null:
		return
	_active_rush = packed.instantiate()
	var root: Node = get_tree().current_scene
	_world_cache = root.get_node_or_null("World")
	_ui_cache = root.get_node_or_null("UI")
	if _world_cache:
		_world_cache.visible = false
		_world_cache.process_mode = Node.PROCESS_MODE_DISABLED
	if _ui_cache:
		_ui_cache.visible = false
	root.add_child(_active_rush)
	_active_rush.match_ended.connect(_on_rush_ended)

func _on_rush_ended(_qualifies: bool, cash: int) -> void:
	# Réputation + affinité Seu João + mestre : ActivityRewards (signature "milho").
	var inv: Inventory = _player_inventory()
	if inv and cash > 0:
		inv.add_money(cash)
	if _active_rush:
		_active_rush.queue_free()
		_active_rush = null
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

func _apply_reputation(delta: Dictionary) -> void:
	for axis_key in delta:
		ReputationSystem.modify(axis_key, delta[axis_key])

func _player_inventory() -> Inventory:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Inventory") as Inventory
