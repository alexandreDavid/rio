extends Node2D

# Racine de la Favela : habillage des dalles taguées (terre du morro, végétation,
# quadra). Pas d'AmbientDrifter ici — le drift des vautours vit déjà sur le
# nœud enfant FavelaCollisionGenerator, un second scanner les ferait dériver
# deux fois plus vite.

func _ready() -> void:
	DistrictDresser.dress(self)
	# Comme District.gd : sans tri en Y, tout le morro se dessinait d'un bloc
	# et recouvrait le joueur dès qu'il montait au-dessus de l'origine.
	WorldFx.enable_y_sort(self)
	# Les étiquettes restent lisibles par-dessus les maisons empilées.
	for l in find_children("*", "Label", true, false):
		(l as Label).z_index = 3
