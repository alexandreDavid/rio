extends Node

# Multi-axis reputation. Each axis moves independently. Autoload name: ReputationSystem.
# Axes can be expanded — keep order stable or migrate saves.

enum Axis { CIVIC, POLICE, STREET, TOURIST, CHARISMA }

const MIN_VALUE: int = -100
const MAX_VALUE: int = 100

var _values: Array[int] = []
# Compteur par source pour limiter les gains répétitifs (ex. gym → max 3 points de charisma).
# Clé = identifiant de source libre (ex. "gym"), valeur = total déjà gagné via cette source.
var _source_gains: Dictionary = {}

func _ready() -> void:
	_values.resize(Axis.size())
	_values.fill(0)

func get_value(axis: int) -> int:
	return _values[axis]

func modify(axis: int, delta: int) -> void:
	_values[axis] = clamp(_values[axis] + delta, MIN_VALUE, MAX_VALUE)
	EventBus.reputation_changed.emit(Axis.keys()[axis], _values[axis])

func set_value(axis: int, value: int) -> void:
	_values[axis] = clamp(value, MIN_VALUE, MAX_VALUE)
	EventBus.reputation_changed.emit(Axis.keys()[axis], _values[axis])

# Applique `delta` au plus sur `axis`, en respectant un plafond total pour `source_id`.
# Retourne le delta effectivement appliqué (0 si la source est plafonnée).
func gain_capped(axis: int, delta: int, source_id: String, cap: int) -> int:
	if delta <= 0 or cap <= 0:
		return 0
	var already: int = int(_source_gains.get(source_id, 0))
	if already >= cap:
		return 0
	var applied: int = min(delta, cap - already)
	_source_gains[source_id] = already + applied
	modify(axis, applied)
	return applied

func source_gained(source_id: String) -> int:
	return int(_source_gains.get(source_id, 0))

func serialize() -> Dictionary:
	var out: Dictionary = {}
	for i in Axis.size():
		out[Axis.keys()[i]] = _values[i]
	out["_source_gains"] = _source_gains.duplicate()
	return out

func deserialize(data: Dictionary) -> void:
	for i in Axis.size():
		var key: String = Axis.keys()[i]
		if data.has(key):
			_values[i] = data[key]
	_source_gains = data.get("_source_gains", {}).duplicate() if data.get("_source_gains") != null else {}
