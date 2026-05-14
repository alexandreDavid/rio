extends CanvasLayer

# Tutoriel d'accueil paginé. S'ouvre une seule fois au premier lancement
# (Settings.tutorial_seen). Réouvrable depuis l'app Ajustes via open().

const PAGES: Array = [
	{
		"title": "Bem-vindo a Copacabana",
		"text": "Tu hérites d'une dette de 50 000 R$ envers le consortium. Trois voies s'offrent à toi pour t'en sortir : Polícia, Tráfico, Prefeito. Joue ce que tu veux devenir.",
	},
	{
		"title": "Comment bouger",
		"text": "Mobile : joystick virtuel en bas à gauche.\nDesktop : WASD ou flèches.\n\nInteragis avec [E] (desktop) ou en t'approchant et en tapotant le NPC sur mobile. Un « ! » jaune flotte au-dessus des NPCs qui ont quelque chose à te proposer.",
	},
	{
		"title": "Le HUD",
		"text": "En haut à droite :\n📱 téléphone (apps)\n📖 journal narratif\n💾 sauvegarder\n📸 prendre une photo (touche F)\n\nLa carte de quête (top droite) indique ta priorité actuelle. ✦ = trame, • = activité.",
	},
	{
		"title": "Le téléphone",
		"text": "📱 ouvre tes apps :\n🚕 Taxi — voyager entre quartiers\n💪 Saúde — stats, dette, tracker d'acte\n📜 Crônica — toutes les quêtes\n📰 Notícias — manchettes du bairro\n📸 Álbum — tes photos\n🏆 Conquistas — jalons\n⚙ Ajustes — volumes audio",
	},
	{
		"title": "Première étape",
		"text": "Sors de la maison de tio Zé par la pente sud. Descends jusqu'au calçadão de Copacabana. Cherche Seu João près de sa charrette de milho — il te lancera la trame.\n\nBonne chance, sobrinho.",
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
	# Auto-ouvre au premier lancement (pas de save existante + jamais vu).
	if not Settings.tutorial_seen and not SaveSystem.has_save():
		call_deferred("open")

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
