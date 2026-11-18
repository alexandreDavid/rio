class_name BeachZone
extends RefCounted

# Où peut-on lancer une roda d'altinha ? Les pieds dans le sable d'une plage
# jouable. Partagé par le bouton ⚽ tactile, la touche Espace / Ⓧ et les
# astuces contextuelles.

const Cfg = preload("res://scripts/world/CopacabanaConfig.gd")
const SAND_TOP_Y: float = 128.0

# Plages jouables hors Copa : district → bande de sable locale (l'altinha se
# joue partout où il y a du sable et du monde — Ipanema, Icaraí).
const BEACH_BANDS: Dictionary = {
	"zona_sul": {"x": [-900.0, 900.0], "y": [104.0, 196.0]},
	"niteroi": {"x": [890.0, 1690.0], "y": [-36.0, 116.0]},
}


static func altinha_here() -> bool:
	var p: Node = GameManager.player
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return false
	if p.has_method("is_mounted") and p.is_mounted():
		return false
	var pos: Vector2 = (p as Node2D).global_position
	var district: String = DistrictManager.current()
	if district == "copacabana":
		return pos.y >= SAND_TOP_Y and pos.y <= Cfg.shore_y(pos.x)
	if not BEACH_BANDS.has(district):
		return false
	# Bande locale au district → conversion via l'offset du nœud district.
	var dnode: Node = DistrictManager._find_district_node(district)
	if not (dnode is Node2D):
		return false
	var local: Vector2 = pos - (dnode as Node2D).global_position
	var band: Dictionary = BEACH_BANDS[district]
	return local.x >= band.x[0] and local.x <= band.x[1] \
		and local.y >= band.y[0] and local.y <= band.y[1]
