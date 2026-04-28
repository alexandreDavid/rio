extends Control

# Mini-carte top-down de Copacabana, coin bas-droit du HUD. Affiche la position
# du joueur, du TaxiStand, du MissionBoard et du consortium. Quand le joueur
# est hors Copacabana (dans un district), la mini-carte affiche le label du
# district courant à la place.

const MAP_X_MIN: float = 160.0
const MAP_X_MAX: float = 2200.0
const MAP_Y_MIN: float = -240.0
const MAP_Y_MAX: float = 420.0

const VIEW_W: float = 220.0
const VIEW_H: float = 80.0

const PLAYER_DOT_SIZE: float = 8.0
const POI_DOT_SIZE: float = 6.0

# Nœuds de scène à projeter sur la mini-carte (NodePath relatif à /root/Main/World).
# Couleur = teinte du dot.
const POIS: Dictionary = {
	"TaxiStand":        Color(0.95, 0.85, 0.4, 1),    # jaune taxi
	"MissionBoard":     Color(0.95, 0.5, 0.4, 1),     # rouge tableau
	"Consortium":       Color(0.6, 0.3, 0.55, 1),     # violet consortium
	"SeuJoao":          Color(0.55, 0.85, 0.55, 1),   # vert tio Zé
}

@onready var bg: ColorRect = $Bg
@onready var sand_strip: ColorRect = $SandStrip
@onready var sea_strip: ColorRect = $SeaStrip
@onready var road_strip: ColorRect = $RoadStrip
@onready var label_district: Label = $DistrictLabel
@onready var pois_layer: Control = $PoisLayer
@onready var player_dot: ColorRect = $PoisLayer/PlayerDot

var _poi_dots: Dictionary = {}
var _world_node: Node = null
var _last_district: String = "copacabana"

func _ready() -> void:
	_setup_strips()
	_make_poi_dots()
	_world_node = get_tree().current_scene.get_node_or_null("World")
	if DistrictManager:
		DistrictManager.district_changed.connect(_on_district_changed)
	_on_district_changed(DistrictManager.current() if DistrictManager else "copacabana")

func _process(_delta: float) -> void:
	if _last_district != "copacabana":
		return
	_refresh_player_dot()

func _setup_strips() -> void:
	# Bandes Y : sable (128..400), av. atlantica (0..64), commerces (-64..0),
	# nossa senhora (-128..-64), 2e rangée (-192..-128). On prend une vue compacte.
	if sand_strip:
		var y0: float = _y_to_view(128.0)
		var y1: float = _y_to_view(400.0)
		sand_strip.position = Vector2(0, y0)
		sand_strip.size = Vector2(VIEW_W, y1 - y0)
	if sea_strip:
		var y0_s: float = _y_to_view(400.0)
		sea_strip.position = Vector2(0, y0_s)
		sea_strip.size = Vector2(VIEW_W, VIEW_H - y0_s)
	if road_strip:
		var y0_r: float = _y_to_view(0.0)
		var y1_r: float = _y_to_view(64.0)
		road_strip.position = Vector2(0, y0_r)
		road_strip.size = Vector2(VIEW_W, y1_r - y0_r)

func _make_poi_dots() -> void:
	for name in POIS:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(POI_DOT_SIZE, POI_DOT_SIZE)
		dot.color = POIS[name]
		dot.visible = false
		pois_layer.add_child(dot)
		_poi_dots[name] = dot

func _refresh_player_dot() -> void:
	if GameManager.player == null or player_dot == null:
		return
	var pos: Vector2 = GameManager.player.global_position
	var view_pos: Vector2 = _world_to_view(pos)
	player_dot.position = view_pos - Vector2(PLAYER_DOT_SIZE, PLAYER_DOT_SIZE) / 2.0
	# Refresh POIs (les NPCs peuvent bouger via NPCScheduler).
	for name in POIS:
		var node: Node2D = _world_node.get_node_or_null(name) if _world_node else null
		var dot: ColorRect = _poi_dots.get(name)
		if dot == null:
			continue
		if node == null or not (node is Node2D):
			dot.visible = false
			continue
		var p: Vector2 = (node as Node2D).global_position
		if p.x < MAP_X_MIN - 200.0 or p.x > MAP_X_MAX + 200.0:
			# Hors zone (ex. NPC dans un intérieur ou un district).
			dot.visible = false
			continue
		var v: Vector2 = _world_to_view(p)
		dot.position = v - Vector2(POI_DOT_SIZE, POI_DOT_SIZE) / 2.0
		dot.visible = true

func _world_to_view(p: Vector2) -> Vector2:
	var nx: float = clamp((p.x - MAP_X_MIN) / (MAP_X_MAX - MAP_X_MIN), 0.0, 1.0)
	var ny: float = clamp((p.y - MAP_Y_MIN) / (MAP_Y_MAX - MAP_Y_MIN), 0.0, 1.0)
	return Vector2(nx * VIEW_W, ny * VIEW_H)

func _y_to_view(world_y: float) -> float:
	var ny: float = clamp((world_y - MAP_Y_MIN) / (MAP_Y_MAX - MAP_Y_MIN), 0.0, 1.0)
	return ny * VIEW_H

func _on_district_changed(district_id: String) -> void:
	_last_district = district_id
	var in_copa: bool = district_id == "copacabana"
	# Strips et dots visibles uniquement sur Copacabana.
	if sand_strip:
		sand_strip.visible = in_copa
	if sea_strip:
		sea_strip.visible = in_copa
	if road_strip:
		road_strip.visible = in_copa
	if pois_layer:
		pois_layer.visible = in_copa
	if label_district:
		label_district.visible = not in_copa
		label_district.text = DistrictManager.get_label(district_id)
