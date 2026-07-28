class_name ColonyWorkSnapshot
extends RefCounted

var active: bool = false
var migration_candidate_zone_id: StringName = &""
var migration_candidate_stable_ticks: int = 0
var migration_target_zone_id: StringName = &""
var completed_migration_count: int = 0
var scouted_zone_count: int = 0
var delivered_waste_batch_count: int = 0
var cleaned_waste_tray_count: int = 0
var cleanable_tray_facility_ids: Array[int] = []
var clean_action_pending_facility_id: int = -1
var active_waste_task_count: int = 0
var active_scout_task_count: int = 0
var active_migration_task_count: int = 0
