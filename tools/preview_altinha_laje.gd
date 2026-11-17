extends SceneTree

# Aperçu de la roda de Juca (altinha, décor « laje », défi 8 toques) :
#   godot --path . -s tools/preview_altinha_laje.gd --write-movie out.png --quit-after 40
func _initialize() -> void:
	var game: Node = (load("res://scenes/minigames/Altinha.tscn") as PackedScene).instantiate()
	game.set("touch_goal", 8)
	game.set("setting", "laje")
	root.add_child.call_deferred(game)
