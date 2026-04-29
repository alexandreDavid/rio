class_name DialogueSpot
extends Node2D

# Spot interactable static qui affiche une ligne de dialogue ad-hoc via
# DialogueBridge.register_runtime_dialogue + start_dialogue. Utile pour des
# personnages secondaires (mère, grand-mère, voisin) sans créer de NPCData
# ou de script dédié. Le `npc_id` est libre et sert juste à grouper les
# entrées du journal narratif si nécessaire.

@export var npc_id: String = "spot"
@export var speaker: String = "Speaker"
@export_multiline var text: String = "..."
@export var prompt: String = "Parler"
@export var choices: PackedStringArray = PackedStringArray(["D'accord"])

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable == null:
		return
	interactable.prompt = prompt
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	var knot_id: String = "spot_" + npc_id
	var data: Dictionary = {
		"speaker": speaker,
		"text": text,
		"choices": Array(choices),
	}
	DialogueBridge.register_runtime_dialogue(knot_id, data)
	DialogueBridge.start_dialogue(npc_id, knot_id)
