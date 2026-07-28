class_name ColonyWorkState
extends RefCounted

var migration_candidate_zone_id: StringName = &""
var migration_candidate_stable_ticks: int = 0
var migration_target_zone_id: StringName = &""
var completed_migration_count: int = 0
var scouted_zone_count: int = 0
var delivered_waste_batch_count: int = 0
var cleaned_waste_tray_count: int = 0


func duplicate_state() -> ColonyWorkState:
	var copied := ColonyWorkState.new()
	copied.migration_candidate_zone_id = migration_candidate_zone_id
	copied.migration_candidate_stable_ticks = migration_candidate_stable_ticks
	copied.migration_target_zone_id = migration_target_zone_id
	copied.completed_migration_count = completed_migration_count
	copied.scouted_zone_count = scouted_zone_count
	copied.delivered_waste_batch_count = delivered_waste_batch_count
	copied.cleaned_waste_tray_count = cleaned_waste_tray_count
	return copied
