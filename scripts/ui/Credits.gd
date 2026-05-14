extends CanvasLayer

# Écran générique — déclenché depuis l'Épilogue ou les Ajustes. Affiche un
# défilement vertical de crédits puis 2 boutons : « Retour au menu » qui
# recharge Intro.tscn, ou « Continuer » qui ferme l'overlay.

@onready var body_label: Label = $Panel/Margin/Layout/ScrollContainer/Body
@onready var scroll: ScrollContainer = $Panel/Margin/Layout/ScrollContainer
@onready var menu_button: Button = $Panel/Margin/Layout/Buttons/Menu
@onready var close_button: Button = $Panel/Margin/Layout/Buttons/Close

const INTRO_SCENE: String = "res://scenes/main/Intro.tscn"

const CREDITS_TEXT: String = """
Rio — Copacabana
vertical slice

═══════════════════════

Conception & écriture
  Alexandre David

Direction technique
  Alexandre David

Engine
  Godot 4.6 (Forward+)

Scripts & systèmes
  GDScript statiquement typé
  Autoloads modulaires (EventBus,
  CampaignManager, NPCAffinity,
  AchievementSystem, …)

Dialogues
  Mécanique placeholder
  + intégration Ink prête

Inspirations
  Rio de Janeiro
  Copacabana, Niterói, Barra
  Le Morro et ses légendes

Tests
  2140 assertions, 0 échecs
  IntegrationTest headless

═══════════════════════

Co-développement
  Claude Opus 4.7 (1M context)
  Anthropic

═══════════════════════

Merci d'avoir joué.

Para o povo, pelo povo.

╭───────────────────────╮
│  CARNAVAL  ✦  RIO     │
╰───────────────────────╯
"""

func _ready() -> void:
	visible = false
	if menu_button:
		menu_button.pressed.connect(_on_menu)
	if close_button:
		close_button.pressed.connect(_on_close)
	if body_label:
		body_label.text = CREDITS_TEXT

func open() -> void:
	visible = true
	get_tree().paused = true
	# Auto-scroll lent du contenu.
	if scroll:
		scroll.scroll_vertical = 0
		_animate_scroll()

func _animate_scroll() -> void:
	if scroll == null or body_label == null:
		return
	await get_tree().process_frame
	var max_y: int = max(0, int(body_label.size.y - scroll.size.y))
	if max_y <= 0:
		return
	var tw: Tween = create_tween()
	tw.tween_property(scroll, "scroll_vertical", max_y, max(8.0, float(max_y) / 28.0))

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(INTRO_SCENE)

func _on_close() -> void:
	visible = false
	get_tree().paused = false
