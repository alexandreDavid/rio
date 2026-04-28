extends Node

# JSON save/load. Autoload name: SaveSystem.
# Auto-save déclenché sur les événements narratifs clés (quêtes, acte, dette, jour).
# Les sauvegardes sont debouncées via call_deferred pour éviter de thrasher le disque
# quand plusieurs signaux tombent dans la même frame.

signal save_committed()
signal save_loaded()

const SAVE_PATH: String = "user://savegame.json"
# Bump à chaque refonte de l'état qui invalide les saves antérieures.
const SAVE_VERSION: int = 2

var _save_pending: bool = false
var _loading: bool = false

func _ready() -> void:
	EventBus.quest_accepted.connect(_schedule_save)
	EventBus.quest_completed.connect(_schedule_save)
	EventBus.quest_failed.connect(_schedule_save)
	EventBus.quest_updated.connect(_schedule_save_two)
	EventBus.act_changed.connect(_schedule_save)
	EventBus.debt_paid.connect(_schedule_save_two)
	EventBus.day_elapsed.connect(_schedule_save)
	EventBus.endgame_chosen.connect(_schedule_save)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_F5:
			save_game()
			get_viewport().set_input_as_handled()
		elif key == KEY_F9 and has_save():
			load_game()
			get_viewport().set_input_as_handled()

# Signaux à 1 ou 2 paramètres ne sont pas directement compatibles avec une callable
# sans arg — on passe par des wrappers pour chaque arité utilisée.
func _schedule_save(_arg1 = null) -> void:
	_request_save()

func _schedule_save_two(_arg1 = null, _arg2 = null) -> void:
	_request_save()

func _request_save() -> void:
	if _save_pending or _loading:
		return
	_save_pending = true
	call_deferred("_commit_save")

func _commit_save() -> void:
	_save_pending = false
	save_game()

func save_game() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"reputation": ReputationSystem.serialize(),
		"quests": QuestManager.serialize(),
		"time": TimeOfDay.serialize(),
		"campaign": CampaignManager.serialize(),
		"npc_schedule": NPCScheduler.serialize(),
		"dynamic_missions": DynamicMissionManager.serialize(),
		"district": DistrictManager.serialize(),
		"journal": NarrativeJournal.serialize(),
		"player": _serialize_player(),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for writing" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	save_committed.emit()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("SaveSystem: parse error %s" % err)
		return false
	var data: Dictionary = json.data
	var save_ver: int = int(data.get("version", 0))
	if save_ver != SAVE_VERSION:
		push_warning("SaveSystem: version incompatible (save=%d, attendue=%d) — save ignorée" % [save_ver, SAVE_VERSION])
		discard_save()
		return false
	_loading = true
	ReputationSystem.deserialize(data.get("reputation", {}))
	QuestManager.deserialize(data.get("quests", {}))
	TimeOfDay.deserialize(data.get("time", {}))
	CampaignManager.deserialize(data.get("campaign", {}))
	NPCScheduler.deserialize(data.get("npc_schedule", {}))
	DynamicMissionManager.deserialize(data.get("dynamic_missions", {}))
	DistrictManager.deserialize(data.get("district", {}))
	NarrativeJournal.deserialize(data.get("journal", {}))
	_deserialize_player(data.get("player", {}))
	_broadcast_post_load()
	_loading = false
	save_loaded.emit()
	return true

# Rejoue les signaux clés pour que les listeners (HUD, scheduler NPCs, etc.) re-render
# leur état depuis les valeurs chargées. Sinon ils restent sur les valeurs initiales.
func _broadcast_post_load() -> void:
	for i in ReputationSystem.Axis.size():
		EventBus.reputation_changed.emit(ReputationSystem.Axis.keys()[i], ReputationSystem.get_value(i))
	EventBus.act_changed.emit(CampaignManager.current_act)
	EventBus.debt_paid.emit(0, CampaignManager.debt_remaining())
	EventBus.day_elapsed.emit(TimeOfDay.day_count)
	NPCScheduler.reposition_all()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func discard_save() -> void:
	# Supprime la save + repose l'état en mémoire aux valeurs neuves.
	# Utile pour "Nouvelle partie" ou après un bump de SAVE_VERSION.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_save_pending = false

func _serialize_player() -> Dictionary:
	var p: Node = GameManager.player
	if p == null or not (p is Node2D):
		return {}
	var inv: Node = p.get_node_or_null("Inventory")
	return {
		"position": [p.global_position.x, p.global_position.y],
		"inventory": inv.serialize() if inv and inv.has_method("serialize") else {},
	}

func _deserialize_player(data: Dictionary) -> void:
	var p: Node = GameManager.player
	if p == null or not (p is Node2D) or data.is_empty():
		return
	if data.has("position"):
		var arr: Array = data["position"]
		p.global_position = Vector2(arr[0], arr[1])
	var inv: Node = p.get_node_or_null("Inventory")
	if inv and inv.has_method("deserialize"):
		inv.deserialize(data.get("inventory", {}))
