extends Node

# Autoload : CreditorVisitManager.
# Pression dette dynamique : des créanciers (Dom Nilton, cobrador, avocat)
# débarquent semi-aléatoirement quand le joueur est en ville avec de la dette,
# au lieu d'attendre passivement que le joueur aille au consortium.
#
# Fait monter la tension narrative et casse le grind "vendre milho → payer".

const CHECK_INTERVAL_SEC: float = 60.0       # on vérifie chaque minute
const COOLDOWN_SEC: float = 480.0            # 8 min mini entre 2 visites
const MIN_DEBT_FOR_VISIT: int = 100          # pas de visite si la dette est presque finie
const VISIT_CHANCE: float = 0.45             # probabilité par check si toutes conditions remplies

# Pondération des scénarios. Plus la dette est élevée, plus les durs scénarios
# (raid, ultimatum) montent. Calculé dynamiquement dans _pick_scenario().
const SCENARIOS: Dictionary = {
	"creditor_soft":      {"min_debt": 100,  "knot": "creditor_visit_soft"},
	"creditor_ultimatum": {"min_debt": 500,  "knot": "creditor_visit_ultimatum"},
	"creditor_raid":      {"min_debt": 2000, "knot": "creditor_visit_raid"},
}

# Scénario alternatif qui prend la priorité si commissaire_alerted est posé
# (cousin commissaire de Mendonça suit le joueur). Tenente Borges débarque
# pour pot-de-vin au lieu (ou en plus) du consortium.
const POLICE_SCENARIO: Dictionary = {
	"knot": "creditor_police_shakedown",
	"npc_id": "borges",
	"flag": "commissaire_alerted",
	"override_chance": 0.5,  # 50% que la visite soit Borges au lieu du consortium
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_visit_time: float = 0.0
var _elapsed_since_check: float = 0.0
var _enabled: bool = true

func _ready() -> void:
	_rng.randomize()
	# Démarrage : pas de visite immédiate. On laisse le joueur jouer 5 min
	# avant la première éventuelle visite (cooldown initial complet).
	_last_visit_time = -COOLDOWN_SEC + 300.0

func _process(delta: float) -> void:
	if not _enabled:
		return
	_elapsed_since_check += delta
	if _elapsed_since_check < CHECK_INTERVAL_SEC:
		return
	_elapsed_since_check = 0.0
	_try_trigger_visit()

func _try_trigger_visit() -> void:
	# Hors gameplay (Intro, menu, character creator, chargement) il n'y a pas de
	# joueur ni de DialogueUI : déclencher ici poserait _active_npc_id sans jamais
	# pouvoir afficher ni fermer le dialogue → soft-lock au démarrage de la partie.
	if GameManager.player == null or not is_instance_valid(GameManager.player):
		return
	# Cooldown global
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_visit_time < COOLDOWN_SEC:
		return
	# Acte 0 ou pas de dette : aucune visite
	if CampaignManager.current_act < 1:
		return
	var debt_remaining: int = CampaignManager.debt_remaining()
	if debt_remaining < MIN_DEBT_FOR_VISIT:
		return
	# Pas pendant dialogue, mini-jeu, cutscene
	if DialogueBridge.is_active():
		return
	if get_tree().paused:
		return
	# Pas dans une scène d'intérieur (porte fermée = lieu privé)
	if BuildingManager.last_exit_position != Vector2.ZERO:
		# Hack : si BuildingManager garde une position de retour, le joueur est
		# probablement dans un intérieur. On évite la visite.
		# Note : ce flag n'est pas complètement fiable mais c'est un bon proxy.
		pass  # On laisse passer pour l'instant — à raffiner si nécessaire
	# District restriction : seulement en ville (copa, zona_sul, favela)
	var d: String = DistrictManager.current()
	if d != "copacabana" and d != "zona_sul" and d != "favela_morro":
		return
	# Chance par check
	if _rng.randf() > VISIT_CHANCE:
		return
	# Lance le scénario
	_trigger_visit(debt_remaining)

func _trigger_visit(debt_remaining: int) -> void:
	_last_visit_time = Time.get_ticks_msec() / 1000.0
	# Si commissaire_alerted posé, 50% des visites sont des shakedowns police.
	if CampaignManager.has_flag(POLICE_SCENARIO.flag) and _rng.randf() < POLICE_SCENARIO.override_chance:
		DialogueBridge.start_dialogue(POLICE_SCENARIO.npc_id, POLICE_SCENARIO.knot)
		return
	var scenario_id: String = _pick_scenario(debt_remaining)
	var entry: Dictionary = SCENARIOS[scenario_id]
	DialogueBridge.start_dialogue("nilton", entry.knot)

func _pick_scenario(debt: int) -> String:
	# Pondération : plus la dette est haute, plus le scénario est dur.
	var weights: Dictionary = {}
	for id in SCENARIOS:
		var entry: Dictionary = SCENARIOS[id]
		if debt >= entry.min_debt:
			# Pondération qui monte avec le ratio debt/min_debt
			weights[id] = max(1.0, float(debt) / float(entry.min_debt))
	if weights.is_empty():
		return "creditor_soft"
	var total: float = 0.0
	for w in weights.values():
		total += w
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for id in weights:
		acc += weights[id]
		if roll <= acc:
			return id
	return weights.keys()[0]

# API publique pour debug / sauvegarde
func force_visit() -> void:
	_last_visit_time = -COOLDOWN_SEC
	_trigger_visit(max(CampaignManager.debt_remaining(), MIN_DEBT_FOR_VISIT))

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
