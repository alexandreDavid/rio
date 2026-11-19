extends CanvasLayer

# Outil dev : salle d'arcade des mini-jeux, pour les essayer hors partie.
# Lancer via tools/play_minigames.sh (sauvegardes mises à l'abri), ou depuis
# l'écran titre d'un build de debug (bouton « Mini-jeux (test) », iPhone compris).
# Un bouton par scène de scenes/minigames (+ Kite = Surf en mode kitesurf) ;
# à la fin d'une partie (ou sur Sair), retour à la liste.

const DIR: String = "res://scenes/minigames"

var _grid: GridContainer = null
var _current: Node = null
var _last: Label = null

func _ready() -> void:
	UITheme.apply(get_tree().root)
	# CanvasLayer : la liste ignore les caméras des mini-jeux.
	layer = 60
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.18, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_top = 30
	box.offset_right = -40
	box.offset_bottom = -30
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	SafeArea.apply(box)
	var back: Button = Button.new()
	back.text = "← Retour au titre"
	back.theme_type_variation = &"TouchButton"
	back.add_theme_font_size_override("font_size", 33)
	back.custom_minimum_size = Vector2(0, 110)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main/Intro.tscn"))
	box.add_child(back)
	var title: Label = Label.new()
	title.text = "Mini-jeux de Rio — choisis-en un"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_last = Label.new()
	_last.add_theme_font_size_override("font_size", 22)
	_last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_last)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(_grid)
	var files: PackedStringArray = DirAccess.get_files_at(DIR)
	for raw in files:
		# Dans un export, les scènes sont listées « X.tscn.remap » (converties) :
		# on retire le suffixe, load() suit le remap tout seul.
		var f: String = raw.trim_suffix(".remap")
		if f.ends_with(".tscn"):
			_add_button(f.get_basename(), DIR + "/" + f, "")
	_add_button("Kite", DIR + "/Surf.tscn", "kitesurf")
	add_to_group("gamepad_menu")
	GamepadBridge.focus_first.call_deferred(self)
	EventBus.minigame_ended.connect(_on_minigame_ended)

func _add_button(label: String, path: String, kite_id: String) -> void:
	var b: Button = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(300, 110)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 33)
	b.pressed.connect(_launch.bind(path, kite_id))
	_grid.add_child(b)

func _launch(path: String, kite_id: String) -> void:
	if _current:
		return
	_current = (load(path) as PackedScene).instantiate()
	if kite_id != "":
		_current.set("minigame_id", kite_id)
	visible = false
	get_tree().root.add_child(_current)

func _on_minigame_ended(id: String, result: Dictionary) -> void:
	_last.text = "Dernier : %s — %s" % [id, "qualifié ✓" if result.get("qualifies", false) else "non qualifié"]
	# Le jeu a déjà affiché son bilan avant d'émettre : retour quasi immédiat.
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
	visible = true
	GamepadBridge.focus_first(self)
