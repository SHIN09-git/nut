class_name FacilityPlacementOptionSnapshot
extends RefCounted

var type_id: StringName
var slot: Vector2i
var orientation: int


func _init(
	new_type_id: StringName,
	new_slot: Vector2i,
	new_orientation: int
) -> void:
	type_id = new_type_id
	slot = new_slot
	orientation = new_orientation
