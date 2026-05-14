extends Node

# Autoload : AchievementSystem. Tient à jour la liste des jalons franchis.
# Réévalue tous les achievements à chaque signal narratif (quest, acte, dette,
# endgame, dialogue). Émet achievement_unlocked sur transition pour permettre
# un toast HUD ou un son. Persisté dans la save (via SaveSystem).

signal achievement_unlocked(id: String, data: Dictionary)

const CATALOG: Array = [
	{"id": "first_quest", "icon": "🎯", "title": "Primeira missão", "desc": "Accepter votre première quête."},
	{"id": "first_payment", "icon": "💸", "title": "Primeiro acompte", "desc": "Premier R$ versé au consortium."},
	{"id": "wealthy_10k", "icon": "💵", "title": "Dez mil pagos", "desc": "Verser 10 000 R$ au consortium."},
	{"id": "debt_cleared", "icon": "💰", "title": "Dívida saldada", "desc": "Solder la dette de 50 000 R$."},
	{"id": "act_2", "icon": "🎬", "title": "Acte 2 — Os verdadeiros rostos", "desc": "Franchir le seuil de l'acte 2."},
	{"id": "act_3", "icon": "🎬", "title": "Acte 3 — A última volta", "desc": "Atteindre l'acte 3."},
	{"id": "act_4", "icon": "🎬", "title": "Acte 4 — O Reinado", "desc": "Régner sur le bairro."},
	{"id": "endgame_prefeito", "icon": "🏛", "title": "Coronel do Bairro", "desc": "Sceller la voie Prefeito."},
	{"id": "endgame_policia", "icon": "🚓", "title": "Chefe de Polícia", "desc": "Sceller la voie Polícia."},
	{"id": "endgame_trafico", "icon": "👑", "title": "Patrão do Morro", "desc": "Sceller la voie Tráfico."},
	{"id": "carnaval_complete", "icon": "🎭", "title": "Sapucaí cantou", "desc": "Mener le défilé du Sambódromo."},
	{"id": "pacto_barra", "icon": "✍", "title": "Pacto da Barra", "desc": "Sceller le pacte avec Magalhães."},
	{"id": "commissaire_alerted", "icon": "🚨", "title": "Olho da Polícia", "desc": "Pousser Mendonça à appeler son cousin commissaire."},
	{"id": "first_familiar", "icon": "🤝", "title": "Compañero", "desc": "Atteindre l'affinité « familier » avec un NPC."},
	{"id": "three_familiar", "icon": "👥", "title": "Coração do bairro", "desc": "Trois NPCs en affinité « familier »."},
	{"id": "chatterbox", "icon": "🗨", "title": "Quem fala com todos", "desc": "Discuter avec 10 NPCs différents."},
	{"id": "globetrotter", "icon": "🚖", "title": "Conhece a cidade", "desc": "Visiter 5 districts différents."},
	{"id": "respeitado", "icon": "⭐", "title": "Respeitado", "desc": "Atteindre 50 sur un axe de réputation."},
	{"id": "beach_athlete", "icon": "🏐", "title": "Atleta da praia", "desc": "Compléter une activité sportive (volley, surf, SUP, basket…)."},
	{"id": "niteroi_resident", "icon": "⛴", "title": "Filho da baía", "desc": "Compléter les deux quêtes de Bruno à Niterói."},
	{"id": "first_photo", "icon": "📸", "title": "Carioca documentariste", "desc": "Prendre votre première photo."},
	{"id": "shutterbug", "icon": "🖼", "title": "Acervo carioca", "desc": "Prendre 5 photos."},
	{"id": "pesca_baia", "icon": "🐟", "title": "Pesca da Baía", "desc": "Sortir un poisson au ponton de Niterói."},
	{"id": "viewpoint_collector", "icon": "🌅", "title": "Vistas da cidade", "desc": "Admirer 3 viewpoints panoramiques."},
	{"id": "escape_artist", "icon": "🕊", "title": "Sem polícia atrás", "desc": "Atteindre l'acte 3 sans alerter le commissaire."},
]

var _unlocked: Dictionary = {}
# Districts visités pour le jalon globetrotter. Sérialisé dans la save.
var _districts_visited: Dictionary = {}

