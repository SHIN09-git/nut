class_name FacilitySnapshot
extends RefCounted

var facility_id: int
var type_id: StringName
var slot: Vector2i
var orientation: int
var footprint: Vector2i
var placement_layer: FacilityData.PlacementLayer
var zone_id: StringName
var available: bool
var player_removable: bool


func _init(
	new_facility_id: int,
	new_type_id: StringName,
	new_slot: Vector2i,
	new_orientation: int,
	new_footprint: Vector2i,
	new_placement_layer: FacilityData.PlacementLayer,
	new_zone_id: StringName,
	new_available: bool,
	new_player_removable: bool
) -> void:
	facility_id = new_facility_id
	type_id = new_type_id
	slot = new_slot
	orientation = new_orientation
	footprint = new_footprint
	placement_layer = new_placement_layer
	zone_id = new_zone_id
	available = new_available
	player_removable = new_player_removable
