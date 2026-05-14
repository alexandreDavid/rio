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
@onready var photos_screen: Control = $Frame/Screens/Photos
@onready var noticias_screen: Control = $Frame/Screens/Noticias
@onready var noticias_box: VBoxContainer = $Frame/Screens/Noticias/Scroll/Box
@onready var ajustes_screen: Control = $Frame/Screens/Ajustes
@onready var slider_music: HSlider = $Frame/Screens/Ajustes/Box/MusicRow/MusicSlider
@onready var slider_sfx: HSlider = $Frame/Screens/Ajustes/Box/SfxRow/SfxSlider
@onready var slider_ambient: HSlider = $Frame/Screens/Ajustes/Box/AmbientRow/AmbientSlider
@onready var replay_tutorial_btn: Button = $Frame/Screens/Ajustes/Box/ReplayTutorial
@onready var show_credits_btn: Button = $Frame/Screens/Ajustes/Box/ShowCredits
@onready var quit_game_btn: Button = $Frame/Screens/Ajustes/Box/QuitGame
@onready var slot_btn_1: Button = $Frame/Screens/Ajustes/Box/SlotRow/Slot1
@onready var slot_btn_2: Button = $Frame/Screens/Ajustes/Box/SlotRow/Slot2
@onready var slot_btn_3: Button = $Frame/Screens/Ajustes/Box/SlotRow/Slot3
@onready var conquistas_screen: Control = $Frame/Screens/Conquistas
@onready var conquistas_box: VBoxContainer = $Frame/Screens/Conquistas/Scroll/Box
@onready var conquistas_counter: Label = $Frame/Screens/Conquistas/Counter
@onready var mapa_screen: Control = $Frame/Screens/Mapa
@onready var mapa_box: VBoxContainer = $Frame/Screens/Mapa/Scroll/Box
@onready var mapa_here_label: Label = $Frame/Screens/Mapa/HereLabel
@onready var taxi_list: VBoxContainer = $Frame/Screens/Taxi/Scroll/Box
@onready var taxi_status: Label = $Frame/Screens/Taxi/Status
@onready var stats_box: VBoxContainer = $Frame/Screens/Stats/Scroll/Box
@onready var cronica_box: VBoxContainer = $Frame/Screens/Cronica/Scroll/Box
@onready var cronica_counter: Label = $Frame/Screens/Cronica/Counter
@onready var photos_box: VBoxContainer = $Frame/Screens/Photos/Scroll/Box
@onready var photos_path_label: Label = $Frame/Screens/Photos/PathLabel
@onready var photos_empty: Label = $Frame/Screens/Photos/Empty
@onready var back_button: Button = $Frame/BackButton
@onready var close_button: Button = $Frame/CloseButton
@onready var photo_viewer: Control = $Frame/PhotoViewer
@onready var viewer_image: TextureRect = $Frame/PhotoViewer/ViewerImage
@onready var viewer_name: Label = $Frame/PhotoViewer/ViewerName
@onready var viewer_close: Button = $Frame/PhotoViewer/ViewerClose

# App home screen buttons
@onready var app_taxi: Button = $Frame/Screens/Home/Grid/Taxi
@onready var app_stats: Button = $Frame/Screens/Home/Grid/Stats
@onready var app_journal: Button = $Frame/Screens/Home/Grid/Journal
@onready var app_missions: Button = $Frame/Screens/Home/Grid/Missions
@onready var app_cronica: Button = $Frame/Screens/Home/Grid/Cronica
@onready var app_photos: Button = $Frame/Screens/Home/Grid/Photos
@onready var app_noticias: Button = $Frame/Screens/Home/Grid/Noticias
@onready var app_ajustes: Button = $Frame/Screens/Home/Grid/Ajustes
@onready var app_conquistas: Button = $Frame/Screens/Home/Grid/Conquistas
@onready var app_mapa: Button = $Frame/Screens/Home/Grid/Mapa

const PHOTOS_DIR: String = "user://photos"

