class_name ColonyState
extends RefCounted

const QUEEN_ENTITY_ID: int = 0

var simulation_tick: int = 0
var queen: QueenModel
var ants: Array[AntModel] = []
var _next_entity_id: int = 1


func _init() -> void:
	queen = QueenModel.new(QUEEN_ENTITY_ID)


func create_egg() -> AntModel:
	var egg: AntModel = AntModel.new(_next_entity_id, AntModel.LifeStage.EGG)
	_next_entity_id += 1
	ants.append(egg)
	queen.laid_egg_count += 1
	return egg
