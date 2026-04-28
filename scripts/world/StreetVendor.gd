class_name StreetVendor
extends Node2D

# Marchand ambulant. Une transaction unique : payer X reais, recevoir un effet
# (stamina, rep, ou flag de découverte). Le marchand reste interactable
# (la transaction se répète tant que le joueur a l'argent).

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
		interactable.prompt = "%s — R$ %d" % [item_label, price]

func _on_interact(_by: Node) -> void:
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	if inv.money < price:
		_show_line(flavor_text_broke)
		return
	if not inv.spend_money(price):
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
	_show_line(flavor_text_offer)

func _show_line(text: String) -> void:
	var knot_id: String = "vendor_" + vendor_id
	DialogueBridge.register_runtime_dialogue(knot_id, {
		"speaker": flavor_speaker,
		"text": text,
		"choices": ["Obrigado"],
	})
	DialogueBridge.start_dialogue("vendor", knot_id)
