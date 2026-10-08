extends SceneTree

# Outil dev : rend les éléments du thème UI (cadres, boutons, pastilles,
# barre, prompt) sur fond neutre et sauve un PNG.
# Usage : godot --path . --script tools/preview_ui_theme.gd -- <out.png>

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/ui_theme.png"
	UITheme.apply(root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.35, 0.45, 0.55)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var panel: Panel = Panel.new()
	panel.position = Vector2(40, 40)
	panel.size = Vector2(420, 220)
	root.add_child(panel)
	var title: Label = Label.new()
	title.theme_type_variation = &"PixelTitle"
	title.text = "Diário de missões"
	title.position = Vector2(60, 56)
	root.add_child(title)
	var body: Label = Label.new()
	body.text = "✦ L'héritage empoisonné\n  • Aller voir le consortium"
	body.position = Vector2(60, 100)
	root.add_child(body)
	var b: Button = Button.new()
	b.text = "📱"
	b.position = Vector2(500, 40)
	b.size = Vector2(72, 72)
	b.add_theme_font_size_override("font_size", 32)
	root.add_child(b)
	var pb: Button = Button.new()
	pb.theme_type_variation = &"PixelButton"
	pb.text = "✦ 1 · 0"
	pb.position = Vector2(600, 40)
	pb.size = Vector2(168, 72)
	root.add_child(pb)
	var tb: Button = Button.new()
	tb.theme_type_variation = &"TouchButton"
	tb.text = "✋"
	tb.position = Vector2(500, 140)
	tb.size = Vector2(128, 128)
	tb.add_theme_font_size_override("font_size", 52)
	root.add_child(tb)
	var tb2: Button = Button.new()
	tb2.theme_type_variation = &"TouchButton"
	tb2.text = "🏃"
	tb2.position = Vector2(650, 160)
	tb2.size = Vector2(104, 104)
	tb2.button_pressed = true
	tb2.toggle_mode = true
	root.add_child(tb2)
	var bar: ProgressBar = ProgressBar.new()
	bar.position = Vector2(40, 300)
	bar.size = Vector2(400, 14)
	bar.value = 45
	bar.show_percentage = false
	root.add_child(bar)
	var prompt: Label = Label.new()
	prompt.theme_type_variation = &"Pastille"
	prompt.text = "[E] Parler à la voisine"
	prompt.position = Vector2(40, 340)
	root.add_child(prompt)
	var choice: Button = Button.new()
	choice.text = "Calme-toi. Je le retrouve."
	choice.position = Vector2(40, 420)
	choice.size = Vector2(700, 56)
	choice.add_theme_font_size_override("font_size", 22)
	root.add_child(choice)
	await process_frame
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit(0)
