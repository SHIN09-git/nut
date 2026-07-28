class_name InitialFacilityConfig
extends RefCounted

var facility_id: int
var type_id: StringName
var slot: Vector2i
var orientation: int
var zone_id: StringName
var available: bool
var player_removable: bool


static func from_data(data: InitialFacilityData) -> InitialFacilityConfig:
	if data == null or not data.is_valid():
		return null
	var config: InitialFacilityConfig = InitialFacilityConfig.new()
	config.facility_id = data.facility_id
	config.type_id = data.type_id
	config.slot = data.slot
	config.orientation = data.orientation
	config.zone_id = data.zone_id
	config.available = data.available
	config.player_removable = data.player_removable
	return config
