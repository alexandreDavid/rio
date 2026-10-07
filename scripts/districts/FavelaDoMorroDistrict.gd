extends Node2D

# Racine de la Favela : habillage des dalles taguées (terre du morro, végétation,
# quadra). Pas d'AmbientDrifter ici — le drift des vautours vit déjà sur le
# nœud enfant FavelaCollisionGenerator, un second scanner les ferait dériver
# deux fois plus vite.

func _ready() -> void:
	DistrictDresser.dress(self)
