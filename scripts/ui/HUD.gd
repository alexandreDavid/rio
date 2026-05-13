extends Control

# Paths à maintenir synchronisés avec scenes/ui/HUD.tscn.
@onready var money_label: Label = $Top/MoneyLabel
@onready var stamina_bar: ProgressBar = $Top/StaminaBar
@onready var stock_label: Label = $Top/StockLabel
@onready var day_label: Label = $Top/Clock/DayLabel
@onready var phase_bar: ProgressBar = $Top/Clock/PhaseBar
@onready var debt_label: Label = $Top/DebtLabel
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var character_sheet: PanelContainer = $CharacterSheet
@onready var abilities: VBoxContainer = $CharacterSheet/Margin/Layout/Abilities
@onready var menu_button: Button = $MenuButton
@onready var journal_button: Button = $JournalButton
@onready var save_button: Button = $SaveButton
@onready var photo_button: Button = $PhotoButton
@onready var close_sheet_button: Button = $CharacterSheet/Margin/Layout/Close
@onready var save_toast: Label = $SaveToast
@onready var quest_tracker: PanelContainer = $QuestTracker
@onready var quest_tracker_name: Label = $QuestTracker/Margin/VBox/QuestName
@onready var quest_tracker_objective: Label = $QuestTracker/Margin/VBox/QuestObjective

# Clé = nom d'axe renvoyé par EventBus.reputation_changed (ReputationSystem.Axis.keys()).
# Valeur = teinte appliquée à la barre pour distinguer les axes d'un coup d'œil.
const AXIS_COLORS: Dictionary = {
	"CIVIC":    Color(0.55, 0.85, 0.55),  # vert — respect
	"POLICE":   Color(0.4, 0.6, 0.95),    # bleu — relation police
	"STREET":   Color(0.9, 0.55, 0.3),    # orange — voyou
	"TOURIST":  Color(0.95, 0.85, 0.35),  # jaune — touristes
	"CHARISMA": Color(0.85, 0.45, 0.85),  # rose — charisma
}

var _active_interactables: Array[Node] = []

