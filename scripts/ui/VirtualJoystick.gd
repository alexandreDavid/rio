class_name VirtualJoystick
extends Control

# Joystick virtuel : injecte les actions "move_left/right/forward/back" via
# Input.action_press/release. Fonctionne en tactile ET en souris (desktop).

@export var radius: float = 80.0
@export var dead_zone: float = 0.25

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2, radius * 2)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, Color(0, 0, 0, 0.35))
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
	draw_circle(center + _knob_offset, radius * 0.42, Color(1, 1, 1, 0.55))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event.position, event.pressed, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(event.position, event.pressed, 0)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)
	elif event is InputEventMouseMotion and _touch_index == 0:
		_update_knob(event.position)

func _on_touch(pos: Vector2, pressed: bool, index: int) -> void:
	if pressed and _touch_index == -1:
		_touch_index = index
		_update_knob(pos)
	elif not pressed and index == _touch_index:
		_touch_index = -1
		_knob_offset = Vector2.ZERO
		_apply_actions(Vector2.ZERO)
		queue_redraw()

func _update_knob(pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = pos - center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob_offset = offset
	_apply_actions(offset / radius)
	queue_redraw()

func _apply_actions(axis: Vector2) -> void:
	_set_axis("move_left", "move_right", axis.x)
	_set_axis("move_forward", "move_back", axis.y)

func _set_axis(neg_action: String, pos_action: String, value: float) -> void:
	if value < -dead_zone:
		Input.action_press(neg_action, absf(value))
		Input.action_release(pos_action)
	elif value > dead_zone:
		Input.action_press(pos_action, value)
		Input.action_release(neg_action)
	else:
		Input.action_release(neg_action)
		Input.action_release(pos_action)
