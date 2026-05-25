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
var _phone_badge: Label = null
# Pour le flash `+R$ X` à chaque gain : on garde la dernière valeur vue pour
# calculer le delta. L'init évite un faux flash au chargement de partie.
var _last_money_shown: int = 0
var _money_init_done: bool = false
@onready var journal_button: Button = $JournalButton
@onready var save_button: Button = $SaveButton
@onready var photo_button: Button = $PhotoButton
@onready var close_sheet_button: Button = $CharacterSheet/Margin/Layout/Close
@onready var toast_stack: VBoxContainer = $ToastStack
const MAX_TOASTS: int = 4
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
	AchievementSystem.achievement_unlocked.connect(_on_achievement_unlocked)
	# Badge cumulé du bouton 📱 : se rafraîchit quand un événement peut
	# changer un compteur (quête, achievement, fin de dialogue qui peut
	# ajouter un knot Crônica).
	EventBus.quest_accepted.connect(func(_q): _refresh_phone_badge())
	EventBus.quest_completed.connect(func(_q): _refresh_phone_badge())
	EventBus.dialogue_ended.connect(func(_n): _refresh_phone_badge())
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
		_setup_phone_badge()
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
	# Le joueur a ouvert le phone : il va voir les badges individuels, on
	# peut cacher le dot rouge du bouton.
	call_deferred("_refresh_phone_badge")

func _setup_phone_badge() -> void:
	if menu_button == null:
		return
	_phone_badge = Label.new()
	_phone_badge.name = "Badge"
	_phone_badge.text = "●"
	_phone_badge.add_theme_font_size_override("font_size", 18)
	_phone_badge.add_theme_color_override("font_color", Color(0.95, 0.2, 0.18, 1))
	_phone_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_phone_badge.add_theme_constant_override("outline_size", 4)
	_phone_badge.anchor_left = 1.0
	_phone_badge.anchor_right = 1.0
	_phone_badge.offset_left = -22.0
	_phone_badge.offset_top = 0.0
	_phone_badge.offset_right = -4.0
	_phone_badge.offset_bottom = 22.0
	_phone_badge.visible = false
	menu_button.add_child(_phone_badge)
	_refresh_phone_badge()

func _refresh_phone_badge() -> void:
	if _phone_badge == null:
		return
	# Si le téléphone est ouvert, pas de badge (les badges in-app prennent le relais).
	var phone: Node = get_tree().current_scene.get_node_or_null("Phone")
	if phone and "visible" in phone and phone.visible:
		_phone_badge.visible = false
		return
	var total: int = 0
	total += max(0, NarrativeJournal.unlocked_count() - Settings.last_seen_cronica)
	total += max(0, AchievementSystem.count_unlocked() - Settings.last_seen_conquistas)
	# Photos : count via DirAccess pour éviter d'instancier Phone.
	if DirAccess.dir_exists_absolute("user://photos"):
		var n: int = 0
		for f in DirAccess.get_files_at("user://photos"):
			if f.to_lower().ends_with(".png"):
				n += 1
		total += max(0, n - Settings.last_seen_photos)
	_phone_badge.visible = total > 0

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
		AchievementSystem.notify_first_photo()
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
	# Flash visible à chaque gain (positif uniquement, et > 0 R$ après init).
	# Évite qu'un gain de quête/achievement/district paraisse `tomber du ciel` —
	# le joueur voit toujours le delta qui s'affiche au-dessus du compteur.
	var delta: int = amount - _last_money_shown
	_last_money_shown = amount
	if not _money_init_done:
		_money_init_done = true
		return
	if delta > 0:
		_flash_money_delta(delta)

func _flash_money_delta(delta: int) -> void:
	if money_label == null:
		return
	var lbl: Label = Label.new()
	lbl.text = "+R$ %d" % delta
	lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(0, 24)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label.add_child(lbl)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", 44.0, 1.1)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tween.chain().tween_callback(lbl.queue_free)

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
	_flash_toast("Partie chargée", Color(0.7, 0.95, 0.7, 1), 1.0)
	# Message de bienvenue contextualisé après une courte pause, pour laisser
	# le toast principal partir d'abord. Donne au joueur de quoi se replanter
	# narrativement à la reprise.
	call_deferred("_welcome_back_after_load")
	# Re-seed : on ne veut pas toaster les MAIN déjà connues dans la save chargée.
	_signaled_main_ids.clear()
	_main_toast_seeded = false
	call_deferred("_seed_main_signaled")