# Badges rouges sur les icônes du home — créés en code pour éviter de toucher
# la scène. Mis à jour à chaque ouverture de l'écran home.
var _badges: Dictionary = {}

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
	if app_photos:
		app_photos.pressed.connect(func(): _show_screen("photos"))
	if app_noticias:
		app_noticias.pressed.connect(func(): _show_screen("noticias"))
	if app_ajustes:
		app_ajustes.pressed.connect(func(): _show_screen("ajustes"))
	if app_conquistas:
		app_conquistas.pressed.connect(func(): _show_screen("conquistas"))
	if app_mapa:
		app_mapa.pressed.connect(func(): _show_screen("mapa"))
	_setup_app_badges()
	# Sliders volumes — émettent au glisser, persistés par Settings.
	if slider_music:
		slider_music.value_changed.connect(func(v): Settings.set_music(v))
	if slider_sfx:
		slider_sfx.value_changed.connect(func(v): Settings.set_sfx(v))
	if slider_ambient:
		slider_ambient.value_changed.connect(func(v): Settings.set_ambient(v))
	if replay_tutorial_btn:
		replay_tutorial_btn.pressed.connect(_replay_tutorial)
	if show_credits_btn:
		show_credits_btn.pressed.connect(_show_credits)
	if quit_game_btn:
		# Sur mobile/web : revenir au menu (quit ferme un onglet web et est
		# bloqué par les stores mobiles). Sur desktop : quit proprement.
		if OS.has_feature("mobile") or OS.has_feature("web"):
			quit_game_btn.text = "Retour au menu"
			quit_game_btn.pressed.connect(_back_to_menu)
		else:
			quit_game_btn.pressed.connect(_quit_game)
	if slot_btn_1:
		slot_btn_1.pressed.connect(func(): _on_slot_pressed(1))
	if slot_btn_2:
		slot_btn_2.pressed.connect(func(): _on_slot_pressed(2))
	if slot_btn_3:
		slot_btn_3.pressed.connect(func(): _on_slot_pressed(3))
	if back_button:
		back_button.pressed.connect(func(): _show_screen("home"))
	if close_button:
		close_button.pressed.connect(close)
	if viewer_close:
		viewer_close.pressed.connect(_close_photo_viewer)
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
	_refresh_badges()
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

func _setup_app_badges() -> void:
	# Crée un Label rouge attaché en haut-droite de chaque app sujette à
	# notification. Caché par défaut, _refresh_badges décide quand l'afficher.
	for pair in [["cronica", app_cronica], ["conquistas", app_conquistas], ["photos", app_photos]]:
		var app_id: String = pair[0]
		var btn: Button = pair[1]
		if btn == null:
			continue
		var badge: Label = Label.new()
		badge.text = ""
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		badge.add_theme_color_override("font_outline_color", Color(0.85, 0.15, 0.12, 1))
		badge.add_theme_constant_override("outline_size", 8)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -28.0
		badge.offset_top = 4.0
		badge.offset_right = -4.0
		badge.offset_bottom = 26.0
		badge.visible = false
		btn.add_child(badge)
		_badges[app_id] = badge

func _refresh_badges() -> void:
	var cronica_new: int = NarrativeJournal.unlocked_count() - Settings.last_seen_cronica
	var conquistas_new: int = AchievementSystem.count_unlocked() - Settings.last_seen_conquistas
	var photos_new: int = _list_photo_files().size() - Settings.last_seen_photos
	_update_badge("cronica", cronica_new)
	_update_badge("conquistas", conquistas_new)
	_update_badge("photos", photos_new)

func _update_badge(app_id: String, count: int) -> void:
	var badge: Label = _badges.get(app_id, null) as Label
	if badge == null:
		return
	if count > 0:
		var was_hidden: bool = not badge.visible
		badge.text = str(count) if count < 10 else "9+"
		badge.visible = true
		# Pulse subtil à la première apparition (transition cachée → visible).
		if was_hidden:
			badge.pivot_offset = badge.size / 2.0
			badge.scale = Vector2(1.5, 1.5)
			var tw: Tween = create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.28)
	else:
		badge.visible = false

