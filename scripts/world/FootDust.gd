class_name FootDust
extends Node2D

# Poussière de pas sur le sable : un petit nuage clair qui s'élargit et
# s'efface, tous les ~22 px de marche (plus gros en courant). Enfant du
# joueur ; les nuages sont posés dans le monde (ils restent sur place).

const STEP_PX: float = 22.0
var _acc: float = 0.0
var _last: Vector2 = Vector2.ZERO
var _tex: ImageTexture = null


func _ready() -> void:
	var img: Image = Image.create(3, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.98, 0.92, 0.72, 0.85))
	img.set_pixel(0, 1, Color(0, 0, 0, 0))
	img.set_pixel(2, 1, Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(img)
	_last = global_position


func _physics_process(_delta: float) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var p: Vector2 = parent.global_position
	var d: float = p.distance_to(_last)
	_last = p
	if d < 0.5 or d > 60.0:
		return
	if not parent.has_method("_current_surface") or String(parent.call("_current_surface")) != "sand":
		return
	_acc += d
	if _acc < STEP_PX:
		return
	_acc = 0.0
	var world: Node = parent.get_parent()
	if world == null:
		return
	var puff: Sprite2D = Sprite2D.new()
	puff.texture = _tex
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puff.global_position = p + Vector2(randf_range(-4.0, 4.0), 9.0)
	puff.scale = Vector2(3, 3)
	puff.z_index = -1
	world.add_child(puff)
	var tw: Tween = puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "modulate:a", 0.0, 0.45)
	tw.tween_property(puff, "scale", Vector2(6, 4), 0.45)
	tw.tween_property(puff, "position:y", puff.position.y - 6.0, 0.45)
	tw.chain().tween_callback(puff.queue_free)
