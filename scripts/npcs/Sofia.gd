extends NPC

# Sofia : touriste japonaise au pied du bondinho. Veut un guide pour le
# sommet du Pão de Açúcar. Quête complétée quand le joueur arrive au
# district pao_acucar avec la quête active.

const QUEST_ID: String = "sofia_bondinho_tour"
const OBJECTIVE_ID: String = "guide_to_summit"

func _ready() -> void:
	super._ready()
	# Listen au district_changed pour cocher l'objectif quand le joueur monte
	# au sommet via le bondinho.
	DistrictManager.district_changed.connect(_on_district_changed)

func _on_district_changed(district_id: String) -> void:
	if district_id == "pao_acucar" and QuestManager.is_active(QUEST_ID):
		QuestManager.complete_objective(QUEST_ID, OBJECTIVE_ID)

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot
	if QuestManager.is_completed(QUEST_ID):
		knot = "sofia_done"
	elif QuestManager.is_active(QUEST_ID):
		knot = "sofia_remind"
	elif QuestManager.is_available(QUEST_ID):
		knot = "sofia_offer"
	DialogueBridge.start_dialogue(data.id, knot)