func _welcome_back_after_load() -> void:
	await get_tree().create_timer(1.4).timeout
	var act: int = CampaignManager.current_act
	var day: int = TimeOfDay.day_count
	var debt: int = CampaignManager.debt_remaining()
	var endgame: int = CampaignManager.chosen_endgame
	var lines: Array[String] = ["Bem-vindo de volta · Jour %d · Acte %d" % [day, act]]
	if act >= 4 and endgame != CampaignManager.Endgame.NONE:
		lines.append("Reinado : %s" % CampaignManager.reign_title())
	elif debt > 0:
		lines.append("Dette restante : R$ %d" % debt)
	else:
		lines.append("Dette soldée")
	_flash_toast("\n".join(lines), Color(0.95, 0.88, 0.55, 1), 3.5)

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
	"prologue_pedrinho": {
		"text": "✓ Pedrinho est rentré — Le morro est libre. Va voir Seu João pour ta dette",
		"hide_signals": ["act1_heritage"],
	},
	"trafico_a1_livraison": {
		"text": "✓ Paquet livré — Reparle au contact du calçadão (Copacabana)",
		"hide_signals": ["trafico_a2_pickup"],
	},
	"trafico_a2_pickup": {
		"text": "✓ Sacoche récupérée — Le contact a un coffre à conduire",
		"hide_signals": ["trafico_a3_chauffeur"],
	},
	"trafico_a3_chauffeur": {
		"text": "✓ Coffre livré à Botafogo — Le morro parle de toi. Retourne voir le contact (Copa)",
		"hide_signals": ["trafico_a4_ipanema"],
	},
	"trafico_a4_ipanema": {
		"text": "✓ Deal conclu à Ipanema — Un voisin t'a vu. Remonte au morro le faire taire",
		"hide_signals": ["trafico_a5_intim"],
	},
	"trafico_a5_intim": {
		"text": "✓ Le voisin s'est tu — Prends le SUP à Ipanema, l'îlot t'attend au large",
		"hide_signals": ["trafico_a6_cagarras"],
	},
	"trafico_a6_cagarras": {
		"text": "✓ Chargement réceptionné — Un vieux du Palace veut te voir (Copa)",
		"hide_signals": ["trafico_a7_tioze"],
	},
	"trafico_a7_tioze": {
		"text": "✓ Tu as entendu le concierge — La grosse livraison t'attend (Niterói)",
		"hide_signals": ["trafico_a8_baia"],
	},
	"trafico_a8_baia": {
		"text": "✓ Baie traversée, dette presque soldée — Tito t'attend au morro pour la corrida",
		"hide_signals": ["trafico_a9_corrida"],
	},
	"trafico_a9_corrida": {
		"text": "✓ Última corrida menée — Le Morro est à toi. Tu es le Patrão.",
		"hide_signals": [],
	},
	"policia_b1_intel": {
		"text": "✓ Visage rapporté — Reparle à l'agent en civil (calçadão, Copa)",
		"hide_signals": ["policia_b2_filature"],
	},
	"policia_b2_filature": {
		"text": "✓ Réseau cartographié — Conduis la patrouille à Botafogo",
		"hide_signals": ["policia_b3_escorte"],
	},
	"policia_b3_escorte": {
		"text": "✓ Patrouille en place — Descente sur le dealer à Arpoador (Zona Sul)",
		"hide_signals": ["policia_b4_descente"],
	},
	"policia_b4_descente": {
		"text": "✓ Dealer coffré — Monte au Corcovado pour le repérage",
		"hide_signals": ["policia_b5_reperage"],
	},
	"policia_b5_reperage": {
		"text": "✓ Remise repérée — Un vieux du Palace veut te voir (Copa)",
		"hide_signals": ["policia_b6_tioze"],
	},
	"policia_b6_tioze": {
		"text": "✓ Tu as entendu le concierge — Saisie à Niterói",
		"hide_signals": ["policia_b7_saisie"],
	},
	"policia_b7_saisie": {
		"text": "✓ Cargaison saisie — « Sécurise » la foule au Maracanã",
		"hide_signals": ["policia_b8_seguranca"],
	},
	"policia_b8_seguranca": {
		"text": "✓ Foule matée, dette presque soldée — Retrouve Ramos pour la Madrugada",
		"hide_signals": ["policia_b9_madrugada"],
	},
	"policia_b9_madrugada": {
		"text": "✓ Operação Madrugada — Tu es Chefe de Polícia honoraire.",
		"hide_signals": [],
	},
	"consortium_c1_recouvrement": {
		"text": "✓ Recouvrement effectué — Va voir Magalhães à Barra (tournée des loyers)",
		"hide_signals": ["consortium_c2_loyers"],
	},
	"consortium_c2_loyers": {
		"text": "✓ Loyers encaissés — Le syndic a un « partenariat » à Ipanema (Zona Sul)",
		"hide_signals": ["consortium_c3_partenariat"],
	},
	"consortium_c3_partenariat": {
		"text": "✓ Partenariat signé — Un VIP arrive à Santos Dumont",
		"hide_signals": ["consortium_c4_vip"],
	},
	"consortium_c4_vip": {
		"text": "✓ VIP reçu — Donation à blanchir au MAC (Niterói)",
		"hide_signals": ["consortium_c5_mac"],
	},
	"consortium_c5_mac": {
		"text": "✓ Donation blanchie — Un vieux du Palace veut te voir (Copa)",
		"hide_signals": ["consortium_c6_tioze"],
	},
	"consortium_c6_tioze": {
		"text": "✓ Tu as entendu le concierge — Aligne les trois condomínios (Barra)",
		"hide_signals": ["consortium_c7_condos"],
	},
	"consortium_c7_condos": {
		"text": "✓ Trois condos alignés, dette presque soldée — Le dernier libre du calçadão (Copa)",
		"hide_signals": ["consortium_c8_menace"],
	},
	"consortium_c8_menace": {
		"text": "✓ Le dernier a signé — Magalhães t'attend au Riserva Uno pour le Pacto",
		"hide_signals": ["consortium_c9_pacto"],
	},
	"consortium_c9_pacto": {
		"text": "✓ Pacto da Barra signé — Tu es la maison. Sócio do Consórcio.",
		"hide_signals": [],
	},
	"prefeito_d1_peticao": {
		"text": "✓ Pétition signée — Organise le tournoi de basket à l'Aterro",
		"hide_signals": ["prefeito_d2_basquete"],
	},
	"prefeito_d2_basquete": {
		"text": "✓ Tournoi réussi — Médiation à régler dans la favela",
		"hide_signals": ["prefeito_d3_mediation"],
	},
	"prefeito_d3_mediation": {
		"text": "✓ Conflit désamorcé — Protège la procession en Zona Sul",
		"hide_signals": ["prefeito_d4_procession"],
	},
	"prefeito_d4_procession": {
		"text": "✓ Procession protégée — Mène le meeting au Maracanã",
		"hide_signals": ["prefeito_d5_rally"],
	},
	"prefeito_d5_rally": {
		"text": "✓ Meeting enflammé — Inauguration au MAC de Niterói",
		"hide_signals": ["prefeito_d6_mac"],
	},
	"prefeito_d6_mac": {
		"text": "✓ Expo inaugurée — Un vieux du Palace veut te remettre quelque chose (Copa)",
		"hide_signals": ["prefeito_d7_tioze"],
	},
	"prefeito_d7_tioze": {
		"text": "✓ Dossier en main — Retourne le calçadão avec la preuve (Copa)",
		"hide_signals": ["prefeito_d8_campagne"],
	},
	"prefeito_d8_campagne": {
		"text": "✓ Le calçadão a basculé, dette effacée par la vérité — Le Padre t'attend pour l'élection",
		"hide_signals": ["prefeito_d9_eleicao"],
	},
	"prefeito_d9_eleicao": {
		"text": "✓ Élection gagnée — Tu es le Coronel do Bairro.",
		"hide_signals": [],
	},
	"act1_heritage": {
		"text": "✓ Acompte payé — Choisis ton camp : Tito (Morro), Ramos (Bar do Policial), Magalhães (Barra) ou le Padre (chapelle)",
		"hide_signals": [],
	},
	"consortium_peninsula": {
		"text": "✦ Chaîne consortium scellée — Magalhães te rappelle au Riserva Uno (Barra)",
		"hide_signals": ["pacto_barra"],
	},
	"pacto_barra": {
		"text": "✓ Pacto da Barra signé — endossement politique en poche",
		"hide_signals": [],
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

func _on_achievement_unlocked(_id: String, data: Dictionary) -> void:
	var icon: String = data.get("icon", "🏆")
	var title: String = data.get("title", "Conquista")
	var reward: int = int(data.get("reward", 0))
	var text: String = "%s %s" % [icon, title]
	if reward > 0:
		text += "  +R$ %d" % reward
	_flash_toast(text, Color(0.95, 0.85, 0.4, 1), 3.0)
	_refresh_phone_badge()

func _on_dynamic_mission_completed(category: int, money: int, rep: int) -> void:
	var label: String = DynamicMissionManager.CATEGORY_LABELS.get(category, "")
	_flash_toast("Mission %s : +R$ %d  ·  +%d %s" % [label, money, rep, label.to_upper()])

func _flash_toast(text: String, color: Color = Color(0.7, 0.95, 0.7, 1), duration: float = 1.2) -> void:
	if toast_stack == null:
		return
	# Limite la pile : si on a déjà MAX_TOASTS, supprime le plus ancien.
	while toast_stack.get_child_count() >= MAX_TOASTS:
		var oldest: Node = toast_stack.get_child(0)
		oldest.queue_free()
		await get_tree().process_frame
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	toast_stack.add_child(label)
	# Anim d'entrée : scale 0.85 → 1.0 avec léger overshoot.
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.85, 0.85)
	var entrance: Tween = create_tween()
	entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(label, "scale", Vector2.ONE, 0.22)
	# Fade-out + queue_free.
	var fade: Tween = create_tween()
	fade.tween_interval(duration)
	fade.tween_property(label, "modulate:a", 0.0, 0.4)
	fade.tween_callback(func(): if is_instance_valid(label): label.queue_free())

