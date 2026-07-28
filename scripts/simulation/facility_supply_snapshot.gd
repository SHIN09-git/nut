class_name FacilitySupplySnapshot
extends RefCounted

var type_id: StringName
var unlock_type_id: StringName
var remaining_count: int
var unlocked: bool


func _init(
	new_type_id: StringName,
	new_unlock_type_id: StringName,
	new_remaining_count: int,
	new_unlocked: bool
) -> void:
	type_id = new_type_id
	unlock_type_id = new_unlock_type_id
	remaining_count = new_remaining_count
	unlocked = new_unlocked
