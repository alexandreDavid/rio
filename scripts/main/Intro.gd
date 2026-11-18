extends Control

# Écran d'ouverture style « Mario » : 3 slots toujours visibles + bouton reset
# par slot. Le narratif d'ouverture (« Ce matin, tu te réveilles... ») ne vit
# plus ici — il est joué EN JEU par MainBoot avec le décor en fond.
# Tap slot → charge la save si présente, sinon démarre une nouvelle partie.
# Tap reset → confirmation au 2ᵉ tap (état stocké dans `_reset_pending`).

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"

@onready var slot_buttons: Array[Button] = [$Panel/Layout/Slot1Row/Slot1, $Panel/Layout/Slot2Row/Slot2, $Panel/Layout/Slot3Row/Slot3]
@onready var reset_buttons: Array[Button] = [$Panel/Layout/Slot1Row/Slot1Reset, $Panel/Layout/Slot2Row/Slot2Reset, $Panel/Layout/Slot3Row/Slot3Reset]
@onready var reset_hint: Label = $Panel/Layout/ResetHint
@onready var title_block: Control = $TitleBlock
@onready var panel: Control = $Panel

var _reset_pending: int = 0  # 1..3 = slot en attente de confirmation, 0 = aucun

func _ready() -> void:
	UITheme.apply(get_tree().root)
	add_to_group("gamepad_menu")
	for i in 3:
		var slot: int = i + 1
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(slot))
		reset_buttons[i].pressed.connect(_on_reset_pressed.bind(slot))
	_style_title()
	_add_arcade_button()
	_refresh()
	slot_buttons[clampi(Settings.current_slot - 1, 0, 2)].grab_focus()
	_play_entrance()

# Builds de debug seulement (dont l'export iOS de test) : accès direct aux
# mini-jeux, pour les essayer sur téléphone sans jouer jusqu'à leur lieu.
func _add_arcade_button() -> void:
	if not OS.is_debug_build():
		return
	var b: Button = Button.new()
	b.text = "🎮 Mini-jeux (test)"
	b.theme_type_variation = &"TouchButton"
	b.add_theme_font_size_override("font_size", 33)
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(24, 24)
	b.size = Vector2(420, 120)
	b.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://tools/MinigamePicker.tscn"))
	add_child(b)
	SafeArea.apply(b)

# Titre en police pixel, agrandi par multiples entiers (net sur tout écran).
func _style_title() -> void:
	var big: FontFile = PixelFont.font(3, true)
	var title: Label = $TitleBlock/Title
	title.add_theme_font_override("font", big)
	title.add_theme_font_size_override("font_size", big.fixed_size * 4)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sub: Label = $TitleBlock/Subtitle
	sub.add_theme_font_override("font", big)
	sub.add_theme_font_size_override("font_size", big.fixed_size * 2)
	sub.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	sub.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Le titre descend, le panneau monte : l'écran respire avant qu'on choisisse.
func _play_entrance() -> void:
	title_block.modulate.a = 0.0
	panel.modulate.a = 0.0
	var title_y: float = title_block.position.y
	var panel_y: float = panel.position.y
	title_block.position.y = title_y - 40.0
	panel.position.y = panel_y + 60.0
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_block, "modulate:a", 1.0, 0.8)
	tw.tween_property(title_block, "position:y", title_y, 0.9)
	tw.tween_property(panel, "modulate:a", 1.0, 0.6).set_delay(0.5)
	tw.tween_property(panel, "position:y", panel_y, 0.7).set_delay(0.5)

func _refresh() -> void:
	for i in 3:
		var slot: int = i + 1
		var info: Dictionary = SaveSystem.slot_info(slot)
		var current: bool = slot == Settings.current_slot
		var prefix: String = "📍 " if current else "  "
		var text: String
		if info.is_empty():
			text = "%s✨ Nouvelle partie" % prefix
		else:
			var act: int = int(info.get("act", 1))
			var day: int = int(info.get("day", 1))
			var debt: int = int(info.get("debt_paid", 0))
			var endgame: int = int(info.get("endgame", 0))
			var path_str: String = ""
			if voie_label(endgame) != "":
				path_str = "  ·  " + voie_label(endgame)
			text = "%sJour %d  ·  Acte %d%s  ·  R$ %d payés" % [
					prefix, day, act, path_str, debt]
		slot_buttons[i].text = text
		reset_buttons[i].disabled = info.is_empty()
		# Icône reset : 🗑 par défaut, ⚠ Confirmer si en attente.
		if _reset_pending == slot:
			reset_buttons[i].text = "⚠"
			reset_buttons[i].modulate = Color(1, 0.7, 0.7)
		else:
			reset_buttons[i].text = "🗑"
			reset_buttons[i].modulate = Color(1, 1, 1)
	reset_hint.visible = _reset_pending != 0

# Indexé par l'enum Endgame (NONE, PREFEITO, POLICIA, TRAFICO, CONSORTIUM) —
# l'ancien tableau positionnel décalait toutes les voies d'un cran.
static func voie_label(endgame: int) -> String:
	match endgame:
		CampaignManager.Endgame.PREFEITO: return "Prefeito"
		CampaignManager.Endgame.POLICIA: return "Polícia"
		CampaignManager.Endgame.TRAFICO: return "Tráfico"
		CampaignManager.Endgame.CONSORTIUM: return "Consórcio"
	return ""

func _on_slot_pressed(slot: int) -> void:
	# Tap sur un slot annule un éventuel reset en cours sur un autre.
	_reset_pending = 0
	Settings.set_current_slot(slot)
	if not SaveSystem.has_save_at(slot):
		# Slot vide → nouvelle partie propre (pas de save à charger).
		SaveSystem.discard_save()
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_reset_pressed(slot: int) -> void:
	if _reset_pending == slot:
		# 2ᵉ tap → on supprime pour de bon.
		SaveSystem.discard_save_at(slot)
		_reset_pending = 0
	else:
		# 1er tap → on arme la confirmation.
		_reset_pending = slot
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_reset_pending = 0
			_refresh()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			_on_slot_pressed(Settings.current_slot)
			get_viewport().set_input_as_handled()