func _show_screen(name: String) -> void:
	home_screen.visible = (name == "home")
	taxi_screen.visible = (name == "taxi")
	stats_screen.visible = (name == "stats")
	cronica_screen.visible = (name == "cronica")
	if photos_screen:
		photos_screen.visible = (name == "photos")
	if noticias_screen:
		noticias_screen.visible = (name == "noticias")
	if ajustes_screen:
		ajustes_screen.visible = (name == "ajustes")
	if conquistas_screen:
		conquistas_screen.visible = (name == "conquistas")
	if mapa_screen:
		mapa_screen.visible = (name == "mapa")
	if back_button:
		back_button.visible = (name != "home")
	if name == "taxi":
		_refresh_taxi()
	elif name == "stats":
		_refresh_stats()
	elif name == "cronica":
		_refresh_cronica()
	elif name == "photos":
		_refresh_photos()
	elif name == "noticias":
		_refresh_noticias()
	elif name == "ajustes":
		_refresh_ajustes()
	elif name == "conquistas":
		_refresh_conquistas()
	elif name == "mapa":
		_refresh_mapa()
	# Marque comme "vue" l'app ouverte (badge disparaît au retour home).
	if name == "cronica":
		Settings.mark_seen("cronica", NarrativeJournal.unlocked_count())
	elif name == "conquistas":
		Settings.mark_seen("conquistas", AchievementSystem.count_unlocked())
	elif name == "photos":
		Settings.mark_seen("photos", _list_photo_files().size())
	elif name == "home":
		_refresh_badges()

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
	stats_box.add_child(HSeparator.new())
	# Tracker progression d'acte (cible + barre + pivots manquants)
	_add_act_tracker()
	stats_box.add_child(HSeparator.new())
	# Stats cumulatives de la run (compteurs purs).
	_add_run_stats()
	stats_box.add_child(HSeparator.new())
	# Réputation 5 axes avec barres
	for axis_name in REP_AXIS_NAMES:
		var axis_int: int = ReputationSystem.Axis.get(axis_name)
		var value: int = ReputationSystem.get_value(axis_int)
		_add_rep_row(axis_name, value)

# Section « 📊 Stats de partie » : compteurs cumulatifs visibles depuis la
# Saúde. Donne un sens d'avancement au joueur en dehors des actes/quêtes.
func _add_run_stats() -> void:
	var section: Label = Label.new()
	section.text = "📊 Stats de partie"
	section.add_theme_font_size_override("font_size", 13)
	section.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	stats_box.add_child(section)
	_add_stat_label("📅 Jours vécus", str(TimeOfDay.day_count), Color(0.85, 0.85, 0.95))
	_add_stat_label("🗨 NPCs rencontrés", str(NPCAffinity._counts.keys().size()), Color(0.85, 0.85, 0.95))
	_add_stat_label("✅ Quêtes complétées", str(_count_completed_quests()), Color(0.85, 0.85, 0.95))
	_add_stat_label("🚖 Districts visités", str(AchievementSystem._districts_visited.keys().size()), Color(0.85, 0.85, 0.95))
	_add_stat_label("📸 Photos prises", str(_list_photo_files().size()), Color(0.85, 0.85, 0.95))
	_add_stat_label("🌅 Viewpoints admirés", str(_count_viewpoints()), Color(0.85, 0.85, 0.95))
	_add_stat_label("🏆 Conquistas", "%d / %d" % [AchievementSystem.count_unlocked(), AchievementSystem.count_total()], Color(0.95, 0.85, 0.4))

func _count_completed_quests() -> int:
	var n: int = 0
	for qid in QuestManager._state:
		if QuestManager.is_completed(qid):
			n += 1
	return n

