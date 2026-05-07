extends CanvasLayer

# Téléphone mobile — overlay style smartphone qui remplace le menu simple
# du HUD. Plusieurs apps : Taxi (commande à distance), Saúde (stats /
# réputation / argent / dette), Journal et Missões (placeholders ouvrant
# les UIs existantes).

const REP_AXIS_NAMES: Array[String] = ["CIVIC", "POLICE", "STREET", "TOURIST", "CHARISMA"]
const REP_AXIS_LABELS: Dictionary = {
	"CIVIC":    "Respect",
	"POLICE":   "Police",
	"STREET":   "Voyou",
	"TOURIST":  "Touristes",
	"CHARISMA": "Charisme",
}
const REP_AXIS_COLORS: Dictionary = {
	"CIVIC":    Color(0.55, 0.85, 0.55),
	"POLICE":   Color(0.4, 0.6, 0.95),
	"STREET":   Color(0.9, 0.55, 0.3),
	"TOURIST":  Color(0.95, 0.85, 0.35),
	"CHARISMA": Color(0.85, 0.45, 0.85),
}

@onready var backdrop: ColorRect = $Backdrop
@onready var frame: Panel = $Frame
@onready var clock_label: Label = $Frame/StatusBar/Clock
@onready var home_screen: Control = $Frame/Screens/Home
@onready var taxi_screen: Control = $Frame/Screens/Taxi
@onready var stats_screen: Control = $Frame/Screens/Stats
@onready var cronica_screen: Control = $Frame/Screens/Cronica
@onready var taxi_list: VBoxContainer = $Frame/Screens/Taxi/Scroll/Box
@onready var taxi_status: Label = $Frame/Screens/Taxi/Status
@onready var stats_box: VBoxContainer = $Frame/Screens/Stats/Scroll/Box
@onready var cronica_box: VBoxContainer = $Frame/Screens/Cronica/Scroll/Box
@onready var cronica_counter: Label = $Frame/Screens/Cronica/Counter
@onready var back_button: Button = $Frame/BackButton
@onready var close_button: Button = $Frame/CloseButton

# App home screen buttons
@onready var app_taxi: Button = $Frame/Screens/Home/Grid/Taxi
@onready var app_stats: Button = $Frame/Screens/Home/Grid/Stats
@onready var app_journal: Button = $Frame/Screens/Home/Grid/Journal
@onready var app_missions: Button = $Frame/Screens/Home/Grid/Missions
@onready var app_cronica: Button = $Frame/Screens/Home/Grid/Cronica

func _ready() -> void:
	visible = false
	# Wire app icons.
	if app_taxi:
		app_taxi.pressed.connect(func(): _show_screen("taxi"))
	if app_stats:
		app_stats.pressed.connect(func(): _show_screen("stats"))
	if app_journal:
		app_journal.pressed.connect(_open_journal)
	if app_missions:
		app_missions.pressed.connect(_open_missions)
	if app_cronica:
		app_cronica.pressed.connect(func(): _show_screen("cronica"))
	if back_button:
		back_button.pressed.connect(func(): _show_screen("home"))
	if close_button:
		close_button.pressed.connect(close)
	# Listeners pour live refresh quand le téléphone est ouvert.
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_rep_changed)
	EventBus.debt_paid.connect(_on_debt_changed)
	# Met à jour l'horloge au moment de l'ouverture.

func _process(_delta: float) -> void:
	if visible and clock_label:
		var t: Dictionary = Time.get_time_dict_from_system()
		clock_label.text = "%02d:%02d" % [t.hour, t.minute]

# ------------------------------------------------------------------
# Open / close
# ------------------------------------------------------------------

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_show_screen("home")
	get_tree().paused = true

# Ouvre directement sur l'app Crônica (raccourci HUD K).
func open_cronica() -> void:
	visible = true
	_show_screen("cronica")
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

# ------------------------------------------------------------------
# Screens
# ------------------------------------------------------------------

func _show_screen(name: String) -> void:
	home_screen.visible = (name == "home")
	taxi_screen.visible = (name == "taxi")
	stats_screen.visible = (name == "stats")
	cronica_screen.visible = (name == "cronica")
	if back_button:
		back_button.visible = (name != "home")
	if name == "taxi":
		_refresh_taxi()
	elif name == "stats":
		_refresh_stats()
	elif name == "cronica":
		_refresh_cronica()

# ------------------------------------------------------------------
# Taxi app
# ------------------------------------------------------------------

func _refresh_taxi() -> void:
	if taxi_list == null:
		return
	for child in taxi_list.get_children():
		child.queue_free()
	for id in DistrictManager.available_destinations():
		var btn: Button = Button.new()
		var fare: int = DistrictManager.get_fare(id)
		var label: String = DistrictManager.get_label(id)
		btn.text = ("%s  ·  R$ %d" % [label, fare]) if fare > 0 else label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func(): _on_taxi_pressed(id))
		taxi_list.add_child(btn)
	_update_taxi_status()

