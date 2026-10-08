extends SceneTree

# Outil dev : rend quelques Labels en police pixel (PixelFont) et sauve un PNG.
# Usage : godot --path . --script tools/preview_pixel_font.gd -- <out.png>

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/pixel_font.png"
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.35, 0.45, 0.55)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var samples: Array = [
		["BAR DO MORRO · PADARIA SÃO SEBASTIÃO · P4 · R$ 1 250", 3, true, Color(1, 0.95, 0.8)],
		["Carrocinha de tio Zé — Volei Ipanema (Arpoador) ✓ ✦ ↓ Sortir", 3, true, Color(0.95, 0.85, 0.4)],
		["àâãáéêèíóôõúüç ÀÂÃÉÊÍÓÔÕÚÇ 0123456789 !?,.;:'\"-–—/()[]%&*+=<>…•", 3, true, Color.WHITE],
		["the quick brown fox jumps over the lazy dog", 2, false, Color.WHITE],
		["THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG", 2, false, Color.WHITE],
		["Mãe · Vovó · Seu João · Dom Nilton · Tito · Ramos 🥖 🏐 📍", 2, true, Color(0.9, 0.9, 0.9)],
		["Diário de missões  HISTÓRIA  Atividades  1 ✦ 0", 1, false, Color.WHITE],
	]
	var y: float = 30.0
	for s in samples:
		var l: Label = Label.new()
		l.text = s[0]
		l.position = Vector2(30, y)
		l.add_theme_color_override("font_color", s[3])
		PixelFont.apply(l, s[1], s[2])
		root.add_child(l)
		y += 12.0 * s[1] * 3.0 + 10.0
	# Comparaison : la police système, même taille.
	var ref: Label = Label.new()
	ref.text = "Police système 22 px (référence)"
	ref.position = Vector2(30, y + 20)
	ref.add_theme_font_size_override("font_size", 22)
	root.add_child(ref)
	await process_frame
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit(0)
