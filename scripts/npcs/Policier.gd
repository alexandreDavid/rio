extends NPC

const QUEST: String = "police_report"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	# Priorité quête : offer/remind/done écrasent toujours le chat d'ambiance.
	# Sinon le joueur restait coincé sur les knots `policier_chat_*` sans
	# jamais voir l'offre (la quête était de fait infaisable).
	var knot: String = ""
	if QuestManager.is_completed(QUEST):
		knot = "policier_done"
	elif QuestManager.is_active(QUEST):
		knot = "policier_remind"
	elif QuestManager.is_available(QUEST):
		knot = data.ink_knot  # `policier_intro` → `policier_offer` via `next`
	else:
		knot = NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
				"", "",
				"policier_chat_morning", "policier_chat_afternoon", "policier_chat_evening")
	DialogueBridge.start_dialogue(data.id, knot)
