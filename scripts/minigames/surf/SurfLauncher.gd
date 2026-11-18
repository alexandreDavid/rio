class_name SurfLauncher
extends Node2D

# Lance le mini-jeu de surf. Réputation + affinité + mestre : ActivityRewards
# (signature "surf") ; le launcher ne gère que la quête de Lucas.

@export var interactable: Interactable
@export var match_scene: PackedScene

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
	_launch()

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

const LUCAS_QUEST_ID: String = "lucas_arpoador_surf"
const LUCAS_OBJ_ID: String = "win_surf_session"

func _on_match_ended(qualifies: bool, _time_survived: float) -> void:
	if qualifies:
		# Quête Lucas (Arpoador) : la 1re session surf qualifiée coche l'objectif.
		if QuestManager.is_active(LUCAS_QUEST_ID):
			QuestManager.complete_objective(LUCAS_QUEST_ID, LUCAS_OBJ_ID)
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
