extends Node

# Autoload: garde la position de sortie à utiliser quand le joueur quitte
# un intérieur. Permet à plusieurs bâtiments de partager une même scène
# d'intérieur tout en renvoyant le joueur devant le bon bâtiment.

var last_exit_position: Vector2 = Vector2.ZERO

# Le joueur est-il dans un intérieur ? Posé par BuildingDoor (entrée/sortie),
# remis à false par DistrictManager (un taxi téléporte toujours dehors).
# Sert aux systèmes qui ne doivent pas frapper en lieu privé
# (CreditorVisitManager : pas de cobrador dans le salon de la mère).
var is_inside: bool = false
