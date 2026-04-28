extends CanvasLayer

# Overlay plein écran : codex narratif. Touche J pour ouvrir/fermer.
# Colonne gauche = catégories, colonne milieu = entrées débloquées, colonne
# droite = contenu de l'entrée sélectionnée.

@onready var root: Control = $Root
@onready var category_list: VBoxContainer = $Root/Panel/HBox/Categories/Scroll/Box
@onready var entry_list: VBoxContainer = $Root/Panel/HBox/Entries/Scroll/Box
@onready var detail_speaker: Label = $Root/Panel/HBox/Detail/Speaker
@onready var detail_text: Label = $Root/Panel/HBox/Detail/Body
@onready var detail_title: Label = $Root/Panel/HBox/Detail/Title
@onready var counter: Label = $Root/Panel/Header/Counter
@onready var close_button: Button = $Root/Panel/Header/Close

var _current_category: String = ""
var _current_knot: String = ""

func _ready() -> void:
	visible = false
	# Bloque l'input du jeu mais reste accessible.
	if root:
		root.process_mode = Node.PROCESS_MODE_ALWAYS
	if close_button:
		close_button.pressed.connect(_close)
	NarrativeJournal.entry_unlocked.connect(_on_entry_unlocked)
	_select_first_unlocked_category()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_J:
		toggle()
	elif event.keycode == KEY_ESCAPE and visible:
		_close()

func toggle() -> void:
	visible = not visible
	if visible:
		_select_first_unlocked_category()
		_refresh_categories()
		_refresh_entries()
		_refresh_counter()

func _close() -> void:
	visible = false

func _on_entry_unlocked(_knot_id: String) -> void:
	if visible:
		_refresh_categories()
		_refresh_entries()
		_refresh_counter()

func _select_first_unlocked_category() -> void:
	# Préfère une catégorie qui a des entrées débloquées.
	for cat in NarrativeJournal.CATEGORIES:
		if NarrativeJournal.entries_in(cat.id).size() > 0:
			_current_category = cat.id
			return
	# Fallback : première catégorie déclarative.
	if NarrativeJournal.CATEGORIES.size() > 0:
		_current_category = NarrativeJournal.CATEGORIES[0].id

func _refresh_counter() -> void:
	if counter:
		counter.text = "%d / %d entradas" % [NarrativeJournal.unlocked_count(), NarrativeJournal.total_count()]

func _refresh_categories() -> void:
	if category_list == null:
		return
	for child in category_list.get_children():
		child.queue_free()
	for cat in NarrativeJournal.CATEGORIES:
		var count: int = NarrativeJournal.entries_in(cat.id).size()
		var btn: Button = Button.new()
		btn.text = "%s  (%d)" % [cat.label, count]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 14)
		if cat.id == _current_category:
			btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1))
		elif count == 0:
			btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1))
		var cat_id: String = cat.id
		btn.pressed.connect(func(): _on_category_selected(cat_id))
		category_list.add_child(btn)

func _on_category_selected(cat_id: String) -> void:
	_current_category = cat_id
	_current_knot = ""
	_refresh_categories()
	_refresh_entries()
	_show_detail("", "", "")

func _refresh_entries() -> void:
	if entry_list == null:
		return
	for child in entry_list.get_children():
		child.queue_free()
	var entries: Array = NarrativeJournal.entries_in(_current_category)
	if entries.is_empty():
		var empty: Label = Label.new()
		empty.text = "Aucune entrée déverrouillée pour cette catégorie."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
		entry_list.add_child(empty)
		return
	for entry in entries:
		var btn: Button = Button.new()
		btn.text = entry.title
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 14)
		if entry.knot == _current_knot:
			btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1))
		var knot_id: String = entry.knot
		var title: String = entry.title
		btn.pressed.connect(func(): _on_entry_selected(knot_id, title))
		entry_list.add_child(btn)

func _on_entry_selected(knot_id: String, title: String) -> void:
	_current_knot = knot_id
	_refresh_entries()
	var content: Dictionary = NarrativeJournal.get_entry_content(knot_id)
	_show_detail(title, content.get("speaker", ""), content.get("text", ""))

func _show_detail(title: String, speaker: String, text: String) -> void:
	if detail_title:
		detail_title.text = title
	if detail_speaker:
		detail_speaker.text = speaker
	if detail_text:
		detail_text.text = text
