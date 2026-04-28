extends Node

# Autoload: garde la position de sortie à utiliser quand le joueur quitte
# un intérieur. Permet à plusieurs bâtiments de partager une même scène
# d'intérieur tout en renvoyant le joueur devant le bon bâtiment.

var last_exit_position: Vector2 = Vector2.ZERO
