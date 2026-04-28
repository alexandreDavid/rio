extends NPC

# Dona Irene : quête lost_dog (retrouver Bingo) puis job répétable de promenade.
# Reçoit aussi le pain de Seu Tonio si la quête padaria_delivery est active.

const QUEST: String = "lost_dog"
const OBJ_FIND: String = "find_dog"
const OBJ_RETURN: String = "return_dog"
const QUEST_BREAD: String = "padaria_delivery"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	# Priorité one-shot : la livraison du pain prime sur tout le reste tant qu'elle est en cours.
	if QuestManager.is_active(QUEST_BREAD):
		DialogueBridge.start_dialogue(data.id, "irene_receives_bread")
		return
	var knot: String = data.ink_knot  # irene_intro
	if QuestManager.is_completed(QUEST):
		knot = "irene_walk_offer"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if objs.get(OBJ_FIND, false) and not objs.get(OBJ_RETURN, false):
			knot = "irene_receives_dog"
		else:
			knot = "irene_remind"
	DialogueBridge.start_dialogue(data.id, knot)
