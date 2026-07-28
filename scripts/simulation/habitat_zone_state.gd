class_name HabitatZoneState
extends RefCounted

var zone_id: StringName
var humidity: float
var connected_zone_ids: Array[StringName] = []
var available: bool = true


func _init(
	new_zone_id: StringName,
	new_humidity: float,
	new_connected_zone_ids: Array[StringName],
	new_available: bool
) -> void:
	zone_id = new_zone_id
	humidity = clampf(new_humidity, 0.0, 1.0)
	connected_zone_ids.assign(new_connected_zone_ids)
	available = new_available


static func from_data(zone_data: HabitatZoneData) -> HabitatZoneState:
	if zone_data == null or not zone_data.is_valid():
		return null
	return HabitatZoneState.new(
		zone_data.zone_id,
		zone_data.initial_humidity,
		zone_data.connected_zone_ids,
		zone_data.available
	)


func duplicate_state() -> HabitatZoneState:
	return HabitatZoneState.new(
		zone_id,
		humidity,
		connected_zone_ids,
		available
	)


func duplicate_environment_state() -> HabitatZoneState:
	return HabitatZoneState.new(
		zone_id,
		humidity,
		[],
		available
	)


func apply_humidity_adjustment(amount: float) -> bool:
	if is_nan(amount) or is_inf(amount):
		return false
	humidity = clampf(humidity + amount, 0.0, 1.0)
	return true


func can_reach(target_zone_id: StringName) -> bool:
	return (
		available
		and (
			target_zone_id == zone_id
			or connected_zone_ids.has(target_zone_id)
		)
	)
