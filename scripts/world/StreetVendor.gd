class_name StreetVendor
extends Node2D

# Marchand ambulant. Une transaction unique : payer X reais, recevoir un effet
# (stamina, rep, ou flag de découverte). Le marchand reste interactable
# (la transaction se répète tant que le joueur a l'argent).
#
# Jeitinho : chaque achat compte dans NPCAffinity (id « vendor_<vendor_id> »).
# Freguês connu (tier 1) = 1 R$ de moins ; freguês familier (tier 2) =
# « preço de amigo », 2 R$ de moins (plancher 1). La relation se sent au
# comptoir, pas seulement dans les salutations.

@export var vendor_id: String = "generic"
@export var item_label: String = "Água de coco"
@export var price: int = 5
@export var stamina_recover: float = 30.0
@export var rep_axis: int = 3   # TOURIST par défaut
@export var rep_gain: int = 0   # 0 = pas de gain rep
@export var flavor_speaker: String = "Vendedor"
@export_multiline var flavor_text_offer: String = "Água de coco bem fresca, freguês !"
@export_multiline var flavor_text_broke: String = "Volta quando tiveres uns trocados, viu ?"

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interact)
		_refresh_prompt()
	# L'affinité s'incrémente à la fermeture du dialogue d'achat — on
	# rafraîchit le prix affiché à ce moment-là.
	EventBus.dialogue_ended.connect(func(npc_id: String) -> void:
		if npc_id == "vendor_" + vendor_id:
			_refresh_prompt())

# Prix effectif selon le tier d'affinité du marchand (jeitinho au comptoir).
func current_price() -> int:
	var discount: int = NPCAffinity.tier("vendor_" + vendor_id)
	return max(1, price - discount)

func _refresh_prompt() -> void:
	if interactable == null:
		return
	var p: int = current_price()
	if p < price:
		interactable.prompt = "%s — R$ %d (preço de amigo)" % [item_label, p]
	else:
		interactable.prompt = "%s — R$ %d" % [item_label, p]

func _on_interact(_by: Node) -> void:
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	var p: int = current_price()
	if inv.money < p:
		_show_line(flavor_text_broke)
		return
	if not inv.spend_money(p):
		return
	# Effets : stamina, rep, flag de visite.
	if stamina_recover > 0.0 and GameManager.player:
		var stam: Stamina = GameManager.player.get_node_or_null("Stamina") as Stamina
		if stam:
			stam.recover(stamina_recover)
	if rep_gain > 0:
		ReputationSystem.gain_capped(rep_axis, rep_gain, "vendors_" + vendor_id, 5)
	if not CampaignManager.has_flag("vendor_" + vendor_id):
		CampaignManager.set_flag("vendor_" + vendor_id)
	# Le comptoir crée la relation : l'achat compte pour l'affinité du marchand
	# (via dialogue_ended sur « vendor_<id> ») → remises aux prochains passages.
	var line: String = flavor_text_offer
	if current_price() < price:
		line += "\n*il te fait le preço de amigo sans que tu demandes — ici, on connaît ta tête.*"
	_show_line(line)
	_refresh_prompt()

func _show_line(text: String) -> void:
	var knot_id: String = "vendor_" + vendor_id
	DialogueBridge.register_runtime_dialogue(knot_id, {
		"speaker": flavor_speaker,
		"text": text,
		"choices": ["Obrigado"],
	})
	DialogueBridge.start_dialogue("vendor_" + vendor_id, knot_id)
