class_name FacilitySupplyState
extends RefCounted

var remaining_by_type: Dictionary[StringName, int] = {}


func _init(initial_counts: Dictionary[StringName, int] = {}) -> void:
	for type_id: StringName in initial_counts:
		remaining_by_type[type_id] = initial_counts[type_id]


func get_remaining(type_id: StringName) -> int:
	return int(remaining_by_type.get(type_id, 0))


func consume(type_id: StringName) -> bool:
	var remaining: int = get_remaining(type_id)
	if remaining <= 0:
		return false
	remaining_by_type[type_id] = remaining - 1
	return true


func restore(type_id: StringName) -> bool:
	if not remaining_by_type.has(type_id):
		return false
	remaining_by_type[type_id] += 1
	return true


func copy_state() -> FacilitySupplyState:
	return FacilitySupplyState.new(remaining_by_type)
