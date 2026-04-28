class_name Viewpoint
extends Node2D

# Point de vue / mirante interactif. Récompense unique au premier passage
# (CampaignManager.set_flag), plus une mini-réputation TOURIST. Réinteragir
# n'apporte rien — c'est juste de la mise en valeur du lieu. La flag se nomme
# "viewpoint_<id>", lue par DialogueBridge ou autres scripts au besoin.

@export var viewpoint_id: String = "generic"
@export var prompt_first: String = "Admirer la vue"
@export var prompt_done: String = "Vue admirée"
@export var flavor_speaker: String = "Sobrinho"
@export_multiline var flavor_text: String = "Une vue à couper le souffle."
@export var money_reward: int = 50

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interact)
		_refresh_prompt()

func _refresh_prompt() -> void:
	if interactable == null:
		return
	interactable.prompt = prompt_done if _is_done() else prompt_first

func _is_done() -> bool:
	return CampaignManager.has_flag(_flag_name())

func _flag_name() -> String:
	return "viewpoint_" + viewpoint_id

func _on_interact(_by: Node) -> void:
	if _is_done():
		# Affichage flavor texte seul, pas de récompense.
		_show_flavor()
		return
	CampaignManager.set_flag(_flag_name())
	if money_reward > 0 and GameManager.player:
		var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
		if inv:
			inv.add_money(money_reward)
	ReputationSystem.gain_capped(ReputationSystem.Axis.TOURIST, 1, "viewpoints", 8)
	_show_flavor()
	_refresh_prompt()

func _show_flavor() -> void:
	# On utilise DialogueBridge pour avoir une bulle propre, même sans NPC.
	var knot_id: String = "viewpoint_" + viewpoint_id
	# On injecte temporairement le contenu — knot éphémère, pas besoin d'entrée
	# statique dans PLACEHOLDER_DIALOGUES.
	DialogueBridge.register_runtime_dialogue(knot_id, {
		"speaker": flavor_speaker,
		"text": flavor_text,
		"choices": ["Continuer"],
	})
	DialogueBridge.start_dialogue("viewpoint", knot_id)
