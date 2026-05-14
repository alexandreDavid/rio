extends Node

# Autoload : AchievementSystem. Tient à jour la liste des jalons franchis.
# Réévalue tous les achievements à chaque signal narratif (quest, acte, dette,
# endgame, dialogue). Émet achievement_unlocked sur transition pour permettre
# un toast HUD ou un son. Persisté dans la save (via SaveSystem).

signal achievement_unlocked(id: String, data: Dictionary)

const CATALOG: Array = [
	{"id": "first_quest", "icon": "🎯", "title": "Primeira missão", "desc": "Accepter votre première quête."},
	{"id": "first_payment", "icon": "💸", "title": "Primeiro acompte", "desc": "Premier R$ versé au consortium."},
	{"id": "debt_cleared", "icon": "💰", "title": "Dívida saldada", "desc": "Solder la dette de 50 000 R$."},
	{"id": "act_2", "icon": "🎬", "title": "Acte 2 — Os verdadeiros rostos", "desc": "Franchir le seuil de l'acte 2."},
	{"id": "act_3", "icon": "🎬", "title": "Acte 3 — A última volta", "desc": "Atteindre l'acte 3."},
	{"id": "act_4", "icon": "🎬", "title": "Acte 4 — O Reinado", "desc": "Régner sur le bairro."},
	{"id": "endgame_prefeito", "icon": "🏛", "title": "Coronel do Bairro", "desc": "Sceller la voie Prefeito."},
	{"id": "endgame_policia", "icon": "🚓", "title": "Chefe de Polícia", "desc": "Sceller la voie Polícia."},
	{"id": "endgame_trafico", "icon": "👑", "title": "Patrão do Morro", "desc": "Sceller la voie Tráfico."},
	{"id": "pacto_barra", "icon": "✍", "title": "Pacto da Barra", "desc": "Sceller le pacte avec Magalhães."},
	{"id": "commissaire_alerted", "icon": "🚨", "title": "Olho da Polícia", "desc": "Pousser Mendonça à appeler son cousin commissaire."},
	{"id": "first_familiar", "icon": "🤝", "title": "Compañero", "desc": "Atteindre l'affinité « familier » avec un NPC."},
	{"id": "three_familiar", "icon": "👥", "title": "Coração do bairro", "desc": "Trois NPCs en affinité « familier »."},
	{"id": "first_photo", "icon": "📸", "title": "Carioca documentariste", "desc": "Prendre votre première photo."},
	{"id": "pesca_baia", "icon": "🐟", "title": "Pesca da Baía", "desc": "Sortir un poisson au ponton de Niterói."},
]

var _unlocked: Dictionary = {}

func _ready() -> void:
	EventBus.quest_accepted.connect(_re_evaluate_one)
	EventBus.quest_completed.connect(_re_evaluate_one)
	EventBus.act_changed.connect(_re_evaluate_one)
	EventBus.debt_paid.connect(_re_evaluate_two)
	EventBus.endgame_chosen.connect(_re_evaluate_one)
	EventBus.dialogue_ended.connect(_re_evaluate_one)

func _re_evaluate_one(_a = null) -> void:
	_evaluate_all()

func _re_evaluate_two(_a = null, _b = null) -> void:
	_evaluate_all()

func is_unlocked(id: String) -> bool:
	return _unlocked.get(id, false)

func count_unlocked() -> int:
	var n: int = 0
	for id in _unlocked:
		if _unlocked[id]:
			n += 1
	return n

func count_total() -> int:
	return CATALOG.size()

# Appelé par HUD quand le joueur prend sa première photo (action hors EventBus).
func notify_first_photo() -> void:
	_unlock("first_photo")

func _evaluate_all() -> void:
	if not is_unlocked("first_quest") and QuestManager.get_active_ids().size() > 0:
		_unlock("first_quest")
	if not is_unlocked("first_payment") and CampaignManager.has_flag("first_payment_done"):
		_unlock("first_payment")
	if not is_unlocked("debt_cleared") and CampaignManager.debt_remaining() == 0 and CampaignManager.debt_paid > 0:
		_unlock("debt_cleared")
	if not is_unlocked("act_2") and CampaignManager.current_act >= 2:
		_unlock("act_2")
	if not is_unlocked("act_3") and CampaignManager.current_act >= 3:
		_unlock("act_3")
	if not is_unlocked("act_4") and CampaignManager.current_act >= 4:
		_unlock("act_4")
	if not is_unlocked("endgame_prefeito") and CampaignManager.chosen_endgame == CampaignManager.Endgame.PREFEITO:
		_unlock("endgame_prefeito")
	if not is_unlocked("endgame_policia") and CampaignManager.chosen_endgame == CampaignManager.Endgame.POLICIA:
		_unlock("endgame_policia")
	if not is_unlocked("endgame_trafico") and CampaignManager.chosen_endgame == CampaignManager.Endgame.TRAFICO:
		_unlock("endgame_trafico")
	if not is_unlocked("pacto_barra") and CampaignManager.has_flag("barra_pacto_sealed"):
		_unlock("pacto_barra")
	if not is_unlocked("commissaire_alerted") and CampaignManager.has_flag("commissaire_alerted"):
		_unlock("commissaire_alerted")
	if not is_unlocked("pesca_baia") and QuestManager.is_completed("bruno_pesca_baia"):
		_unlock("pesca_baia")
	# Affinité — itère sur les compteurs internes (≥5 visites = familiar).
	if not is_unlocked("first_familiar") and _familiar_count() >= 1:
		_unlock("first_familiar")
	if not is_unlocked("three_familiar") and _familiar_count() >= 3:
		_unlock("three_familiar")

func _familiar_count() -> int:
	var n: int = 0
	for npc_id in NPCAffinity._counts:
		if NPCAffinity.tier(npc_id) == NPCAffinity.Tier.FAMILIAR:
			n += 1
	return n

func _unlock(id: String) -> void:
	if _unlocked.get(id, false):
		return
	_unlocked[id] = true
	var data: Dictionary = _find_in_catalog(id)
	achievement_unlocked.emit(id, data)

func _find_in_catalog(id: String) -> Dictionary:
	for entry in CATALOG:
		if entry.id == id:
			return entry
	return {}

# --- Persistance ---

func serialize() -> Dictionary:
	return {"unlocked": _unlocked.duplicate()}

func deserialize(data: Dictionary) -> void:
	_unlocked = data.get("unlocked", {}).duplicate() if data.get("unlocked") != null else {}
