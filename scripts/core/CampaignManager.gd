extends Node

# Suit l'état narratif global : acte courant, dette envers le consortium,
# progression vers l'un des quatre endgames (Prefeito / Polícia / Tráfico /
# Consórcio). Autoload name: CampaignManager.
#
# Canon des personnages de la maison (à respecter dans TOUT texte joueur) :
#   - Zé = l'oncle disparu (frère de mãe). Sa maison, sa carrocinha, sa dette.
#     Il se cache comme concierge du Palace (révélé au pivot tioze de la voie).
#   - Seu João = le vieux compadre de Zé, pas du sang. Il a pris place à la
#     table pour veiller sur mãe et vovó. Le joueur l'appelle « tio » par
#     respect carioca — mais il n'est JAMAIS « tio Zé » dans l'UI.

# CONSORTIUM ajouté en dernier : préserve les valeurs int existantes
# (NONE=0, PREFEITO=1, POLICIA=2, TRAFICO=3, CONSORTIUM=4) pour les saves.
enum Endgame { NONE, PREFEITO, POLICIA, TRAFICO, CONSORTIUM }

# Somme totale due au consortium. La quête de fin (A9/B9/C9/D9) solde
# automatiquement le reliquat — les seuils ci-dessous sont des jalons de RYTHME,
# pas une obligation de gagner 50 000 R$ à la sueur du milho.
const DEBT_TOTAL: int = 50000
# Acompte à verser pour déclencher le passage à l'acte 2 (facilement atteignable).
const ACT1_THRESHOLD: int = 500
# Acte 2 = échantillon libre : chaque patron offre sa mission intro (A1/B1/C1/D1)
# sans pacte. Seuil calé sur le revenu des 4 missions intro (~1 050 R$) + un peu
# de milho/side → l'acte 3 (vrai choix de voie) s'ouvre sans grind.
const ACT2_THRESHOLD: int = 2000
# Acte 3 → 4 : la voie est scellée, le joueur enchaîne A1-A7. Seuil calé pour
# être franchi en complétant la chaîne (les missions paient désormais le gros du
# revenu), laissant A8 (gros coup) / A9 (couronnement) pour l'acte 4.
const ACT3_THRESHOLD: int = 6000

# Titres d'acte — SOURCE UNIQUE pour le HUD, le bandeau, le Diário, l'app
# Saúde et la carte d'acte. Titre portugais (identité) + sous-titre français
# (ce que l'acte attend du joueur). Ne pas dupliquer ces chaînes ailleurs.
const ACT_TITLES: Dictionary = {
	1: {"title": "Acte 1 — A herança", "subtitle": "L'héritage"},
	2: {"title": "Acte 2 — Os verdadeiros rostos", "subtitle": "Les vrais visages"},
	3: {"title": "Acte 3 — A última volta", "subtitle": "Le dernier tour"},
	4: {"title": "Acte 4 — Os Grandes Lances", "subtitle": "Les grands coups"},
	5: {"title": "Acte 5 — O Reinado", "subtitle": "Le règne"},
}

# Carte d'acte (ActCard) : ce qui vient de se passer + ce qu'on attend de toi.
# Le corps est volontairement concret (qui, où, combien) — c'est LA réponse à
# « je ne comprends pas où j'en suis » à chaque bascule.
const ACT_CARDS: Dictionary = {
	2: "Cinq cents reais posés sur la table de Dom Nilton, et une nuit dans la maison de Zé. Le morro a parlé : quatre patrons ont senti l'odeur d'un môme qui paie à l'heure.\n\nChacun te propose UN premier boulot — Tito au morro, Capitão Ramos à l'Academia, le Padre à l'église, Magalhães à la Barra. Goûte-les tous : rien ne t'engage encore.\n\nNilton veut 2 000 R$ au total avant de t'ouvrir le vrai choix. Milho, missions, courriers — tout compte.",
	3: "Deux mille reais. Dom Nilton l'a dit lui-même : le reste ne sortira pas de ta carrocinha.\n\nC'est le moment du pacte. Choisis ton parrain — Tito, Ramos, Magalhães ou le Padre — et scelle-le. Une seule voie, jusqu'au bout : les trois autres se ferment.\n\nChaque mission de ta voie crédite ta dette directement. À 6 000 R$ payés, les Grands Lances s'ouvrent.",
	4: "Six mille reais. Le bairro connaît ton nom, et ton parrain te confie les gros coups.\n\nTa voie va au bout : le pivot au Copacabana Palace (un vieux du Palace en sait long sur Zé), le gros coup, puis le couronnement. C'est LÀ que la dette se solde — pas au milho.\n\nLe Fixer du calçadão a aussi des lances hors trame, si tu veux les tenter.",
	5: "La dette est soldée. Dom Nilton a fermé son carnet noir.\n\nCopacabana est à toi, à ta manière. Deux missions de règne t'attendent sur le calçadão, dans le verbe de ta voie. Puis la Sapucaí : trois cent mille voix, et les tiens en première ligne.\n\nC'est le Carnaval. Va la tête haute.",
}

