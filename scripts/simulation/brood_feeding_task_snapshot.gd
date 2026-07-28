class_name BroodFeedingTaskSnapshot
extends RefCounted

var state: BroodFeedingTaskModel.State
var target_brood_id: int
var origin_zone_id: StringName
var target_zone_id: StringName
var route_zone_ids: Array[StringName] = []
var elapsed_ticks: int
var duration_ticks: int


func _init(
	new_state: BroodFeedingTaskModel.State = (
		BroodFeedingTaskModel.State.IDLE
	),
	new_target_brood_id: int = -1,
	new_origin_zone_id: StringName = &"",
	new_target_zone_id: StringName = &"",
	new_route_zone_ids: Array[StringName] = [],
	new_elapsed_ticks: int = 0,
	new_duration_ticks: int = 0
) -> void:
	state = new_state
	target_brood_id = new_target_brood_id
	origin_zone_id = new_origin_zone_id
	target_zone_id = new_target_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	elapsed_ticks = new_elapsed_ticks
	duration_ticks = new_duration_ticks


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(
		float(elapsed_ticks) / float(duration_ticks),
		0.0,
		1.0
	)