func _count_viewpoints() -> int:
	var n: int = 0
	for k in CampaignManager.flags:
		if String(k).begins_with("viewpoint_") and CampaignManager.flags[k]:
			n += 1
	return n

# Vue « Estratégia » : combien de R$ + quels pivots manquent pour passer au
# prochain acte. Acte 4 (règne) affiche le titre. Acte 3 sans voie choisie
# pointe vers les trois NPCs de finale.
func _add_act_tracker() -> void:
	var act: int = CampaignManager.current_act
	var section: Label = Label.new()
	section.add_theme_font_size_override("font_size", 13)
	section.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	if act >= 4:
		section.text = "🏛 Reinado : %s" % CampaignManager.reign_title()
		stats_box.add_child(section)
		var hint: Label = Label.new()
		hint.text = "Le pouvoir est à toi. Sambódromo t'attend pour le défilé."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_box.add_child(hint)
		return
	if act == 3:
		section.text = "🎯 Acte 3 — Choisir une voie"
		stats_box.add_child(section)
		_add_act3_hint()
		return
	section.text = "🎯 Acte %d → %d" % [act, act + 1]
	stats_box.add_child(section)
	# Barre de progression dette (acte 1→2 = 500, acte 2→3 = 25000).
	var threshold: int = CampaignManager.ACT1_THRESHOLD if act == 1 else CampaignManager.ACT2_THRESHOLD
	var paid: int = CampaignManager.debt_paid
	var pct_bar: HBoxContainer = HBoxContainer.new()
	pct_bar.add_theme_constant_override("separation", 8)
	var pct_label: Label = Label.new()
	pct_label.text = "💰"
	pct_label.custom_minimum_size = Vector2(28, 0)
	pct_bar.add_child(pct_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(threshold)
	bar.value = float(min(paid, threshold))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 12)
	bar.modulate = Color(0.95, 0.85, 0.4) if paid >= threshold else Color(0.95, 0.55, 0.45)
	pct_bar.add_child(bar)
	var val: Label = Label.new()
	val.text = "%d / %d" % [min(paid, threshold), threshold]
	val.add_theme_font_size_override("font_size", 10)
	pct_bar.add_child(val)
	stats_box.add_child(pct_bar)
	# Pivots manquants
	var pivots: Array = CampaignManager.ACT_PIVOT_QUESTS.get(act + 1, [])
	for pid in pivots:
		var done: bool = QuestManager.is_completed(pid)
		var q: Quest = QuestManager.get_quest(pid)
		var row: Label = Label.new()
		var name: String = q.display_name if q != null and q.display_name != "" else pid
		row.text = "  %s %s" % [("✓" if done else "▢"), name]
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55) if done else Color(0.7, 0.7, 0.75))
		stats_box.add_child(row)

func _add_act3_hint() -> void:
	var endgame: int = CampaignManager.chosen_endgame
	var hint: Label = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	if endgame == CampaignManager.Endgame.NONE:
		hint.text = "Trois voies, mutuellement exclusives :\n  • Ramos (Bar) → Polícia\n  • Miguel (Morro) → Tráfico\n  • Padre (Chapelle) → Prefeito"
	else:
		var name: String = CampaignManager.endgame_name()
		hint.text = "Voie scellée : %s. Termine la chaîne pour l'acte 4." % name
	stats_box.add_child(hint)

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

# ------------------------------------------------------------------
# Photos app — liste les screenshots du mode photo (user://photos/)
# ------------------------------------------------------------------

const THUMB_W: int = 96
const THUMB_H: int = 54

func _refresh_photos() -> void:
	if photos_box == null:
		return
	for child in photos_box.get_children():
		child.queue_free()
	var files: Array[String] = _list_photo_files()
	# Path absolu OS pour donner au joueur l'emplacement réel des PNG.
	if photos_path_label:
		var abs_path: String = ProjectSettings.globalize_path(PHOTOS_DIR + "/")
		photos_path_label.text = abs_path
	if photos_empty:
		photos_empty.visible = files.is_empty()
	for fname in files:
		photos_box.add_child(_build_photo_row(fname))