# Toast doré "✦ Nouvelle quête : <nom>" pour MAIN qui devient is_available().
# Le seed initial (deferred + post-load) garantit qu'on ne re-toaste pas les MAIN
# déjà connues du joueur (cas chargement de save).
var _signaled_main_ids: Dictionary = {}
var _main_toast_seeded: bool = false

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_lost.connect(_on_interaction_lost)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.corn_cart_state_changed.connect(_on_cart_state)
	EventBus.corn_stock_changed.connect(_on_stock_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.day_elapsed.connect(_on_day_elapsed)
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.quest_accepted.connect(_on_quest_change_check_main)
	EventBus.quest_completed.connect(_on_quest_change_check_main)
	EventBus.quest_accepted.connect(_refresh_tracker_for)
	EventBus.quest_completed.connect(_refresh_tracker_for)
	EventBus.quest_updated.connect(_refresh_tracker_for_obj)
	call_deferred("_refresh_tracker")
	SaveSystem.save_committed.connect(_on_save_committed)
	SaveSystem.save_loaded.connect(_on_save_loaded)
	DynamicMissionManager.mission_completed.connect(_on_dynamic_mission_completed)
	call_deferred("_seed_main_signaled")
	_refresh_day()
	_refresh_debt()
	if interaction_prompt:
		interaction_prompt.hide()
	if stock_label:
		stock_label.hide()
	if character_sheet:
		character_sheet.hide()  # remplacé par l'app Saúde du téléphone
	if menu_button:
		menu_button.pressed.connect(_toggle_phone)
	if close_sheet_button:
		close_sheet_button.pressed.connect(_toggle_phone)
	if journal_button:
		journal_button.pressed.connect(_toggle_journal)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if photo_button:
		photo_button.pressed.connect(_on_photo_pressed)
	_init_abilities()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	# Raccourcis clavier = bonus dev / desktop. La cible est mobile (touch),
	# donc toutes ces fonctions doivent rester accessibles via boutons à l'écran.
	# P : ouvre / ferme le téléphone (bouton 📱 du HUD).
	# C : raccourci historique vers la fiche perso → ouvre maintenant l'app Saúde du téléphone.
	if key == KEY_P or key == KEY_C:
		_toggle_phone()
		get_viewport().set_input_as_handled()
	# K : raccourci direct vers l'app Crônica (toggle). Sur mobile, passer par 📱 → 📜.
	elif key == KEY_K:
		_toggle_cronica()
		get_viewport().set_input_as_handled()
	# F : photo mode — screenshot dans user://photos/. Sur mobile, bouton 📸 du HUD.
	elif key == KEY_F:
		_on_photo_pressed()
		get_viewport().set_input_as_handled()

func _toggle_phone() -> void:
	var phone: Node = get_tree().current_scene.get_node_or_null("Phone")
	if phone and phone.has_method("toggle"):
		phone.toggle()

func _toggle_cronica() -> void:
	var phone: Node = get_tree().current_scene.get_node_or_null("Phone")
	if phone == null:
		return
	if phone.visible:
		phone.close()
	elif phone.has_method("open_cronica"):
		phone.open_cronica()

func _on_save_pressed() -> void:
	SaveSystem.save_game()

func _on_photo_pressed() -> void:
	# Cache temporairement le HUD pour un cliché propre, puis attend une frame.
	var was_visible: bool = visible
	visible = false
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	visible = was_visible
	if img == null:
		_flash_toast("📸 Photo impossible", Color(0.95, 0.55, 0.45, 1))
		return
	DirAccess.make_dir_recursive_absolute("user://photos")
	var t: Dictionary = Time.get_datetime_dict_from_system()
	var name: String = "photo_%04d%02d%02d_%02d%02d%02d.png" % [
			t.year, t.month, t.day, t.hour, t.minute, t.second]
	var path: String = "user://photos/" + name
	var err: int = img.save_png(path)
	if err == OK:
		_flash_toast("📸 " + name, Color(0.9, 0.95, 0.7, 1), 2.0)
	else:
		_flash_toast("📸 Échec de l'écriture", Color(0.95, 0.55, 0.45, 1))

func _toggle_journal() -> void:
	var journal: Node = get_tree().current_scene.get_node_or_null("JournalUI")
	if journal and journal.has_method("toggle"):
		journal.toggle()

func _process(_delta: float) -> void:
	# Stamina bar.
	if stamina_bar and GameManager.player:
		var stam: Node = GameManager.player.get_node_or_null("Stamina")
		if stam:
			stamina_bar.value = stam.ratio() * 100.0
	# Barre de progression de la phase de la journée.
	if phase_bar:
		phase_bar.value = TimeOfDay.phase_progress()

func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "R$ %d" % amount

func _on_interaction_available(node: Node) -> void:
	if node and not _active_interactables.has(node):
		_active_interactables.append(node)
	_refresh_prompt()

func _on_interaction_lost(node: Node) -> void:
	_active_interactables.erase(node)
	_refresh_prompt()

func _on_interaction_unavailable() -> void:
	_active_interactables.clear()
	_refresh_prompt()

func _refresh_prompt() -> void:
	if interaction_prompt == null:
		return
	for i in range(_active_interactables.size() - 1, -1, -1):
		if not is_instance_valid(_active_interactables[i]):
			_active_interactables.remove_at(i)
	if _active_interactables.size() == 0:
		interaction_prompt.hide()
		return
	var top: Node = _active_interactables.back()
	var prompt_text: String
	if top.has_method("effective_prompt"):
		prompt_text = top.effective_prompt()
	elif "prompt" in top:
		prompt_text = top.prompt
	else:
		prompt_text = "Interagir"
	interaction_prompt.text = "[E] " + prompt_text
	interaction_prompt.show()

func _on_cart_state(carrying: bool) -> void:
	if stock_label:
		stock_label.visible = carrying

func _on_stock_changed(remaining: int) -> void:
	if stock_label:
		stock_label.text = "Milho: %d" % remaining

func _init_abilities() -> void:
	if abilities == null:
		return
	for axis_name in AXIS_COLORS:
		var row: HBoxContainer = abilities.get_node_or_null(_row_name(axis_name)) as HBoxContainer
		if row == null:
			continue
		var bar: ProgressBar = row.get_node("Bar") as ProgressBar
		bar.modulate = AXIS_COLORS[axis_name]
		var axis_idx: int = ReputationSystem.Axis.keys().find(axis_name)
		if axis_idx >= 0:
			_set_axis_display(axis_name, ReputationSystem.get_value(axis_idx))

func _on_reputation_changed(axis_name: String, new_value: int) -> void:
	_set_axis_display(axis_name, new_value)
	# Le prompt d'interaction peut dépendre d'un seuil de rep (locked_prompt) : rafraîchir.
	_refresh_prompt()

func _set_axis_display(axis_name: String, value: int) -> void:
	if abilities == null:
		return
	var row: HBoxContainer = abilities.get_node_or_null(_row_name(axis_name)) as HBoxContainer
	if row == null:
		return
	var bar: ProgressBar = row.get_node("Bar") as ProgressBar
	var label: Label = row.get_node("Value") as Label
	bar.value = value
	label.text = "%+d" % value if value != 0 else "0"

func _row_name(axis_name: String) -> String:
	return "Row" + axis_name

func _on_day_elapsed(_new_day: int) -> void:
	_refresh_day()

func _on_phase_changed(_phase: int) -> void:
	_refresh_day()
	var labels: Dictionary = {
		TimeOfDay.Phase.MORNING: "☀ Le matin se lève",
		TimeOfDay.Phase.AFTERNOON: "🌤 L'après-midi commence",
		TimeOfDay.Phase.EVENING: "🌙 Le soir tombe",
	}
	if labels.has(TimeOfDay.current_phase):
		_flash_toast(labels[TimeOfDay.current_phase])

func _on_debt_paid(_amount: int, remaining: int) -> void:
	_refresh_debt()
	# Dette soldée en acte 3 sans voie choisie : indique au joueur où finir le règne.
	if remaining <= 0 and CampaignManager.current_act == 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE:
		_flash_toast("Dette soldée — Va voir Ramos / Miguel / Padre pour clore ton règne")

func _on_act_changed(new_act: int) -> void:
	_refresh_debt()
	_refresh_day()
	var titles: Dictionary = {
		2: "Acte 2 — Os verdadeiros rostos",
		3: "Acte 3 — A última volta",
		4: "Acte 4 — O Reinado",
	}
	if titles.has(new_act):
		_flash_toast(titles[new_act])

func _refresh_day() -> void:
	if day_label:
		var icons: Dictionary = {
			TimeOfDay.Phase.MORNING: "☀ Matin",
			TimeOfDay.Phase.AFTERNOON: "🌤 Après-midi",
			TimeOfDay.Phase.EVENING: "🌙 Soir",
		}
		var phase_text: String = icons.get(TimeOfDay.current_phase, "")
		day_label.text = "Jour %d · Acte %d · %s" % [TimeOfDay.day_count, CampaignManager.current_act, phase_text]

func _refresh_debt() -> void:
	if debt_label == null:
		return
	# Acte 4 : la dette est derrière, le label affiche le titre de règne.
	if CampaignManager.current_act >= 4 and CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE:
		debt_label.text = "Reinado : %s" % CampaignManager.reign_title()
		debt_label.modulate = Color(1, 0.92, 0.55, 1)
		return
	var remaining: int = CampaignManager.debt_remaining()
	if remaining <= 0:
		debt_label.text = "Dette: soldée"
		debt_label.modulate = Color(0.55, 0.85, 0.55, 1)
	else:
		debt_label.text = "Dette: R$ %d" % remaining
		debt_label.modulate = Color(1, 1, 1, 1)

func _on_save_committed() -> void:
	_flash_toast("Sauvegardé")

func _on_save_loaded() -> void:
	_flash_toast("Partie chargée")
	# Re-seed : on ne veut pas toaster les MAIN déjà connues dans la save chargée.
	_signaled_main_ids.clear()
	_main_toast_seeded = false
	call_deferred("_seed_main_signaled")

# Marque comme "déjà connues" toutes les MAIN actuellement available/active/completed.
# Appelé en deferred pour laisser MainBoot._register_quests() finir.
func _seed_main_signaled() -> void:
	for q in QuestManager._quests.values():
		if not (q is Quest):
			continue
		var quest: Quest = q
		if quest.quest_type != Quest.QuestType.MAIN:
			continue
		if QuestManager.is_available(quest.id) or QuestManager.is_active(quest.id) or QuestManager.is_completed(quest.id):
			_signaled_main_ids[quest.id] = true
	_main_toast_seeded = true

func _on_quest_change_check_main(quest_id: String) -> void:
	# Jalons narratifs : à chaque MAIN complétée, un toast doré dit explicitement
	# le NPC suivant et son lieu. La trame est linéaire en acte 2+ donc il y a
	# toujours une suite claire. Pré-marquer les MAIN suivantes comme déjà
	# signalées empêche les "✦ Nouvelle quête" génériques d'écraser ce message.
	if _main_toast_seeded and MAIN_NEXT_HINT.has(quest_id):
		var hint: Dictionary = MAIN_NEXT_HINT[quest_id]
		for next_id in hint.get("hide_signals", []):
			_signaled_main_ids[next_id] = true
		_flash_toast(hint.text, Color(0.95, 0.8, 0.4, 1), 3.5)
	_check_new_main_available()

# Mapping quest_id (juste complétée) → toast jalon avec NPC + lieu de la suite.
# `hide_signals` = MAIN à pré-marquer comme déjà signalées pour empêcher les
# toasts "✦" génériques d'écraser le message clair de jalon.
const MAIN_NEXT_HINT: Dictionary = {
	"act1_heritage": {
		"text": "✓ Acompte payé — Rencontre Ramos (Bar do Policial) et Tito (Morro)",
		"hide_signals": ["act1_meet_ramos", "act1_meet_tito"],
	},
	"act1_meet_ramos": {
		"text": "✓ Ramos satisfait — Continue : Tito au cœur du Morro",
		"hide_signals": [],
	},
	"act1_meet_tito": {
		"text": "✓ Tito honoré — Continue : Capitão Ramos (Bar do Policial)",
		"hide_signals": [],
	},
	"act2_intro": {
		"text": "✓ Tio Zé démasqué — Va voir Ramos pour l'Operação Carnaval",
		"hide_signals": ["act2_ramos_operacao"],
	},
	"act2_ramos_operacao": {
		"text": "✓ Operação tranchée — Va voir le Padre à la chapelle",
		"hide_signals": ["act2_padre_orfanato"],
	},
	"act2_padre_orfanato": {
		"text": "✓ Orfanato sauvé — Monte au Morro voir Miguel",
		"hide_signals": ["act2_miguel_favela"],
	},
	"act2_miguel_favela": {
		"text": "✓ Convoi livré — Retourne au Copacabana Palace pour le pivot d'acte 3",
		"hide_signals": [],
	},
	"act3_policia_intel": {
		"text": "✓ Dossier monté — Retourne voir Ramos pour l'Operação Madrugada",
		"hide_signals": ["act3_policia_madrugada"],
	},
	"act3_trafico_pickup": {
		"text": "✓ Sac livré — Retourne voir Miguel pour la corrida",
		"hide_signals": ["act3_trafico_corrida"],
	},
	"act3_prefeito_endorsements": {
		"text": "✓ Coalition scellée — Retourne au Padre pour l'élection",
		"hide_signals": ["act3_prefeito_eleicao"],
	},
	"act3_policia_madrugada": {
		"text": "✓ Madrugada bouclée — La voie Polícia s'ouvre. Acte 4 : Purga",
		"hide_signals": ["act4_policia_purga"],
	},
	"act3_trafico_corrida": {
		"text": "✓ Corrida menée — La voie Tráfico s'ouvre. Acte 4 : Coleta do Patrão",
		"hide_signals": ["act4_trafico_tributo"],
	},
	"act3_prefeito_eleicao": {
		"text": "✓ Élection gagnée — La voie Prefeito s'ouvre. Acte 4 : Audiências",
		"hide_signals": ["act4_prefeito_audiencia"],
	},
	"act4_policia_purga": {
		"text": "✓ Purga consommée — Sambódromo : mène le Carnaval",
		"hide_signals": ["act4_carnaval_desfile"],
	},
	"act4_trafico_tributo": {
		"text": "✓ Tribut perçu — Sambódromo : mène le Carnaval",
		"hide_signals": ["act4_carnaval_desfile"],
	},
	"act4_prefeito_audiencia": {
		"text": "✓ Audiences données — Sambódromo : mène le Carnaval",
		"hide_signals": ["act4_carnaval_desfile"],
	},
}

# Toast doré pour chaque MAIN qui vient de devenir disponible (prereq satisfait
# ou bascule d'acte). N'agit qu'après le seed initial.
func _check_new_main_available() -> void:
	if not _main_toast_seeded:
		return
	for q in QuestManager._quests.values():
		if not (q is Quest):
			continue
		var quest: Quest = q
		if quest.quest_type != Quest.QuestType.MAIN:
			continue
		if _signaled_main_ids.has(quest.id):
			continue
		if QuestManager.is_available(quest.id):
			_signaled_main_ids[quest.id] = true
			_flash_toast("✦ Nouvelle quête : %s" % quest.display_name, Color(1.0, 0.9, 0.55, 1))

func _on_dynamic_mission_completed(category: int, money: int, rep: int) -> void:
	var label: String = DynamicMissionManager.CATEGORY_LABELS.get(category, "")
	_flash_toast("Mission %s : +R$ %d  ·  +%d %s" % [label, money, rep, label.to_upper()])

func _flash_toast(text: String, color: Color = Color(0.7, 0.95, 0.7, 1), duration: float = 1.2) -> void:
	if save_toast == null:
		return
	save_toast.text = text
	save_toast.visible = true
	save_toast.modulate = color
	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(save_toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): save_toast.visible = false)

