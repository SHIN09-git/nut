class_name ForagingTaskSnapshot
extends RefCounted

enum State {
	IDLE,
	SEEKING_FOOD,
	MOVING_TO_FOOD,
	COLLECTING,
	RETURNING_TO_NEST,
	SHARING,
}

var state: int
var target_food_source_id: int
var origin_zone_id: StringName
var target_zone_id: StringName
var nest_zone_id: StringName
var route_zone_ids: Array[StringName] = []
var carried_portions: int
var elapsed_ticks: int
var duration_ticks: int


func _init(
	new_state: int = State.IDLE,
	new_target_food_source_id: int = -1,
	new_origin_zone_id: StringName = &"",
	new_target_zone_id: StringName = &"",
	new_nest_zone_id: StringName = &"",
	new_route_zone_ids: Array[StringName] = [],
	new_carried_portions: int = 0,
	new_elapsed_ticks: int = 0,
	new_duration_ticks: int = 0
) -> void:
	state = new_state
	target_food_source_id = new_target_food_source_id
	origin_zone_id = new_origin_zone_id
	target_zone_id = new_target_zone_id
	nest_zone_id = new_nest_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	carried_portions = new_carried_portions
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
