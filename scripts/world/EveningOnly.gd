class_name EveningOnly
extends Node2D

# Conteneur de décor visible uniquement en phase EVENING (TimeOfDay).
# À attacher à un nœud regroupant la « vie du soir » d'une scène district
# (ex. la mureta da Urca animée dans BotafogoFlamengo).

func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	_on_phase_changed(TimeOfDay.current_phase)

func _on_phase_changed(phase: int) -> void:
	visible = phase == TimeOfDay.Phase.EVENING
