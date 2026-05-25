extends Node

# Autoload : NarrativeJournal.
# Codex consultable des dialogues importants déjà joués. Chaque entrée est un
# knot Ink présent dans la liste curatée ci-dessous. Lorsque DialogueBridge
# joue un knot référencé, il est marqué "lu" et apparaît dans le journal.
# Persisté via SaveSystem (serialize/deserialize).

signal entry_unlocked(knot_id: String)

# Catégories ordonnées (affichage UI). Clé = id interne, valeur = libellé.
const CATEGORIES: Array = [
	{"id": "act1",      "label": "Acte 1 — L'héritage"},
	{"id": "act2",      "label": "Acte 2 — Le carrefour"},
	{"id": "act3",      "label": "Acte 3 — Choix de voie"},
	{"id": "act4",      "label": "Acte 4 — Reinado"},
	{"id": "consortium","label": "Le consortium"},
	{"id": "police",    "label": "Capitão Ramos & la police"},
	{"id": "trafico",   "label": "Tito & le morro"},
	{"id": "sides",     "label": "Missions secondaires"},
	{"id": "districts", "label": "Districts & escapades"},
	{"id": "carnaval",  "label": "Carnaval & finale"},
	{"id": "conquistas","label": "Conquistas franchies"},
]

# Liste curatée. Clé = ink_knot exact ; valeur = { category, title }.
# Tous les knots qui ne sont pas dans cette liste sont silencieusement ignorés
# (on ne pollue pas le journal avec les répétitions cosmétiques).
const JOURNAL_ENTRIES: Dictionary = {
	# --- ACTE 1 ---
	"seu_joao_heritage":        {"category": "act1", "title": "L'héritage de tio Zé"},
	"seu_joao_debt_who":        {"category": "act1", "title": "Une dette de cinquante mille"},
	"seu_joao_advice":          {"category": "act1", "title": "Les conseils de tio Seu João"},
	"seu_joao_evening_first_payment": {"category": "act1", "title": "Premier acompte — la soirée"},
	"seu_joao_evening_ramos":   {"category": "act1", "title": "Tio Zé sur Capitão Ramos"},
	"seu_joao_evening_what_next":{"category": "act1", "title": "Trouver un parrain ou payer seul"},
	# --- CONSORTIUM ---
	"consortium_intro":         {"category": "consortium", "title": "Première visite chez Dom Nilton"},
	"consortium_threat":        {"category": "consortium", "title": "La menace de Claudinho"},
	"consortium_after_threshold":{"category": "consortium","title": "Le clin d'œil de Dom Nilton"},
	"consortium_settled":       {"category": "consortium", "title": "Dette soldée"},
	"consortium_airport_offer": {"category": "consortium", "title": "Don Salvatore arrive à Rio"},
	"consortium_airport_done":  {"category": "consortium", "title": "Le padrinho à bon port"},
	# --- POLICE / RAMOS ---
	"ramos_intro":              {"category": "police", "title": "Capitão Ramos vous remarque"},
	"ramos_active":             {"category": "police", "title": "La caisse de solidarité"},
	"ramos_thanks":             {"category": "police", "title": "Bienvenue dans la famille bleue"},
	# --- TITO / MORRO ---
	"tito_favor_ask":           {"category": "trafico", "title": "Tito demande un service"},
	# --- ACTE 2 ---
	"contessa_act2_offer":      {"category": "act2", "title": "Le gala de la Contessa"},
	"pecheur_act2_offer":       {"category": "act2", "title": "Seu Pedro a vu quelque chose"},
	"pecheur_act2_done":        {"category": "act2", "title": "La mer parle moins fort"},
	"seu_joao_evening_act2_reveal": {"category": "act2", "title": "La vérité sur ton oncle Zé"},
	"seu_joao_evening_why_silent":  {"category": "act2", "title": "La règle du silence"},
	"seu_joao_evening_how_known":   {"category": "act2", "title": "Le morro savait depuis huit ans"},
	"spot_mae_letter":              {"category": "act2", "title": "La lettre du consortium chez mãe"},
	"spot_vovo_letter_observed":    {"category": "act2", "title": "Vovó a vu mãe pleurer en silence"},
	"spot_mae_revisit":             {"category": "act2", "title": "Le consortium a demandé du sucre"},
	"spot_mae_sick":                {"category": "act2", "title": "Mãe tombe malade"},
	"spot_vovo_ze_anonymous_letter":{"category": "act2", "title": "Un mot anonyme sous la porte"},
	"tito_act2_loyalty_offer":      {"category": "trafico", "title": "Tito veut une preuve de loyauté"},
	"tito_act2_loyalty_done":       {"category": "trafico", "title": "Tito te confie la corrida"},
	"tito_act2_loyalty_declined":   {"category": "trafico", "title": "Tito te tourne le dos"},
	"consortium_act3_intro":        {"category": "act2", "title": "Dom Nilton ouvre les trois portes"},
	"spot_vizinho_jorge_offer":     {"category": "sides", "title": "Seu Jorge cherche son petit-fils"},
	"spot_vizinho_jorge_return":    {"category": "sides", "title": "Beto renvoyé chez Seu Jorge"},
	"spot_beto_lost":               {"category": "sides", "title": "Beto fourgue sur le calçadão"},
	# --- META : runs cumulées ---
	"seu_joao_ng_plus_intro":       {"category": "act1", "title": "Le déjà-vu de tio Zé"},
	"spot_vovo_ng_plus_dejavu":     {"category": "carnaval", "title": "Vovó se souvient des autres règnes"},
	# --- ACTE 3 ---
	# (Les knots act3_ sont auto-générés ; on documente les pivots clés.)
	"seu_joao_evening_path_chosen": {"category": "act3", "title": "Le médaillon de l'aïeul"},
	# --- ACTE 4 ---
	"seu_joao_carnaval_offer":  {"category": "act4", "title": "Reinado au Sambódromo"},
	"seu_joao_carnaval_done":   {"category": "act4", "title": "Toute la Sapucaí chante ton nom"},
	"seu_joao_evening_carnaval_eve": {"category": "act4", "title": "La veille de la Sapucaí"},
	# --- CARNAVAL / FINALE ---
	# --- SIDES ---
	"tourist_vip_tour_offer":   {"category": "sides", "title": "Le touriste VIP cherche un guide"},
	"tourist_vip_tour_done":    {"category": "sides", "title": "Le touriste rentre satisfait"},
	"contessa_date_offer":      {"category": "sides", "title": "Une soirée privée avec la Contessa"},
	"contessa_date_done_smitten":{"category": "sides","title": "Le sourire de la Contessa"},
	# --- DISTRICTS ---
	"ronaldo_dj_offer":         {"category": "districts", "title": "DJ au Pão de Açúcar"},
	"ronaldo_torcida_offer":    {"category": "districts", "title": "Mener la torcida au Maracanã"},
	"ronaldo_basket_offer":     {"category": "districts", "title": "Basquete na Aterro do Flamengo"},
	"carlos_lagoa_offer":       {"category": "districts", "title": "Volta da Lagoa avec Carlos"},
	"padre_corcovado_offer":    {"category": "districts", "title": "La relique du Corcovado"},
	# --- CONQUISTAS — paragraphes rétrospectifs, marqués au déblocage ---
	"conquista_first_quest":        {"category": "conquistas", "title": "Primeira missão"},
	"conquista_first_payment":      {"category": "conquistas", "title": "Primeiro acompte"},
	"conquista_debt_cleared":       {"category": "conquistas", "title": "Dívida saldada"},
	"conquista_act_2":              {"category": "conquistas", "title": "Acte 2 — Os verdadeiros rostos"},
	"conquista_act_3":              {"category": "conquistas", "title": "Acte 3 — A última volta"},
	"conquista_act_4":              {"category": "conquistas", "title": "Acte 4 — O Reinado"},
	"conquista_endgame_prefeito":   {"category": "conquistas", "title": "Coronel do Bairro"},
	"conquista_endgame_policia":    {"category": "conquistas", "title": "Chefe de Polícia"},
	"conquista_endgame_trafico":    {"category": "conquistas", "title": "Patrão do Morro"},
	"conquista_pacto_barra":        {"category": "conquistas", "title": "Pacto da Barra"},
	"conquista_commissaire_alerted":{"category": "conquistas", "title": "Olho da Polícia"},
	"conquista_first_familiar":     {"category": "conquistas", "title": "Compañero"},
	"conquista_three_familiar":     {"category": "conquistas", "title": "Coração do bairro"},
	"conquista_first_photo":        {"category": "conquistas", "title": "Carioca documentariste"},
	"conquista_pesca_baia":         {"category": "conquistas", "title": "Pesca da Baía"},
	"conquista_wealthy_10k":        {"category": "conquistas", "title": "Dez mil pagos"},
	"conquista_carnaval_complete":  {"category": "conquistas", "title": "Sapucaí cantou"},
	"conquista_chatterbox":         {"category": "conquistas", "title": "Quem fala com todos"},
	"conquista_globetrotter":       {"category": "conquistas", "title": "Conhece a cidade"},
	"conquista_respeitado":         {"category": "conquistas", "title": "Respeitado"},
	"conquista_beach_athlete":      {"category": "conquistas", "title": "Atleta da praia"},
	"conquista_niteroi_resident":   {"category": "conquistas", "title": "Filho da baía"},
	"conquista_shutterbug":         {"category": "conquistas", "title": "Acervo carioca"},
	"conquista_viewpoint_collector":{"category": "conquistas", "title": "Vistas da cidade"},
	"conquista_escape_artist":      {"category": "conquistas", "title": "Sem polícia atrás"},
}

