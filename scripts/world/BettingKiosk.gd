class_name BettingKiosk
extends Node2D

# Kiosque APOSTAS de l'Hipódromo da Gávea. Le joueur mise un montant fixe ;
# 40% de chances de gagner ×2 le montant. Le script gère les fonds via
# Inventory et affiche le résultat via DialogueBridge.

@export var bet_amount: int = 20
@export var npc_id: String = "apostador"
@export var speaker: String = "Apostador"

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable == null:
		return
	interactable.prompt = "Parier %d R$" % bet_amount
	interactable.interacted.connect(_on_interacted)

func _on_interacted(by: Node) -> void:
	if by == null:
		return
	var inv: Inventory = (by as Node).get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	if inv.money < bet_amount:
		_show("nofunds",
			"*ferme son guichet d'un coup sec* Pas assez de fonds, sobrinho. Reviens avec au moins %d reais en poche." % bet_amount,
			["Compris"])
		return
	# Mise prise immédiatement, puis résolution aléatoire.
	if not inv.spend_money(bet_amount):
		return
	var roll: float = randf()
	var won: bool = roll < 0.4
	var payout: int = bet_amount * 2 if won else 0
	if won:
		inv.add_money(payout)
		_show("win",
			"*frappe le comptoir, large sourire* Le numéro 4 par deux longueurs ! %d reais pour toi, freguês. La prochaine course dans dix minutes." % payout,
			["Obrigado"])
	else:
		_show("lose",
			"*déchire le ticket d'un mouvement sec* L'outsider a craqué dans le dernier virage. C'est ça les paris, sobrinho. Tu retentes ?",
			["Une autre fois"])

func _show(knot_suffix: String, text: String, choices: Array) -> void:
	var knot_id: String = "bet_kiosk_" + knot_suffix
	var data: Dictionary = {
		"speaker": speaker,
		"text": text,
		"choices": choices,
	}
	DialogueBridge.register_runtime_dialogue(knot_id, data)
	DialogueBridge.start_dialogue(npc_id, knot_id)
