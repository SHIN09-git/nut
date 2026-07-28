class_name WasteCleanupTaskSnapshot
extends RefCounted

var state: WasteCleanupTaskModel.State
var origin_zone_id: StringName
var source_zone_id: StringName
var target_tray_facility_id: int
var target_zone_id: StringName
var route_zone_ids: Array[StringName] = []
var reserved_amount: float
var carried_amount: float
var elapsed_ticks: int
var duration_ticks: int


func _init(task: WasteCleanupTaskModel = null) -> void:
	if task == null:
		state = WasteCleanupTaskModel.State.IDLE
		return
	state = task.state
	origin_zone_id = task.origin_zone_id
	source_zone_id = task.source_zone_id
	target_tray_facility_id = task.target_tray_facility_id
	target_zone_id = task.target_zone_id
	route_zone_ids.assign(task.route_zone_ids)
	reserved_amount = task.reserved_amount
	carried_amount = task.carried_amount
	elapsed_ticks = task.elapsed_ticks
	duration_ticks = task.duration_ticks


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(float(elapsed_ticks) / float(duration_ticks), 0.0, 1.0)
