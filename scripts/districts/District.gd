class_name District
extends AmbientDrifter

# Base des racines de district : drift décoratif (AmbientDrifter) + habillage
# des dalles de sol taguées (DistrictDresser). Les scripts de district
# spécifiques (portes d'intérieur…) étendent cette classe ; une scène sans
# logique propre pointe directement sur ce script.

func _ready() -> void:
	super._ready()
	DistrictDresser.dress(self)
