class_name WorkerTaskModel
extends RefCounted

enum State {
	IDLE,
	MOVING_TO_BROOD,
	PICKING_UP,
	CARRYING_TO_ZONE,
	DROPPING,
}

var state: State = State.IDLE
var origin_zone_id: StringName = &""
var target_brood_id: int = -1
var target_zone_id: StringName = &""
var carried_brood_id: int = -1
var elapsed_ticks: int = 0
var duration_ticks: int = 0
var next_decision_tick: int = 0


func begin(
	new_state: State,
	new_origin_zone_id: StringName,
	new_target_brood_id: int,
	new_target_zone_id: StringName,
	new_duration_ticks: int
) -> void:
	state = new_state
	origin_zone_id = new_origin_zone_id
	target_brood_id = new_target_brood_id
	target_zone_id = new_target_zone_id
	elapsed_ticks = 0
	duration_ticks = maxi(new_duration_ticks, 1)


func reset_to_idle(new_next_decision_tick: int) -> void:
	state = State.IDLE
	origin_zone_id = &""
	target_brood_id = -1
	target_zone_id = &""
	carried_brood_id = -1
	elapsed_ticks = 0
	duration_ticks = 0
	next_decision_tick = new_next_decision_tick


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)
