extends NPC

# Spécialisation : tio Zé (Seu João) parle différemment selon où il est et où
# en est l'histoire. Dans la maison du morro, il devient le mentor familial qui
# commente les pivots narratifs (1er acompte, reveal du Concierge, choix de voie,
# veille du Carnaval). Sur le calçadão / charrette, il garde son rôle d'origine.

const QUEST_ID: String = "quest_milho_01"
const QUEST_INTEL: String = "act3_policia_intel"
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

# Décide du knot Ink à jouer selon les états campagne / quête / charrette.
# L'ordre = priorité (le 1er match gagne).
func _pick_knot() -> String:
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart

	# --- Acte 4 : on parle du Carnaval avant tout ---
	if QuestManager.is_active(QUEST_CARNAVAL):
		return "seu_joao_carnaval_remind"
	if QuestManager.is_completed(QUEST_CARNAVAL):
		return "seu_joao_carnaval_done"
	if QuestManager.is_available(QUEST_CARNAVAL):
		return "seu_joao_carnaval_offer"

	# --- Veille du Carnaval (acte 4 sans encore avoir lancé la quête défilé) ---
	if CampaignManager.current_act == 4:
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

	# --- Acte 3 : Ramos a demandé une intel — tio Zé recoupe ---
	if QuestManager.is_active(QUEST_INTEL):
		var iobjs: Dictionary = QuestManager.get_objectives_state(QUEST_INTEL)
		if not iobjs.get("intel_seu_joao", false):
			return "seu_joao_act3_intel"

	# --- États historiques (charrette / quête milho) ---
	if cart != null and cart.is_carrying():
		return "seu_joao_return"
	if QuestManager.is_active(QUEST_ID):
		return "seu_joao_reminder"
	if not CampaignManager.has_flag("act1_started"):
		# Première rencontre : déclenche l'héritage narratif (acte 1).
		return "seu_joao_heritage"

	# Fallback : ligne neutre (utilise le knot par défaut du NPCData).
	return data.ink_knot
