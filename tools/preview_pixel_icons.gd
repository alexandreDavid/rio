extends SceneTree
# Planche de contrôle des icônes pixel (PixelIcons) rendues par la police de
# l'interface, à ×4 et ×2, sur fond sombre et clair :
#   godot --path . --resolution 1500x900 -s tools/preview_pixel_icons.gd -- <out.png>
func _init() -> void:
	UITheme.apply(root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	flow.offset_left = 16
	flow.offset_top = 12
	flow.offset_right = -16
	flow.add_theme_constant_override("h_separation", 26)
	flow.add_theme_constant_override("v_separation", 8)
	root.add_child(flow)
	var all: Array = PixelIcons.ICONS.keys() + PixelIcons.SYMBOLS.keys()
	# 3e argument « gros » : seulement les dessins, à ×8, pour juger les formes.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var huge: bool = args.size() > 1 and args[1] == "gros"
	for ch in all:
		var big: Label = Label.new()
		big.text = ch
		big.add_theme_font_size_override("font_size", 88 if huge else 44)
		flow.add_child(big)
	if huge:
		for i in 6:
			await process_frame
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	for ch in all:
		var small: Label = Label.new()
		small.text = ch
		small.add_theme_font_size_override("font_size", 22)
		small.add_theme_color_override("font_color", Color(0.96, 0.82, 0.36))
		flow.add_child(small)
	var line: Label = Label.new()
	line.text = "🎯 → Copa : va voir Zé  ·  📍 Carrocinha 28m  ·  🚨 Blitz !  ·  ⏱ 12s  ·  💰 R$ 50  ·  🤝 pacte 🕊 (muets)  ·  Ⓐ Ⓑ Ⓧ Ⓨ  ·  ★ ✓ × ♪ ↑ ↓ ← →"
	line.add_theme_font_size_override("font_size", 33)
	line.custom_minimum_size = Vector2(1440, 0)
	flow.add_child(line)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
