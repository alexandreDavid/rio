class_name VolleyLauncher
extends Node2D

# Lancement du mini-jeu beach-volley en scène additive.
# Le pari est optionnel : à 0 on peut jouer gratuit.

@export var interactable: Interactable
@export var match_scene: PackedScene
@export var bet_amount: int = 0

var _active_match: Node = null
var _world_cache: Node = null
var _ui_cache: Node = null

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.interacted.connect(_on_interact)
		print("[VolleyLauncher] signal connected, match_scene=%s" % match_scene)

func _on_interact(_by: Node) -> void:
	print("[VolleyLauncher] _on_interact — active=%s match_scene=%s" % [_active_match, match_scene])
	if _active_match:
		print("[VolleyLauncher] match déjà actif, ignore")
		return
	if match_scene == null:
		push_error("[VolleyLauncher] match_scene non assigné dans le .tscn")
		return
	var inv: Inventory = _player_inventory()
	if bet_amount > 0 and inv and not inv.spend_money(bet_amount):
		print("[VolleyLauncher] pas assez d'argent (besoin %d)" % bet_amount)
		return
	_launch()

func _launch() -> void:
	print("[VolleyLauncher] launching match")
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
	print("[VolleyLauncher] match instancié et ajouté à l'arbre")

func _on_match_ended(won: bool, _sp: int, _so: int) -> void:
	print("[VolleyLauncher] match ended, won=%s" % won)
	var inv: Inventory = _player_inventory()
	if won and inv and bet_amount > 0:
		inv.add_money(bet_amount * 2)
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
	# Restaure la caméra du joueur
	if GameManager.player:
		var player_cam: Camera2D = GameManager.player.get_node_or_null("Camera2D")
		if player_cam:
			player_cam.make_current()

func _player_inventory() -> Inventory:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Inventory") as Inventory
