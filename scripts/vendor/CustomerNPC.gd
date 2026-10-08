class_name CustomerNPC
extends NPC

# Client de la plage. Une vente par client et par tournée : après achat, le
# dialogue change ("já comprei") jusqu'à la prochaine prise de la carrocinha ou
# la phase suivante de la journée (playtest 2026-10-07, F5 : les 3 clients
# n'achetaient qu'une fois pour toute la partie — 15 R$ de milho en acte 1).

enum Archetype { TOURIST, LOCAL, KID }

const KNOTS := {
	Archetype.TOURIST: "haggle_with_tourist",
	Archetype.LOCAL: "haggle_with_local",
	Archetype.KID: "kid_asks",
}

const REGIONS := {
	Archetype.TOURIST: {"region": Rect2(774, 53, 180, 196), "scale": 0.246},  # row 0 col 3
	Archetype.LOCAL: {"region": Rect2(85, 53, 136, 196), "scale": 0.246},     # row 0 col 0
	Archetype.KID: {"region": Rect2(792, 512, 146, 256), "scale": 0.1875},    # row 2 col 3
}

# Mapping archétype → ID de sprite individuel (assets/sprites/npcs/<id>.png).
const ARCHETYPE_IDS := {
	Archetype.TOURIST: "customer_tourist",
	Archetype.LOCAL:   "customer_local",
	Archetype.KID:     "customer_kid",
}

@export var archetype: int = Archetype.LOCAL

var has_purchased: bool = false

func _ready() -> void:
	super._ready()
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.time_of_day_changed.connect(func(_phase: int) -> void: has_purchased = false)
	EventBus.corn_cart_state_changed.connect(func(carrying: bool) -> void:
		if carrying:
			has_purchased = false)
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	# Priorité : sprite individuel par archétype.
	var sprite_id: String = ARCHETYPE_IDS.get(archetype, "customer_local")
	if NPC.try_load_sprite(sprite, sprite_id):
		return
	# Fallback : région d'atlas historique selon l'archétype.
	var info: Dictionary = REGIONS.get(archetype, REGIONS[Archetype.TOURIST])
	sprite.region_rect = info["region"]
	var s: float = info["scale"]
	sprite.scale = Vector2(s, s)

func _get_id() -> String:
	return data.id if data else "customer_%s" % name

func _on_customer_served(npc_id: String) -> void:
	if npc_id == _get_id():
		has_purchased = true

func _on_interacted(_by: Node) -> void:
	if has_purchased:
		DialogueBridge.start_dialogue(_get_id(), "customer_satisfied")
		return
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	if cart == null or not cart.is_carrying() or cart.stock <= 0:
		return
	var knot: String = KNOTS.get(archetype, "haggle_with_local")
	DialogueBridge.start_dialogue(_get_id(), knot)
