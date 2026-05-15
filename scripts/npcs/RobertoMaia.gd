extends NPC

# Roberto Maia : journaliste indépendant qui enquête sur Don Vincenzo.
# Cible de la quête baia_silence_press — le joueur peut le payer, l'intimider,
# ou (rare) le convaincre de changer de cible.

const QUEST_SILENCE: String = "baia_silence_press"
const OBJ_SILENCE: String = "silence_journalist"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = "roberto_default"
	if QuestManager.is_active(QUEST_SILENCE) \
			and not QuestManager.is_objective_done(QUEST_SILENCE, OBJ_SILENCE):
		knot = "roberto_confront"
	elif CampaignManager.has_flag("roberto_silenced"):
		knot = "roberto_silenced"
	DialogueBridge.start_dialogue(data.id, knot)
