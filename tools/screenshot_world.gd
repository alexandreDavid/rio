extends Node2D

# Outil dev : capture le monde complet (Copacabana générée + districts en place,
# autoloads chargés). Contrairement à screenshot_scene.gd, les scripts qui
# dépendent des singletons compilent, donc le rendu est celui du jeu.
# Usage : godot --path . tools/ScreenshotWorld.tscn -- <out_prefix> "x:y:zoom,..."
# Coordonnées monde (un district = son offset dans Copacabana.tscn + local).

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("args: <out_prefix> <x:y:zoom,...>")
		get_tree().quit(2)
		return
	var packed: PackedScene = load("res://scenes/world/Copacabana.tscn")
	var inst: Node = packed.instantiate()
	add_child(inst)
	for other in find_children("*", "Camera2D", true, false):
		(other as Camera2D).enabled = false
	var cam: Camera2D = Camera2D.new()
	add_child(cam)
	cam.make_current()
	for i in 3:
		await get_tree().process_frame
	var idx: int = 0
	for c in args[1].split(","):
		var parts: PackedStringArray = c.split(":")
		cam.position = Vector2(float(parts[0]), float(parts[1]))
		var z: float = float(parts[2])
		cam.zoom = Vector2(z, z)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [args[0], idx])
		print("saved %s_%d.png" % [args[0], idx])
		idx += 1
	get_tree().quit(0)
