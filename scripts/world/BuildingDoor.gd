class_name BuildingDoor
extends Node2D

# Porte téléporteur. Entrée : stocke la position de retour dans BuildingManager
# avant de téléporter vers destination. Sortie (is_exit=true) : récupère la
# position de retour stockée pour renvoyer le joueur devant le bon bâtiment.

@export var interactable: Interactable
@export var destination: Vector2 = Vector2.ZERO
@export var prompt_text: String = "Entrer"
@export var is_exit: bool = false
@export var return_offset: Vector2 = Vector2(0, 32)  # où le joueur réapparaît après sortie
# Gating optionnel : si renseigné, la porte refuse l'entrée tant que le seuil n'est pas atteint.
@export var required_reputation: Dictionary = {}
@export var locked_prompt: String = ""
# Hook narratif d'ouverture : si vrai, le 1er clic sur cette porte (avant que
# l'héritage soit accepté) déclenche IntroSeuJoaoBump à la place du téléport.
# Sert à la porte de sortie de la maison du tio Zé : le joueur clique sortir,
# Seu João rentre par cette porte et empêche le départ.
@export var intro_bump_door: bool = false

const _IntroSeuJoaoBumpScript: Script = preload("res://scripts/cutscenes/IntroSeuJoaoBump.gd")

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = prompt_text
		interactable.required_reputation = required_reputation
		interactable.locked_prompt = locked_prompt
		interactable.interacted.connect(_on_interacted)
	# Visuel uniquement pour les portes de sortie (intérieurs) — les portes
	# d'entrée des bâtiments restent invisibles (les bâtiments dessinent leurs
	# propres façades). Skip si un visuel a déjà été placé manuellement (cf.
	# HouseInterior qui a ses propres ColorRects).
	if is_exit and get_node_or_null("DoorFrame") == null:
		_build_exit_visual()

# Crée un petit visuel de porte de sortie : cadre brun + panneau bois +
# poignée + paillasson + flèche "↓ Sortir". Auto-appliqué à toutes les
# ExitDoor des intérieurs.
func _build_exit_visual() -> void:
	var frame: ColorRect = ColorRect.new()
	frame.name = "DoorFrame"
	frame.offset_left = -16.0
	frame.offset_top = -22.0
	frame.offset_right = 16.0
	frame.offset_bottom = 6.0
	frame.color = Color(0.28, 0.18, 0.12, 1)
	add_child(frame)
	var panel: ColorRect = ColorRect.new()
	panel.name = "DoorPanel"
	panel.offset_left = -12.0
	panel.offset_top = -18.0
	panel.offset_right = 12.0
	panel.offset_bottom = 4.0
	panel.color = Color(0.55, 0.34, 0.20, 1)
	add_child(panel)
	var line: ColorRect = ColorRect.new()
	line.name = "DoorPanelLine"
	line.offset_left = -12.0
	line.offset_top = -6.0
	line.offset_right = 12.0
	line.offset_bottom = -4.0
	line.color = Color(0.32, 0.20, 0.12, 1)
	add_child(line)
	var knob: ColorRect = ColorRect.new()
	knob.name = "DoorKnob"
	knob.offset_left = 6.0
	knob.offset_top = -10.0
	knob.offset_right = 9.0
	knob.offset_bottom = -7.0
	knob.color = Color(0.92, 0.78, 0.32, 1)
	add_child(knob)
	var mat: ColorRect = ColorRect.new()
	mat.name = "DoorMat"
	mat.offset_left = -18.0
	mat.offset_top = 6.0
	mat.offset_right = 18.0
	mat.offset_bottom = 12.0
	mat.color = Color(0.42, 0.30, 0.22, 1)
	add_child(mat)
	var arrow: Label = Label.new()
	arrow.name = "ExitArrow"
	arrow.offset_left = -32.0
	arrow.offset_top = -42.0
	arrow.offset_right = 32.0
	arrow.offset_bottom = -22.0
	arrow.text = "↓ Sortir"
	arrow.horizontal_alignment = 1
	arrow.add_theme_font_size_override("font_size", 11)
	arrow.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1))
	arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	arrow.add_theme_constant_override("outline_size", 3)
	add_child(arrow)

func _on_interacted(by: Node) -> void:
	if by == null or not (by is Node2D):
		return
	# Bump narratif : intercepte la sortie avant le téléport tant que l'héritage
	# n'a pas démarré. Seu João débarque par cette porte et bloque le joueur.
	if intro_bump_door and is_exit and not _intro_bump_completed():
		EventBus.interaction_unavailable.emit()
		_IntroSeuJoaoBumpScript.run(self)
		return
	var target: Vector2
	if is_exit:
		target = BuildingManager.last_exit_position
		if target == Vector2.ZERO:
			target = destination  # fallback si on a spawné directement dans l'intérieur
	else:
		BuildingManager.last_exit_position = global_position + return_offset
		target = destination
	var cam: Camera2D = by.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
	(by as Node2D).global_position = target
	if cam:
		cam.reset_smoothing()
	EventBus.interaction_unavailable.emit()

func _intro_bump_completed() -> bool:
	# Source de vérité fiable : l'état de la quête heritage est auto-persisté
	# via QuestManager.serialize. Si elle est active ou complétée, le joueur
	# a forcément vu la cinématique d'introduction.
	if QuestManager.is_active("act1_heritage") or QuestManager.is_completed("act1_heritage"):
		return true
	# Fallback flags (parfois posés par debug skip ou autres chemins) — pas
	# fiables seuls car set_flag ne déclenche pas auto-save, mais utiles si
	# le joueur a passé par Cmd+2.
	return CampaignManager.has_flag("intro_bump_seen") \
			or CampaignManager.has_flag("intro_seen") \
			or CampaignManager.has_flag("act1_started")
