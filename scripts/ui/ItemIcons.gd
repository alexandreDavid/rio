class_name ItemIcons
extends RefCounted

# Catalogue des 12 icônes d'objets de `assets/sprites/props_ai.png` (vraie
# transparence ; la variante `props_ai_clean.png` a un damier incrusté et ne
# doit pas être utilisée). Régions mesurées par segmentation alpha le
# 2026-10-07. Rien ne les affiche encore : elles attendent le HUD, le Diário
# ou les Conquistas (milho = carrocinha, posto = bouée, água de coco…).

const TEXTURE: String = "res://assets/sprites/props_ai.png"
const REGIONS: Dictionary = {
	"carrocinha_milho": Rect2(70, 102, 259, 229),
	"anel": Rect2(464, 133, 179, 141),
	"boia_volei": Rect2(795, 102, 213, 204),
	"agua_de_coco": Rect2(1168, 80, 162, 219),
	"violao": Rect2(1491, 65, 229, 258),
	"chapeu_palha": Rect2(1839, 109, 246, 182),
	"canga": Rect2(83, 422, 212, 202),
	"mala": Rect2(445, 413, 206, 203),
	"apito": Rect2(795, 429, 213, 171),
	"encomenda": Rect2(1160, 422, 204, 202),
	"chave": Rect2(1516, 422, 187, 201),
	"reais": Rect2(1864, 422, 200, 194),
}


static func texture(id: String) -> AtlasTexture:
	if not REGIONS.has(id):
		push_warning("[ItemIcons] icône inconnue : " + id)
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = load(TEXTURE)
	atlas.region = REGIONS[id]
	return atlas
