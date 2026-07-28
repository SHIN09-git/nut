class_name HabitatZoneSnapshot
extends RefCounted

var zone_id: StringName
var humidity: float
var light_exposure: float
var pollution: float
var connected_zone_ids: Array[StringName] = []
var available: bool
var discovered: bool
var discovered_tick: int


func _init(
	new_zone_id: StringName,
	new_humidity: float,
	new_connected_zone_ids: Array[StringName],
	new_available: bool,
	new_light_exposure: float = 0.5,
	new_pollution: float = 0.0,
	new_discovered: bool = true,
	new_discovered_tick: int = 0
) -> void:
	zone_id = new_zone_id
	humidity = new_humidity
	light_exposure = new_light_exposure
	pollution = new_pollution
	connected_zone_ids.assign(new_connected_zone_ids)
	available = new_available
	discovered = new_discovered
	discovered_tick = new_discovered_tick
