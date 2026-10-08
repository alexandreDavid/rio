class_name Seagulls
extends Node2D

# Mouettes au-dessus du sable et de l'eau : quelques sprites 2 images (ailes
# hautes / basses) dessinés en code, qui traversent la bande en boucle avec
# une légère ondulation. Pur décor (rendu C).

@export var count: int = 4
@export var band: Rect2 = Rect2(-200, 300, 3300, 170)
@export var speed_range: Vector2 = Vector2(28.0, 46.0)

var _birds: Array = []
var _frames: Array = []
var _t: float = 0.0


func _ready() -> void:
	_frames = [_frame(true), _frame(false)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for i in count:
		var s: Sprite2D = Sprite2D.new()
		s.texture = _frames[0]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(3, 3)
		s.position = Vector2(rng.randf_range(band.position.x, band.end.x), rng.randf_range(band.position.y, band.end.y))
		var dir: float = -1.0 if rng.randf() < 0.5 else 1.0
		s.flip_h = dir > 0.0
		add_child(s)
		_birds.append({"node": s, "dir": dir, "speed": rng.randf_range(speed_range.x, speed_range.y),
			"base_y": s.position.y, "phase": rng.randf() * TAU, "flap": rng.randf()})


func _process(delta: float) -> void:
	_t += delta
	for b in _birds:
		var s: Sprite2D = b.node
		s.position.x += b.dir * b.speed * delta
		s.position.y = b.base_y + sin(_t * 0.8 + b.phase) * 9.0
		if b.dir > 0.0 and s.position.x > band.end.x + 40.0:
			s.position.x = band.position.x - 40.0
		elif b.dir < 0.0 and s.position.x < band.position.x - 40.0:
			s.position.x = band.end.x + 40.0
		var frame: int = int(floor((_t * 3.2 + b.flap * 10.0))) % 2
		s.texture = _frames[frame]


# 9×5 natifs : un « V » d'ailes blanches contourées, bec jaune.
static func _frame(up: bool) -> ImageTexture:
	var img: Image = Image.create(9, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var w: Color = Color(0.96, 0.96, 0.94, 1)
	var d: Color = Color(0.25, 0.25, 0.3, 1)
	if up:
		for p in [[0, 0], [1, 1], [2, 2], [6, 2], [7, 1], [8, 0]]:
			img.set_pixel(p[0], p[1], w)
		for p in [[3, 3], [5, 3]]:
			img.set_pixel(p[0], p[1], w)
		img.set_pixel(4, 3, d)
		img.set_pixel(4, 4, Color(0.95, 0.75, 0.2, 1))
	else:
		for p in [[0, 3], [1, 2], [2, 2], [6, 2], [7, 2], [8, 3]]:
			img.set_pixel(p[0], p[1], w)
		for p in [[3, 2], [5, 2]]:
			img.set_pixel(p[0], p[1], w)
		img.set_pixel(4, 2, d)
		img.set_pixel(4, 3, Color(0.95, 0.75, 0.2, 1))
	return ImageTexture.create_from_image(img)
