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
@onready var close_sheet_button: Button = $CharacterSheet/Margin/Layout/Close
@onready var save_toast: Label = $SaveToast

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
	SaveSystem.save_committed.connect(_on_save_committed)
	SaveSystem.save_loaded.connect(_on_save_loaded)
	DynamicMissionManager.mission_completed.connect(_on_dynamic_mission_completed)
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
	_init_abilities()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	# P : ouvre / ferme le téléphone (bouton 📱 du HUD).
	# C : raccourci historique vers la fiche perso → ouvre maintenant l'app Saúde du téléphone.
	if key == KEY_P or key == KEY_C:
		_toggle_phone()
		get_viewport().set_input_as_handled()

func _toggle_phone() -> void:
	var phone: Node = get_tree().current_scene.get_node_or_null("Phone")
	if phone and phone.has_method("toggle"):
		phone.toggle()

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

func _on_dynamic_mission_completed(category: int, money: int, rep: int) -> void:
	var label: String = DynamicMissionManager.CATEGORY_LABELS.get(category, "")
	_flash_toast("Mission %s : +R$ %d  ·  +%d %s" % [label, money, rep, label.to_upper()])

func _flash_toast(text: String) -> void:
	if save_toast == null:
		return
	save_toast.text = text
	save_toast.visible = true
	save_toast.modulate = Color(0.7, 0.95, 0.7, 1)
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(save_toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): save_toast.visible = false)
