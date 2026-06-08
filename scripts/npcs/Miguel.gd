extends NPC

# Miguel — colis de Botafogo (SIDE deliver_package_01). Le rôle de lieutenant
# Tráfico passe désormais par les spots de la voie A, plus par Miguel.

const DELIVERY_QUEST: String = "deliver_package_01"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = NPCAffinity.knot_for_tier(data.id, data.ink_knot,
			"miguel_chat_warm", "miguel_chat_familiar")
	if QuestManager.is_active(DELIVERY_QUEST):
		knot = "miguel_waiting"
	elif QuestManager.is_completed(DELIVERY_QUEST):
		knot = "miguel_done"
	DialogueBridge.start_dialogue(data.id, knot)
