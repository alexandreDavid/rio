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
]

# Liste curatée. Clé = ink_knot exact ; valeur = { category, title }.
# Tous les knots qui ne sont pas dans cette liste sont silencieusement ignorés
# (on ne pollue pas le journal avec les répétitions cosmétiques).
const JOURNAL_ENTRIES: Dictionary = {
	# --- ACTE 1 ---
	"seu_joao_heritage":        {"category": "act1", "title": "L'héritage de tio Zé"},
	"seu_joao_debt_who":        {"category": "act1", "title": "Une dette de cinquante mille"},
	"seu_joao_advice":          {"category": "act1", "title": "Les conseils de tio Seu João"},
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
	# --- ACTE 3 ---
	# (Les knots act3_ sont auto-générés ; on documente les pivots clés.)
	# --- ACTE 4 ---
	"seu_joao_carnaval_offer":  {"category": "act4", "title": "Reinado au Sambódromo"},
	"seu_joao_carnaval_done":   {"category": "act4", "title": "Toute la Sapucaí chante ton nom"},
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
	"pecheur_cagarras_offer":   {"category": "districts", "title": "La botija des Cagarras"},
	"pecheur_cagarras_done":    {"category": "districts", "title": "La mer t'aime bien"},
	"carlos_lagoa_offer":       {"category": "districts", "title": "Volta da Lagoa avec Carlos"},
	"padre_corcovado_offer":    {"category": "districts", "title": "La relique du Corcovado"},
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
