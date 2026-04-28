class_name DayLighting
extends CanvasModulate

# Tint global appliqué à l'ensemble du monde (CanvasItems) selon la phase de la
# journée. Les variations restent subtiles pour ne pas écraser les districts
# qui ont déjà un ciel thématique (Corcovado nuit, Pão de Açúcar sunset...).

const PHASE_TINTS: Array[Color] = [
	Color(0.92, 0.95, 1.0, 1),   # MORNING : très léger cool
	Color(1.0, 1.0, 1.0, 1),     # AFTERNOON : neutre
	Color(1.0, 0.88, 0.78, 1),   # EVENING : chaud / doré
]

const FADE_DURATION: float = 1.4

func _ready() -> void:
	color = _phase_tint(TimeOfDay.current_phase)
	EventBus.time_of_day_changed.connect(_on_phase_changed)

func _phase_tint(phase: int) -> Color:
	if phase < 0 or phase >= PHASE_TINTS.size():
		return Color(1, 1, 1, 1)
	return PHASE_TINTS[phase]

func _on_phase_changed(phase: int) -> void:
	var target: Color = _phase_tint(phase)
	var tween: Tween = create_tween()
	tween.tween_property(self, "color", target, FADE_DURATION)