func _list_photo_files() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(PHOTOS_DIR):
		return out
	for f in DirAccess.get_files_at(PHOTOS_DIR):
		if f.to_lower().ends_with(".png"):
			out.append(f)
	# Plus récents d'abord (noms horodatés YYYYMMDD_HHMMSS triés desc).
	out.sort_custom(func(a, b): return a > b)
	return out

func _build_photo_row(fname: String) -> Control:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(360, THUMB_H + 12)
	row.flat = true
	row.pressed.connect(func(): _open_photo_viewer(fname))
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)
	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = Vector2(THUMB_W, THUMB_H)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = _load_photo_texture(fname)
	hbox.add_child(thumb)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label: Label = Label.new()
	name_label.text = fname
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	info.add_child(name_label)
	var size_label: Label = Label.new()
	size_label.text = _photo_size_text(fname)
	size_label.add_theme_font_size_override("font_size", 10)
	size_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	info.add_child(size_label)
	hbox.add_child(info)
	return row

func _load_photo_texture(fname: String) -> Texture2D:
	var img: Image = Image.load_from_file(PHOTOS_DIR + "/" + fname)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

func _photo_size_text(fname: String) -> String:
	var f: FileAccess = FileAccess.open(PHOTOS_DIR + "/" + fname, FileAccess.READ)
	if f == null:
		return ""
	var size: int = f.get_length()
	f.close()
	if size > 1024 * 1024:
		return "%.1f MB" % (float(size) / (1024.0 * 1024.0))
	return "%d KB" % int(size / 1024.0)

func _open_photo_viewer(fname: String) -> void:
	if photo_viewer == null or viewer_image == null:
		return
	viewer_image.texture = _load_photo_texture(fname)
	if viewer_name:
		viewer_name.text = fname
	photo_viewer.visible = true

func _close_photo_viewer() -> void:
	if photo_viewer:
		photo_viewer.visible = false
	if viewer_image:
		viewer_image.texture = null

# ------------------------------------------------------------------
# Notícias app — manchettes réactives selon l'état narratif courant.
# ------------------------------------------------------------------

const NEWS_COLOR_AMBIENT: Color = Color(0.85, 0.85, 0.80)
const NEWS_COLOR_CIVIC: Color = Color(0.55, 0.95, 0.55)
const NEWS_COLOR_POLICE: Color = Color(0.55, 0.78, 0.95)
const NEWS_COLOR_WARN: Color = Color(0.95, 0.62, 0.45)
const NEWS_COLOR_SOCIETY: Color = Color(0.85, 0.55, 0.95)
const NEWS_COLOR_WIN: Color = Color(0.95, 0.85, 0.40)

func _refresh_noticias() -> void:
	if noticias_box == null:
		return
	for child in noticias_box.get_children():
		child.queue_free()
	var items: Array = _build_news_items()
	for item in items:
		noticias_box.add_child(_build_news_row(item))

