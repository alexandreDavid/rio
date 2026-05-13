class_name DayLighting
extends CanvasModulate

# Tint global appliqué à l'ensemble du monde (CanvasItems) selon la phase de la
# journée. Les variations restent subtiles pour ne pas écraser les districts
# qui ont déjà un ciel thématique (Corcovado nuit, Pão de Açúcar sunset...).

const PHASE_TINTS: Array[Color] = [
	Color(1.0, 0.85, 0.62, 1),   # MORNING : aube dorée chaleureuse
	Color(1.0, 1.0, 1.0, 1),     # AFTERNOON : neutre, plein jour
	Color(0.42, 0.45, 0.70, 1),  # EVENING : nuit bleutée (~55% luminosité)
]

const FADE_DURATION: float = 3.0

func _ready() -> void:
	color = _phase_tint(TimeOfDay.current_phase)
	_refresh_nightlights(TimeOfDay.current_phase)
	EventBus.time_of_day_changed.connect(_on_phase_changed)

func _phase_tint(phase: int) -> Color:
	if phase < 0 or phase >= PHASE_TINTS.size():
		return Color(1, 1, 1, 1)
	return PHASE_TINTS[phase]

func _on_phase_changed(phase: int) -> void:
	var target: Color = _phase_tint(phase)
	var tween: Tween = create_tween()
	tween.tween_property(self, "color", target, FADE_DURATION)
	_refresh_nightlights(phase)

# Allume/éteint tous les CanvasItem dans le groupe "nightlight" selon la phase.
# Convention : un noeud tagué `nightlight` est éteint le jour, allumé le soir.
# Les districts les placent (lampadaires, vitres jaunes, halos de phare).
func _refresh_nightlights(phase: int) -> void:
	var is_night: bool = phase == TimeOfDay.Phase.EVENING
	for node in get_tree().get_nodes_in_group("nightlight"):
		if node is CanvasItem:
			(node as CanvasItem).visible = is_night
