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
	{
		"id": "pickpocket_kid",
		"label": "Carteirista",
		"speaker": "Sobrinho",
		"text": "Tu sens une main glisser dans ta poche arrière. Tu retournes — un gosse, treize ans peut-être, déjà à dix mètres. Trop tard. *vérifies ton fric* Quinze reais évaporés. Une partie de toi a presque envie de l'applaudir pour la technique.",
		"money": -15,
		"rep_axis": -1,
		"rep_amount": 0,
		"icon": "🏃",
		"spawn_zones": ["av_atlantica", "calcadao"],
	},
	{
		"id": "wedding_photographer",
		"label": "Photo de mariage",
		"speaker": "Mariée",
		"text": "*la mariée et son nouvel époux courent sur le sable, le photographe a deux secondes pour le shot* Senhor ! Vous voulez nous tenir le bouquet pendant la photo ? *vingt secondes de gloire, le photographe te glisse 30 reais dans la main au passage*",
		"money": 30,
		"rep_axis": 3,  # TOURIST
		"rep_amount": 1,
		"icon": "📸",
		"spawn_zones": ["sand", "calcadao"],
	},
	{
		"id": "street_fight",
		"label": "Briga de rua",
		"speaker": "Sobrinho",
		"text": "Deux hommes ivres se balancent des mots devant le bar. Un commence à lever le poing. Tu te glisses entre les deux, mains levées : « calma, fica frio, vão sentar ». Ça désamorce. Le barman, soulagé, te file une cachaça gratuite — 8 reais d'économie.",
		"money": 8,
		"rep_axis": 2,  # STREET
		"rep_amount": 2,
		"icon": "✋",
		"spawn_zones": ["av_atlantica"],
	},
	{
		"id": "lost_kid",
		"label": "Criança perdida",
		"speaker": "Gamin",
		"text": "*petit, six ans peut-être, t-shirt orange, mâche sa main* Eu... j'sais plus où est maman. *tu repères une femme paniquée au loin sur le calçadão, tu lui ramènes le gamin* La mère essaie de te donner 50 reais, refuses, elle insiste, tu finis par prendre 20 pour faire la paix.",
		"money": 20,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "👶",
		"spawn_zones": ["sand", "calcadao"],
	},
	{
		"id": "fake_rolex",
		"label": "Rolex mystère",
		"speaker": "Vendedor",
		"text": "*ouvre sa veste, six montres alignées sur la doublure* Rolex original, freguês, 80 reais. *tu inspectes, le poids sonne creux, la trotteuse saute par à-coups* Tu hausses les épaules et reprends ta route. Le mec t'insulte en s'éloignant. Pas une bonne affaire.",
		"money": 0,
		"rep_axis": -1,
		"rep_amount": 0,
		"icon": "⌚",
		"spawn_zones": ["av_atlantica"],
	},
	{
		"id": "homeless_blessing",
		"label": "Vovó da rua",
		"speaker": "Sobrinho",
		"text": "Une vieille recroquevillée près du mur, regard clair. Tu lui glisses 10 reais sans réfléchir. Elle te prend la main, te dit quelque chose en bas-portugais que tu ne comprends qu'à moitié — « ton oncle te regarde, sobrinho ». Tu sens ton dos se redresser tout seul.",
		"money": -10,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 3,
		"icon": "🕊️",
		"spawn_zones": ["nossa_senhora", "av_atlantica"],
	},
	{
		"id": "mare_limpa",
		"label": "Marée propre",
		"speaker": "Sobrinho",
		"text": "Trois carcasses de canots calcinés sur le sable de Leme, rubalise de la PM autour. Plus loin, Seu Pedro répare ses filets. Il te voit, porte deux doigts à son chapeau, sans un mot. La nuit, dit-on sur le calçadão, la mer dort enfin. Ton info a fait ça.",
		"money": 0,
		"rep_axis": 0,
		"rep_amount": 2,
		"icon": "🚤",
		"spawn_zones": ["sand"],
		"flag": "pecheur_to_ramos",
	},
	{
		"id": "mare_do_morro",
		"label": "Marée du morro",
		"speaker": "Gamin du morro",
		"text": "*un gosse te fourre un paquet de crevettes fraîches dans les mains et détale* « De la part de Miguel — la marée a été bonne ce mois-ci ! » *Tu ne demandes pas quelle marée. Sur le morro, on dit que les canots noirs passent désormais par un autre quai — et que le péage remonte la colline.*",
		"money": 0,
		"rep_axis": 2,
		"rep_amount": 2,
		"icon": "🦐",
		"spawn_zones": ["calcadao"],
		"flag": "pecheur_to_miguel",
	},
	# --- Payoffs différés des carrefours de voie (le monde se souvient) ---
	{
		"id": "recado_caxias",
		"label": "Um recado de Caxias",
		"speaker": "Gamin du morro",
		"text": "*un gosse te rattrape en courant et te fourre un papier plié dans la main avant de détaler* « Je recommence à zéro ici. Personne sait. Merci pour le bus. » *Pas de signature. T'en avais pas besoin.*",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "🎫",
		"spawn_zones": ["calcadao"],
		"flag": "voisin_exilado",
	},
	{
		"id": "morro_calado",
		"label": "O morro se cala",
		"speaker": "Sobrinho",
		"text": "*Deux femmes discutent fort près des étals. L'une te repère — et la conversation meurt d'un coup. Elles fixent leurs sandales jusqu'à ce que tu sois passé. Le morro n'a pas oublié le voisin livré à Miguel. Le silence aussi, c'est du respect. Le pire genre.*",
		"money": 0,
		"rep_axis": 2,  # STREET
		"rep_amount": 2,
		"icon": "🤫",
		"spawn_zones": ["calcadao", "nossa_senhora"],
		"flag": "voisin_entregue",
	},
	{
		"id": "informante_arpoador",
		"label": "O informante",
		"speaker": "Vendeur de lunettes",
		"text": "*ton dealer d'Arpoador — vendeur de lunettes, officiellement — surgit à ta hauteur, te fourre une paire de contrefaçons dans les mains* Cadeau maison, chefe. *à voix basse, en te réglant la monture* Un chargement passe par la feira jeudi. Dis-le au Capitão — et dis-lui que ça vient de toi. *il disparaît dans la foule*",
		"money": 120,
		"rep_axis": 1,  # POLICE
		"rep_amount": 2,
		"icon": "🕶",
		"spawn_zones": ["calcadao", "av_atlantica"],
		"flag": "dealer_informante",
	},
	{
		"id": "vinho_vincenzo",
		"label": "Vinho da Itália",
		"speaker": "Coursier",
		"text": "*un coursier te tend une caisse de vin, étiquette toscane, sans un mot d'expéditeur — juste un bristol : « Aux affaires qui roulent. V. » Tu la revends au premier bar venu. Mais au poste, quelqu'un a vu la livraison, et les fardas te saluent une demi-seconde trop tard, maintenant.*",
		"money": 150,
		"rep_axis": 1,  # POLICE
		"rep_amount": -2,
		"icon": "🍷",
		"spawn_zones": ["av_atlantica"],
		"flag": "saisie_vendida",
	},
	{
		"id": "suco_1601",
		"label": "Suco do 1601",
		"speaker": "Gamine",
		"text": "*un petit stand de suco improvisé sur le calçadão — c'est la gamine du 1601, en visite chez sa tante de Copa* MOÇO ! *elle te tend un gobelet débordant* Vovô dit que t'es le monsieur des tomates ! C'est cadeau, il a dit, POUR TOUJOURS ! *elle crie « pour toujours » comme un décret officiel*",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "🧃",
		"spawn_zones": ["calcadao"],
		"flag": "inquilino_coberto",
	},
	{
		"id": "cafezinho_kiosque",
		"label": "Cafezinho em silêncio",
		"speaker": "Sobrinho",
		"text": "*en passant devant le dernier kiosque libre du calçadão, la vieille dame pose un cafezinho sur le comptoir, exactement sur ton passage. Elle ne te regarde pas, ne dit rien, retourne à sa caisse. Le café est sucré comme pour un habitué. Elle sait. Elle saura toujours.*",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "☕",
		"spawn_zones": ["calcadao"],
		"flag": "kiosque_livre",
	},
	{
		"id": "manchetes_brasa",
		"label": "Manchetes em brasa",
		"speaker": "Camelô de journaux",
		"text": "EXTRA, EXTRA ! « LE CONSORTIUM NOMMÉ EN PLEIN MAC » ! *le camelô agite le journal — ton discours en une, ta photo au micro* Troisième réimpression, freguês ! *il baisse d'un ton en te reconnaissant* …C'est toi, hein ? *il t'en glisse un gratuit* Garde-le. Et garde tes arrières aussi — y'a des gens très calmes qui l'ont acheté ce matin.",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "📰",
		"spawn_zones": ["calcadao", "nossa_senhora"],
		"flag": "discurso_guerra",
	},
	{
		"id": "caixas_morro",
		"label": "Duas caixas pro morro",
		"speaker": "Moradora",
		"text": "*une femme du morro t'arrête, un plat couvert d'un torchon dans les mains* Tiens. Un pavê. *devant ton air perdu* La pharmacie de la biqueira a eu des « arrivages » le mois dernier — les remèdes de mon mari, à prix de voisin. Personne sait d'où ça vient. *elle te colle le plat dans les bras* Moi je sais pas non plus. Mange.",
		"money": 0,
		"rep_axis": 2,  # STREET
		"rep_amount": 2,
		"icon": "📦",
		"spawn_zones": ["calcadao"],
		"flag": "carga_desviada",
	},
	{
		"id": "vassoura_parvis",
		"label": "A vassoura do parvis",
		"speaker": "Beata",
		"text": "*une beata t'attrape le bras devant l'église* Tu as vu le garçon qui balaie le parvis ? Neném, du morro. *elle se signe* Il était avec les autres, avant — et maintenant il ouvre la chapelle le matin. Le Padre dit que c'est toi qui l'as amené. *elle te fourre une médaille de São Jorge dans la main* Pour toi. São Jorge protège ceux qui sortent les gosses du feu.",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 2,
		"icon": "🙏",
		"spawn_zones": ["nossa_senhora", "calcadao"],
		"flag": "nenem_protegido",
	},
	{
		"id": "pos_jogo_vitoria",
		"label": "Lundi de gloire",
		"speaker": "Sobrinho",
		"text": "Le bairro a la gueule de bois des bons jours. Le PM fredonne, le padeiro offre le cafezinho, et trois inconnus te prennent dans leurs bras parce que tu portes les bonnes couleurs. Le {time} a gagné hier — aujourd'hui, tout le monde est de la famille.",
		"money": 0,
		"rep_axis": 4,
		"rep_amount": 2,
		"icon": "🎉",
		"spawn_zones": ["calcadao", "av_atlantica"],
		"flag": "jogo_vitoria",
	},
	{
		"id": "pos_jogo_derrota",
		"label": "Lundi de deuil",
		"speaker": "Sobrinho",
		"text": "Le calçadão est silencieux comme une église. Le kiosquier remballe les drapeaux sans un mot. Un vieux en maillot du {time} fixe la mer, les mains dans le dos. Tu t'assois à côté de lui. Vous ne dites rien. C'est exactement ce qu'il fallait dire.",
		"money": 0,
		"rep_axis": 0,
		"rep_amount": 1,
		"icon": "🖤",
		"spawn_zones": ["calcadao"],
		"flag": "jogo_derrota",
	},
	{
		"id": "roda_pagode",
		"label": "Roda de pagode",
		"speaker": "Sobrinho",
		"text": "Autour d'une table du quiosque, un cavaquinho, un pandeiro, un repique — et dix voix qui connaissent toutes les paroles. Quelqu'un te tend un tamborim sans te demander ton avis. Tu rates deux temps, tu trouves le troisième. À la fin du morceau, une dame te ressert de la farofa comme si t'étais de la famille.",
		"money": 0,
		"rep_axis": 4,  # CHARISMA
		"rep_amount": 3,
		"icon": "🪘",
		"spawn_zones": ["calcadao"],
		"phases": [2],  # le pagode, c'est le soir
	},
	{
		"id": "altinha_circle",
		"label": "Roda de altinha",
		"speaker": "Sobrinho",
		"text": "Cinq joueurs, un ballon qui ne touche jamais le sable. Le cercle s'ouvre, on te fait signe d'entrer. Tu tiens trois touches, t'en rates une, tu sauves la suivante d'un talon désespéré — le cercle hurle « CARACA ! ». Personne ne compte les points. C'est ça, le jeu.",
		"money": 0,
		"rep_axis": 2,  # STREET
		"rep_amount": 2,
		"icon": "⚽",
		"spawn_zones": ["sand"],
		"phases": [1],  # l'altinha, c'est l'après-midi
	},
	{
		"id": "fla_flu_debate",
		"label": "Fla x Flu",
		"speaker": "Sobrinho",
		"text": "Devant le bar, un type en rouge et noir et un autre en tricolor refont le derby de dimanche à grands gestes. Ils t'attrapent par l'épaule : « E aí, tu torces pra quem ? » Tu poses la main sur le cœur : {time}, depuis toujours. La moitié du bar applaudit, l'autre moitié te paie une bière pour essayer de te convertir.",
		"money": 0,
		"rep_axis": 4,  # CHARISMA
		"rep_amount": 2,
		"icon": "🔥",
		"spawn_zones": ["av_atlantica"],
		"phases": [2],  # les débats de bar, c'est le soir
	},
	{
		"id": "sunset_applause",
		"label": "Pôr do sol",
		"speaker": "Sobrinho",
		"text": "Le soleil glisse derrière le Forte et le ciel passe à l'orange brûlé. Autour de toi, les gens s'arrêtent un à un. Quand le disque disparaît, la plage entière applaudit — les vendeurs, les baigneurs, le PM en faction. Tu applaudis aussi. À Rio, on remercie le soleil.",
		"money": 0,
		"rep_axis": 0,  # CIVIC
		"rep_amount": 1,
		"icon": "🌅",
		"spawn_zones": ["sand"],
		"phases": [2],
	},
	{
		"id": "ipanema_band",
		"label": "Cordel de bossa",
		"speaker": "Sobrinho",
		"text": "Un trio bossa s'est installé sur le calçadão : guitare, voix, cajón. Tu t'arrêtes, t'écoutes Garota de Ipanema version 2026. Cinq minutes, dix. Tu laisses 5 reais dans le chapeau au moment de partir.",
		"money": -5,
		"rep_axis": 4,  # CHARISMA
		"rep_amount": 2,
		"icon": "🎸",
		"spawn_zones": ["calcadao"],
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

func _on_phase_changed(phase: int) -> void:
	# Nettoie l'événement précédent.
	_clear_active()
	# On ne spawne que sur Copacabana ; ailleurs, le joueur ne le verra pas.
	if DistrictManager.current() != "copacabana":
		return
	if _rng.randf() > SPAWN_CHANCE:
		return
	# Les événements à "phases" ne sortent qu'aux bons moments de la journée
	# (le pagode le soir, l'altinha l'après-midi…).
	var pool: Array = EVENT_POOL.filter(
		func(e: Dictionary) -> bool:
			if e.has("phases") and not phase in e.phases:
				return false
			if e.has("flag") and not CampaignManager.has_flag(String(e.flag)):
				return false
			return true
	)
	if pool.is_empty():
		return
	var entry: Dictionary = pool[_rng.randi() % pool.size()]
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