var current_act: int = 1
var debt_paid: int = 0
var chosen_endgame: int = Endgame.NONE
# Flags narratifs libres (utilisés par les dialogues Ink et les cinématiques scriptées).
# Ex. "met_ramos", "tio_ze_revealed", "ratted_on_tito".
var flags: Dictionary = {}

# Compteur de runs terminées (incrémenté par Epilogue.gd dans user://ng_plus.json).
# Chargé au démarrage par MainBoot. Non sérialisé dans la save (vit dans le fichier méta).
# >0 → la run actuelle est une Nouvelle Partie+, certaines lignes en tiennent compte.
var ng_plus_count: int = 0
# Liste textuelle des voies déjà closes ("prefeito", "policia", "trafico"). Permet aux
# dialogues d'acknowledger qu'on a déjà été X dans une vie antérieure.
var completed_paths: Array = []

# --- Dette ---

# Pivots narratifs déclenchés par paliers de dette payée. À chaque palier
# atteint en acte ≥ 2, on pose un flag exploité par les ReactiveDialogueSpot
# de la maison (mãe et vovó). Évalués en cascade : un saut large peut poser
# plusieurs flags en une seule transaction.
# Paliers calés sur la fenêtre de l'acte 2 (acompte 500 → seuil acte 3 à 2000)
# pour que les beats famille se jouent bien PENDANT l'acte 2.
const ACT2_MILESTONES: Array = [
	{"threshold": 600,  "flag": "mae_letter_triggered"},
	{"threshold": 1000, "flag": "mae_consortium_revisit_triggered"},
	{"threshold": 1400, "flag": "mae_sick_triggered"},
	{"threshold": 1800, "flag": "tio_ze_letter_triggered"},
]

func _ready() -> void:
	# Une quête de pivot complétée peut être la dernière condition manquante
	# pour franchir un acte — on revérifie à chaque complétion.
	EventBus.quest_completed.connect(_on_quest_completed)

func _on_quest_completed(_quest_id: String) -> void:
	_check_act_advance()

func debt_remaining() -> int:
	return max(DEBT_TOTAL - debt_paid, 0)

func pay_debt(amount: int) -> int:
	if amount <= 0:
		return 0
	var applied: int = min(amount, debt_remaining())
	if applied <= 0:
		return 0
	debt_paid += applied
	if not has_flag("first_payment_done"):
		set_flag("first_payment_done")
	EventBus.debt_paid.emit(applied, debt_remaining())
	_check_act_advance()
	# Paliers acte 2 — évalués après _check_act_advance pour que current_act
	# reflète bien le nouvel acte si on vient juste de basculer.
	if current_act >= 2:
		for m in ACT2_MILESTONES:
			var flag: String = String(m.flag)
			var threshold: int = int(m.threshold)
			if debt_paid >= threshold and not has_flag(flag):
				set_flag(flag)
	return applied

# --- Actes ---

# Quêtes principales qui doivent être complétées pour franchir un acte (en plus du seuil de dette).
# Le gating narratif force le joueur à suivre la trame, pas seulement à farmer.
# Pivots requis pour avancer (en plus du seuil de dette). Post-refonte : les
# quêtes legacy act1_meet_*, act2_intro, act2_ramos/padre/miguel_* n'existent
# plus. Acte 2 = échantillon libre ; le passage à l'acte 3 est gated par le
# choix d'un patron (cf. VOIE_FLAGS dans can_advance_to_act).
const ACT_PIVOT_QUESTS: Dictionary = {
	2: ["act1_heritage"],
}

const VOIE_FLAGS: Array[String] = ["voie_trafico", "voie_policia", "voie_consortium", "voie_prefeito"]

