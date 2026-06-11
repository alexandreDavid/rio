extends SceneTree

# Outil dev : capture des screenshots d'une scène district sans gameplay.
# Usage : godot --path . --script tools/screenshot_scene.gd -- <res_path> <out_prefix> <cam_positions "x:y:zoom,...">
# Exemple : -- res://scenes/districts/FavelaDoMorro.tscn /tmp/favela "0:-350:0.5,0:-700:0.5"

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("args: <res_path> <out_prefix> <x:y:zoom,...>")
		quit(2)
		return
	var scene_path: String = args[0]
	var out_prefix: String = args[1]
	var cams: PackedStringArray = args[2].split(",")

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("scène introuvable : " + scene_path)
		quit(2)
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)

	# Désactive toute caméra embarquée (ex. celle du Player) pour garder la main.
	for other in root.find_children("*", "Camera2D", true, false):
		(other as Camera2D).enabled = false

	var cam: Camera2D = Camera2D.new()
	cam.enabled = true
	root.add_child(cam)
	cam.make_current()

	await process_frame
	await process_frame

	var idx: int = 0
	for c in cams:
		var parts: PackedStringArray = c.split(":")
		cam.position = Vector2(float(parts[0]), float(parts[1]))
		var z: float = float(parts[2])
		cam.zoom = Vector2(z, z)
		await process_frame
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [out_prefix, idx])
		print("saved %s_%d.png" % [out_prefix, idx])
		idx += 1
	quit(0)
