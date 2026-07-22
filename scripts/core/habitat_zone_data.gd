class_name HabitatZoneData
extends Resource

@export var zone_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var initial_humidity: float = 0.5
@export var connected_zone_ids: Array[StringName] = []
@export var available: bool = true


func is_valid() -> bool:
	if (
		zone_id.is_empty()
		or is_nan(initial_humidity)
		or is_inf(initial_humidity)
		or initial_humidity < 0.0
		or initial_humidity > 1.0
	):
		return false

	var seen_connections: Dictionary[StringName, bool] = {}
	for connected_zone_id: StringName in connected_zone_ids:
		if (
			connected_zone_id.is_empty()
			or connected_zone_id == zone_id
			or seen_connections.has(connected_zone_id)
		):
			return false
		seen_connections[connected_zone_id] = true
	return true
