class_name HabitatZoneState
extends RefCounted

var zone_id: StringName
var humidity: float
var light_exposure: float
var pollution: float
var connected_zone_ids: Array[StringName] = []
var available: bool = true


func _init(
	new_zone_id: StringName,
	new_humidity: float,
	new_connected_zone_ids: Array[StringName],
	new_available: bool,
	new_light_exposure: float = 0.5,
	new_pollution: float = 0.0
) -> void:
	zone_id = new_zone_id
	humidity = clampf(new_humidity, 0.0, 1.0)
	light_exposure = clampf(new_light_exposure, 0.0, 1.0)
	pollution = clampf(new_pollution, 0.0, 1.0)
	connected_zone_ids.assign(new_connected_zone_ids)
	available = new_available


static func from_data(zone_data: HabitatZoneData) -> HabitatZoneState:
	if zone_data == null or not zone_data.is_valid():
		return null
	return HabitatZoneState.new(
		zone_data.zone_id,
		zone_data.initial_humidity,
		zone_data.connected_zone_ids,
		zone_data.available,
		zone_data.initial_light_exposure,
		zone_data.initial_pollution
	)


func duplicate_state() -> HabitatZoneState:
	return HabitatZoneState.new(
		zone_id,
		humidity,
		connected_zone_ids,
		available,
		light_exposure,
		pollution
	)


func duplicate_environment_state() -> HabitatZoneState:
	return HabitatZoneState.new(
		zone_id,
		humidity,
		[],
		available,
		light_exposure,
		pollution
	)


func apply_humidity_adjustment(amount: float) -> bool:
	if is_nan(amount) or is_inf(amount):
		return false
	humidity = clampf(humidity + amount, 0.0, 1.0)
	return true


func set_humidity(value: float) -> bool:
	if not is_finite(value):
		return false
	humidity = clampf(value, 0.0, 1.0)
	return true


func set_light_exposure(value: float) -> bool:
	if not is_finite(value):
		return false
	light_exposure = clampf(value, 0.0, 1.0)
	return true


func set_pollution(value: float) -> bool:
	if not is_finite(value):
		return false
	pollution = clampf(value, 0.0, 1.0)
	return true


func can_reach(target_zone_id: StringName) -> bool:
	return (
		available
		and (
			target_zone_id == zone_id
			or connected_zone_ids.has(target_zone_id)
		)
	)
