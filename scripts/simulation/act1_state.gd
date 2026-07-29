class_name Act1State
extends RefCounted

enum QueenCareState {
	RESTING,
	GATHERING,
	BROOD_CARE,
}

var light_cover_applied: bool = false
var light_cover_action_count: int = 0
var queen_care_state: QueenCareState = QueenCareState.RESTING
var queen_care_elapsed_ticks: int = 0
var queen_care_target_brood_id: int = -1
var completed_queen_care_count: int = 0
var pupa_stable_ticks: int = 0
var first_worker_entity_id: int = -1
var first_worker_emerged_tick: int = -1
var first_worker_care_recorded: bool = false
var environment_stable_ticks: int = 0
