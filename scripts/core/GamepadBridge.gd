class_name GamepadBridge
extends Node

# Autoload « Gamepad » : rend tout le jeu jouable à la manette (Switch, Steam
# Deck, iPad + manette) sans toucher aux 18 mini-jeux un par un. Le stick
# gauche est branché dans l'InputMap (move_*) ; les boutons sont traduits en
# touches clavier équivalentes que le jeu sait déjà lire (E, Shift, P, J,
# flèches pour les jeux de rythme). Dans un menu (un bouton a le focus), A et
# B deviennent ui_accept / ui_cancel et la croix navigue nativement.
#
# Disposition : A = action · B = courir (tenir) / retour · X = Espace (service)
# · Y ou Start = téléphone · Select = Diário · gâchettes = courir.

signal mode_changed(gamepad: bool)

# Lu par les UI (InputHints, MobileControls) sans dépendre de l'autoload.
static var active: bool = false

# Marqueur des événements synthétisés : ils ne doivent pas faire basculer le
# mode ni être retraduits.
const SYNTH_DEVICE: int = 77

const BUTTON_KEYS: Dictionary = {
	JOY_BUTTON_B: KEY_SHIFT,
	JOY_BUTTON_X: KEY_SPACE,
	JOY_BUTTON_Y: KEY_P,
	JOY_BUTTON_START: KEY_P,
	JOY_BUTTON_BACK: KEY_J,
	JOY_BUTTON_LEFT_SHOULDER: KEY_SHIFT,
	JOY_BUTTON_RIGHT_SHOULDER: KEY_SHIFT,
}
const DPAD_KEYS: Dictionary = {
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
	JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
	JOY_BUTTON_DPAD_UP: KEY_UP,
	JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
}
const TRIGGER_THRESHOLD: float = 0.5

# Ce qui a été envoyé à l'appui, pour relâcher exactement la même chose même
# si le focus a changé entre-temps (bouton -> InputEvent synthétisé).
var _held: Dictionary = {}
var _trigger_down: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and Input.get_connected_joypads().is_empty():
		_set_active(false)


func _input(event: InputEvent) -> void:
	if event.device == SYNTH_DEVICE:
		return
	if event is InputEventJoypadButton:
		_set_active(true)
		_on_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = event
		if absf(m.axis_value) > 0.4:
			_set_active(true)
		if m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT:
			_on_trigger(m)
	elif event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey:
		if event.is_pressed():
			_set_active(false)


func _on_button(b: InputEventJoypadButton) -> void:
	var id: int = b.button_index
	if b.pressed:
		if _held.has(id):
			return
		var ev: InputEvent = _translate(id)
		if ev == null:
			return
		_held[id] = ev
		_send(ev, true)
	elif _held.has(id):
		_send(_held[id], false)
		_held.erase(id)


func _translate(id: int) -> InputEvent:
	var in_menu: bool = _menu_has_focus()
	if id == JOY_BUTTON_A:
		return _action("ui_accept") if in_menu else _key(KEY_E)
	if id == JOY_BUTTON_B and in_menu:
		return _action("ui_cancel")
	if DPAD_KEYS.has(id):
		# Dans un menu, la croix navigue déjà (ui_* natifs) : ne pas doubler.
		return null if in_menu else _key(DPAD_KEYS[id])
	if BUTTON_KEYS.has(id):
		return _key(BUTTON_KEYS[id])
	return null


func _on_trigger(m: InputEventJoypadMotion) -> void:
	var down: bool = m.axis_value > TRIGGER_THRESHOLD
	if down == bool(_trigger_down.get(m.axis, false)):
		return
	_trigger_down[m.axis] = down
	_send(_key(KEY_SHIFT), down)


func _key(code: int) -> InputEventKey:
	var k: InputEventKey = InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	return k


func _action(name: String) -> InputEventAction:
	var a: InputEventAction = InputEventAction.new()
	a.action = name
	return a


func _send(template: InputEvent, pressed: bool) -> void:
	var ev: InputEvent = template.duplicate()
	ev.device = SYNTH_DEVICE
	if ev is InputEventKey:
		(ev as InputEventKey).pressed = pressed
	elif ev is InputEventAction:
		(ev as InputEventAction).pressed = pressed
	Input.parse_input_event(ev)


func _menu_has_focus() -> bool:
	var owner: Control = get_viewport().gui_get_focus_owner()
	return owner != null and owner.is_visible_in_tree()


func _set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	_apply_focus_style(on)
	if on:
		# Un menu déjà ouvert (groupe gamepad_menu) devient navigable tout de suite.
		for menu in get_tree().get_nodes_in_group("gamepad_menu"):
			if menu is CanvasItem and (menu as CanvasItem).is_visible_in_tree():
				focus_first(menu)
				break
	else:
		var owner: Control = get_viewport().gui_get_focus_owner()
		if owner:
			owner.release_focus()
	mode_changed.emit(on)


# Le cadre de focus n'est visible qu'à la manette : au doigt, le bouton tapé
# garderait sinon un liseré doré.
func _apply_focus_style(on: bool) -> void:
	var theme: Theme = UITheme.build()
	var box: StyleBox = UITheme.frame_box(UITheme.GOLD, Color(0, 0, 0, 0), 10, 6) if on else StyleBoxEmpty.new()
	for type in ["Button", "TouchButton", "PixelButton", "CheckBox", "CheckButton", "OptionButton"]:
		theme.set_stylebox("focus", type, box)


# Donne le focus au premier bouton visible sous `root` (menus, téléphone) —
# seulement à la manette, et seulement si rien n'a déjà le focus dedans.
static func focus_first(root: Node) -> void:
	if not active or root == null or not root.is_inside_tree():
		return
	var owner: Control = root.get_viewport().gui_get_focus_owner()
	if owner != null and owner.is_visible_in_tree() and root.is_ancestor_of(owner):
		return
	var btn: BaseButton = _first_button(root)
	if btn:
		btn.grab_focus()


# Retour haptique : vibration de la manette si elle est en main, sinon du
# téléphone (iOS/Android). `strength` 0-1, `duration` en secondes.
static func pulse(strength: float, duration: float) -> void:
	if active:
		for pad in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, strength * 0.6, strength, duration)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration * 1000.0), clampf(strength, 0.1, 1.0))


# Les boutons du HUD et des contrôles tactiles ne prennent jamais le focus :
# sinon A, au lieu d'interagir, rappuierait sur le dernier bouton touché.
static func no_focus(root: Node) -> void:
	if root is BaseButton:
		(root as BaseButton).focus_mode = Control.FOCUS_NONE
	for c in root.get_children():
		no_focus(c)


static func _first_button(n: Node) -> BaseButton:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return null
	if n is BaseButton:
		var b: BaseButton = n
		if b.focus_mode != Control.FOCUS_NONE and not b.disabled:
			return b
	for c in n.get_children():
		var found: BaseButton = _first_button(c)
		if found:
			return found
	return null
