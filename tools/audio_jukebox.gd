extends SceneTree

# Juke-box d'écoute : un bouton par musique, ambiance et SFX câblés dans
# AudioManager. Musiques et ambiances bouclent (re-cliquer = stop).
#   godot --path . -s tools/audio_jukebox.gd

var _loop: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _now: Label
var _current: String = ""


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var am: Node = root.get_node_or_null("AudioManager")
	if am:
		am.process_mode = Node.PROCESS_MODE_DISABLED
		for c in am.get_children():
			if c is AudioStreamPlayer:
				(c as AudioStreamPlayer).stop()
	_loop = AudioStreamPlayer.new()
	_sfx = AudioStreamPlayer.new()
	root.add_child(_loop)
	root.add_child(_sfx)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 24
	scroll.offset_right = -24
	scroll.offset_bottom = -24
	root.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	_now = Label.new()
	_now.text = "Clique un son. Musiques et ambiances bouclent ; re-clique pour arrêter."
	_now.add_theme_font_size_override("font_size", 22)
	col.add_child(_now)
	var am_script: Script = load("res://scripts/audio/AudioManager.gd")
	var consts: Dictionary = am_script.get_script_constant_map()
	_section(col, "Musiques (par district)", consts["DISTRICT_MUSIC"], true)
	var amb: Dictionary = {}
	for k in consts["DISTRICT_AMBIENT"]:
		var p: String = consts["DISTRICT_AMBIENT"][k]
		amb[p.get_file().get_basename()] = p
	_section(col, "Ambiances", amb, true)
	_section(col, "Bruitages", consts["SFX_PATHS"], false)


func _section(col: VBoxContainer, title: String, entries: Dictionary, looping: bool) -> void:
	var h: Label = Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	col.add_child(h)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	var keys: Array = entries.keys()
	keys.sort()
	for k in keys:
		var path: String = entries[k]
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(300, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.text = "%s  ·  %s" % [k, path.get_file()] if looping else String(k)
		b.disabled = not ResourceLoader.exists(path)
		b.pressed.connect(_play.bind(path, looping, String(k)))
		grid.add_child(b)


func _play(path: String, looping: bool, label: String) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if looping:
		if _current == path and _loop.playing:
			_loop.stop()
			_current = ""
			_now.text = "■ Arrêté"
			return
		if "loop" in stream:
			stream.loop = true
		_loop.stream = stream
		_loop.play()
		_current = path
		_now.text = "▶ %s  (%.0f s, boucle)" % [label, stream.get_length()]
	else:
		_sfx.stream = stream
		_sfx.play()
		_now.text = "♪ %s" % label
