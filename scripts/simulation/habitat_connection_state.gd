class_name HabitatConnectionState
extends RefCounted

var connection_id: int
var first_zone_id: StringName
var second_zone_id: StringName
var gated: bool
var open: bool
var owner_facility_id: int


func _init(
	new_connection_id: int,
	new_first_zone_id: StringName,
	new_second_zone_id: StringName,
	new_gated: bool = false,
	new_open: bool = true,
	new_owner_facility_id: int = -1
) -> void:
	connection_id = new_connection_id
	first_zone_id = new_first_zone_id
	second_zone_id = new_second_zone_id
	gated = new_gated
	open = new_open
	owner_facility_id = new_owner_facility_id


func copy_state() -> HabitatConnectionState:
	return HabitatConnectionState.new(
		connection_id,
		first_zone_id,
		second_zone_id,
		gated,
		open,
		owner_facility_id
	)
