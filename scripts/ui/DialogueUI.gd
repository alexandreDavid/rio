extends Control

# Paths à maintenir synchronisés avec scenes/ui/DialogueUI.tscn.
@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: RichTextLabel = $Panel/Text
@onready var choices_container: VBoxContainer = $Panel/Choices

func _ready() -> void:
	DialogueBridge.line_shown.connect(_on_line_shown)
	DialogueBridge.choices_presented.connect(_on_choices_presented)
	DialogueBridge.dialogue_finished.connect(_on_dialogue_finished)
	hide()

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
		text_label.text = text
	_clear_choices()

func _on_choices_presented(choices: Array) -> void:
	print("[DialogueUI] _on_choices_presented — %d choix" % choices.size())
	_clear_choices()
	if choices_container == null:
		return
	for i in choices.size():
		var btn: Button = Button.new()
		btn.text = str(choices[i])
		btn.custom_minimum_size = Vector2(0, 64)
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)
	# Focus le premier bouton pour Enter/flèches au clavier.
	if choices_container.get_child_count() > 0:
		var first: Button = choices_container.get_child(0) as Button
		if first:
			first.grab_focus()

func _on_choice_pressed(index: int) -> void:
	print("[DialogueUI] _on_choice_pressed(%d) — button clicked" % index)
	DialogueBridge.choose(index)

func _on_dialogue_finished() -> void:
	_clear_choices()
	hide()

func _clear_choices() -> void:
	if choices_container == null:
		return
	for child in choices_container.get_children():
		child.queue_free()
