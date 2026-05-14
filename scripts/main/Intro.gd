extends Control

# Scène d'introduction : texte narratif + rappel des contrôles.
# Espace/Entrée (ou tap sur le bouton) pour avancer ; à la fin, bascule sur Main.tscn.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"

const STORY_PAGES: Array[String] = [
	"Rio de Janeiro. Copacabana. Un matin comme les autres, sauf que Zé — ton oncle, ton parrain, ton problème — a disparu.\n\nIl t'a laissé trois choses : sa carrocinha de milho, les clefs d'un studio au Morro, et une dette de cinquante mille reais.\n\nLe Carnaval est dans un mois. Tu ferais mieux d'avoir réglé la note d'ici là.",
	"À toi de choisir comment t'en sortir.\n\nDeviens un pilier de la communauté. Entre dans la police. Ou prends la rue.\n\nSelon les gens que tu aides, les gens que tu trahis, et la tête que tu gardes quand tout dérape, tu finiras Prefeito, Chefe de Polícia, ou Rei do Tráfico.",
	"Contrôles :\n\n• Joystick en bas à gauche — se déplacer\n• Bouton E en bas à droite — interagir (parler, prendre, acheter…)\n• Bouton ☰ en haut à droite — voir tes caractéristiques\n\nLes dialogues ont souvent plusieurs choix. Chaque choix modifie tes stats (Respect, Voyou, Police, Touristes, Charisma).\n\nBonne chance, parceiro.",
]

@onready var title_label: Label = $Layout/Title
@onready var body_label: RichTextLabel = $Layout/Body
@onready var continue_button: Button = $Layout/Continue
@onready var load_button: Button = $Layout/LoadSave
@onready var newgame_button: Button = $Layout/NewGame
@onready var slot_picker_button: Button = $Layout/SlotPicker
@onready var slots_panel: PanelContainer = $SlotsPanel
@onready var slot_btn_1: Button = $SlotsPanel/Margin/VBox/Slot1
@onready var slot_btn_2: Button = $SlotsPanel/Margin/VBox/Slot2
@onready var slot_btn_3: Button = $SlotsPanel/Margin/VBox/Slot3
@onready var slots_close: Button = $SlotsPanel/Margin/VBox/SlotsClose

var _page: int = 0

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_advance)
	if load_button:
		load_button.pressed.connect(_goto_main)
	if newgame_button:
		newgame_button.pressed.connect(_start_new_game)
	if slot_picker_button:
		slot_picker_button.pressed.connect(_open_slots)
	if slots_close:
		slots_close.pressed.connect(_close_slots)
	if slot_btn_1:
		slot_btn_1.pressed.connect(func(): _on_slot_selected(1))
	if slot_btn_2:
		slot_btn_2.pressed.connect(func(): _on_slot_selected(2))
	if slot_btn_3:
		slot_btn_3.pressed.connect(func(): _on_slot_selected(3))
	_render()

func _open_slots() -> void:
	_refresh_slot_buttons()
	if slots_panel:
		slots_panel.visible = true

func _close_slots() -> void:
	if slots_panel:
		slots_panel.visible = false

func _refresh_slot_buttons() -> void:
	var buttons: Array = [slot_btn_1, slot_btn_2, slot_btn_3]
	var path_labels: Array[String] = ["Polícia", "Tráfico", "Prefeito"]
	for i in 3:
		var slot: int = i + 1
		var btn: Button = buttons[i]
		if btn == null:
			continue
		var info: Dictionary = SaveSystem.slot_info(slot)
		var prefix: String = "📍 " if slot == Settings.current_slot else "   "
		if info.is_empty():
			btn.text = "%sSlot %d — vide  ·  Démarrer une partie" % [prefix, slot]
		else:
			var act: int = info.get("act", 1)
			var day: int = info.get("day", 1)
			var debt: int = info.get("debt_paid", 0)
			var endgame: int = info.get("endgame", 0)
			var endgame_str: String = ""
			if endgame >= 1 and endgame <= 3:
				endgame_str = "  ·  " + path_labels[endgame - 1]
			btn.text = "%sSlot %d  ·  Jour %d  ·  Acte %d%s  ·  R$ %d payés" % [
					prefix, slot, day, act, endgame_str, debt]

func _on_slot_selected(slot: int) -> void:
	Settings.set_current_slot(slot)
	_close_slots()
	_render()

func _start_new_game() -> void:
	SaveSystem.discard_save()
	get_tree().change_scene_to_file(MAIN_SCENE)

func _goto_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	# Raccourcis clavier secondaires (desktop) — sur mobile, on passe par le bouton.
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE:
			get_tree().change_scene_to_file(MAIN_SCENE)
			get_viewport().set_input_as_handled()

func _advance() -> void:
	_page += 1
	if _page >= STORY_PAGES.size():
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	_render()

func _render() -> void:
	if body_label:
		body_label.text = STORY_PAGES[_page]
	if title_label:
		title_label.visible = _page == 0
	if continue_button:
		if _page == STORY_PAGES.size() - 1:
			continue_button.text = "Commencer"
		else:
			continue_button.text = "Continuer"
	# Les boutons « Charger », « Nouvelle partie » et « Slots » ne sont
	# visibles que sur la 1ère page, pour éviter le bruit visuel sur les
	# pages narratives. Le label « Charger » indique le slot courant.
	var has_save: bool = SaveSystem.has_save()
	if load_button:
		load_button.visible = _page == 0 and has_save
		load_button.text = "Charger Slot %d" % Settings.current_slot
	if newgame_button:
		newgame_button.visible = _page == 0 and has_save
		newgame_button.text = "Nouvelle partie (efface Slot %d)" % Settings.current_slot
	if slot_picker_button:
		slot_picker_button.visible = _page == 0
