extends Control

# Scène d'introduction : texte narratif + rappel des contrôles.
# Espace/Entrée (ou tap sur le bouton) pour avancer ; à la fin, bascule sur Main.tscn.

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"

const STORY_PAGES: Array[String] = [
	"Rio de Janeiro. Copacabana. Un matin comme les autres, sauf que Zé — ton oncle, ton parrain, ton problème — a disparu.\n\nIl t'a laissé trois choses : sa carrocinha de milho, les clefs d'un studio au Morro, et une dette de cinquante mille reais.\n\nLe Carnaval est dans un mois. Tu ferais mieux d'avoir réglé la note d'ici là.",
	"À toi de choisir comment t'en sortir.\n\nDeviens un pilier de la communauté. Entre dans la police. Ou prends la rue.\n\nSelon les gens que tu aides, les gens que tu trahis, et la tête que tu gardes quand tout dérape, tu finiras Prefeito, Chefe de Polícia, ou Rei do Tráfico.",
	"Contrôles :\n\n• Joystick en bas à gauche — se déplacer\n• Bouton E en bas à droite — interagir (parler, prendre, acheter…)\n• Bouton ☰ en haut à droite — voir tes caractéristiques\n\nLes dialogues ont souvent plusieurs choix. Chaque choix modifie tes stats (Respect, Voyou, Police, Touristes, Charisma).\n\nBonne chance, parceiro.",
]

@onready var title_label: Label = $Layout/Title
@onready var body_label: RichTextLabel = $Layout/Body
@onready var continue_button: Button = $Layout/Continue
@onready var load_button: Button = $Layout/LoadSave
@onready var newgame_button: Button = $Layout/NewGame

var _page: int = 0

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_advance)
	if load_button:
		load_button.pressed.connect(_goto_main)
	if newgame_button:
		newgame_button.pressed.connect(_start_new_game)
	_render()

func _start_new_game() -> void:
	SaveSystem.discard_save()
	get_tree().change_scene_to_file(MAIN_SCENE)

func _goto_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	# Raccourcis clavier secondaires (desktop) — sur mobile, on passe par le bouton.
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE:
			get_tree().change_scene_to_file(MAIN_SCENE)
			get_viewport().set_input_as_handled()

func _advance() -> void:
	_page += 1
	if _page >= STORY_PAGES.size():
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	_render()

func _render() -> void:
	if body_label:
		body_label.text = STORY_PAGES[_page]
	if title_label:
		title_label.visible = _page == 0
	if continue_button:
		if _page == STORY_PAGES.size() - 1:
			continue_button.text = "Commencer"
		else:
			continue_button.text = "Continuer"
	# Les boutons « Charger » et « Nouvelle partie » ne sont visibles que sur
	# la 1ère page, pour éviter le bruit visuel sur les pages narratives.
	var has_save: bool = SaveSystem.has_save()
	if load_button:
		load_button.visible = _page == 0 and has_save
	if newgame_button:
		newgame_button.visible = _page == 0 and has_save
