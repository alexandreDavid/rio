extends Control

# Gère l'overlay de contrôles mobile : bouton E qui envoie l'action "interact",
# joystick auto-géré. Masque les contrôles pendant les dialogues et les mini-jeux
# (chaque mini-jeu offre ses propres boutons à l'écran, le 📱 deviendrait redondant).


# Pour situer le sable (bande y + rivage) — le bouton Altinha n'apparaît que
# les pieds dedans. Copa utilise la courbe du rivage (Cfg.shore_y) ; les autres
# plages sont des bandes rectangulaires en coordonnées locales du district.
const Cfg = preload("res://scripts/world/CopacabanaConfig.gd")
const SAND_TOP_Y: float = 128.0
const SAND_CHECK_INTERVAL: float = 0.25

# Plages jouables hors Copa : district → bande de sable locale (l'altinha se
# joue partout où il y a du sable et du monde — Ipanema, Icaraí).
const BEACH_BANDS: Dictionary = {
	"zona_sul": {"x": [-900.0, 900.0], "y": [104.0, 196.0]},
	"niteroi": {"x": [890.0, 1690.0], "y": [-36.0, 116.0]},
}

@onready var interact_button: Button = $InteractButton
@onready var altinha_button: Button = $AltinhaButton
@onready var joystick: VirtualJoystick = $Joystick

var _sand_check_accum: float = 0.0

func _ready() -> void:
	if interact_button:
		interact_button.pressed.connect(_on_interact_pressed)
	if altinha_button:
		altinha_button.pressed.connect(func(): EventBus.altinha_requested.emit())
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.minigame_started.connect(_on_minigame_started)
	EventBus.minigame_ended.connect(_on_minigame_ended)

func _process(delta: float) -> void:
	_sand_check_accum += delta
	if _sand_check_accum < SAND_CHECK_INTERVAL:
		return
	_sand_check_accum = 0.0
	if altinha_button:
		altinha_button.visible = _altinha_available()

func _altinha_available() -> bool:
	var p: Node = GameManager.player
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return false
	if p.has_method("is_mounted") and p.is_mounted():
		return false
	var pos: Vector2 = (p as Node2D).global_position
	var district: String = DistrictManager.current()
	if district == "copacabana":
		return pos.y >= SAND_TOP_Y and pos.y <= Cfg.shore_y(pos.x)
	if not BEACH_BANDS.has(district):
		return false
	# Bande locale au district → conversion via l'offset du nœud district.
	var dnode: Node = DistrictManager._find_district_node(district)
	if not (dnode is Node2D):
		return false
	var local: Vector2 = pos - (dnode as Node2D).global_position
	var band: Dictionary = BEACH_BANDS[district]
	return local.x >= band.x[0] and local.x <= band.x[1] \
		and local.y >= band.y[0] and local.y <= band.y[1]

func _on_interact_pressed() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_dialogue_started(_npc_id: String) -> void:
	visible = false

func _on_dialogue_ended(_npc_id: String) -> void:
	visible = true

func _on_minigame_started(_minigame_id: String) -> void:
	visible = false

func _on_minigame_ended(_minigame_id: String, _result: Dictionary) -> void:
	visible = true
