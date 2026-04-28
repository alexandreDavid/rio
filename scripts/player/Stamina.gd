class_name Stamina
extends Node

@export var max_value: float = 100.0
var current: float

func _ready() -> void:
	current = max_value

func drain(amount: float) -> void:
	current = max(0.0, current - amount)

func recover(amount: float) -> void:
	current = min(max_value, current + amount)

func is_exhausted() -> bool:
	return current <= 0.0

func ratio() -> float:
	return current / max_value if max_value > 0.0 else 0.0
