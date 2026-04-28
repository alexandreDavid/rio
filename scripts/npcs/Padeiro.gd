extends NPC

# Seu Tonio, padeiro de la Padaria São Sebastião.
# Vente courante + livraison à Dona Irene + aprentissage de fournée (minijeu) après la livraison.

const QUEST: String = "padaria_delivery"
const OBJ: String = "deliver_bread"
const QUEST_BAKING: String = "padaria_baking"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	var knot: String = data.ink_knot  # padaria_intro
	if QuestManager.is_active(QUEST):
		# Quête à objectif unique : auto-complétée à la livraison, donc 'active' = pas livré.
		knot = "padaria_remind"
	elif QuestManager.is_active(QUEST_BAKING):
		knot = "padaria_baking_remind"
	elif QuestManager.is_completed(QUEST_BAKING):
		# Menu standard : la borne de fournil reste dispo via le prop dédié.
		knot = "padaria_intro"
	elif QuestManager.is_available(QUEST_BAKING) and QuestManager.is_completed(QUEST):
		# Première livraison faite → propose la formation fournil.
		knot = "padaria_baking_offer"
	# Sinon (UNAVAILABLE / AVAILABLE first quest / COMPLETED first quest) : menu standard.
	DialogueBridge.start_dialogue(data.id, knot)
