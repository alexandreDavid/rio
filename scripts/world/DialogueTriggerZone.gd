class_name DialogueTriggerZone
extends Area2D

# Zone invisible qui fait venir un dialogue AU joueur quand il la traverse —
# généralisation de MaePrologueTrigger (ingrédient n°1 du prologue Pedrinho :
# le donneur vient à toi, pas de panneau de quête). Une fois déclenchée, pose
# `fired_flag` et ne rejoue plus jamais.
#
# Conditions optionnelles : `required_flag` (ex. la voie scellée) et
# `quest_active` (ex. la 1re mission de chaîne en cours). Le dialogue est un
# knot runtime — mêmes clés qu'une variante de ReactiveDialogueSpot (speaker,
# text, choices, actions passées à DialogueBridge sur le choix 0).

@export var npc_id: String = "trigger"
@export var speaker: String = ""
@export_multiline var text: String = ""
@export var choices: Array[String] = ["…"]
@export var actions: Dictionary = {}
@export var required_flag: String = ""
@export var quest_active: String = ""
@export var fired_flag: String = ""  # obligatoire : garantit le une-seule-fois (persisté)

func _ready() -> void:
	collision_mask = 1  # couche du joueur (PlayerController)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if fired_flag == "" or CampaignManager.has_flag(fired_flag):
		return
	if required_flag != "" and not CampaignManager.has_flag(required_flag):
		return
	if quest_active != "" and not QuestManager.is_active(quest_active):
		return
	if DialogueBridge.is_active() or CutsceneRunner.is_running():
		return  # ne coupe jamais une scène en cours ; on rejouera au prochain passage
	CampaignManager.set_flag(fired_flag)
	var knot_id: String = "trigger_%s_%s" % [npc_id, fired_flag]
	var data: Dictionary = {
		"speaker": speaker if speaker != "" else npc_id,
		"text": text,
		"choices": choices,
	}
	if not actions.is_empty():
		data["on_choose"] = {"0": actions}
	DialogueBridge.register_runtime_dialogue(knot_id, data)
	DialogueBridge.start_dialogue(npc_id, knot_id)
