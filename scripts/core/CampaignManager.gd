extends Node

# Suit l'état narratif global : acte courant, dette envers le consortium,
# progression vers l'un des trois endgames (Prefeito / Polícia / Tráfico).
# Autoload name: CampaignManager.

enum Endgame { NONE, PREFEITO, POLICIA, TRAFICO }

# Somme totale due à la fin de l'acte 1 pour le consortium.
const DEBT_TOTAL: int = 50000
# Acompte à verser pour déclencher le passage à l'acte 2 (facilement atteignable).
const ACT1_THRESHOLD: int = 500
# Acompte cumulé nécessaire à l'acte 3 (dernière ligne droite avant remboursement final).
const ACT2_THRESHOLD: int = 25000

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
const ACT2_MILESTONES: Array = [
	{"threshold": 5000,  "flag": "mae_letter_triggered"},
	{"threshold": 10000, "flag": "mae_consortium_revisit_triggered"},
	{"threshold": 15000, "flag": "mae_sick_triggered"},
	{"threshold": 20000, "flag": "tio_ze_letter_triggered"},
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
# Acte 2 est linéaire : intro (cutscene) → ramos → padre → miguel. Le pivot vers
# l'acte 3 attend la fin de la chaîne complète (act2_miguel_favela).
const ACT_PIVOT_QUESTS: Dictionary = {
	2: ["act1_heritage", "act1_meet_ramos", "act1_meet_tito"],  # acompte + 2 mentors
	3: ["act2_intro", "act2_ramos_operacao", "act2_padre_orfanato", "act2_miguel_favela"],
}

func can_advance_to_act(n: int) -> bool:
	if not ACT_PIVOT_QUESTS.has(n):
		return false
	for pivot_id in ACT_PIVOT_QUESTS[n]:
		if not QuestManager.is_completed(pivot_id):
			return false
	if n == 2:
		return current_act == 1 and debt_paid >= ACT1_THRESHOLD
	if n == 3:
		return current_act == 2 and debt_paid >= ACT2_THRESHOLD
	return false

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

# Acte 3 : la finale clôture la dette (l'argent vient de la voie choisie, pas du joueur),
# scelle la voie ET ouvre l'acte 4 (Reinado). Émet endgame_chosen + act_changed(4).
func complete_endgame(path: int) -> void:
	chosen_endgame = path
	var remaining: int = debt_remaining()
	if remaining > 0:
		debt_paid = DEBT_TOTAL
		EventBus.debt_paid.emit(remaining, 0)
	EventBus.endgame_chosen.emit(path)
	if current_act < 4:
		current_act = 4
		EventBus.act_changed.emit(4)

# Titre du joueur en acte 4 selon la voie.
func reign_title() -> String:
	match chosen_endgame:
		Endgame.PREFEITO: return "Coronel do Bairro"
		Endgame.POLICIA:  return "Chefe de Polícia"
		Endgame.TRAFICO:  return "Patrão do Morro"
		_: return ""

func endgame_name() -> String:
	match chosen_endgame:
		Endgame.PREFEITO: return "Prefeito"
		Endgame.POLICIA:  return "Chefe de Polícia"
		Endgame.TRAFICO:  return "Rei do Tráfico"
		_: return "Indéterminé"

# --- Flags narratifs ---

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

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