func _build_news_items() -> Array:
	# Renvoie un tableau de Dictionaries {text, source, color}, du plus récent
	# (haut) au plus contextuel (bas). Filtré sur l'état campagne/quêtes/dette.
	var out: Array = []
	var act: int = CampaignManager.current_act
	var debt: int = CampaignManager.debt_remaining()
	var day: int = TimeOfDay.day_count
	var endgame: int = CampaignManager.chosen_endgame

	# Manchettes endgame (acte 4 — règne).
	if act >= 4:
		match endgame:
			CampaignManager.Endgame.PREFEITO:
				out.append({"text": "Subprefeitura civica anunciada — Coronel do Bairro recebe a faixa", "source": "O Globo Rio", "color": NEWS_COLOR_WIN})
			CampaignManager.Endgame.POLICIA:
				out.append({"text": "Operação Madrugada encerra ciclo de violência — Chefe de Polícia condecorado", "source": "Jornal do Brasil", "color": NEWS_COLOR_WIN})
			CampaignManager.Endgame.TRAFICO:
				out.append({"text": "Hierarquia do Morro consolidada — novo Patrão silencia o bairro", "source": "Extra", "color": NEWS_COLOR_WIN})

	# Pacto da Barra — pivot business.
	if CampaignManager.has_flag("barra_pacto_sealed"):
		out.append({"text": "Riserva Uno formaliza parceria de segurança privada — três condomínios alinhados", "source": "Veja Rio", "color": NEWS_COLOR_SOCIETY})

	# Mendonça / commissaire — danger.
	if CampaignManager.has_flag("commissaire_alerted"):
		out.append({"text": "PM intensifica rondas na Barra após denúncia anônima de extorsão", "source": "Extra", "color": NEWS_COLOR_WARN})

	# Endorsements — campagne politique en cours.
	if QuestManager.is_active("act3_prefeito_endorsements") or QuestManager.is_completed("act3_prefeito_endorsements"):
		out.append({"text": "Coalizão civica reúne padre, comerciantes e padaria histórica", "source": "O Globo Rio", "color": NEWS_COLOR_CIVIC})

	# Pivot acte 2 — révélation Concierge.
	if CampaignManager.has_flag("tio_ze_revealed"):
		out.append({"text": "Concierge do Palace mantém perfil discreto — vizinhos surpreendem", "source": "Sociedade Rio", "color": NEWS_COLOR_SOCIETY})

	# Operação Carnaval — Ramos / acte 2.
	if QuestManager.is_completed("act2_ramos_operacao"):
		out.append({"text": "PM divulga balanço de Operação Carnaval — silêncio sobre fontes", "source": "Jornal do Brasil", "color": NEWS_COLOR_POLICE})

	# Orfanato — padre / acte 2.
	if QuestManager.is_completed("act2_padre_orfanato"):
		out.append({"text": "Paróquia salva orfanato em campanha relâmpago — agradecimentos públicos", "source": "Diário do Bairro", "color": NEWS_COLOR_CIVIC})

	# Convoi favela — Miguel / acte 2.
	if QuestManager.is_completed("act2_miguel_favela"):
		out.append({"text": "Comboio de mantimentos chega ao Morro — voluntários anônimos", "source": "Extra", "color": NEWS_COLOR_SOCIETY})

	# Crise dette élevée (joueur en retard).
	if act >= 2 and debt > 30000:
		out.append({"text": "Jovens cariocas enfrentam dívidas familiares herdadas — fenômeno cresce", "source": "Folha Rio", "color": NEWS_COLOR_WARN})
	elif act >= 3 and debt > 0 and debt <= 5000:
		out.append({"text": "Histórias de superação no calçadão — perseverança paga dívidas", "source": "Diário do Bairro", "color": NEWS_COLOR_CIVIC})

	# Niterói — chaîne consortium boucle vers la baie.
	if QuestManager.is_completed("bruno_carga"):
		out.append({"text": "MAC Niemeyer prepara exposição de junho — curadoria recebe peça inédita", "source": "Veja Rio", "color": NEWS_COLOR_AMBIENT})

	# Réputation extrême.
	if ReputationSystem.get_value(ReputationSystem.Axis.POLICE) >= 50:
		out.append({"text": "Comunidade elogia 'cidadão exemplar' anônimo — PM agradece", "source": "Jornal do Brasil", "color": NEWS_COLOR_POLICE})
	if ReputationSystem.get_value(ReputationSystem.Axis.STREET) >= 50:
		out.append({"text": "Lendas urbanas no Morro — sobrinho misterioso protege os pequenos", "source": "Extra", "color": NEWS_COLOR_SOCIETY})

	# Carnaval — proche pendant acte 4.
	if act >= 4:
		out.append({"text": "Sambódromo afinado — ensaios técnicos liberam ingressos do bloco", "source": "O Globo Rio", "color": NEWS_COLOR_AMBIENT})
	else:
		out.append({"text": "Carnaval 2026 — preparativos começam nos blocos do bairro", "source": "O Globo Rio", "color": NEWS_COLOR_AMBIENT})

	# Météo & vie de quartier — toujours présents pour donner du grain.
	out.append({"text": "Posto 5 registra recorde de surfistas no fim de semana", "source": "Extra", "color": NEWS_COLOR_AMBIENT})
	out.append({"text": "Tempo na praia : sol forte, 32°C, ventos leves de sul", "source": "Diário do Bairro", "color": NEWS_COLOR_AMBIENT})
	if day >= 5:
		out.append({"text": "Vendedores de milho assados disputam território no calçadão", "source": "Sociedade Rio", "color": NEWS_COLOR_AMBIENT})
	return out

