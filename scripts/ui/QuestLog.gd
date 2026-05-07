extends Panel

# Journal des quêtes actives, reconstruit sur chaque événement pertinent.
# Sépare visuellement la trame principale (MAIN) des activités libres (SIDE) :
# section "História", puis "Atividades", chacune avec son propre style.

const MAIN_TITLE_COLOR: Color = Color(1.0, 0.9, 0.55)      # doré : trame
const SIDE_TITLE_COLOR: Color = Color(0.65, 0.85, 1.0)     # bleu pâle : activité
const SECTION_HEADER_COLOR: Color = Color(0.95, 0.85, 0.4, 0.85)
const SIDE_SECTION_HEADER_COLOR: Color = Color(0.55, 0.78, 1.0, 0.85)

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
	var main_ids: Array[String] = []
	var side_ids: Array[String] = []
	for qid in active:
		var q: Quest = QuestManager.get_quest(qid)
		if q != null and q.quest_type == Quest.QuestType.MAIN:
			main_ids.append(qid)
		else:
			side_ids.append(qid)

	if header_count:
		header_count.text = "%d ✦ %d" % [main_ids.size(), side_ids.size()]

	if active.is_empty():
		var none: Label = Label.new()
		none.text = "Nenhuma missão ativa"
		none.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		none.add_theme_font_size_override("font_size", 13)
		vbox.add_child(none)
		return

	if not main_ids.is_empty():
		_add_section_header("História", SECTION_HEADER_COLOR)
		for quest_id in main_ids:
			_add_quest_block(quest_id, true)
	if not side_ids.is_empty():
		if not main_ids.is_empty():
			_add_spacer()
		_add_section_header("Atividades", SIDE_SECTION_HEADER_COLOR)
		for quest_id in side_ids:
			_add_quest_block(quest_id, false)

func _clear() -> void:
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

func _add_section_header(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

func _add_spacer() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

func _add_quest_block(quest_id: String, is_main: bool) -> void:
	var quest: Quest = QuestManager.get_quest(quest_id)
	if quest == null or vbox == null:
		return
	var title: Label = Label.new()
	var prefix: String = "✦ " if is_main else "• "
	title.text = "%s%s" % [prefix, quest.display_name]
	title.add_theme_color_override("font_color", MAIN_TITLE_COLOR if is_main else SIDE_TITLE_COLOR)
	title.add_theme_font_size_override("font_size", 18 if is_main else 16)
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
