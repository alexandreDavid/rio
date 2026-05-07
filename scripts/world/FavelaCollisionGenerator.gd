extends Node2D

# Génère les boîtes de collision pour chaque maison dessinée à la main dans
# FavelaDoMorro.tscn (les ColorRect des maisons n'ont pas de StaticBody2D).
# Pour la maison du tio Zé, la boîte est raccourcie en bas afin de laisser
# l'accès à la TioZeDoor (BuildingDoor) qui se trouve au sud du mur.
const HOUSE_BOUNDS: Array[Rect2] = [
	Rect2(-50, -1080, 100, 70),    # CapelaWall
	Rect2(-260, -990, 100, 90),    # House_top_L
	Rect2(100, -980, 120, 100),    # House_top_R
	Rect2(-200, -880, 100, 80),    # House_900_L
	Rect2(60, -850, 120, 100),     # House_850_R
	Rect2(-250, -780, 120, 100),   # House_750_L
	Rect2(80, -700, 120, 100),     # House_700_R
	Rect2(-300, -680, 180, 110),   # TioZeHouseWall (réduit 140→110 pour accès porte)
	Rect2(80, -600, 140, 120),     # House_600_R
	Rect2(-260, -520, 130, 120),   # House_500_L
	Rect2(60, -460, 180, 120),     # BarDoMorroWall
	Rect2(-250, -380, 130, 120),   # House_350_L
	Rect2(100, -300, 120, 120),    # House_250_R
	Rect2(-240, -220, 120, 120),   # House_180_L
	Rect2(80, -150, 120, 100),     # House_100_R
	Rect2(-260, -80, 150, 110),    # PadariaWall
	Rect2(100, 0, 120, 100),       # House_30_R
	Rect2(-240, 80, 120, 100),     # House_140_L
]

func _ready() -> void:
	for r in HOUSE_BOUNDS:
		var body: StaticBody2D = StaticBody2D.new()
		body.position = r.position + r.size * 0.5
		add_child(body)
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.add_child(shape)
