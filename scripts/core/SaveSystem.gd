extends Node

# JSON save/load. Autoload name: SaveSystem.
# Auto-save déclenché sur les événements narratifs clés (quêtes, acte, dette, jour).
# Les sauvegardes sont debouncées via call_deferred pour éviter de thrasher le disque
# quand plusieurs signaux tombent dans la même frame.

signal save_committed()
signal save_loaded()

const LEGACY_SAVE_PATH: String = "user://savegame.json"
const SAVE_PATH_PATTERN: String = "user://savegame_slot%d.json"
# Bump à chaque refonte de l'état qui invalide les saves antérieures.
const SAVE_VERSION: int = 2

func current_save_path() -> String:
	return SAVE_PATH_PATTERN % Settings.current_slot

func slot_save_path(slot: int) -> String:
	return SAVE_PATH_PATTERN % clampi(slot, 1, 3)

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
	# Migration : ancienne save unique → slot 1, une fois pour toutes.
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(slot_save_path(1)):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(LEGACY_SAVE_PATH),
			ProjectSettings.globalize_path(slot_save_path(1)))

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
		"affinity": NPCAffinity.serialize(),
		"achievements": AchievementSystem.serialize(),
		"player": _serialize_player(),
	}
	var path: String = current_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for writing" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	save_committed.emit()
	return true

func load_game() -> bool:
	var path: String = current_save_path()
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
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
	NPCAffinity.deserialize(data.get("affinity", {}))
	AchievementSystem.deserialize(data.get("achievements", {}))
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
	return FileAccess.file_exists(current_save_path())

func has_save_at(slot: int) -> bool:
	return FileAccess.file_exists(slot_save_path(slot))

func discard_save() -> void:
	# Supprime la save + repose l'état en mémoire aux valeurs neuves.
	# Utile pour "Nouvelle partie" ou après un bump de SAVE_VERSION.
	var path: String = current_save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_save_pending = false

func discard_save_at(slot: int) -> void:
	var path: String = slot_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# Métadonnées minimales d'un slot pour l'UI : current_act, debt_paid, day.
# Renvoie {} si le slot est vide.
func slot_info(slot: int) -> Dictionary:
	var path: String = slot_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	var campaign: Dictionary = data.get("campaign", {})
	var time_data: Dictionary = data.get("time", {})
	return {
		"act": int(campaign.get("current_act", 1)),
		"debt_paid": int(campaign.get("debt_paid", 0)),
		"day": int(time_data.get("day_count", 1)),
		"endgame": int(campaign.get("chosen_endgame", 0)),
	}

# Bascule de slot : sauve l'état courant, puis charge le slot demandé.
# Si le slot cible est vide, le jeu reprend en état neuf (post-load broadcast).
func switch_to_slot(new_slot: int) -> void:
	if new_slot == Settings.current_slot:
		return
	save_game()
	Settings.set_current_slot(new_slot)
	if has_save():
		load_game()

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
