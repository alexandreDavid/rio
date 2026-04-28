extends Panel

# Journal des quêtes actives, reconstruit sur chaque événement pertinent.
# Le panneau s'auto-masque s'il n'y a pas de quête active.

@onready var vbox: VBoxContainer = $VBox
@onready var header_count: Label = $HeaderBg/HeaderCount

func _ready() -> void:
	EventBus.quest_accepted.connect(_on_quest_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.quest_failed.connect(_on_quest_event)
	_redraw()

func _on_quest_event(_quest_id: String) -> void:
	_redraw()

func _on_quest_updated(_quest_id: String, _objective_id: String) -> void:
	_redraw()

func _redraw() -> void:
	_clear()
	visible = true
	var active: Array[String] = QuestManager.get_active_ids()
	if header_count:
		header_count.text = "%d ativa(s)" % active.size()
	if active.is_empty():
		var none: Label = Label.new()
		none.text = "Nenhuma missão ativa"
		none.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		none.add_theme_font_size_override("font_size", 13)
		vbox.add_child(none)
		return
	for quest_id in active:
		_add_quest_block(quest_id)

func _clear() -> void:
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

func _add_quest_block(quest_id: String) -> void:
	var quest: Quest = QuestManager.get_quest(quest_id)
	if quest == null or vbox == null:
		return
	var title: Label = Label.new()
	title.text = quest.display_name
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	var state: Dictionary = QuestManager.get_objectives_state(quest_id)
	for obj in quest.objectives:
		var line: Label = Label.new()
		var done: bool = state.get(obj.id, false)
		var mark: String = "✓" if done else "•"
		var suffix: String = "  (optionnel)" if obj.optional else ""
		line.text = "  %s %s%s" % [mark, obj.description, suffix]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 15)
		if done:
			line.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		vbox.add_child(line)