func can_advance_to_act(n: int) -> bool:
	if n == 2:
		if not QuestManager.is_completed("act1_heritage"):
			return false
		# L'acte 2 ne s'ouvre qu'APRÈS le retour à la maison + la nuit chez tio Zé
		# (flag act1_closed), en plus de l'acompte payé. Le simple paiement ne
		# suffit plus : il faut rentrer parler à tio Zé.
		if not has_flag("act1_closed"):
			return false
		return current_act == 1 and debt_paid >= ACT1_THRESHOLD
	if n == 3:
		# Avancement libre au seuil dette : pas besoin d'avoir scellé une voie en
		# acte 2 — c'est justement en acte 3 que le pacte se signe.
		return current_act == 2 and debt_paid >= ACT2_THRESHOLD
	if n == 4:
		# Acte 3 → 4 : 25 000 R$ remboursés, on entre dans « Os Grandes Lances ».
		# A8 gros coup, A9 couronnement, et l'option assassinat du consortium.
		return current_act == 3 and debt_paid >= ACT3_THRESHOLD
	return false

# Seuil de dette payée (cumulée) à atteindre pour franchir l'acte courant.
# 0 = acte 4+ : plus de seuil, la voie se solde au couronnement (complete_endgame).
func next_act_threshold() -> int:
	match current_act:
		1: return ACT1_THRESHOLD
		2: return ACT2_THRESHOLD
		3: return ACT3_THRESHOLD
		_: return 0

func advance_act() -> bool:
	var next_act: int = current_act + 1
	if not can_advance_to_act(next_act):
		return false
	current_act = next_act
	EventBus.act_changed.emit(current_act)
	return true

func _check_act_advance() -> void:
	# Avancement passif : dès que le seuil est atteint, l'acte progresse.
	# Les dialogues peuvent réagir à EventBus.act_changed.
	if can_advance_to_act(current_act + 1):
		advance_act()

# --- Endgame ---

func set_endgame(path: int) -> void:
	chosen_endgame = path
	EventBus.endgame_chosen.emit(path)

# Acte 4 → 5 : couronnement de la voie. Clôt la dette (l'argent vient de la voie),
# scelle endgame_chosen ET ouvre l'acte 5 (Reinado/Carnaval). Émet act_changed(5).
func complete_endgame(path: int) -> void:
	chosen_endgame = path
	var remaining: int = debt_remaining()
	if remaining > 0:
		debt_paid = DEBT_TOTAL
		EventBus.debt_paid.emit(remaining, 0)
	EventBus.endgame_chosen.emit(path)
	if current_act < 5:
		current_act = 5
		EventBus.act_changed.emit(5)

# Titre d'acte complet (« Acte 2 — Os verdadeiros rostos »).
func act_title(n: int) -> String:
	return String(ACT_TITLES.get(n, {}).get("title", "Acte %d" % n))

# Sous-titre français (« Les vrais visages »).
func act_subtitle(n: int) -> String:
	return String(ACT_TITLES.get(n, {}).get("subtitle", ""))

# Corps de la carte d'acte ("" pour l'acte 1 — l'intro narrative s'en charge).
func act_card_body(n: int) -> String:
	return String(ACT_CARDS.get(n, ""))

# Titre du joueur en acte 5 (Reinado) selon la voie.
func reign_title() -> String:
	match chosen_endgame:
		Endgame.PREFEITO: return "Coronel do Bairro"
		Endgame.POLICIA:  return "Chefe de Polícia"
		Endgame.TRAFICO:  return "Patrão do Morro"
		Endgame.CONSORTIUM: return "Sócio do Consórcio"
		_: return ""

func endgame_name() -> String:
	match chosen_endgame:
		Endgame.PREFEITO: return "Prefeito"
		Endgame.POLICIA:  return "Chefe de Polícia"
		Endgame.TRAFICO:  return "Rei do Tráfico"
		Endgame.CONSORTIUM: return "Sócio do Consórcio"
		_: return "Indéterminé"

# --- Flags narratifs ---

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	# Le pacte d'une voie (voie_* flag) déclenche le passage à l'acte 3 si la
	# dette est franchie. Sans ça, le joueur reste figé à l'acte 2 après le pact.
	# act1_closed (retour maison + nuit chez tio Zé) déclenche le passage à
	# l'acte 2 — c'est ce retour, pas le paiement seul, qui ferme l'acte 1.
	if value and (VOIE_FLAGS.has(key) or key == "act1_closed"):
		_check_act_advance()

func has_flag(key: String) -> bool:
	return flags.has(key) and flags[key]

func get_flag(key: String) -> Variant:
	return flags.get(key)

# --- Persistance ---

func serialize() -> Dictionary:
	return {
		"current_act": current_act,
		"debt_paid": debt_paid,
		"chosen_endgame": chosen_endgame,
		"flags": flags.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	current_act = data.get("current_act", 1)
	debt_paid = data.get("debt_paid", 0)
	chosen_endgame = data.get("chosen_endgame", Endgame.NONE)
	flags = data.get("flags", {}).duplicate() if data.get("flags") != null else {}
