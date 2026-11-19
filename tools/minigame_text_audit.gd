extends Node

# Outil dev : audit de lisibilité des mini-jeux au format iPhone. Lance chaque
# scène de scenes/minigames, prend une capture et liste les textes visibles
# dont la hauteur à l'écran passe sous le plancher du jeu (UIFit.MIN_SCREEN_FONT,
# en px de canevas — un Label du monde compte avec le zoom de sa caméra).
#   tools/minigame_text_audit.sh <out_prefix>

const DIR: String = "res://scenes/minigames"
var _prefix: String = ""
var _problems: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_prefix = args[0] if args.size() > 0 else "/tmp/mg_text"
	UITheme.apply(get_tree().root)
	await get_tree().process_frame
	for raw in DirAccess.get_files_at(DIR):
		var f: String = raw.trim_suffix(".remap")
		if not f.ends_with(".tscn"):
			continue
		var game: Node = (load(DIR + "/" + f) as PackedScene).instantiate()
		get_tree().root.add_child(game)
		var t: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 1500:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_prefix, f.get_basename()])
		var small: Array = []
		_collect(game, small)
		print("-- %s : %d texte(s) sous %d px" % [f.get_basename(), small.size(), int(UIFit.MIN_SCREEN_FONT)])
		for line in small:
			_problems += 1
			print("   PETIT   %s" % line)
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("== AUDIT TEXTES : %d problème(s)" % _problems)
	get_tree().quit(0)


func _collect(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is Label or n is Button or n is RichTextLabel:
		var c: Control = n
		var text: String = String(c.get("text"))
		if text.strip_edges() != "":
			var key: String = "normal_font_size" if n is RichTextLabel else "font_size"
			var px: float = float(c.get_theme_font_size(key)) * absf(c.get_global_transform_with_canvas().get_scale().y)
			if px < UIFit.MIN_SCREEN_FONT - 0.5:
				out.append("%-44s %4.1f px  « %s »" % [String(n.get_path()).get_slice("/", 2) + "/…/" + String(n.name), px, text.substr(0, 40).replace("\n", " ")])
	for child in n.get_children():
		_collect(child, out)