func _on_taxi_pressed(district_id: String) -> void:
	if DistrictManager.travel_to(district_id):
		close()
	else:
		var fare: int = DistrictManager.get_fare(district_id)
		if taxi_status:
			taxi_status.text = "Pas assez (R$ %d requis)" % fare
			taxi_status.modulate = Color(0.95, 0.4, 0.4, 1)

func _update_taxi_status() -> void:
	if taxi_status == null:
		return
	var money: int = _get_money()
	taxi_status.text = "Tu as R$ %d en poche" % money
	taxi_status.modulate = Color(0.95, 0.92, 0.85, 1)

func _on_money_changed(_amount: int) -> void:
	if visible and taxi_screen.visible:
		_update_taxi_status()
	if visible and stats_screen.visible:
		_refresh_stats()

# ------------------------------------------------------------------
# Stats / Saúde app
# ------------------------------------------------------------------

func _refresh_stats() -> void:
	if stats_box == null:
		return
	for child in stats_box.get_children():
		child.queue_free()
	# Argent + dette
	_add_stat_label("💰 Argent", "R$ %d" % _get_money(), Color(0.95, 0.85, 0.4))
	_add_stat_label("💸 Dette consortium", "R$ %d" % CampaignManager.debt_remaining(), Color(0.95, 0.55, 0.45))
	# Acte courant
	_add_stat_label("🎬 Acte", str(CampaignManager.current_act), Color(0.85, 0.85, 0.95))
	# Stamina
	var stam: Stamina = _get_stamina()
	if stam:
		_add_stat_label("⚡ Énergie", "%d / %d" % [int(stam.current), int(stam.max_value)], Color(0.55, 0.95, 0.55))
	# Séparateur
	var sep: HSeparator = HSeparator.new()
	stats_box.add_child(sep)
	# Réputation 5 axes avec barres
	for axis_name in REP_AXIS_NAMES:
		var axis_int: int = ReputationSystem.Axis.get(axis_name)
		var value: int = ReputationSystem.get_value(axis_int)
		_add_rep_row(axis_name, value)

func _add_stat_label(prefix: String, value: String, color: Color) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var l1: Label = Label.new()
	l1.text = prefix
	l1.custom_minimum_size = Vector2(160, 0)
	l1.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1))
	row.add_child(l1)
	var l2: Label = Label.new()
	l2.text = value
	l2.add_theme_color_override("font_color", color)
	row.add_child(l2)
	stats_box.add_child(row)

