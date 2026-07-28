class_name AntSnapshot
extends RefCounted

var entity_id: int
var life_stage: AntModel.LifeStage
var total_age_ticks: int
var stage_age_ticks: int
var stage_duration_ticks: int
var zone_id: StringName
var zone_entered_tick: int
var reserved_by_ant_id: int
var carrier_ant_id: int
var worker_task_state: int
var task_origin_zone_id: StringName
var target_brood_id: int
var target_zone_id: StringName
var carried_brood_id: int
var task_elapsed_ticks: int
var task_duration_ticks: int
var foraging_task: ForagingTaskSnapshot
var protein_supported_growth_ticks: int
var feeding_task: BroodFeedingTaskSnapshot
var waste_cleanup_task: WasteCleanupTaskSnapshot
var scout_task: ScoutTaskSnapshot
var migration_task: MigrationTaskSnapshot


func _init(
	new_entity_id: int,
	new_life_stage: AntModel.LifeStage,
	new_total_age_ticks: int,
	new_stage_age_ticks: int,
	new_stage_duration_ticks: int,
	new_zone_id: StringName = &"",
	new_zone_entered_tick: int = 0,
	new_reserved_by_ant_id: int = -1,
	new_carrier_ant_id: int = -1,
	new_worker_task_state: int = WorkerTaskModel.State.IDLE,
	new_task_origin_zone_id: StringName = &"",
	new_target_brood_id: int = -1,
	new_target_zone_id: StringName = &"",
	new_carried_brood_id: int = -1,
	new_task_elapsed_ticks: int = 0,
	new_task_duration_ticks: int = 0,
	new_foraging_task: ForagingTaskSnapshot = null,
	new_protein_supported_growth_ticks: int = 0,
	new_feeding_task: BroodFeedingTaskSnapshot = null,
	new_waste_cleanup_task: WasteCleanupTaskSnapshot = null,
	new_scout_task: ScoutTaskSnapshot = null,
	new_migration_task: MigrationTaskSnapshot = null
) -> void:
	entity_id = new_entity_id
	life_stage = new_life_stage
	total_age_ticks = new_total_age_ticks
	stage_age_ticks = new_stage_age_ticks
	stage_duration_ticks = new_stage_duration_ticks
	zone_id = new_zone_id
	zone_entered_tick = new_zone_entered_tick
	reserved_by_ant_id = new_reserved_by_ant_id
	carrier_ant_id = new_carrier_ant_id
	worker_task_state = new_worker_task_state
	task_origin_zone_id = new_task_origin_zone_id
	target_brood_id = new_target_brood_id
	target_zone_id = new_target_zone_id
	carried_brood_id = new_carried_brood_id
	task_elapsed_ticks = new_task_elapsed_ticks
	task_duration_ticks = new_task_duration_ticks
	foraging_task = new_foraging_task
	protein_supported_growth_ticks = maxi(
		new_protein_supported_growth_ticks,
		0
	)
	feeding_task = new_feeding_task
	waste_cleanup_task = new_waste_cleanup_task
	scout_task = new_scout_task
	migration_task = new_migration_task


func get_stage_progress() -> float:
	if stage_duration_ticks <= 0:
		return 1.0
	return clampf(
		float(stage_age_ticks) / float(stage_duration_ticks),
		0.0,
		1.0
	)


func get_task_progress() -> float:
	if task_duration_ticks <= 0:
		return 0.0
	return clampf(
		float(task_elapsed_ticks) / float(task_duration_ticks),
		0.0,
		1.0
	)