# ─── Quest tracker (panel haut-droite) ───────────────────────────────────────
# Affiche la quête MAIN active prioritaire (sinon une SIDE) + son 1er objectif
# non complété. Caché si aucune quête active.

func _refresh_tracker_for(_quest_id: String) -> void:
	_refresh_tracker()

func _refresh_tracker_for_obj(_quest_id: String, _obj_id: String) -> void:
	_refresh_tracker()

var _tracker_last_text: String = ""

func _refresh_tracker() -> void:
	if quest_tracker == null:
		return
	var quest: Quest = _pick_tracked_quest()
	if quest == null:
		quest_tracker.visible = false
		_tracker_last_text = ""
		return
	var prefix: String = "✦" if quest.quest_type == Quest.QuestType.MAIN else "•"
	var name_text: String = "%s %s" % [prefix, quest.display_name]
	var obj_desc: String = _first_pending_obj_desc(quest)
	if quest_tracker_name:
		quest_tracker_name.text = name_text
	if quest_tracker_objective:
		quest_tracker_objective.text = "→ %s" % obj_desc
	# Anim subtile uniquement quand le contenu change réellement.
	var combined: String = name_text + " / " + obj_desc
	var was_invisible: bool = not quest_tracker.visible
	quest_tracker.visible = true
	if combined != _tracker_last_text or was_invisible:
		_tracker_last_text = combined
		_play_tracker_punch()

func _play_tracker_punch() -> void:
	if quest_tracker == null:
		return
	quest_tracker.pivot_offset = quest_tracker.size / 2.0
	quest_tracker.scale = Vector2(0.92, 0.92)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(quest_tracker, "scale", Vector2.ONE, 0.22)

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