var _read: Dictionary = {}  # knot_id -> true

func mark_read(knot_id: String) -> void:
	if knot_id == "" or _read.has(knot_id):
		return
	_read[knot_id] = true
	if JOURNAL_ENTRIES.has(knot_id):
		entry_unlocked.emit(knot_id)

func is_read(knot_id: String) -> bool:
	return _read.has(knot_id)

# Liste des entrées débloquées dans une catégorie. Préserve l'ordre de
# JOURNAL_ENTRIES (déclaratif).
func entries_in(category_id: String) -> Array:
	var out: Array = []
	for knot in JOURNAL_ENTRIES:
		if not _read.has(knot):
			continue
		var meta: Dictionary = JOURNAL_ENTRIES[knot]
		if meta.get("category", "") != category_id:
			continue
		out.append({"knot": knot, "title": meta.get("title", knot)})
	return out

# Nombre total d'entrées débloquées (toutes catégories).
func unlocked_count() -> int:
	var n: int = 0
	for knot in JOURNAL_ENTRIES:
		if _read.has(knot):
			n += 1
	return n

func total_count() -> int:
	return JOURNAL_ENTRIES.size()

# Récupère le contenu d'une entrée pour l'affichage : speaker + texte.
# On va chercher dans DialogueBridge.PLACEHOLDER_DIALOGUES ; si Ink prendra le
# relais un jour, l'API restera la même côté UI.
func get_entry_content(knot_id: String) -> Dictionary:
	# Lit depuis PLACEHOLDER_DIALOGUES (knots scriptés) ou _runtime_dialogues
	# (knots éphémères). Le helper de DialogueBridge masque les deux sources.
	if not DialogueBridge._has_placeholder(knot_id):
		return {}
	var d: Dictionary = DialogueBridge._get_placeholder(knot_id)
	return {"speaker": d.get("speaker", ""), "text": d.get("text", "")}

# --- Persistance ---

func serialize() -> Dictionary:
	return {"read": _read.duplicate()}

func deserialize(data: Dictionary) -> void:
	_read = data.get("read", {})
