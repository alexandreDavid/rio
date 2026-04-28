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

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = prompt_text
		interactable.required_reputation = required_reputation
		interactable.locked_prompt = locked_prompt
		interactable.interacted.connect(_on_interacted)

func _on_interacted(by: Node) -> void:
	if by == null or not (by is Node2D):
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
