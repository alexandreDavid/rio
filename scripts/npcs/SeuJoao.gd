extends NPC

# Spécialisation : le knot dépend de l'état de quête et du portage de la charrette.

const QUEST_ID: String = "quest_milho_01"
const QUEST_CARNAVAL: String = "act4_carnaval_desfile"

func _ready() -> void:
	# Appel explicite : en Godot 4, override de _ready n'appelle PAS super automatiquement.
	super._ready()
	print("[SeuJoao] _ready (override) done")

func _on_interacted(_by: Node) -> void:
	if data == null:
		push_warning("SeuJoao: data is null")
		return
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	var knot: String = data.ink_knot
	# Acte 4 — défilé du Carnaval : tio Zé propose le couronnement public.
	if QuestManager.is_active(QUEST_CARNAVAL):
		knot = "seu_joao_carnaval_remind"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_completed(QUEST_CARNAVAL):
		knot = "seu_joao_carnaval_done"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if QuestManager.is_available(QUEST_CARNAVAL):
		knot = "seu_joao_carnaval_offer"
		DialogueBridge.start_dialogue(data.id, knot)
		return
	if cart != null and cart.is_carrying():
		knot = "seu_joao_return"
	elif QuestManager.is_active(QUEST_ID):
		knot = "seu_joao_reminder"
	elif not CampaignManager.has_flag("act1_started"):
		# Première rencontre : déclenche l'héritage narratif (acte 1).
		knot = "seu_joao_heritage"
	DialogueBridge.start_dialogue(data.id, knot)