# ─── Quest tracker (panel haut-droite) ───────────────────────────────────────
# Affiche la quête MAIN active prioritaire (sinon une SIDE) + son 1er objectif
# non complété. Caché si aucune quête active.

func _refresh_tracker_for(_quest_id: String) -> void:
	_refresh_tracker()

func _refresh_tracker_for_obj(_quest_id: String, _obj_id: String) -> void:
	_refresh_tracker()

func _refresh_tracker() -> void:
	if quest_tracker == null:
		return
	var quest: Quest = _pick_tracked_quest()
	if quest == null:
		quest_tracker.visible = false
		return
	quest_tracker.visible = true
	var prefix: String = "✦" if quest.quest_type == Quest.QuestType.MAIN else "•"
	if quest_tracker_name:
		quest_tracker_name.text = "%s %s" % [prefix, quest.display_name]
	var obj_desc: String = _first_pending_obj_desc(quest)
	if quest_tracker_objective:
		quest_tracker_objective.text = "→ %s" % obj_desc

# Préfère la MAIN active la plus récente ; à défaut, n'importe quelle active.
func _pick_tracked_quest() -> Quest:
	var active: Array[String] = QuestManager.get_active_ids()
	var fallback: Quest = null
	# Itère en ordre inverse pour prioriser la plus récente
	for i in range(active.size() - 1, -1, -1):
		var q: Quest = QuestManager.get_quest(active[i])
		if q == null:
			continue
		if q.quest_type == Quest.QuestType.MAIN:
			return q
		if fallback == null:
			fallback = q
	return fallback

func _first_pending_obj_desc(quest: Quest) -> String:
	var state: Dictionary = QuestManager.get_objectives_state(quest.id)
	for obj in quest.objectives:
		if not bool(state.get(obj.id, false)):
			return obj.description
	return "Retourner voir le contact"
