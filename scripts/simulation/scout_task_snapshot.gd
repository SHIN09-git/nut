class_name ScoutTaskSnapshot
extends RefCounted

var state: ScoutTaskModel.State
var origin_zone_id: StringName
var target_zone_id: StringName
var route_zone_ids: Array[StringName] = []
var elapsed_ticks: int
var duration_ticks: int


func _init(task: ScoutTaskModel = null) -> void:
	if task == null:
		state = ScoutTaskModel.State.IDLE
		return
	state = task.state
	origin_zone_id = task.origin_zone_id
	target_zone_id = task.target_zone_id
	route_zone_ids.assign(task.route_zone_ids)
	elapsed_ticks = task.elapsed_ticks
	duration_ticks = task.duration_ticks


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)
