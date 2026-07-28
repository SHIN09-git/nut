class_name ScoutTaskModel
extends RefCounted

enum State {
	IDLE,
	MOVING_TO_ZONE,
	OBSERVING,
	RETURNING,
}

var state: State = State.IDLE
var origin_zone_id: StringName = &""
var target_zone_id: StringName = &""
var route_zone_ids: Array[StringName] = []
var elapsed_ticks: int = 0
var duration_ticks: int = 0
var next_decision_tick: int = 0


func begin(
	new_state: State,
	new_origin_zone_id: StringName,
	new_target_zone_id: StringName,
	new_route_zone_ids: Array[StringName],
	new_duration_ticks: int
) -> void:
	state = new_state
	origin_zone_id = new_origin_zone_id
	target_zone_id = new_target_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	elapsed_ticks = 0
	duration_ticks = maxi(new_duration_ticks, 1)


func reset_to_idle(new_next_decision_tick: int) -> void:
	state = State.IDLE
	origin_zone_id = &""
	target_zone_id = &""
	route_zone_ids.clear()
	elapsed_ticks = 0
	duration_ticks = 0
	next_decision_tick = maxi(new_next_decision_tick, 0)


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)
