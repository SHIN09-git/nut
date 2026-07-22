class_name HabitatZoneSnapshot
extends RefCounted

var zone_id: StringName
var humidity: float
var connected_zone_ids: Array[StringName] = []
var available: bool


func _init(
	new_zone_id: StringName,
	new_humidity: float,
	new_connected_zone_ids: Array[StringName],
	new_available: bool
) -> void:
	zone_id = new_zone_id
	humidity = new_humidity
	connected_zone_ids.assign(new_connected_zone_ids)
	available = new_available
