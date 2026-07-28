class_name MigrationTaskModel
extends RefCounted

enum State {
	IDLE,
	MOVING_TO_MEMBER,
	PICKING_UP,
	CARRYING_TO_ZONE,
	DROPPING,
}

var state: State = State.IDLE
var origin_zone_id: StringName = &""
var member_origin_zone_id: StringName = &""
var target_entity_id: int = -1
var target_zone_id: StringName = &""
var carried_entity_id: int = -1
var route_zone_ids: Array[StringName] = []
var returning_to_origin: bool = false
var elapsed_ticks: int = 0
var duration_ticks: int = 0
var next_decision_tick: int = 0


func begin(
	new_state: State,
	new_origin_zone_id: StringName,
	new_member_origin_zone_id: StringName,
	new_target_entity_id: int,
	new_target_zone_id: StringName,
	new_route_zone_ids: Array[StringName],
	new_duration_ticks: int
) -> void:
	state = new_state
	origin_zone_id = new_origin_zone_id
	member_origin_zone_id = new_member_origin_zone_id
	target_entity_id = new_target_entity_id
	target_zone_id = new_target_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	elapsed_ticks = 0
	duration_ticks = maxi(new_duration_ticks, 1)


func reset_to_idle(new_next_decision_tick: int) -> void:
	state = State.IDLE
	origin_zone_id = &""
	member_origin_zone_id = &""
	target_entity_id = -1
	target_zone_id = &""
	carried_entity_id = -1
	route_zone_ids.clear()
	returning_to_origin = false
	elapsed_ticks = 0
	duration_ticks = 0
	next_decision_tick = maxi(new_next_decision_tick, 0)


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)


func is_carrying() -> bool:
	return (
		state == State.CARRYING_TO_ZONE
		or state == State.DROPPING
		or carried_entity_id >= 0
	)
