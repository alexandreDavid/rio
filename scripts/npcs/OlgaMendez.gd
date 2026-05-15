extends NPC

# Olga Mendez : main droite de Don Vincenzo. Remet le paquet du premier
# passage au joueur. Devient hostile/tense si le joueur refuse le pacto final.

const QUEST_SMUGGLE: String = "baia_smuggle_intro"
const OBJ_PICKUP: String = "pickup_packet"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = "olga_default"
	if QuestManager.is_active(QUEST_SMUGGLE) \
			and not QuestManager.is_objective_done(QUEST_SMUGGLE, OBJ_PICKUP):
		knot = "olga_handover_packet"
	elif CampaignManager.has_flag("baia_pacto_sealed"):
		knot = "olga_after_pacto"
	elif CampaignManager.has_flag("baia_refused"):
		knot = "olga_hostile"
	DialogueBridge.start_dialogue(data.id, knot)
