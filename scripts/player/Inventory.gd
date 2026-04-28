class_name Inventory
extends Node

var money: int = 0
var _slots: Dictionary = {}  # item_id (String) -> quantity (int)

func add_item(item_id: String, quantity: int = 1) -> void:
	_slots[item_id] = _slots.get(item_id, 0) + quantity
	EventBus.item_acquired.emit(item_id, quantity)

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if _slots.get(item_id, 0) < quantity:
		return false
	_slots[item_id] -= quantity
	if _slots[item_id] <= 0:
		_slots.erase(item_id)
	EventBus.item_consumed.emit(item_id, quantity)
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return _slots.get(item_id, 0) >= quantity

func get_quantity(item_id: String) -> int:
	return _slots.get(item_id, 0)

func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true

func serialize() -> Dictionary:
	return {"money": money, "slots": _slots.duplicate()}

func deserialize(data: Dictionary) -> void:
	money = data.get("money", 0)
	_slots = data.get("slots", {}).duplicate()
	EventBus.money_changed.emit(money)
