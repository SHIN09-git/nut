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


func _init(
	new_entity_id: int,
	initial_stage: LifeStage = LifeStage.EGG
) -> void:
	entity_id = new_entity_id
	life_stage = initial_stage


func transition_to(next_stage: LifeStage) -> void:
	life_stage = next_stage
	stage_age_ticks = 0


static func get_stage_display_name(stage: LifeStage) -> String:
	match stage:
		LifeStage.EGG:
			return "卵"
		LifeStage.LARVA:
			return "幼虫"
		LifeStage.PUPA:
			return "蛹"
		LifeStage.WORKER:
			return "工蚁"
		_:
			return "未知阶段"
