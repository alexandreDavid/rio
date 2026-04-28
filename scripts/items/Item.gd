class_name Item
extends Resource

# Authored as .tres files in resources/items/.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var sell_value: int = 0