# Districts groupés par région géographique pour l'app Mapa.
const MAPA_REGIONS: Array = [
	{"label": "🌄 Norte", "ids": ["sambodromo", "maracana", "corcovado"]},
	{"label": "🌅 Leste (baía + bondinho)", "ids": ["niteroi", "pao_acucar", "santos_dumont", "aterro_flamengo", "botafogo_flamengo"]},
	{"label": "🏙 Centro", "ids": ["favela_morro", "copacabana"]},
	{"label": "🏖 Sul + Oeste", "ids": ["zona_sul", "cagarras", "barra_tijuca"]},
]

func _refresh_mapa() -> void:
	if mapa_box == null:
		return
	for child in mapa_box.get_children():
		child.queue_free()
	var current_id: String = DistrictManager.current()
	if mapa_here_label:
		mapa_here_label.text = "Vous êtes ici : %s" % DistrictManager.get_label(current_id)
	for region in MAPA_REGIONS:
		var header: Label = Label.new()
		header.text = String(region.label)
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		mapa_box.add_child(header)
		for id in region.ids:
			if not DistrictManager.DISTRICTS.has(id):
				continue
			mapa_box.add_child(_build_mapa_row(id, current_id))
		var sep: HSeparator = HSeparator.new()
		mapa_box.add_child(sep)

func _build_mapa_row(district_id: String, current_id: String) -> Control:
	var info: Dictionary = DistrictManager.DISTRICTS[district_id]
	var label: String = DistrictManager.get_label(district_id)
	var fare: int = DistrictManager.get_fare(district_id)
	var taxi_ok: bool = info.get("taxi_available", true)
	var is_current: bool = (district_id == current_id)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(360, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 12)
	var prefix: String = "📍 " if is_current else "  "
	var suffix: String
	if is_current:
		suffix = "  · ici"
	elif not taxi_ok:
		suffix = "  · bondinho seulement"
	elif fare > 0:
		suffix = "  · R$ %d" % fare
	else:
		suffix = ""
	btn.text = "%s%s%s" % [prefix, label, suffix]
	btn.disabled = is_current or not taxi_ok
	if is_current:
		btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	elif not taxi_ok:
		btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	if not btn.disabled:
		btn.pressed.connect(func(): _on_mapa_pressed(district_id))
	return btn

func _on_mapa_pressed(district_id: String) -> void:
	if DistrictManager.travel_to(district_id):
		close()

func _refresh_conquistas() -> void:
	if conquistas_box == null:
		return
	for child in conquistas_box.get_children():
		child.queue_free()
	if conquistas_counter:
		conquistas_counter.text = "%d / %d débloquées" % [AchievementSystem.count_unlocked(), AchievementSystem.count_total()]
	for entry in AchievementSystem.CATALOG:
		conquistas_box.add_child(_build_achievement_row(entry))

