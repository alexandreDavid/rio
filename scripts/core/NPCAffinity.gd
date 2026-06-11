extends Node

# Autoload : NPCAffinity.
# Compteur d'interactions par NPC. Permet aux scripts d'NPC de varier leur
# salutation selon l'historique : tier 0 = jamais vu, tier 1 = connu (≥2),
# tier 2 = familier (≥5). Branché sur EventBus.dialogue_ended pour
# n'incrémenter qu'après un échange réellement abouti.

enum Tier { STRANGER, ACQUAINTANCE, FAMILIAR }

const ACQUAINTANCE_THRESHOLD: int = 2
const FAMILIAR_THRESHOLD: int = 5

var _counts: Dictionary = {}

func _ready() -> void:
	EventBus.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(npc_id: String) -> void:
	if npc_id == "":
		return
	_counts[npc_id] = int(_counts.get(npc_id, 0)) + 1

func count(npc_id: String) -> int:
	return int(_counts.get(npc_id, 0))

# Crédit d'affinité hors dialogue (ex. activité partagée : un match de volley
# avec Camila compte comme une vraie interaction — cf. ActivityRewards).
func bump(npc_id: String, amount: int = 1) -> void:
	if npc_id == "":
		return
	_counts[npc_id] = int(_counts.get(npc_id, 0)) + amount

func tier(npc_id: String) -> int:
	var c: int = count(npc_id)
	if c >= FAMILIAR_THRESHOLD:
		return Tier.FAMILIAR
	if c >= ACQUAINTANCE_THRESHOLD:
		return Tier.ACQUAINTANCE
	return Tier.STRANGER

# Choisit un knot parmi 3 variantes selon le tier de familiarité.
# Helper pour les scripts NPC qui veulent un "default greeting" qui évolue.
func knot_for_tier(npc_id: String, base: String, warm: String = "", familiar: String = "") -> String:
	match tier(npc_id):
		Tier.FAMILIAR:
			if familiar != "":
				return familiar
			if warm != "":
				return warm
		Tier.ACQUAINTANCE:
			if warm != "":
				return warm
	return base

# Variante qui combine affinité + phase de la journée. Priorité :
# 1. familiar (toutes phases), 2. warm (toutes phases), 3. phase matin/après-midi/soir,
# 4. base. Permet à un NPC inconnu (stranger) d'avoir des variantes horaires.
func knot_for_tier_or_phase(npc_id: String, base: String, warm: String, familiar: String,
		morning: String = "", afternoon: String = "", evening: String = "") -> String:
	match tier(npc_id):
		Tier.FAMILIAR:
			if familiar != "":
				return familiar
			if warm != "":
				return warm
		Tier.ACQUAINTANCE:
			if warm != "":
				return warm
	# Stranger : phase de la journée si dispo.
	match TimeOfDay.current_phase:
		TimeOfDay.Phase.MORNING:
			if morning != "":
				return morning
		TimeOfDay.Phase.AFTERNOON:
			if afternoon != "":
				return afternoon
		TimeOfDay.Phase.EVENING:
			if evening != "":
				return evening
	return base

# --- Persistance ---

func serialize() -> Dictionary:
	return {"counts": _counts.duplicate()}

func deserialize(data: Dictionary) -> void:
	_counts = data.get("counts", {}).duplicate() if data.get("counts") != null else {}
