class_name Act1Snapshot
extends RefCounted

var active: bool = false
var queen_care: QueenCareSnapshot
var first_worker_entity_id: int = -1
var first_worker_emerged_tick: int = -1
var first_worker_care_recorded: bool = false
var environment_stable_ticks: int = 0
var environment_stable_required_ticks: int = 0
