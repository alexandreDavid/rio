class_name ReactiveDialogueSpot
extends Node2D

# Variante de DialogueSpot qui choisit le texte en fonction de l'état narratif
# (flags CampaignManager + acte courant). Permet à un personnage statique
# (mère, grand-mère, voisin) de réagir à la progression du joueur sans avoir
# besoin d'un NPC scripté.
#
# `variants` est une liste de Dictionnaires :
#   { "flag": "first_payment_done", "text": "...", "speaker": "...", "choices": [...] }
# La 1re variante dont la condition match est utilisée. La condition peut être :
#   - "flag": un flag CampaignManager qui doit être set
#   - "not_flag": un flag CampaignManager qui doit NE PAS être set
#   - "act": acte minimal requis
# Une variante sans condition (le "default") doit toujours être en dernier.

@export var npc_id: String = "spot"
@export var prompt: String = "Parler"

# Variantes de dialogue. Format ci-dessus. Doit contenir au moins une entrée.
@export var variants: Array[Dictionary] = []

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable == null:
		return
	interactable.prompt = prompt
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	var variant: Dictionary = _pick_variant()
	if variant.is_empty():
		return
	var knot_id: String = "spot_%s_%s" % [npc_id, str(variant.get("id", "default"))]
	var data: Dictionary = {
		"speaker": variant.get("speaker", "Speaker"),
		"text": variant.get("text", "..."),
		"choices": variant.get("choices", ["D'accord"]),
	}
	# Actions post-lecture (choix 0). Raccourcis usuels (set_flag_after, earn_after)
	# + un passthrough `actions` qui permet d'utiliser n'importe quel verbe supporté
	# par DialogueBridge (accept_quest, finish_quest, rep, pay_debt…).
	var post_actions: Dictionary = {}
	var post_flag: String = variant.get("set_flag_after", "")
	if post_flag != "":
		post_actions["set_flag"] = post_flag
	var earn_after: int = int(variant.get("earn_after", 0))
	if earn_after > 0:
		post_actions["earn"] = earn_after
	var passthrough: Dictionary = variant.get("actions", {})
	for k in passthrough:
		post_actions[k] = passthrough[k]
	if not post_actions.is_empty():
		data["on_choose"] = {"0": post_actions}
	DialogueBridge.register_runtime_dialogue(knot_id, data)
	DialogueBridge.start_dialogue(npc_id, knot_id)

# Sélectionne la 1re variante dont la condition est satisfaite (ordre = priorité).
func _pick_variant() -> Dictionary:
	for v in variants:
		if _variant_matches(v):
			return v
	return {}

func _variant_matches(v: Dictionary) -> bool:
	var flag: String = v.get("flag", "")
	if flag != "" and not CampaignManager.has_flag(flag):
		return false
	var not_flag: String = v.get("not_flag", "")
	if not_flag != "" and CampaignManager.has_flag(not_flag):
		return false
	var min_act: int = int(v.get("act", 0))
	if min_act > 0 and CampaignManager.current_act < min_act:
		return false
	return true
