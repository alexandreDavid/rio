extends Node

# Outil dev : capture l'écran d'épilogue d'une voie avec ses carrefours posés,
# pour vérifier lisibilité et défilement sans jouer jusqu'au desfile.
# Lancé comme scène (les autoloads sont nécessaires) :
#   godot --path . tools/PreviewEpilogue.tscn -- <voie 1-4> <out.png> [flag,flag,...] [scroll_px]

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("args: <voie> <out.png> [flags] [scroll_px]")
		get_tree().quit(2)
		return
	var path: int = int(args[0])
	if args.size() >= 3:
		for flag in args[2].split(",", false):
			CampaignManager.flags[flag] = true
	var screen: CanvasLayer = load("res://scenes/ui/EpilogueScreen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	CampaignManager.chosen_endgame = path
	screen.call("_show_epilogue")
	get_tree().paused = false
	for i in 4:
		await get_tree().process_frame
	if args.size() >= 4:
		screen.get_node("Panel/Margin/Layout/Scroll").scroll_vertical = int(args[3])
		for i in 3:
			await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(args[1])
	print("saved ", args[1], " ", img.get_size())
	get_tree().quit(0)
