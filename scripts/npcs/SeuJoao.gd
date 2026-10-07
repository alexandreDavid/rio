extends NPC

# Spécialisation : Seu João (le compadre de Zé, PAS l'oncle) parle différemment selon où il est et où
# en est l'histoire. Dans la maison du morro, il devient le mentor familial qui
# commente les pivots narratifs (1er acompte, reveal du Concierge, choix de voie,
# veille du Carnaval). Sur le calçadão / charrette, il garde son rôle d'origine.

const QUEST_ID: String = "quest_milho_01"
const QUEST_CARNAVAL: String = "act4_carnaval_desfile"

func _ready() -> void:
	# Appel explicite : en Godot 4, override de _ready n'appelle PAS super automatiquement.
	super._ready()
	_apply_visibility()
	# Au chargement d'une save, les flags arrivent APRÈS _ready — on re-évalue
	# pour ne pas rester caché à tort si la save indique que l'héritage est
	# déjà entamé.
	if SaveSystem.has_signal("save_loaded"):
		SaveSystem.save_loaded.connect(_apply_visibility)

func _apply_visibility() -> void:
	# Source fiable : l'état de la quête (auto-persisté). Heritage active ou
	# complétée = le joueur a vu Seu João au moins une fois → visible.
	var heritage_started: bool = QuestManager.is_active("act1_heritage") \
			or QuestManager.is_completed("act1_heritage") \
			or QuestManager.is_active("prologue_pedrinho") \
			or QuestManager.is_completed("prologue_pedrinho") \
			or CampaignManager.has_flag("prologue_started") \
			or CampaignManager.has_flag("intro_bump_seen") \
			or CampaignManager.has_flag("intro_seen") \
			or CampaignManager.has_flag("act1_started")
	visible = heritage_started
	if interactable:
		interactable.enabled = heritage_started

func _on_interacted(_by: Node) -> void:
	if data == null:
		push_warning("SeuJoao: data is null")
		return
	await _approach_player_if_far()
	var knot: String = _pick_knot()
	DialogueBridge.start_dialogue(data.id, knot)

# Depuis le Carnaval : la fierté (une fois), puis le rythme de la semaine —
# la feijoada du samedi, avec Zé à table s'il a été secouru.
func _pos_carnaval_knot() -> String:
	if not CampaignManager.has_flag("seu_joao_carnaval_done_seen"):
		CampaignManager.set_flag("seu_joao_carnaval_done_seen")
		return "seu_joao_carnaval_done"
	if CarnavalCalendar.is_sabado():
		if not _is_at_home():
			return "seu_joao_feijoada_chama"
		if int(CampaignManager.flags.get("feijoada_day", 0)) == TimeOfDay.day_count:
			return "seu_joao_feijoada_after"
		CampaignManager.set_flag("feijoada_day", TimeOfDay.day_count)
		NPCAffinity.bump("seu_joao")
		return "seu_joao_feijoada_ze" if CampaignManager.has_flag("ze_rescued") else "seu_joao_feijoada"
	return "seu_joao_pos_carnaval"

# La feijoada se sert à la table de la maison, pas sur le calçadão.
func _is_at_home() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n.name == "HouseInterior":
			return true
		n = n.get_parent()
	return false

# Décide du knot Ink à jouer selon les états campagne / quête / charrette.
# L'ordre = priorité (le 1er match gagne).
func _pick_knot() -> String:
	# --- PROLOGUE : l'enfant disparu, avant toute la trame ---
	# Tant qu'il n'est pas résolu, Seu João ne parle que de ça. La sortie
	# de la favela est verrouillée en parallèle (DistrictExit).
	if not QuestManager.is_completed("prologue_pedrinho"):
		if QuestManager.is_active("prologue_pedrinho"):
			return "seu_joao_prologue_remind"
		# La quête est donnée par la mère dehors (cutscene MaeAborde), pas ici.
		return "seu_joao_prologue_nudge"

	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart

	# --- Acte 5 (Reinado) : on parle du Carnaval avant tout ---
	if QuestManager.is_active(QUEST_CARNAVAL):
		return "seu_joao_carnaval_remind"
	if QuestManager.is_completed(QUEST_CARNAVAL):
		return _pos_carnaval_knot()
	if QuestManager.is_available(QUEST_CARNAVAL):
		return "seu_joao_carnaval_offer"

	# --- Veille du Carnaval (acte 5 sans encore avoir lancé la quête défilé) ---
	if CampaignManager.current_act == 5:
		return "seu_joao_evening_carnaval_eve"

	# Beats narratifs en attente, dans l'ordre chronologique : si le joueur
	# enchaîne deux pivots (ex. payer 500 puis faire le reveal acte 2 sans rentrer
	# entre les deux), il les rejoue dans l'ordre, un par visite à la maison.

	# --- Soirée du 1er acompte : pivot émotionnel de l'acte 1 (chronologie #1) ---
	if CampaignManager.has_flag("first_payment_done") \
			and not CampaignManager.has_flag("seu_joao_first_payment_seen"):
		CampaignManager.set_flag("seu_joao_first_payment_seen")
		return "seu_joao_evening_first_payment"

	# --- Acte 2+ : Seu João sait que le Concierge est tio Zé (chronologie #2) ---
	if CampaignManager.has_flag("tio_ze_revealed") \
			and not CampaignManager.has_flag("seu_joao_act2_reveal_seen"):
		CampaignManager.set_flag("seu_joao_act2_reveal_seen")
		return "seu_joao_evening_act2_reveal"

	# --- Acte 3 : voie choisie (mentor donne le médaillon) (chronologie #3) ---
	if CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE \
			and not CampaignManager.has_flag("seu_joao_path_chosen_seen"):
		CampaignManager.set_flag("seu_joao_path_chosen_seen")
		return "seu_joao_evening_path_chosen"

	# --- États historiques (charrette / quête milho) ---
	if cart != null and cart.is_carrying():
		return "seu_joao_return"
	if QuestManager.is_active(QUEST_ID):
		return "seu_joao_reminder"
	if not CampaignManager.has_flag("act1_started"):
		# Première rencontre : déclenche l'héritage narratif (acte 1).
		return "seu_joao_heritage"

	# Fallback : ligne neutre, varie selon affinité + phase de la journée.
	return NPCAffinity.knot_for_tier_or_phase(data.id, data.ink_knot,
			"seu_joao_chat_warm", "seu_joao_chat_familiar",
			"seu_joao_chat_morning", "seu_joao_chat_afternoon", "seu_joao_chat_evening")
