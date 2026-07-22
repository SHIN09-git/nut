class_name LifeStagePresenter
extends RefCounted


static func get_display_name(stage: AntModel.LifeStage) -> String:
	match stage:
		AntModel.LifeStage.EGG:
			return "卵"
		AntModel.LifeStage.LARVA:
			return "幼虫"
		AntModel.LifeStage.PUPA:
			return "蛹"
		AntModel.LifeStage.WORKER:
			return "工蚁"
		_:
			return "未知阶段"
