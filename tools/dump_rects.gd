extends SceneTree

# Outil dev : liste les ColorRect/Sprite2D dont le rect global intersecte une zone.
# Usage : godot --path . --script tools/dump_rects.gd -- <res_path> <x> <y> <w> <h>

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var packed: PackedScene = load(args[0])
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	var zone: Rect2 = Rect2(float(args[1]), float(args[2]), float(args[3]), float(args[4]))
	for n in root.find_children("*", "ColorRect", true, false):
		var cr: ColorRect = n as ColorRect
		var r: Rect2 = Rect2(cr.global_position, cr.size)
		if r.intersects(zone) and r.size.x > 40 and r.size.y > 40:
			print("%s | rect=%s | color=%s | z=%d | path=%s" % [cr.name, r, cr.color, cr.z_index, cr.get_path()])
	quit(0)
