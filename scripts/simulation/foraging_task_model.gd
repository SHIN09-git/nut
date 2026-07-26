class_name ForagingTaskModel
extends RefCounted

enum State {
	IDLE,
	SEEKING_FOOD,
	MOVING_TO_FOOD,
	COLLECTING,
	RETURNING_TO_NEST,
	SHARING,
}

var state: State = State.IDLE
var target_food_source_id: int = -1
var origin_zone_id: StringName = &""
var target_zone_id: StringName = &""
var nest_zone_id: StringName = &""
var route_zone_ids: Array[StringName] = []
var route_cache_key: String = ""
var carried_portions: int = 0
var elapsed_ticks: int = 0
var duration_ticks: int = 0


func begin(
	new_state: State,
	new_target_food_source_id: int,
	new_origin_zone_id: StringName,
	new_target_zone_id: StringName,
	new_nest_zone_id: StringName,
	new_route_zone_ids: Array[StringName],
	new_duration_ticks: int
) -> void:
	state = new_state
	target_food_source_id = new_target_food_source_id
	origin_zone_id = new_origin_zone_id
	target_zone_id = new_target_zone_id
	nest_zone_id = new_nest_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	route_cache_key = ""
	elapsed_ticks = 0
	duration_ticks = maxi(new_duration_ticks, 1)


func reset_to_idle() -> void:
	state = State.IDLE
	target_food_source_id = -1
	origin_zone_id = &""
	target_zone_id = &""
	nest_zone_id = &""
	route_zone_ids.clear()
	route_cache_key = ""
	carried_portions = 0
	elapsed_ticks = 0
	duration_ticks = 0


func is_pre_collection() -> bool:
	return (
		state == State.SEEKING_FOOD
		or state == State.MOVING_TO_FOOD
		or state == State.COLLECTING
	)


func is_carrying() -> bool:
	return (
		state == State.RETURNING_TO_NEST
		or state == State.SHARING
	)


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(
		float(elapsed_ticks) / float(duration_ticks),
		0.0,
		1.0
	)


func create_snapshot() -> ForagingTaskSnapshot:
	return ForagingTaskSnapshot.new(
		state,
		target_food_source_id,
		origin_zone_id,
		target_zone_id,
		nest_zone_id,
		route_zone_ids,
		carried_portions,
		elapsed_ticks,
		duration_ticks
	)
