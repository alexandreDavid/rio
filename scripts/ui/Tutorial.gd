extends CanvasLayer

# Guide paginé, consultable depuis l'app Ajustes via open(). Il ne s'ouvre
# plus seul : le joueur neuf apprend par les astuces contextuelles
# (ContextTips), au moment où chaque geste sert.

const PAGES: Array = [
	{
		"title": "Bem-vindo a Copacabana",
		"text": "Ton oncle Zé a disparu. Il te laisse sa carrocinha de milho et 50 000 R$ de dette envers le consortium de Dom Nilton.\n\nQuatre voies pour t'en sortir : Polícia (Capitão Ramos), Tráfico (Tito), Prefeito (le Padre) ou Consórcio (Magalhães). Tu les goûteras toutes avant de choisir.",
	},
	{
		"title": "Comment bouger",
		"text": "Mobile : joystick virtuel en bas à gauche.\nDesktop : WASD ou flèches.\n\nApproche-toi : quand un prompt apparaît, touche ✋ (en bas à droite) — ou [E] au clavier. Un « ! » jaune flotte au-dessus des NPCs qui ont quelque chose à te proposer.",
	},
	{
		"title": "Le HUD",
		"text": "En haut à droite : 📱 le téléphone (toutes les apps).\nEn bas à droite : 📸 prendre une photo.\nPas de bouton sauvegarde : le jeu s'enregistre tout seul.\n\nEn haut au centre : ton panneau Objectif. Il affiche en permanence l'acte en cours, le prochain pas à faire et le lieu où aller.",
	},
	{
		"title": "Toujours savoir où aller",
		"text": "Une flèche dorée — la boussole — pointe en continu vers ton objectif.\n\n📍 Sur place : un anneau marque le point exact.\n➤ Hors écran : la flèche se colle au bord, dans la bonne direction.\n🚕 Autre quartier : elle te renvoie au taxi avec le nom du quartier.\n\nUn message a défilé trop vite ? Tape le panneau Objectif pour revoir le dernier jalon.",
	},
	{
		"title": "Le téléphone",
		"text": "📱 ouvre tes apps :\n🚕 Taxi — voyager entre quartiers\n💪 Saúde — stats, dette, tracker d'acte\n📜 Crônica — toutes les quêtes\n📖 Diário — relire les moments forts\n📰 Notícias — manchettes du bairro\n📸 Álbum — tes photos\n🏆 Conquistas — jalons\n⚙ Ajustes — volumes, sauvegardes",
	},
	{
		"title": "Première étape",
		"text": "Tu es dans la maison de Zé, au morro, avec mãe et vovó. Seu João — le vieux compadre de Zé — va débarquer avec des nouvelles.\n\nEnsuite : le morro d'abord (un gamin a disparu), puis l'escalier vers Copacabana, la carrocinha, et 500 R$ d'acompte chez Dom Nilton.\n\nBonne chance, sobrinho.",
	},
]

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var indicator: Label = $Panel/Margin/VBox/Footer/Indicator
@onready var prev_btn: Button = $Panel/Margin/VBox/Footer/Prev
@onready var next_btn: Button = $Panel/Margin/VBox/Footer/Next
@onready var skip_btn: Button = $Panel/Margin/VBox/Footer/Skip

var _current: int = 0

func _ready() -> void:
	# Cache à la fois la CanvasLayer et ses Control enfants : en Godot 4,
	# CanvasLayer.visible=false stoppe le rendu mais ne désactive PAS toujours
	# l'input des Control enfants. La Backdrop a mouse_filter=STOP par défaut
	# et bloquerait toute la fenêtre tant que le tutoriel n'est pas explicitement
	# ouvert. On désactive les deux niveaux pour être sûr.
	visible = false
	if backdrop:
		backdrop.visible = false
	if panel:
		panel.visible = false
	prev_btn.pressed.connect(_prev)
	next_btn.pressed.connect(_next)
	skip_btn.pressed.connect(_close)
	if panel:
		panel.offset_left = -520.0
		panel.offset_right = 520.0
		panel.offset_top = -400.0
		panel.offset_bottom = 400.0
		body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UIFit.keep_floor(panel, int(UIFit.MIN_SCREEN_FONT))

func open() -> void:
	_current = 0
	if backdrop:
		backdrop.visible = true
	if panel:
		panel.visible = true
	_show_page()
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	if backdrop:
		backdrop.visible = false
	if panel:
		panel.visible = false
	get_tree().paused = false
	Settings.mark_tutorial_seen()

func _next() -> void:
	if _current < PAGES.size() - 1:
		_current += 1
		_show_page()
	else:
		_close()

func _prev() -> void:
	if _current > 0:
		_current -= 1
		_show_page()

func _show_page() -> void:
	var page: Dictionary = PAGES[_current]
	title_label.text = page.get("title", "")
	body_label.text = page.get("text", "")
	indicator.text = "%d / %d" % [_current + 1, PAGES.size()]
	prev_btn.disabled = _current == 0
	next_btn.text = "Terminer" if _current == PAGES.size() - 1 else "Suivant"
