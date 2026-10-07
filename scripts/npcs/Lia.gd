extends NPC

# Professora Lia : l'escolinha de vela de la Marina da Glória (projet social —
# les gosses du morro apprennent à lire le vent). Donne « Vela pro Pedrinho » :
# finir la Regata prouve qu'on peut parrainer le gamin du prologue.

const QUEST_ID: String = "vela_pedrinho"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	DialogueBridge.start_dialogue(data.id, _pick_knot())

func _pick_knot() -> String:
	if QuestManager.is_completed(QUEST_ID):
		return "lia_done"
	if QuestManager.is_active(QUEST_ID):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST_ID)
		return "lia_inscrever" if objs.get("terminar_regata", false) else "lia_remind"
	if QuestManager.is_available(QUEST_ID):
		return "lia_offer"
	return "lia_intro"
