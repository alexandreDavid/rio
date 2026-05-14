extends NPC

# Bruno : vieux capitaine du ferry Rio↔Niterói. Donneur de deux SIDE :
# bruno_carga (livraison) puis bruno_pesca_baia (mini-jeu pêche au ponton).
# Routage par priorité : carga d'abord, pesca ensuite, fallback affinité.

const CARGA_QUEST: String = "bruno_carga"
const CARGA_OBJ: String = "deliver_to_helena"

const PESCA_QUEST: String = "bruno_pesca_baia"
const PESCA_OBJ: String = "haul_baia"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	DialogueBridge.start_dialogue(data.id, _pick_knot())

func _pick_knot() -> String:
	# Pesca — chaîne SIDE qui démarre après carga complétée.
	if QuestManager.is_completed(PESCA_QUEST):
		return "bruno_pesca_done"
	if QuestManager.is_active(PESCA_QUEST):
		return "bruno_pesca_remind"
	if QuestManager.is_available(PESCA_QUEST):
		return "bruno_pesca_offer"
	# Carga — chaîne SIDE initiale.
	if QuestManager.is_completed(CARGA_QUEST):
		return "bruno_after_carga"
	if QuestManager.is_active(CARGA_QUEST):
		return "bruno_remind"
	if QuestManager.is_available(CARGA_QUEST):
		return "bruno_offer"
	# Fallback affinité.
	return NPCAffinity.knot_for_tier(data.id, "bruno_default",
			"bruno_chat_warm", "bruno_chat_familiar")
