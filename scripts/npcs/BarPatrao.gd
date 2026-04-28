extends NPC

# Patrão do Bar do Policial : recrute le joueur comme serveur (bar_waiter),
# puis propose des shifts payés répétables une fois la quête terminée.

const QUEST: String = "bar_waiter"
const OBJ_SHIFT: String = "first_shift"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # patrao_intro
	if QuestManager.is_completed(QUEST):
		knot = "patrao_shift_offer"
	elif QuestManager.is_active(QUEST):
		knot = "patrao_first_shift"
	DialogueBridge.start_dialogue(data.id, knot)
