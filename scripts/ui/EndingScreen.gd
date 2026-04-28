extends CanvasLayer

# Intro du règne (acte 4) : déclenchée par EventBus.endgame_chosen, présente la voie
# au joueur puis le rend au monde — l'acte 4 (gameplay continu) prend le relais.

@onready var title_label: Label = $Panel/Margin/Layout/Title
@onready var body_label: Label = $Panel/Margin/Layout/Body
@onready var continue_button: Button = $Panel/Margin/Layout/Continue

const REIGN_INTROS: Dictionary = {
	CampaignManager.Endgame.PREFEITO: {
		"title": "Coronel do Bairro",
		"body": "Le scrutin tombe en ta faveur. Le Padre célèbre une messe spéciale, l'orfanato chante ton nom, le calçadão accroche ton portrait au mur du café. Le bairro t'appelle Coronel.\n\nMais Coronel ne se repose pas : il y a des audiences à tenir, un Carnaval à organiser, et le Consortium qui ne lâchera pas l'affaire si vite. Va voir le Padre — la première audience t'attend.",
	},
	CampaignManager.Endgame.POLICIA: {
		"title": "Chefe de Polícia",
		"body": "L'Operação Madrugada nettoie le Morro avant l'aube. À 7h, le bairro découvre les manchettes — et toi, debout à côté de Ramos pour la photo. Le poste t'appelle Chefe.\n\nMais Chefe ne dort pas : il faut purger les derniers nids, sécuriser le Carnaval, et l'audit interne arrive. Retourne voir Ramos — la première opération a déjà commencé.",
	},
	CampaignManager.Endgame.TRAFICO: {
		"title": "Patrão do Morro",
		"body": "La corrida traverse Niterói sans une éraflure. Au lever du soleil, le Morro a un nouveau Patrão — toi. Miguel s'efface, Tito passe le mot.\n\nMais Patrão se respecte : les commerçants paient leur tribut, le Carnaval ouvre un marché parallèle, et un cartel de São Paulo regarde la ligne. Va voir Miguel — il y a des comptes à ouvrir.",
	},
}

func _ready() -> void:
	visible = false
	if continue_button:
		continue_button.pressed.connect(_on_continue)
	EventBus.endgame_chosen.connect(_on_endgame)

func _on_endgame(path: int) -> void:
	if not REIGN_INTROS.has(path):
		return
	# Cinématique de bénédiction par le mentor de la voie avant l'écran de fin.
	# Donne du poids au moment de bascule en règne.
	await Act3FinaleCutscenes.run_for(path)
	var data: Dictionary = REIGN_INTROS[path]
	if title_label:
		title_label.text = data.title
	if body_label:
		body_label.text = data.body
	if continue_button:
		continue_button.text = "Commencer le règne"
	visible = true
	var tree: SceneTree = get_tree()
	if tree:
		tree.paused = true

func _on_continue() -> void:
	visible = false
	var tree: SceneTree = get_tree()
	if tree:
		tree.paused = false
