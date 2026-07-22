class_name AntSnapshot
extends RefCounted

var entity_id: int
var life_stage: AntModel.LifeStage
var total_age_ticks: int
var stage_age_ticks: int
var stage_duration_ticks: int


func _init(
	new_entity_id: int,
	new_life_stage: AntModel.LifeStage,
	new_total_age_ticks: int,
	new_stage_age_ticks: int,
	new_stage_duration_ticks: int
) -> void:
	entity_id = new_entity_id
	life_stage = new_life_stage
	total_age_ticks = new_total_age_ticks
	stage_age_ticks = new_stage_age_ticks
	stage_duration_ticks = new_stage_duration_ticks


func get_stage_progress() -> float:
	if stage_duration_ticks <= 0:
		return 1.0
	return clampf(
		float(stage_age_ticks) / float(stage_duration_ticks),
		0.0,
		1.0
	)