func _build_achievement_row(entry: Dictionary) -> Control:
	var unlocked: bool = AchievementSystem.is_unlocked(entry.get("id", ""))
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.12, 1) if unlocked else Color(0.12, 0.12, 0.14, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	var icon_label: Label = Label.new()
	icon_label.text = entry.get("icon", "🏆") if unlocked else "🔒"
	icon_label.custom_minimum_size = Vector2(34, 0)
	icon_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(icon_label)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	var title: Label = Label.new()
	title.text = entry.get("title", "")
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4) if unlocked else Color(0.55, 0.55, 0.6))
	info.add_child(title)
	var desc: Label = Label.new()
	desc.text = entry.get("desc", "")
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75) if unlocked else Color(0.4, 0.4, 0.45))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	# Barre de progression pour les achievements à seuil non débloqués.
	if not unlocked:
		var prog: Dictionary = AchievementSystem.progress_for(entry.get("id", ""))
		if not prog.is_empty():
			info.add_child(_build_progress_row(int(prog.current), int(prog.max)))
	return card

func _build_progress_row(current: int, max_value: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(max_value)
	bar.value = float(current)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 8)
	bar.modulate = Color(0.55, 0.85, 0.95)
	row.add_child(bar)
	var lbl: Label = Label.new()
	lbl.text = "%d/%d" % [current, max_value]
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	row.add_child(lbl)
	return row

func _refresh_ajustes() -> void:
	# Synchronise les sliders avec les valeurs actuelles de Settings.
	# set_value_no_signal pour ne pas déclencher value_changed → save inutile.
	if slider_music:
		slider_music.set_value_no_signal(Settings.music_volume)
	if slider_sfx:
		slider_sfx.set_value_no_signal(Settings.sfx_volume)
	if slider_ambient:
		slider_ambient.set_value_no_signal(Settings.ambient_volume)
	_refresh_slot_buttons()

const SLOT_BUTTONS_BY_INDEX: Array = [null, null, null, null]

func _refresh_slot_buttons() -> void:
	var buttons: Array = [slot_btn_1, slot_btn_2, slot_btn_3]
	for i in 3:
		var slot: int = i + 1
		var btn: Button = buttons[i]
		if btn == null:
			continue
		var info: Dictionary = SaveSystem.slot_info(slot)
		var prefix: String = "📍 " if slot == Settings.current_slot else "  "
		if info.is_empty():
			btn.text = "%sSlot %d — vide" % [prefix, slot]
		else:
			btn.text = "%sSlot %d — Jour %d · Acte %d · R$ %d payés" % [
					prefix, slot, info.get("day", 1), info.get("act", 1), info.get("debt_paid", 0)]
		btn.disabled = (slot == Settings.current_slot)

func _on_slot_pressed(slot: int) -> void:
	SaveSystem.switch_to_slot(slot)
	_refresh_slot_buttons()
	_flash_save_toast("Slot %d chargé" % slot)

func _flash_save_toast(_msg: String) -> void:
	# Utilise le toast du HUD si présent (reuse le système existant).
	# Sinon : muet — l'utilisateur voit déjà le label changer.
	pass

func _replay_tutorial() -> void:
	var t: Node = get_tree().current_scene.get_node_or_null("Tutorial")
	if t and t.has_method("open"):
		close()
		t.open()

func _show_credits() -> void:
	var c: Node = get_tree().current_scene.get_node_or_null("CreditsScreen")
	if c and c.has_method("open"):
		close()
		c.open()

func _quit_game() -> void:
	# Auto-save de courtoisie avant de quitter.
	SaveSystem.save_game()
	get_tree().quit()

func _back_to_menu() -> void:
	# Auto-save puis retour au menu Intro (l'appareil mobile/web n'autorise
	# pas un vrai quit propre).
	SaveSystem.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/Intro.tscn")

func _build_news_row(item: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.18, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var source: Label = Label.new()
	source.text = item.get("source", "")
	source.add_theme_font_size_override("font_size", 9)
	source.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(source)
	var headline: Label = Label.new()
	headline.text = item.get("text", "")
	headline.add_theme_font_size_override("font_size", 12)
	headline.add_theme_color_override("font_color", item.get("color", NEWS_COLOR_AMBIENT))
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(headline)
	return card
