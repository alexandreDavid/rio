extends SceneTree
# Capture hors partie d'un overlay (Diário, Missões…) :
#   godot --path . --write-movie out.png --fixed-fps 10 --quit-after 6 -s tools/preview_overlay.gd -- res://scenes/ui/JournalUI.tscn
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	UITheme.apply()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.35, 0.55, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var path: String = OS.get_cmdline_user_args()[0]
	var ui: Node = (load(path) as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame
	ui.call("open" if ui.has_method("open") else "toggle")
	paused = false
