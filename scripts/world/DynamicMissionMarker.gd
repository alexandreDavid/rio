class_name DynamicMissionMarker
extends Node2D

# Marqueur visible dans le monde pour une mission éphémère acceptée.
# Le joueur doit explicitement INTERAGIR sur la zone (bouton E / tap) pour
# valider l'étape — évite le « money for nothing » d'un trigger automatique
# au passage.

@export var category: int = 0  # DynamicMissionManager.Category

@onready var interactable: Interactable = $Interactable
@onready var pulse_rect: ColorRect = $Pulse
@onready var core_rect: ColorRect = $Core

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func apply_color(c: Color) -> void:
	if core_rect:
		core_rect.color = c
	if pulse_rect:
		pulse_rect.color = Color(c.r, c.g, c.b, 0.4)

func _process(delta: float) -> void:
	# Petit clignotement pour attirer l'œil.
	if pulse_rect:
		var t: float = Time.get_ticks_msec() / 1000.0
		var s: float = 1.0 + 0.25 * sin(t * 4.0)
		pulse_rect.scale = Vector2(s, s)

func _on_interacted(_by: Node) -> void:
	DynamicMissionManager.mark_progress(category)
	# Le manager s'occupe du queue_free via _despawn / re-_spawn.
