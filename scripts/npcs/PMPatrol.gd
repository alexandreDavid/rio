class_name PMPatrol
extends CharacterBody2D

# Policier en patrouille. Déclenche cop_shakedown probabilistiquement quand le
# joueur entre dans sa zone en portant la charrette.

@export var trigger: POITrigger
@export_range(0.0, 1.0) var chance: float = 0.9
@export var cooldown_seconds: float = 20.0

# Tarif récurrent (post-1er shakedown) : moins fréquent mais plus cher,
# pour ne pas étouffer le joueur sans pour autant disparaître.
const RECURRING_CHANCE: float = 0.3
const RECURRING_COOLDOWN: float = 90.0

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

# Tarif récurrent par acte. La rente du calçadão s'ajuste à la prospérité.
const BRIBE_BY_ACT: Dictionary = {
	1: {"amount": 50,  "knot": "cop_shakedown_recurring"},
	2: {"amount": 80,  "knot": "cop_shakedown_recurring_act2"},
	3: {"amount": 150, "knot": "cop_shakedown_recurring_act3"},
	4: {"amount": 150, "knot": "cop_shakedown_recurring_act3"},  # acte 4 : même que 3
}

func _bribe_for_current_act() -> Dictionary:
	var act: int = CampaignManager.current_act
	return BRIBE_BY_ACT.get(act, BRIBE_BY_ACT[1])

func _on_player_entered() -> void:
	# Tant que la cinématique du 1er shakedown n'a pas joué, on laisse MainBoot
	# gérer (il déclenche FirstShakedownCutscene quand le joueur a la charrette
	# + 20 R$ + est sur le calçadão). PMPatrol ne fait rien pour ne pas dédoubler.
	if not CampaignManager.has_flag("first_shakedown_played"):
		return
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	if cart == null or not cart.is_carrying():
		return
	if GameManager.player == null:
		return
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	var bribe: Dictionary = _bribe_for_current_act()
	# Argent du pot-de-vin requis : sinon le choix "Payer" est inutile et le
	# joueur n'a plus que la fuite avec malus de réputation. On le laisse passer.
	if inv.money < int(bribe.amount):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		return
	if randf() > RECURRING_CHANCE:
		_cooldown_until = now + 5.0
		return
	_cooldown_until = now + RECURRING_COOLDOWN
	DialogueBridge.start_dialogue("pm", String(bribe.knot))
