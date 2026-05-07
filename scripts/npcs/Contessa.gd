extends NPC

# Contessa Bianchi : escort acte 1 + gala acte 2 + date privée (side, après gala).
# Pendant escort_contessa, elle suit physiquement le joueur (start_following).

const QUEST: String = "escort_contessa"
const OBJ_BAR: String = "escort_to_bar"
const OBJ_BACK: String = "escort_back_to_palace"
const QUEST_GALA: String = "act2_contessa_gala"
const QUEST_DATE: String = "contessa_date"

# Seuil de charisme en dessous duquel elle refuse d'être vue avec le joueur.
const CHARISMA_THRESHOLD: int = 10

func _ready() -> void:
	super._ready()
	EventBus.quest_accepted.connect(_on_quest_event)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.quest_failed.connect(_on_quest_event)
	# Reprend l'escort si la quête était déjà active au chargement de la save.
	_sync_follow_state()

func _on_quest_event(_quest_id: String) -> void:
	_sync_follow_state()

func _sync_follow_state() -> void:
	if QuestManager.is_active(QUEST):
		start_following()
	else:
		stop_following()

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	var knot: String = data.ink_knot  # contessa_intro
	# Side quest : date privée après le gala (priorité haute si proposée/active).
	if QuestManager.is_active(QUEST_DATE):
		knot = "contessa_date_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST_DATE):
		# Si le joueur a la flag contessa_smitten, dialogue un peu différent.
		if CampaignManager.has_flag("contessa_smitten"):
			knot = "contessa_date_done_smitten"
		else:
			knot = "contessa_date_done"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_available(QUEST_DATE) and QuestManager.is_completed(QUEST_GALA):
		knot = "contessa_date_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	# Acte 2 : gala (prend le pas s'il est dispo).
	if QuestManager.is_active(QUEST_GALA):
		knot = "contessa_act2_remind"
	elif QuestManager.is_completed(QUEST_GALA):
		knot = "contessa_act2_done"
	elif QuestManager.is_available(QUEST_GALA):
		knot = "contessa_act2_offer"
	elif QuestManager.is_completed(QUEST):
		knot = "contessa_farewell"
	elif QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if objs.get(OBJ_BAR, false) and not objs.get(OBJ_BACK, false):
			knot = "contessa_back_at_palace"
		elif not objs.get(OBJ_BAR, false):
			knot = "contessa_waiting"
		else:
			knot = "contessa_back_at_palace"
	else:
		# Pas encore active : on gère le gating CHARISMA ici.
		var charisma: int = ReputationSystem.get_value(ReputationSystem.Axis.CHARISMA)
		if charisma < CHARISMA_THRESHOLD:
			knot = "contessa_snob"
	DialogueBridge.start_dialogue(data.id, knot)
