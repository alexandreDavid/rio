extends NPC

# Jorge le videur : fleurs pour Beatriz, accueil de la Contessa, sécurité du gala.

const QUEST_FLOWERS: String = "flowers_for_beatriz"
const QUEST_ESCORT: String = "escort_contessa"
const OBJ_ESCORT_BAR: String = "escort_to_bar"
const QUEST_GALA: String = "act2_contessa_gala"
const GALA_OBJ: String = "secured_security"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot
	# Priorité acte 2 : sécurité du gala.
	if QuestManager.is_active(QUEST_GALA):
		var gala: Dictionary = QuestManager.get_objectives_state(QUEST_GALA)
		if not gala.get(GALA_OBJ, false):
			DialogueBridge.start_dialogue(data.id, "jorge_act2_gala")
			return
	# Priorité acte 1 : si la Contessa attend d'être montrée au bar, Jorge fait le spectacle.
	if QuestManager.is_active(QUEST_ESCORT):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_ESCORT)
		if not objs.get(OBJ_ESCORT_BAR, false):
			DialogueBridge.start_dialogue(data.id, "jorge_escort_arrival")
			return
	if QuestManager.is_completed(QUEST_FLOWERS):
		knot = "jorge_done"
	elif QuestManager.is_active(QUEST_FLOWERS):
		knot = "jorge_remind"
	DialogueBridge.start_dialogue(data.id, knot)
