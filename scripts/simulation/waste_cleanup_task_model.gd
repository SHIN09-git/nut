class_name WasteCleanupTaskModel
extends RefCounted

enum State {
	IDLE,
	MOVING_TO_WASTE,
	PICKING_UP,
	CARRYING_TO_TRAY,
	DROPPING,
}

var state: State = State.IDLE
var origin_zone_id: StringName = &""
var source_zone_id: StringName = &""
var target_tray_facility_id: int = -1
var target_zone_id: StringName = &""
var route_zone_ids: Array[StringName] = []
var reserved_amount: float = 0.0
var carried_amount: float = 0.0
var elapsed_ticks: int = 0
var duration_ticks: int = 0
var next_decision_tick: int = 0


func begin(
	new_state: State,
	new_origin_zone_id: StringName,
	new_source_zone_id: StringName,
	new_target_tray_facility_id: int,
	new_target_zone_id: StringName,
	new_route_zone_ids: Array[StringName],
	new_reserved_amount: float,
	new_duration_ticks: int
) -> void:
	state = new_state
	origin_zone_id = new_origin_zone_id
	source_zone_id = new_source_zone_id
	target_tray_facility_id = new_target_tray_facility_id
	target_zone_id = new_target_zone_id
	route_zone_ids.assign(new_route_zone_ids)
	reserved_amount = maxf(new_reserved_amount, 0.0)
	elapsed_ticks = 0
	duration_ticks = maxi(new_duration_ticks, 1)


func reset_to_idle(new_next_decision_tick: int) -> void:
	state = State.IDLE
	origin_zone_id = &""
	source_zone_id = &""
	target_tray_facility_id = -1
	target_zone_id = &""
	route_zone_ids.clear()
	reserved_amount = 0.0
	carried_amount = 0.0
	elapsed_ticks = 0
	duration_ticks = 0
	next_decision_tick = maxi(new_next_decision_tick, 0)


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)


func is_carrying() -> bool:
	return (
		state == State.CARRYING_TO_TRAY
		or state == State.DROPPING
		or carried_amount > 0.0
	)