func _add_rep_row(axis_name: String, value: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label: Label = Label.new()
	name_label.text = REP_AXIS_LABELS.get(axis_name, axis_name)
	name_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(name_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = -100.0
	bar.max_value = 100.0
	bar.value = float(value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 14)
	bar.modulate = REP_AXIS_COLORS.get(axis_name, Color.WHITE)
	row.add_child(bar)
	var val_label: Label = Label.new()
	val_label.text = str(value)
	val_label.custom_minimum_size = Vector2(36, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_label)
	stats_box.add_child(row)

func _on_rep_changed(_axis_name: String, _value: int) -> void:
	if visible and stats_screen.visible:
		_refresh_stats()

func _on_debt_changed(_amount: int, _remaining: int) -> void:
	if visible and stats_screen.visible:
		_refresh_stats()

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _get_money() -> int:
	if GameManager.player == null:
		return 0
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	return inv.money if inv else 0

func _get_stamina() -> Stamina:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Stamina") as Stamina

# ------------------------------------------------------------------
# Crônica app — vue panoramique de toutes les quêtes (.tres)
# ------------------------------------------------------------------

# Statut affiché par quête. Ordre = priorité de tri à statut donné.
const _CRONICA_STATUS_COMPLETED: int = 0
const _CRONICA_STATUS_ACTIVE: int = 1
const _CRONICA_STATUS_AVAILABLE: int = 2
const _CRONICA_STATUS_LOCKED: int = 3

func _refresh_cronica() -> void:
	if cronica_box == null:
		return
	for child in cronica_box.get_children():
		child.queue_free()

	# Catégorise et ordonne. Les SIDE verrouillées sont cachées (préserve la
	# découverte) ; les MAIN verrouillées s'affichent (la trame est délibérée).
	var main_lines: Array[Dictionary] = []
	var side_lines: Array[Dictionary] = []
	var main_total: int = 0
	var side_total: int = 0
	var main_done: int = 0
	var side_done: int = 0
	for q in QuestManager._quests.values():
		if not (q is Quest):
			continue
		var quest: Quest = q
		var status: int = _cronica_status(quest.id)
		var is_main: bool = quest.quest_type == Quest.QuestType.MAIN
		if is_main:
			main_total += 1
			if status == _CRONICA_STATUS_COMPLETED:
				main_done += 1
			main_lines.append({"quest": quest, "status": status})
		else:
			side_total += 1
			if status == _CRONICA_STATUS_COMPLETED:
				side_done += 1
			if status != _CRONICA_STATUS_LOCKED:
				side_lines.append({"quest": quest, "status": status})

	if cronica_counter:
		cronica_counter.text = "%d/%d história  ·  %d/%d atividades" % [
				main_done, main_total, side_done, side_total]

	main_lines.sort_custom(_cronica_sort)
	side_lines.sort_custom(_cronica_sort)

	if not main_lines.is_empty():
		_add_cronica_section("HISTÓRIA", Color(1.0, 0.9, 0.55, 1))
		for line in main_lines:
			_add_cronica_line(line.quest, line.status)
	if not side_lines.is_empty():
		if not main_lines.is_empty():
			var sep: HSeparator = HSeparator.new()
			cronica_box.add_child(sep)
		_add_cronica_section("ATIVIDADES", Color(0.65, 0.85, 1.0, 1))
		for line in side_lines:
			_add_cronica_line(line.quest, line.status)
	if main_lines.is_empty() and side_lines.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nenhuma missão registrée"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
		empty.add_theme_font_size_override("font_size", 13)
		cronica_box.add_child(empty)

func _cronica_status(quest_id: String) -> int:
	if QuestManager.is_completed(quest_id):
		return _CRONICA_STATUS_COMPLETED
	if QuestManager.is_active(quest_id):
		return _CRONICA_STATUS_ACTIVE
	if QuestManager.is_available(quest_id):
		return _CRONICA_STATUS_AVAILABLE
	return _CRONICA_STATUS_LOCKED

func _cronica_sort(a: Dictionary, b: Dictionary) -> bool:
	# Active d'abord, puis available, puis completed, puis locked. À statut
	# égal, tri par display_name pour stabilité.
	var order: Array[int] = [_CRONICA_STATUS_ACTIVE, _CRONICA_STATUS_AVAILABLE,
			_CRONICA_STATUS_COMPLETED, _CRONICA_STATUS_LOCKED]
	var ai: int = order.find(a.status)
	var bi: int = order.find(b.status)
	if ai != bi:
		return ai < bi
	return (a.quest as Quest).display_name < (b.quest as Quest).display_name

func _add_cronica_section(title: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	cronica_box.add_child(label)

func _add_cronica_line(quest: Quest, status: int) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	# Première ligne : icône + nom.
	var head: Label = Label.new()
	head.text = "%s %s" % [_cronica_icon(status), quest.display_name]
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", _cronica_color(status))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(head)
	# Sous-ligne : prereqs manquants (cas verrouillé) ou objectif courant (cas actif).
	var sub_text: String = ""
	if status == _CRONICA_STATUS_LOCKED:
		sub_text = _cronica_locked_hint(quest)
	elif status == _CRONICA_STATUS_ACTIVE:
		sub_text = _cronica_active_hint(quest)
	if sub_text != "":
		var sub: Label = Label.new()
		sub.text = "  " + sub_text
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(sub)
	cronica_box.add_child(row)

func _cronica_icon(status: int) -> String:
	match status:
		_CRONICA_STATUS_COMPLETED: return "✓"
		_CRONICA_STATUS_ACTIVE:    return "▶"
		_CRONICA_STATUS_AVAILABLE: return "✦"
		_CRONICA_STATUS_LOCKED:    return "🔒"
	return "·"

func _cronica_color(status: int) -> Color:
	match status:
		_CRONICA_STATUS_COMPLETED: return Color(0.55, 0.85, 0.55, 1)
		_CRONICA_STATUS_ACTIVE:    return Color(1.0, 0.9, 0.55, 1)
		_CRONICA_STATUS_AVAILABLE: return Color(0.85, 0.95, 1.0, 1)
		_CRONICA_STATUS_LOCKED:    return Color(0.55, 0.55, 0.6, 1)
	return Color.WHITE

func _cronica_locked_hint(quest: Quest) -> String:
	# Acte trop tôt prime sur les prereqs, c'est plus parlant.
	if quest.required_act > 0 and CampaignManager.current_act < quest.required_act:
		return "Acte %d requis" % quest.required_act
	var missing: Array[String] = QuestManager.missing_prerequisites(quest.id)
	if missing.is_empty():
		return ""
	var pretty: Array[String] = []
	for pid in missing:
		var pq: Quest = QuestManager.get_quest(pid)
		pretty.append(pq.display_name if pq != null and pq.display_name != "" else pid)
	return "D'abord : %s" % ", ".join(pretty)

func _cronica_active_hint(quest: Quest) -> String:
	# Premier objectif non complété (le journal détaillé reste dans QuestLog).
	var state: Dictionary = QuestManager.get_objectives_state(quest.id)
	for obj in quest.objectives:
		if obj.optional:
			continue
		if not state.get(obj.id, false):
			return obj.description
	return ""

# ------------------------------------------------------------------
# Apps externes (réutilisent les UIs existantes)
# ------------------------------------------------------------------

func _open_journal() -> void:
	close()
	var journal: Node = get_tree().current_scene.get_node_or_null("JournalUI")
	if journal and journal.has_method("toggle"):
		journal.toggle()

func _open_missions() -> void:
	close()
	var missions: Node = get_tree().current_scene.get_node_or_null("MissionBoardUI")
	if missions and missions.has_method("open"):
		missions.open()
