extends Node

# Autoload : RandomEventManager.
# Génère des micro-événements ponctuels sur la map principale Copacabana :
# portefeuille perdu, capoeira de rue, vendeur rare, touriste paumé...
# Apparaissent à un changement de phase, persistent jusqu'à la phase suivante,
# disparaissent même non-ramassés. L'idée : surprise + petit gain + flavor.

const SPAWN_CHANCE: float = 0.55  # par changement de phase
const EVENT_SCENE: String = "res://scenes/props/StreetEvent.tscn"

# Pool d'événements possibles. Chaque entrée a sa météo : où il peut spawn,
# quel reward, quel speaker, quel texte.
const EVENT_POOL: Array = [
	{
		"id": "lost_wallet",
		"label": "Carteira no chão",
		"speaker": "Sobrinho",
		"text": "Un portefeuille traîne dans le sable. Personne autour. La conscience est une notion souple, à Rio. Tu fourres les billets dans la poche et tu siffles.",
		"money": 80,
		"rep_axis": -1,  # -1 = aucun
		"rep_amount": 0,
		"icon": "💰",
		"spawn_zones": ["sand", "calcadao"],
	},
	{
		"id": "street_capoeira",
		"label": "Roda de capoeira",
		"speaker": "Sobrinho",
		"text": "Un cercle se forme. Un berimbau, deux capoeiristas qui se jaugent. Tu jettes un billet dans le chapeau, applaudis quand le ginga décolle. Quelqu'un te tape sur l'épaule, sourire complice.",
		"money": -10,  # tu donnes 10 reais
		"rep_axis": 2,  # STREET
		"rep_amount": 2,
		"icon": "🥁",
		"spawn_zones": ["calcadao"],
	},
	{
		"id": "tourist_lost",
		"label": "Tourista perdido",
		"speaker": "Tourista",
		"text": "Excuse me, the Cristo Redentor — par où ? *carte à l'envers*\n*Tu pointes vers le Corcovado, recommandes le taxi de l'Av. Atlântica. Il insiste pour glisser un billet dans ta main.*",
		"money": 40,
		"rep_axis": 3,  # TOURIST
		"rep_amount": 2,
		"icon": "🗺️",
		"spawn_zones": ["av_atlantica", "calcadao"],
	},
	{
		"id": "rare_pamonha_vendor",
		"label": "Pamonha caseira",
		"speaker": "Vendedor",
		"text": "Pamonha quentinha da roça, fregueês ! Edição limitada de domingo. Tu craques 12 reais, ça vaut chaque centavo.",
		"money": -12,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 1,
		"icon": "🌽",
		"spawn_zones": ["av_atlantica", "nossa_senhora"],
	},
	{
		"id": "samba_parade",
		"label": "Bloco de rua",
		"speaker": "Sobrinho",
		"text": "Un bloco de rua déboule, surdo en tête, drapeaux au vent. Tu te laisses porter une minute, deux, trois. Quand le bloco passe, tu réalises qu'on t'a glissé une bière dans la main.",
		"money": 0,
		"rep_axis": 4,  # CHARISMA
		"rep_amount": 2,
		"icon": "🎉",
		"spawn_zones": ["av_atlantica"],
	},
	{
		"id": "futebol_kids",
		"label": "Pelada de praia",
		"speaker": "Sobrinho",
		"text": "Quatre gamins, deux tongs en guise de but, un ballon dégonflé. Tu rentres un goal d'extérieur du droit, ils gueulent comme si t'étais Garrincha. Le plus vieux te file ses 5 reais d'enchère.",
		"money": 5,
		"rep_axis": 2,  # STREET
		"rep_amount": 1,
		"icon": "⚽",
		"spawn_zones": ["sand"],
	},
]

# Zones de spawn → bbox approximative dans le monde Copacabana.
const SPAWN_BBOX: Dictionary = {
	"sand":          {"x": [400, 2000], "y": [180, 320]},
	"calcadao":      {"x": [400, 2000], "y": [80, 120]},
	"av_atlantica":  {"x": [400, 2000], "y": [20, 50]},
	"nossa_senhora": {"x": [400, 2000], "y": [-100, -70]},
}

var _active_event: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	EventBus.time_of_day_changed.connect(_on_phase_changed)

func _on_phase_changed(_phase: int) -> void:
	# Nettoie l'événement précédent.
	_clear_active()
	# On ne spawne que sur Copacabana ; ailleurs, le joueur ne le verra pas.
	if DistrictManager.current() != "copacabana":
		return
	if _rng.randf() > SPAWN_CHANCE:
		return
	var entry: Dictionary = EVENT_POOL[_rng.randi() % EVENT_POOL.size()]
	_spawn(entry)

func _clear_active() -> void:
	if _active_event and is_instance_valid(_active_event):
		_active_event.queue_free()
	_active_event = null

func _spawn(entry: Dictionary) -> void:
	var scene: PackedScene = load(EVENT_SCENE)
	if scene == null:
		return
	var ev: Node = scene.instantiate()
	var pos: Vector2 = _random_position(entry.get("spawn_zones", ["av_atlantica"]))
	ev.position = pos
	# Configure l'événement via setters typés.
	ev.set("event_id", entry.id)
	ev.set("label_text", entry.label)
	ev.set("icon", entry.icon)
	ev.set("speaker", entry.speaker)
	ev.set("flavor_text", entry.text)
	ev.set("money_delta", entry.money)
	ev.set("rep_axis", entry.rep_axis)
	ev.set("rep_amount", entry.rep_amount)
	# Insère sous World pour qu'il bénéficie de la lumière, du Z-index, etc.
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		ev.queue_free()
		return
	world.add_child(ev)
	_active_event = ev

func _random_position(zones: Array) -> Vector2:
	var zone_id: String = zones[_rng.randi() % zones.size()]
	var bbox: Dictionary = SPAWN_BBOX.get(zone_id, SPAWN_BBOX["av_atlantica"])
	var xr: Array = bbox.x
	var yr: Array = bbox.y
	return Vector2(_rng.randf_range(xr[0], xr[1]), _rng.randf_range(yr[0], yr[1]))
