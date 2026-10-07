extends Node

# Autoload : NarrativeJournal.
# Codex consultable des dialogues importants déjà joués. Chaque entrée est un
# knot Ink présent dans la liste curatée ci-dessous. Lorsque DialogueBridge
# joue un knot référencé, il est marqué "lu" et apparaît dans le journal.
# Persisté via SaveSystem (serialize/deserialize).

signal entry_unlocked(knot_id: String)

# Catégorie synthétique « Onde estou » : pas de knots, son contenu est généré
# par story_so_far() (résumé de la situation depuis les flags). Toujours en tête.
const RESUMO_ID: String = "resumo"

# Catégories ordonnées (affichage UI). Clé = id interne, valeur = libellé.
# Les libellés d'acte sont remplacés à l'affichage par CampaignManager.ACT_TITLES
# (source unique) — voir categories().
const CATEGORIES: Array = [
	{"id": RESUMO_ID,   "label": "📍 Onde estou — où j'en suis"},
	{"id": "act1",      "label": "Acte 1", "act": 1},
	{"id": "act2",      "label": "Acte 2", "act": 2},
	{"id": "act3",      "label": "Acte 3", "act": 3},
	{"id": "act4",      "label": "Acte 4", "act": 4},
	{"id": "act5",      "label": "Acte 5", "act": 5},
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
	"seu_joao_advice":          {"category": "act1", "title": "Les conseils de Seu João"},
	"seu_joao_evening_first_payment": {"category": "act1", "title": "Premier acompte — la soirée"},
	"seu_joao_evening_ramos":   {"category": "act1", "title": "Seu João sur Capitão Ramos"},
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
	"seu_joao_ng_plus_intro":       {"category": "act1", "title": "Le déjà-vu de Seu João"},
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
	"contessa_fundo_offer":     {"category": "sides", "title": "L'argent du gala n'est jamais arrivé"},
	"contessa_fundo_reveal":    {"category": "sides", "title": "Pourquoi la Contessa a quitté Milan"},
	"lia_offer":                {"category": "sides", "title": "Une place à l'escolinha pour Pedrinho"},
	"lia_done":                 {"category": "sides", "title": "Pedrinho à la barre"},
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
	"conquista_act_4":              {"category": "conquistas", "title": "Acte 4 — Os Grandes Lances"},
	"conquista_act_5":              {"category": "conquistas", "title": "Acte 5 — O Reinado"},
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

# Catégories avec les libellés d'acte résolus depuis CampaignManager.ACT_TITLES
# (le Diário, le HUD et l'app Saúde disent ainsi la même chose).
func categories() -> Array:
	var out: Array = []
	for cat in CATEGORIES:
		var c: Dictionary = cat.duplicate()
		if c.has("act"):
			c["label"] = CampaignManager.act_title(int(c.act))
		out.append(c)
	return out

# --- « Onde estou » : résumé de la situation, généré depuis l'état ---
#
# Répond en 4-7 phrases à « qui est qui, qu'est-ce que je dois, où j'en suis,
# qu'est-ce qu'on attend de moi ». Pure (lit CampaignManager / QuestManager /
# CarnavalCalendar), testable, sans effet de bord. Affiché en tête de l'app
# Crônica et comme première catégorie du Diário.

# Les 4 patrons et leur mission d'échantillon (acte 2) / leur flag de voie.
const PATRONS_RESUMO: Array = [
	{"name": "Tito", "where": "le morro", "intro": "trafico_a1_livraison", "voie": "voie_trafico", "label": "Tráfico", "prefix": "trafico_a"},
	{"name": "Capitão Ramos", "where": "l'Academia de Copa", "intro": "policia_b1_intel", "voie": "voie_policia", "label": "Polícia", "prefix": "policia_b"},
	{"name": "Magalhães", "where": "le Riserva Uno, à la Barra", "intro": "consortium_c1_recouvrement", "voie": "voie_consortium", "label": "Consórcio", "prefix": "consortium_c"},
	{"name": "le Padre", "where": "l'église de Copa", "intro": "prefeito_d1_peticao", "voie": "voie_prefeito", "label": "Prefeito", "prefix": "prefeito_d"},
]

func story_so_far() -> Array[String]:
	var lines: Array[String] = []
	var act: int = CampaignManager.current_act
	# 1. Qui est qui.
	if CampaignManager.has_flag("ze_rescued"):
		lines.append("Zé, ton oncle, est vivant : tu l'as arraché à la Mafia da Baía. Il est de retour derrière la réception du Copacabana Palace.")
	elif CampaignManager.has_flag("tio_ze_revealed"):
		lines.append("Zé, ton oncle, n'est pas mort : il se cache comme concierge du Copacabana Palace. Mãe ne le sait pas encore.")
	else:
		lines.append("Zé, ton oncle, a disparu. Il t'a laissé sa carrocinha de milho, sa maison du morro — et 50 000 R$ de dette.")
	lines.append("Seu João, le vieux compadre de Zé, veille sur mãe et vovó à la maison. Dom Nilton, le consortium, attend son argent sur l'Av. Atlântica.")
	# 2. La dette et le palier.
	var paid: int = CampaignManager.debt_paid
	if act >= 5 or CampaignManager.debt_remaining() <= 0:
		lines.append("Dette soldée. Dom Nilton a fermé son carnet noir.")
	else:
		var thr: int = CampaignManager.next_act_threshold()
		var debt_line: String = "Dette : %d R$ payés sur 50 000." % paid
		if thr > 0 and paid < thr:
			debt_line += " Prochain palier : %d R$ (il manque %d)." % [thr, thr - paid]
		lines.append(debt_line)
	# 3. Où j'en suis dans la trame.
	match act:
		1:
			if not QuestManager.is_completed("prologue_pedrinho"):
				lines.append("Avant tout : Pedrinho, le petit du morro, a disparu. Personne ne descend à Copa tant qu'il n'est pas retrouvé.")
			elif paid < CampaignManager.ACT1_THRESHOLD:
				lines.append("Vends du milho au calçadão et pose 500 R$ d'acompte chez Nilton — il te laissera respirer.")
			else:
				lines.append("Acompte payé. Rentre à la maison du morro parler à Seu João : la nuit fermera l'acte.")
		2:
			var tasted: Array[String] = []
			var left: Array[String] = []
			for p in PATRONS_RESUMO:
				if QuestManager.is_completed(String(p.intro)):
					tasted.append(String(p.name))
				else:
					left.append("%s (%s)" % [p.name, p.where])
			lines.append("Quatre patrons te proposent chacun un premier boulot, sans engagement. Rien n'est scellé : le vrai choix vient à l'acte 3.")
			if not tasted.is_empty():
				lines.append("Déjà goûtés : %s." % ", ".join(tasted))
			if not left.is_empty():
				lines.append("Encore à voir : %s." % ", ".join(left))
		3, 4:
			var voie: Dictionary = _voie_resumo()
			if voie.is_empty():
				lines.append("Le milho ne suffira plus. Choisis ton parrain et scelle le pacte — Tito, Ramos, Magalhães ou le Padre. Une seule voie, jusqu'au bout.")
			else:
				lines.append("Ta voie : %s, avec %s. %s" % [voie.label, voie.name, _voie_progress(String(voie.prefix))])
				if act == 3:
					lines.append("Chaque mission de la voie crédite ta dette. À 6 000 R$ payés, les Grands Lances s'ouvrent.")
				else:
					lines.append("Reste le pivot au Palace, le gros coup, puis le couronnement — c'est lui qui solde la dette.")
		_:
			var title: String = CampaignManager.reign_title()
			if CampaignManager.has_flag("pos_carnaval"):
				lines.append("Le Carnaval est passé, la dette est soldée. Copa continue : la feijoada du samedi à la maison, le jogo du dimanche, et les rodas de toujours.")
			elif title != "":
				lines.append("Tu es %s. Deux missions de règne sur le calçadão, puis le desfile de la Sapucaí." % title)
			else:
				lines.append("Le Carnaval est là. Le Sambódromo t'attend.")
	# 4. Le calendrier.
	var cal: String = CarnavalCalendar.hud_label()
	if cal != "":
		lines.append("Calendrier : %s." % cal)
	return lines

# Voie scellée → {label, name, prefix} ou {} si aucune.
func _voie_resumo() -> Dictionary:
	for p in PATRONS_RESUMO:
		if CampaignManager.has_flag(String(p.voie)):
			return {"label": p.label, "name": p.name, "prefix": p.prefix}
	return {}

# « 3 missions sur 9 jouées. » pour une voie (préfixe ex. "trafico_a").
func _voie_progress(prefix: String) -> String:
	var done: int = 0
	var total: int = 0
	for q in QuestManager._quests.values():
		if not (q is Quest):
			continue
		var quest: Quest = q
		if quest.quest_type != Quest.QuestType.MAIN or not quest.id.begins_with(prefix):
			continue
		total += 1
		if QuestManager.is_completed(quest.id):
			done += 1
	if total == 0:
		return ""
	return "%d mission%s sur %d jouée%s." % [done, "s" if done > 1 else "", total, "s" if done > 1 else ""]

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
