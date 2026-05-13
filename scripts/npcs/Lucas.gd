extends NPC

# Lucas : surfeur carioca à Arpoador. Propose un duel de surf au coucher de
# soleil au joueur. Quête complétée quand le joueur gagne une session de surf
# (cf. SurfLauncher hook pour `lucas_arpoador_surf`).

const QUEST_ID: String = "lucas_arpoador_surf"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot  # "lucas_intro"
	if QuestManager.is_completed(QUEST_ID):
		knot = "lucas_done"
	elif QuestManager.is_active(QUEST_ID):
		knot = "lucas_remind"
	elif QuestManager.is_available(QUEST_ID):
		knot = "lucas_offer"
	DialogueBridge.start_dialogue(data.id, knot)
