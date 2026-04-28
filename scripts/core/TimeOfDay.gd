extends Node

# Simplified day cycle: MORNING -> AFTERNOON -> EVENING -> next day.
# Autoload name: TimeOfDay.

enum Phase { MORNING, AFTERNOON, EVENING }

const PHASE_DURATION_SECONDS: float = 300.0  # 5 real min = one phase

var current_phase: int = Phase.MORNING
var day_count: int = 1
var _timer: float = 0.0
var _paused: bool = false

func _process(delta: float) -> void:
	if _paused:
		return
	_timer += delta
	if _timer >= PHASE_DURATION_SECONDS:
		_timer = 0.0
		_advance_phase()

func _advance_phase() -> void:
	var next: int = current_phase + 1
	var new_day: bool = false
	if next >= Phase.size():
		next = Phase.MORNING
		day_count += 1
		new_day = true
	current_phase = next
	EventBus.time_of_day_changed.emit(current_phase)
	if new_day:
		EventBus.day_elapsed.emit(day_count)

func set_paused(paused: bool) -> void:
	_paused = paused

# Renvoie un ratio 0..1 de la progression dans la phase courante.
func phase_progress() -> float:
	return clamp(_timer / PHASE_DURATION_SECONDS, 0.0, 1.0)

func serialize() -> Dictionary:
	return {"phase": current_phase, "day": day_count, "timer": _timer}

func deserialize(data: Dictionary) -> void:
	current_phase = data.get("phase", Phase.MORNING)
	day_count = data.get("day", 1)
	_timer = data.get("timer", 0.0)
