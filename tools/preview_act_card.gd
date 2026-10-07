extends Node

# Outil dev : capture la carte d'acte (ActCard.tscn) avec le texte d'un acte,
# pour vérifier lisibilité et format tactile sans jouer jusqu'à la bascule.
# Lancé comme scène (les autoloads sont nécessaires) :
#   godot --path . tools/PreviewActCard.tscn -- <acte> <out.png> [w] [h]

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("args: <acte> <out.png> [w] [h]")
		get_tree().quit(2)
		return
	var act: int = int(args[0])
	var out: String = args[1]
	if args.size() >= 4:
		var size: Vector2i = Vector2i(int(args[2]), int(args[3]))
		DisplayServer.window_set_size(size)
		get_tree().root.content_scale_size = size
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/ui/ActCard.tscn")
	var card: CanvasLayer = packed.instantiate()
	add_child(card)
	await get_tree().process_frame
	# Force l'affichage sans passer par act_changed (qui exige une vraie bascule).
	card.call("_show_act", act)
	for i in 4:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit(0)
