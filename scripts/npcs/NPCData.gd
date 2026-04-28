class_name NPCData
extends Resource

# Authored as .tres files in resources/npcs/. Reusable across spawners.

@export var id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var ink_knot: String = ""  # default dialogue entry point
@export var faction: String = ""
