class_name MigrationTaskSnapshot
extends RefCounted

var state: MigrationTaskModel.State
var origin_zone_id: StringName
var member_origin_zone_id: StringName
var target_entity_id: int
var target_zone_id: StringName
var carried_entity_id: int
var route_zone_ids: Array[StringName] = []
var returning_to_origin: bool
var elapsed_ticks: int
var duration_ticks: int


func _init(task: MigrationTaskModel = null) -> void:
	if task == null:
		state = MigrationTaskModel.State.IDLE
		target_entity_id = -1
		carried_entity_id = -1
		return
	state = task.state
	origin_zone_id = task.origin_zone_id
	member_origin_zone_id = task.member_origin_zone_id
	target_entity_id = task.target_entity_id
	target_zone_id = task.target_zone_id
	carried_entity_id = task.carried_entity_id
	route_zone_ids.assign(task.route_zone_ids)
	returning_to_origin = task.returning_to_origin
	elapsed_ticks = task.elapsed_ticks
	duration_ticks = task.duration_ticks


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)
