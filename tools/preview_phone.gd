extends SceneTree
# Capture du téléphone hors partie (sans sauvegarde) :
#   godot --path . --write-movie out.png --fixed-fps 10 --quit-after 6 -s tools/preview_phone.gd -- stats
var _screen: String = "home"
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_screen = args[0]
	_run.call_deferred()
func _run() -> void:
	UITheme.apply()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.35, 0.55, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var p: Node = (load("res://scenes/ui/Phone.tscn") as PackedScene).instantiate()
	root.add_child(p)
	await process_frame
	p.open()
	if _screen != "home":
		p._show_screen(_screen)
	paused = false
	for i in 6:
		await process_frame
