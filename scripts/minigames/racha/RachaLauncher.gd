class_name RachaLauncher
extends Node2D

# Borne pari/inscription Racha da Atlântica. Le joueur paye 50 R$ d'inscription
# puis dispute la course (3 tours, 3 IA). Position finale → payout.
# Casse l'inscription si pas assez d'argent.

@export var interactable: Interactable
@export var match_scene: PackedScene
@export var entry_fee: int = 50

var _active_match: Node = null
var _world_cache: Node = null
var _ui_cache: Node = null

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = "Racha da Atlântica (%d R$)" % entry_fee
		interactable.interacted.connect(_on_interact)

func _on_interact(by: Node) -> void:
	if _active_match or match_scene == null:
		return
	var inv: Inventory = (by as Node).get_node_or_null("Inventory") as Inventory if by else null
	if inv == null:
		return
	if not inv.spend_money(entry_fee):
		_show_nofunds()
		return
	_launch()

func _show_nofunds() -> void:
	DialogueBridge.register_runtime_dialogue("racha_nofunds", {
		"speaker": "Organisateur",
		"text": "*hoche la tête, déçu* Pas de fric, pas de course, parceiro. %d reais l'inscription. Reviens quand tu les as." % entry_fee,
		"choices": ["Note"],
	})
	DialogueBridge.start_dialogue("racha_organizer", "racha_nofunds")

func _launch() -> void:
	_active_match = match_scene.instantiate()
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

func _on_match_ended(qualifies: bool, tips: int) -> void:
	if tips > 0:
		var inv: Inventory = null
		if GameManager.player:
			inv = GameManager.player.get_node_or_null("Inventory") as Inventory
		if inv:
			inv.add_money(tips)
	if qualifies:
		ReputationSystem.gain_capped(ReputationSystem.Axis.STREET, 2, "racha_wins", 8)
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
