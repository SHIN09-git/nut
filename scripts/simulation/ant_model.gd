class_name AntModel
extends RefCounted

enum LifeStage {
	EGG,
	LARVA,
	PUPA,
	WORKER,
}

var entity_id: int
var life_stage: LifeStage
var total_age_ticks: int = 0
var stage_age_ticks: int = 0
var zone_id: StringName = &""
var zone_entered_tick: int = 0
var protein_supported_growth_ticks: int = 0
var worker_task: WorkerTaskModel
var foraging_task: ForagingTaskModel
var feeding_task: BroodFeedingTaskModel


func _init(
	new_entity_id: int,
	initial_stage: LifeStage = LifeStage.EGG
) -> void:
	entity_id = new_entity_id
	life_stage = initial_stage


func transition_to(next_stage: LifeStage) -> void:
	life_stage = next_stage
	stage_age_ticks = 0


func configure_brood(
	new_zone_id: StringName,
	new_zone_entered_tick: int
) -> void:
	zone_id = new_zone_id
	zone_entered_tick = new_zone_entered_tick
	worker_task = null
	foraging_task = null
	feeding_task = null


func configure_worker(
	new_zone_id: StringName,
	next_decision_tick: int
) -> void:
	life_stage = LifeStage.WORKER
	zone_id = new_zone_id
	zone_entered_tick = 0
	worker_task = WorkerTaskModel.new()
	worker_task.next_decision_tick = next_decision_tick
	foraging_task = ForagingTaskModel.new()
	protein_supported_growth_ticks = 0


func configure_nutrition_worker(
	new_zone_id: StringName,
	next_decision_tick: int
) -> void:
	configure_worker(new_zone_id, next_decision_tick)
	feeding_task = BroodFeedingTaskModel.new()
	feeding_task.next_decision_tick = next_decision_tick
