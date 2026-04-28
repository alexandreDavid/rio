extends NPC

# Don Salvatore : boss de São Paulo qui débarque à Santos Dumont.
# Apparaît dans le district SantosDumont uniquement quand la quête de pickup est active.
# Sa première interaction complète l'objectif "meet_at_airport".

const QUEST: String = "consortium_airport_pickup"
const OBJ_MEET: String = "meet_at_airport"
const OBJ_DELIVER: String = "deliver_to_consortium"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # salvatore_intro (par défaut)
	if QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objs.get(OBJ_MEET, false):
			knot = "salvatore_arrival"
		elif not objs.get(OBJ_DELIVER, false):
			knot = "salvatore_waiting"
		else:
			knot = "salvatore_intro"
	elif QuestManager.is_completed(QUEST):
		knot = "salvatore_done"
	DialogueBridge.start_dialogue(data.id, knot)
