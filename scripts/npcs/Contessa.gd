extends NPC

# Contessa Bianchi : escort acte 1 + gala acte 2 + date privée (side, après gala)
# + « O fundo do gala » (acte 3+) : filature de Ferretti, carrefour à 3 issues.
# Pendant escort_contessa, elle suit physiquement le joueur (start_following).

const QUEST: String = "escort_contessa"
const OBJ_BAR: String = "escort_to_bar"
const OBJ_BACK: String = "escort_back_to_palace"
const QUEST_GALA: String = "act2_contessa_gala"
const QUEST_DATE: String = "contessa_date"
const QUEST_FUNDO: String = "contessa_fundo"

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
	DialogueBridge.start_dialogue(data.id, _pick_knot())

# L'ordre = priorité (le 1er match gagne).
func _pick_knot() -> String:
	# --- O fundo do gala (acte 3+) : l'arc d'après le gala ---
	if QuestManager.is_active(QUEST_FUNDO):
		var fundo: Dictionary = QuestManager.get_objectives_state(QUEST_FUNDO)
		if not fundo.get("filer_ferretti", false):
			return "contessa_fundo_remind_filer"
		if not fundo.get("ecouter_colombo", false):
			return "contessa_fundo_remind_colombo"
		return "contessa_fundo_reveal"
	if QuestManager.is_completed(QUEST_FUNDO):
		# Le bairro l'a adoptée : le samedi, elle redescend de la feijoada.
		if CampaignManager.has_flag("contessa_publica"):
			if CampaignManager.has_flag("pos_carnaval") and CarnavalCalendar.is_sabado():
				return "contessa_feijoada"
			return "contessa_fundo_after_publica"
		if CampaignManager.has_flag("contessa_discreta"):
			return "contessa_fundo_after_discreta"
		return "contessa_fundo_after_vendida"
	# Side quest : date privée après le gala (priorité haute si active).
	if QuestManager.is_active(QUEST_DATE):
		return "contessa_date_remind"
	if QuestManager.is_available(QUEST_FUNDO):
		return "contessa_fundo_offer"
	if QuestManager.is_completed(QUEST_DATE):
		return "contessa_date_done_smitten" if CampaignManager.has_flag("contessa_smitten") else "contessa_date_done"
	if QuestManager.is_available(QUEST_DATE) and QuestManager.is_completed(QUEST_GALA):
		return "contessa_date_offer"
	# Acte 2 : gala (prend le pas s'il est dispo).
	if QuestManager.is_active(QUEST_GALA):
		return "contessa_act2_remind"
	if QuestManager.is_completed(QUEST_GALA):
		return "contessa_act2_done"
	if QuestManager.is_available(QUEST_GALA):
		return "contessa_act2_offer"
	if QuestManager.is_completed(QUEST):
		return "contessa_farewell"
	if QuestManager.is_active(QUEST):
		var objs: Dictionary = QuestManager.get_objectives_state(QUEST)
		if not objs.get(OBJ_BAR, false):
			return "contessa_waiting"
		return "contessa_back_at_palace"
	# Pas encore active : on gère le gating CHARISMA ici.
	var charisma: int = ReputationSystem.get_value(ReputationSystem.Axis.CHARISMA)
	if charisma < CHARISMA_THRESHOLD:
		return "contessa_snob"
	return data.ink_knot if data != null else "contessa_intro"
