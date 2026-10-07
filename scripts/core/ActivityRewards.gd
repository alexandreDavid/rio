extends Node

# Autoload : ActivityRewards.
# Récompenses NON fongibles : chaque mini-jeu réussi (qualifies) rapporte,
# en plus du tip, une signature qui lui est propre — réputation sur UN axe
# + affinité avec le NPC de l'activité (carburant du jeitinho). Au 3e succès,
# le bairro te reconnaît : flag `mestre_<id>` + toast.
# Choisir son activité a enfin un goût : le volley construit la rue,
# la padaria le respect civique, le valet les touristes…

# Axis : 0 CIVIC, 1 POLICE, 2 STREET, 3 TOURIST, 4 CHARISMA.
const SIGNATURES: Dictionary = {
	"beach_volley":     {"axis": 2, "amount": 2, "npc": "camila", "label": "volley de praia"},
	"surf":             {"axis": 2, "amount": 2, "npc": "lucas", "label": "surf do Arpoador"},
	"cagarras_sup":     {"axis": 2, "amount": 1, "npc": "pedro", "label": "SUP das Cagarras"},
	"padaria":          {"axis": 0, "amount": 2, "npc": "padeiro", "label": "fornada da padaria"},
	"valet":            {"axis": 3, "amount": 2, "npc": "otavio", "label": "valet do Palace"},
	"dj_paoacucar":     {"axis": 4, "amount": 2, "npc": "ronaldo", "label": "pista do Pão de Açúcar"},
	"maracana_torcida": {"axis": 4, "amount": 2, "npc": "ronaldo", "label": "torcida do Maracanã"},
	"aterro_basket":    {"axis": 2, "amount": 1, "npc": "ronaldo", "label": "basquete do Aterro"},
	"fishing":          {"axis": 0, "amount": 1, "npc": "pecheur", "label": "pesca da Colônia"},
	"lagoa_circuit":    {"axis": 3, "amount": 1, "npc": "carlos", "label": "volta da Lagoa"},
	"bike":             {"axis": 0, "amount": 1, "npc": "carlos", "label": "entregas de bike"},
	"exercise":         {"axis": 4, "amount": 1, "npc": "ramos", "label": "treino da academia"},
	"carnaval_samba":   {"axis": 4, "amount": 3, "npc": "", "label": "samba da Sapucaí"},
	"racha_atlantica":  {"axis": 2, "amount": 2, "npc": "", "label": "racha da Atlântica"},
	"altinha":          {"axis": 2, "amount": 1, "npc": "", "label": "altinha da praia"},
	"kitesurf":         {"axis": 2, "amount": 1, "npc": "", "label": "kite da Barra"},
	"milho":            {"axis": 0, "amount": 1, "npc": "seu_joao", "label": "hora do rush do milho"},
}
const MESTRE_THRESHOLD: int = 3
# La réputation d'activité est plafonnée par source : au-delà de 3 réussites
# « payantes » (le seuil mestre), rejouer reste du plaisir/affinité, plus du
# grind de réputation.
const REP_CAP_MULTIPLIER: int = 3

# id → nombre de réussites qualifiantes (persisté).
var _qualify_counts: Dictionary = {}

func _ready() -> void:
	EventBus.minigame_ended.connect(_on_minigame_ended)

func _on_minigame_ended(minigame_id: String, result: Dictionary) -> void:
	if not SIGNATURES.has(minigame_id):
		return
	# « Réussite » = qualifies si présent, sinon won (fishing), sinon rien.
	var ok: bool = bool(result.get("qualifies", result.get("won", false)))
	if not ok:
		return
	var sig: Dictionary = SIGNATURES[minigame_id]
	ReputationSystem.gain_capped(int(sig.axis), int(sig.amount),
		"activity_" + minigame_id, int(sig.amount) * REP_CAP_MULTIPLIER)
	var npc: String = String(sig.npc)
	if npc != "":
		NPCAffinity.bump(npc)
	_qualify_counts[minigame_id] = int(_qualify_counts.get(minigame_id, 0)) + 1
	var mestre_flag: String = "mestre_" + minigame_id
	if int(_qualify_counts[minigame_id]) >= MESTRE_THRESHOLD \
			and not CampaignManager.has_flag(mestre_flag):
		CampaignManager.set_flag(mestre_flag, true)
		EventBus.notification_requested.emit("⭐ O bairro te reconnaît : mestre %s !" % sig.label,
			Color(0.98, 0.85, 0.4, 1))

func count(minigame_id: String) -> int:
	return int(_qualify_counts.get(minigame_id, 0))

# --- Persistance ---

func serialize() -> Dictionary:
	return {"qualify_counts": _qualify_counts.duplicate()}

func deserialize(data: Dictionary) -> void:
	var counts = data.get("qualify_counts")
	_qualify_counts = counts.duplicate() if counts is Dictionary else {}
