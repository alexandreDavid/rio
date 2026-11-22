class_name VirtualJoystick
extends Control

# Joystick virtuel flottant (façon Brawl Stars) : injecte les actions
# "move_left/right/forward/back" via Input.action_press/release. Tactile ET
# souris (desktop).
#  - Flottant : le pouce se pose N'IMPORTE OÙ dans la moitié gauche de l'écran,
#    la base vient dessous. Poser le pouce ne fait donc jamais partir le
#    personnage (avant : disque fixe de 60 pt à viser, et un pouce posé hors
#    centre donnait aussitôt une direction).
#  - Suiveur : si le pouce dépasse le bord, la base le suit — rebrousser chemin
#    demande un petit geste, pas de retraverser tout le disque.
#  - Analogique : zone morte RADIALE, direction libre. (Avant : zone morte par
#    axe — directions aimantées sur 8 caps, et un petit geste en diagonale
#    restait sans effet.)
# Le rect du nœud reste la position de repos (cible des astuces contextuelles).

@export var radius: float = 80.0
# Fraction du rayon sous laquelle le pouce ne commande rien (tremblement).
@export var dead_zone: float = 0.14
# Déflexion quasi complète = sprint ("run"). Sans ça, courir n'existe pas au
# tactile (l'action n'est mappée que sur Shift).
@export var run_threshold: float = 0.85
# Zone où le pouce peut se poser, en fractions de l'écran (gauche, haut,
# droite, bas). Le haut est laissé à la barre d'état et à la minimap.
@export var touch_zone: Rect2 = Rect2(0.0, 0.22, 0.46, 0.78)
@export var floating: bool = true

# Tenu par le bouton 🏃 de MobileControls : tant que true, le joystick ne
# relâche jamais "run" — sinon chaque retour sous le seuil 0.85 annulerait la
# bascule et le sprint serait incompatible avec une direction fine.
var external_run_hold: bool = false

const CARDINAL_SNAP: float = 0.12

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
# Centre de la base dans le repère du nœud ; au repos = centre du rect.
var _base: Vector2 = Vector2.ZERO
var _zone: Control = null


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	_base = size * 0.5
	resized.connect(func() -> void:
		if _touch_index == -1:
			_base = size * 0.5
			queue_redraw())
	visibility_changed.connect(_on_visibility_changed)
	if floating:
		_build_zone.call_deferred()


# Zone de capture : un Control invisible posé DERRIÈRE ses frères, pour que
# les boutons (et le disque de repos) gardent la priorité sur leurs touchers.
func _build_zone() -> void:
	var parent: Node = get_parent()
	if parent == null or _zone != null:
		return
	_zone = Control.new()
	_zone.name = "JoystickZone"
	_zone.anchor_left = touch_zone.position.x
	_zone.anchor_top = touch_zone.position.y
	_zone.anchor_right = touch_zone.position.x + touch_zone.size.x
	_zone.anchor_bottom = touch_zone.position.y + touch_zone.size.y
	_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_zone.focus_mode = Control.FOCUS_NONE
	_zone.visible = is_visible_in_tree()
	_zone.gui_input.connect(_on_zone_input)
	parent.add_child(_zone)
	parent.move_child(_zone, 0)


func _exit_tree() -> void:
	_release()


func _on_visibility_changed() -> void:
	if is_instance_valid(_zone):
		_zone.visible = is_visible_in_tree()
	if not is_visible_in_tree():
		_release()


func _draw() -> void:
	var active: bool = _touch_index != -1
	draw_circle(_base, radius, Color(0, 0, 0, 0.35 if active else 0.22))
	draw_arc(_base, radius, 0, TAU, 48, Color(1, 1, 1, 0.45 if active else 0.28), 2.0)
	draw_circle(_base + _knob_offset, radius * 0.42, Color(1, 1, 1, 0.6 if active else 0.38))


func _gui_input(event: InputEvent) -> void:
	_handle(event, event.position if "position" in event else Vector2.ZERO)


# Événements de la zone flottante, ramenés dans le repère du joystick.
func _on_zone_input(event: InputEvent) -> void:
	if not ("position" in event) or not is_instance_valid(_zone):
		return
	var local: Vector2 = get_global_transform().affine_inverse() * (_zone.get_global_transform() * event.position)
	_handle(event, local)


func _handle(event: InputEvent, pos: Vector2) -> void:
	if event is InputEventScreenTouch:
		_on_touch(pos, event.pressed, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(pos, event.pressed, 0)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(pos)
	elif event is InputEventMouseMotion and _touch_index == 0:
		_update_knob(pos)


func _on_touch(pos: Vector2, pressed: bool, index: int) -> void:
	if pressed and _touch_index == -1:
		_touch_index = index
		# Flottant : la base vient sous le pouce (aucune direction au contact).
		# Fixe : la base reste au centre, le pouce donne tout de suite un cap.
		_base = pos if floating else size * 0.5
		_update_knob(pos)
	elif not pressed and index == _touch_index:
		_release()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_base = size * 0.5
	_apply_actions(Vector2.ZERO)
	queue_redraw()


func _update_knob(pos: Vector2) -> void:
	var offset: Vector2 = pos - _base
	if offset.length() > radius:
		if floating:
			# La base suit le pouce : il reste toujours sur le bord.
			_base = pos - offset.normalized() * radius
		offset = offset.normalized() * radius
	_knob_offset = offset
	_apply_actions(axis_for(offset / radius, dead_zone))
	queue_redraw()


# Déflexion (-1..1 par axe, longueur ≤ 1) → commande : rien sous la zone morte
# radiale, puis la direction exacte du pouce, à pleine force dès la mi-course
# (le personnage marche ou court, il n'a pas de demi-vitesse).
static func axis_for(deflection: Vector2, dead: float) -> Vector2:
	var len: float = deflection.length()
	if len <= dead:
		return Vector2.ZERO
	var dir: Vector2 = deflection / len
	# Aimant léger sur les quatre axes (≈ 7°) : marcher droit sans effort, et
	# un jeu qui lit « haut » en tout-ou-rien ne le reçoit pas d'un tremblement.
	if absf(dir.x) < CARDINAL_SNAP:
		dir.x = 0.0
	if absf(dir.y) < CARDINAL_SNAP:
		dir.y = 0.0
	dir = dir.normalized()
	var strength: float = clampf((len - dead) / maxf(0.5 - dead, 0.01), 0.0, 1.0)
	return dir * maxf(strength, 0.35)


func _apply_actions(axis: Vector2) -> void:
	_set_axis("move_left", "move_right", axis.x)
	_set_axis("move_forward", "move_back", axis.y)
	if _knob_offset.length() >= run_threshold * radius:
		Input.action_press("run")
	elif not external_run_hold:
		Input.action_release("run")


func _set_axis(neg_action: String, pos_action: String, value: float) -> void:
	# Plus de seuil par axe ici (la zone morte est radiale, cf. axis_for) :
	# c'est ce qui donne une direction libre au lieu de huit caps.
	if value < -0.001:
		Input.action_press(neg_action, absf(value))
		Input.action_release(pos_action)
	elif value > 0.001:
		Input.action_press(pos_action, value)
		Input.action_release(neg_action)
	else:
		Input.action_release(neg_action)
		Input.action_release(pos_action)
