class_name QueenCareSnapshot
extends RefCounted

var active: bool = false
var light_cover_applied: bool = false
var light_cover_action_available: bool = false
var light_cover_action_pending: bool = false
var care_state: Act1State.QueenCareState = Act1State.QueenCareState.RESTING
var elapsed_ticks: int = 0
var duration_ticks: int = 0
var target_brood_id: int = -1
var completed_care_count: int = 0
var pupa_stable_ticks: int = 0


func get_progress() -> float:
	if duration_ticks <= 0:
		return 0.0
	return clampf(
		float(elapsed_ticks) / float(duration_ticks),
		0.0,
		1.0
	)