const BEACH_QUESTS: Array[String] = [
	"camila_ipanema_volley",
	"lucas_arpoador_surf",
	"pedro_cagarras_sup",
	"ronaldo_aterro_basket",
	"mateus_cagarras_pesca",
	"diego_botafogo_capoeira",
	"sofia_bondinho_tour",
]

func _ready() -> void:
	EventBus.quest_accepted.connect(_re_evaluate_one)
	EventBus.quest_completed.connect(_re_evaluate_one)
	EventBus.act_changed.connect(_re_evaluate_one)
	EventBus.debt_paid.connect(_re_evaluate_two)
	EventBus.endgame_chosen.connect(_re_evaluate_one)
	EventBus.dialogue_ended.connect(_re_evaluate_one)
	EventBus.reputation_changed.connect(_re_evaluate_two)
	DistrictManager.district_changed.connect(_on_district_visited)
	# Premier district visité = celui où la partie commence.
	_districts_visited[DistrictManager.current()] = true
	# Compte la session de démarrage immédiatement.
	call_deferred("_evaluate_all")

func _on_district_visited(district_id: String) -> void:
	_districts_visited[district_id] = true
	_evaluate_all()

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
	# Réévalue le seuil shutterbug ≥ 5.
	_evaluate_all()

func _photo_count() -> int:
	if not DirAccess.dir_exists_absolute("user://photos"):
		return 0
	var n: int = 0
	for f in DirAccess.get_files_at("user://photos"):
		if f.to_lower().ends_with(".png"):
			n += 1
	return n

func _viewpoint_count() -> int:
	var n: int = 0
	for k in CampaignManager.flags:
		if String(k).begins_with("viewpoint_") and CampaignManager.flags[k]:
			n += 1
	return n

func _beach_quest_done() -> bool:
	for qid in BEACH_QUESTS:
		if QuestManager.is_completed(qid):
			return true
	return false

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
	# Nouveaux jalons (10) :
	if not is_unlocked("wealthy_10k") and CampaignManager.debt_paid >= 10000:
		_unlock("wealthy_10k")
	if not is_unlocked("carnaval_complete") and QuestManager.is_completed("act4_carnaval_desfile"):
		_unlock("carnaval_complete")
	if not is_unlocked("chatterbox") and NPCAffinity._counts.keys().size() >= 10:
		_unlock("chatterbox")
	if not is_unlocked("globetrotter") and _districts_visited.keys().size() >= 5:
		_unlock("globetrotter")
	if not is_unlocked("respeitado"):
		for axis_i in ReputationSystem.Axis.size():
			if ReputationSystem.get_value(axis_i) >= 50:
				_unlock("respeitado")
				break
	if not is_unlocked("beach_athlete") and _beach_quest_done():
		_unlock("beach_athlete")
	if not is_unlocked("niteroi_resident") \
			and QuestManager.is_completed("bruno_carga") \
			and QuestManager.is_completed("bruno_pesca_baia"):
		_unlock("niteroi_resident")
	if not is_unlocked("shutterbug") and _photo_count() >= 5:
		_unlock("shutterbug")
	if not is_unlocked("viewpoint_collector") and _viewpoint_count() >= 3:
		_unlock("viewpoint_collector")
	if not is_unlocked("escape_artist") \
			and CampaignManager.current_act >= 3 \
			and not CampaignManager.has_flag("commissaire_alerted"):
		_unlock("escape_artist")

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
	# Inscrit l'entrée rétrospective correspondante dans la Crônica si elle
	# existe (knot "conquista_<id>" cf. NarrativeJournal.JOURNAL_ENTRIES).
	NarrativeJournal.mark_read("conquista_%s" % id)

func _find_in_catalog(id: String) -> Dictionary:
	for entry in CATALOG:
		if entry.id == id:
			return entry
	return {}

# --- Persistance ---

func serialize() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(),
		"districts_visited": _districts_visited.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	_unlocked = data.get("unlocked", {}).duplicate() if data.get("unlocked") != null else {}
	_districts_visited = data.get("districts_visited", {}).duplicate() if data.get("districts_visited") != null else {}
