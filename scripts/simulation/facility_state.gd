class_name FacilityState
extends RefCounted

var facility_id: int
var type_id: StringName
var slot: Vector2i
var orientation: int
var zone_id: StringName
var available: bool
var player_removable: bool


func _init(
	new_facility_id: int,
	new_type_id: StringName,
	new_slot: Vector2i,
	new_orientation: int,
	new_zone_id: StringName = &"",
	new_available: bool = true,
	new_player_removable: bool = true
) -> void:
	facility_id = new_facility_id
	type_id = new_type_id
	slot = new_slot
	orientation = new_orientation
	zone_id = new_zone_id
	available = new_available
	player_removable = new_player_removable


func copy_state() -> FacilityState:
	return FacilityState.new(
		facility_id,
		type_id,
		slot,
		orientation,
		zone_id,
		available,
		player_removable
	)
