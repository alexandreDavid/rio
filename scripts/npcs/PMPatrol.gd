class_name PMPatrol
extends CharacterBody2D

# Policier en patrouille. Déclenche cop_shakedown probabilistiquement quand le
# joueur entre dans sa zone en portant la charrette.

@export var trigger: POITrigger
@export_range(0.0, 1.0) var chance: float = 0.9
@export var cooldown_seconds: float = 20.0

var _cooldown_until: float = 0.0

func _ready() -> void:
	if trigger == null:
		trigger = get_node_or_null("Trigger") as POITrigger
	if trigger:
		trigger.player_entered.connect(_on_player_entered)
		print("[PMPatrol] connected, chance=%s radius checks trigger=%s" % [chance, trigger])
	# Charge un sprite individuel si présent (assets/sprites/npcs/pm_patrol.png).
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		NPC.try_load_sprite(sprite, "pm_patrol")
	# Permet aux cutscenes de retrouver ce node par groupe.
	add_to_group("pm_patrol")

# Permet aux cutscenes de poser un cooldown après une rencontre scénarisée,
# pour que le random shakedown ne se redéclenche pas immédiatement après.
func set_cooldown(seconds: float) -> void:
	_cooldown_until = Time.get_ticks_msec() / 1000.0 + seconds

func _on_player_entered() -> void:
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	print("[PMPatrol] player entered — cart=%s carrying=%s" % [cart, cart.is_carrying() if cart else "N/A"])
	if cart == null or not cart.is_carrying():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		print("[PMPatrol] cooldown active")
		return
	if randf() > chance:
		_cooldown_until = now + 5.0
		print("[PMPatrol] lucky roll, no shakedown")
		return
	_cooldown_until = now + cooldown_seconds
	print("[PMPatrol] SHAKEDOWN")
	DialogueBridge.start_dialogue("pm", "cop_shakedown")
