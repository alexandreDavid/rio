extends Control

# Paths à maintenir synchronisés avec scenes/ui/DialogueUI.tscn.
@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: RichTextLabel = $Panel/Text
@onready var choices_container: VBoxContainer = $Panel/Choices
@onready var panel: Panel = $Panel
@onready var next_indicator: Label = $Panel/NextIndicator

var _indicator_tween: Tween = null

# Lisible sur iPhone : le canevas fait 1080 px de haut, un px logique y vaut
# ~0,36 pt en paysage — 30 px ≈ 11 pt, le plancher de lecture d'Apple.
const TEXT_SIZE: int = 30
const SPEAKER_SIZE: int = 26
const CHOICE_SIZE: int = 28
const CHOICE_H: int = 68          # plancher ; relevé à la taille d'un doigt (44 pt)
const TEXT_BLOCK_H: float = 190.0  # nom + 3 lignes de réplique
const PANEL_TOP_DEFAULT: float = 0.42
const CHOICE_GAP: int = 8
# Didascalies (*il pose sa louche*) : en italique atténué, pour qu'on
# distingue d'un coup d'œil le geste de la parole.
const STAGE_COLOR: String = "#c9bc96"
var _stage_re: RegEx = RegEx.create_from_string("\\*([^*]+)\\*")

func _ready() -> void:
	add_to_group("gamepad_menu")
	SafeArea.apply(self)
	DialogueBridge.line_shown.connect(_on_line_shown)
	DialogueBridge.choices_presented.connect(_on_choices_presented)
	DialogueBridge.dialogue_finished.connect(_on_dialogue_finished)
	if speaker_label:
		speaker_label.add_theme_font_size_override("font_size", SPEAKER_SIZE)
	if text_label:
		for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			text_label.add_theme_font_size_override(key, TEXT_SIZE)
	if choices_container:
		choices_container.add_theme_constant_override("separation", CHOICE_GAP)
	if panel:
		# Tap dans la zone libre du panel → avance le dialogue si une seule
		# option (knot purement informatif). Les zones de Button restent
		# autonomes et bloquent l'événement.
		panel.gui_input.connect(_on_panel_gui_input)
	hide()

# Garde-fou anti soft-lock : si un dialogue est marqué actif mais que cette UI
# n'affiche rien depuis > STUCK_TIMEOUT (cas d'un dialogue démarré sans pouvoir
# s'afficher — ex. déclenché hors gameplay), on le ferme pour rendre la main au
# joueur plutôt que de le laisser figé.
const STUCK_TIMEOUT: float = 2.0
var _stuck_timer: float = 0.0

func _process(delta: float) -> void:
	if DialogueBridge.is_active() and not visible:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIMEOUT:
			push_warning("[DialogueUI] dialogue actif mais non affiché > %ss — récupération (déblocage joueur)" % STUCK_TIMEOUT)
			DialogueBridge.end_dialogue()
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		print("[DialogueUI] _unhandled_input key=%d physical=%d label=%d" % [event.keycode, event.physical_keycode, event.key_label])
		var keycode: int = event.physical_keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			var index: int = keycode - KEY_1
			if choices_container and index < choices_container.get_child_count():
				print("[DialogueUI] shortcut %d triggered choose(%d)" % [keycode - KEY_0, index])
				DialogueBridge.choose(index)
				accept_event()

func _on_line_shown(speaker: String, text: String) -> void:
	print("[DialogueUI] _on_line_shown speaker=%s text=%s" % [speaker, text])
	show()
	if speaker_label:
		speaker_label.text = speaker
	if text_label:
		text_label.text = format_line(text)
		text_label.scroll_to_line(0)
	_clear_choices()

func _on_choices_presented(choices: Array) -> void:
	print("[DialogueUI] _on_choices_presented — %d choix" % choices.size())
	_clear_choices()
	if choices_container == null:
		return
	for i in choices.size():
		var btn: Button = Button.new()
		btn.text = str(choices[i])
		btn.custom_minimum_size = Vector2(0, _choice_h())
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", CHOICE_SIZE)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)
	# Focus le premier bouton pour Enter/flèches au clavier.
	if choices_container.get_child_count() > 0:
		var first: Button = choices_container.get_child(0) as Button
		if first:
			first.grab_focus()
	# Indicateur « tap pour avancer » : visible uniquement quand 1 seul choix.
	_set_next_indicator(choices.size() == 1)
	_layout_for(choices.size())

# La zone de choix épouse le nombre de boutons : le texte récupère la place
# (avant : 300 px réservés même pour un seul « Continuer »).
func _layout_for(n: int) -> void:
	var h: float = float(n) * _choice_h() + float(maxi(n - 1, 0) * CHOICE_GAP)
	# Beaucoup de choix : le panneau monte pour que chacun garde sa hauteur de
	# doigt ET que la réplique reste lisible.
	if panel:
		var need: float = TEXT_BLOCK_H + h + 44.0
		var top: float = panel.anchor_bottom - need / maxf(size.y, 1.0)
		panel.anchor_top = clampf(top, 0.04, PANEL_TOP_DEFAULT)
	if choices_container:
		choices_container.offset_top = -(h + 16.0)
	if text_label:
		text_label.offset_bottom = -(h + 28.0)

func _choice_h() -> float:
	return maxf(float(CHOICE_H), ceilf(UIFit.touch_min_px(get_viewport())))

# Échappe le BBCode du texte brut puis met les didascalies en italique atténué.
func format_line(text: String) -> String:
	var safe: String = text.replace("[", "[lb]")
	return _stage_re.sub(safe, "[i][color=%s]$1[/color][/i]" % STAGE_COLOR, true)

func _on_choice_pressed(index: int) -> void:
	print("[DialogueUI] _on_choice_pressed(%d) — button clicked" % index)
	DialogueBridge.choose(index)

func _on_dialogue_finished() -> void:
	_clear_choices()
	_set_next_indicator(false)
	hide()

func _clear_choices() -> void:
	if choices_container == null:
		return
	for child in choices_container.get_children():
		child.queue_free()

func _on_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# Tap-to-advance : déclenche choix 0 uniquement quand il n'y a qu'une
	# option (knot informatif, type bavardage). Les knots à choix multiples
	# exigent une décision explicite sur un bouton.
	if choices_container and choices_container.get_child_count() == 1:
		DialogueBridge.choose(0)
		panel.accept_event()

func _set_next_indicator(active: bool) -> void:
	if next_indicator == null:
		return
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	next_indicator.visible = active
	if not active:
		return
	# Pulse alpha 1.0 ↔ 0.35 en boucle.
	next_indicator.modulate.a = 1.0
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(next_indicator, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_indicator_tween.tween_property(next_indicator, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
